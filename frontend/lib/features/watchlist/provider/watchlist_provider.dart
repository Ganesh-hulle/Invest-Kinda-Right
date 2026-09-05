import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/websocket/market_ws_service.dart';
import '../data/watchlist_api.dart';
import '../model/watchlist_models.dart';

class WatchlistProvider extends ChangeNotifier {
  final DioClient dioClient;
  final SecureStorage secureStorage;
  final MarketWsService wsService;

  late final WatchlistApi _api;

  List<WatchlistItem> _items = [];
  bool _isLoading = false;
  StreamSubscription<QuoteUpdate>? _quoteSub;

  WatchlistProvider({
    required this.dioClient,
    required this.secureStorage,
    required this.wsService,
  }) {
    _api = WatchlistApi(dioClient: dioClient);
    init();
  }

  List<WatchlistItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;

  /// Returns instrument tokens for all watchlist items (used by dashboard EMA signals).
  List<int> get instrumentTokens =>
      _items.map((i) => i.instrumentToken).toList();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final tokens = await secureStorage.readWatchlistTokens();
      if (tokens.isNotEmpty) {
        // Build item stubs from stored tokens while we fetch real data
        _items = tokens
            .map((t) => WatchlistItem(
                  instrumentToken: t,
                  tradingsymbol: 'Loading...',
                  exchange: '',
                ))
            .toList();
        notifyListeners();
        await refreshQuotes();
      }
    } catch (e) {
      debugPrint('[Watchlist] init error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    _subscribeToWsStream();
    _connectWsIfNeeded();
  }

  void _subscribeToWsStream() {
    _quoteSub?.cancel();
    _quoteSub = wsService.quoteStream.listen(_onQuoteUpdate);
  }

  void _connectWsIfNeeded() {
    if (_items.isEmpty) return;
    if (!wsService.isConnected) {
      wsService.connect(instrumentTokens);
    } else {
      wsService.subscribe(instrumentTokens);
    }
  }

  // ── Real-time updates ─────────────────────────────────────────────────────

  void _onQuoteUpdate(QuoteUpdate update) {
    final idx =
        _items.indexWhere((i) => i.instrumentToken == update.instrumentToken);
    if (idx == -1) return;

    final old = _items[idx];
    _items[idx] = old.copyWith(
      lastPrice: update.lastPrice,
      change: update.change ?? old.change,
      changePercent: update.changePercent ?? old.changePercent,
      isLoading: false,
    );

    // Update tradingsymbol/exchange from WS if available
    if (update.tradingsymbol != null &&
        _items[idx].tradingsymbol == 'Loading...') {
      _items[idx] = WatchlistItem(
        instrumentToken: update.instrumentToken,
        tradingsymbol: update.tradingsymbol!,
        exchange: update.exchange ?? old.exchange,
        lastPrice: update.lastPrice,
        change: update.change ?? 0,
        changePercent: update.changePercent ?? 0,
      );
    }

    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> addInstrument(InstrumentResult instrument) async {
    // Prevent duplicates
    if (_items.any((i) => i.instrumentToken == instrument.instrumentToken))
      return;

    final newItem = WatchlistItem(
      instrumentToken: instrument.instrumentToken,
      tradingsymbol: instrument.tradingsymbol,
      exchange: instrument.exchange,
      isLoading: true,
    );
    _items.add(newItem);
    notifyListeners();

    await _persistItems();

    // Fetch quote for the new instrument
    final result = await _api.getQuotes([instrument.instrumentToken]);
    result.fold(
      onSuccess: (quotes) {
        if (quotes.isNotEmpty) {
          _applyQuote(quotes.first);
        } else {
          final idx = _items.indexWhere(
              (i) => i.instrumentToken == instrument.instrumentToken);
          if (idx != -1) _items[idx] = _items[idx].copyWith(isLoading: false);
        }
        notifyListeners();
      },
      onFailure: (_) {
        final idx = _items
            .indexWhere((i) => i.instrumentToken == instrument.instrumentToken);
        if (idx != -1) _items[idx] = _items[idx].copyWith(isLoading: false);
        notifyListeners();
      },
    );

    // Subscribe to WS
    if (wsService.isConnected) {
      wsService.subscribe([instrument.instrumentToken]);
    } else {
      wsService.connect(instrumentTokens);
    }
  }

  Future<void> removeInstrument(int token) async {
    _items.removeWhere((i) => i.instrumentToken == token);
    notifyListeners();
    await _persistItems();
  }

  Future<void> refreshQuotes() async {
    if (_items.isEmpty) return;
    final tokens = _items.map((i) => i.instrumentToken).toList();
    final result = await _api.getQuotes(tokens);
    result.fold(
      onSuccess: (quotes) {
        for (final q in quotes) {
          _applyQuote(q);
        }
        notifyListeners();
      },
      onFailure: (f) =>
          debugPrint('[Watchlist] refreshQuotes error: ${f.message}'),
    );
  }

  void _applyQuote(Map<String, dynamic> q) {
    final token = (q['instrumentToken'] as num?)?.toInt() ??
        (q['instrument_token'] as num?)?.toInt();
    if (token == null) return;

    final idx = _items.indexWhere((i) => i.instrumentToken == token);
    if (idx == -1) return;

    final old = _items[idx];
    final tradingsymbol = q['tradingsymbol']?.toString() ?? old.tradingsymbol;
    final exchange = q['exchange']?.toString() ?? old.exchange;
    final lastPrice = (q['lastPrice'] as num?)?.toDouble() ??
        (q['last_price'] as num?)?.toDouble() ??
        old.lastPrice;
    final change = (q['change'] as num?)?.toDouble() ?? old.change;
    final changePercent = (q['changePercent'] as num?)?.toDouble() ??
        (q['change_percent'] as num?)?.toDouble() ??
        old.changePercent;

    _items[idx] = WatchlistItem(
      instrumentToken: token,
      tradingsymbol:
          tradingsymbol == 'Loading...' ? old.tradingsymbol : tradingsymbol,
      exchange: exchange.isEmpty ? old.exchange : exchange,
      lastPrice: lastPrice,
      change: change,
      changePercent: changePercent,
      isLoading: false,
    );
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _persistItems() async {
    final tokens = _items.map((i) => i.instrumentToken).toList();
    await secureStorage.saveWatchlistTokens(tokens);
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _quoteSub?.cancel();
    super.dispose();
  }
}
