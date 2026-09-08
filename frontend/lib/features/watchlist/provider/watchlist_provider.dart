import 'dart:async';
import 'dart:convert';

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
      final jsonStr = await secureStorage.readWatchlistJson();
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
        _items = decoded
            .map((item) => WatchlistItem.fromJson(item as Map<String, dynamic>))
            .toList();
        notifyListeners();
      } else {
        // Fallback for backward compatibility if only raw tokens were stored
        final tokens = await secureStorage.readWatchlistTokens();
        if (tokens.isNotEmpty) {
          _items = tokens
              .map((t) => WatchlistItem(
                    instrumentToken: t,
                    tradingsymbol: 'Token $t',
                    exchange: '',
                  ))
              .toList();
          notifyListeners();
        }
      }

      if (_items.isNotEmpty) {
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
    final hasValidSymbol = update.tradingsymbol != null &&
        update.tradingsymbol!.isNotEmpty &&
        update.tradingsymbol != 'Loading...';

    _items[idx] = old.copyWith(
      tradingsymbol: hasValidSymbol ? update.tradingsymbol! : old.tradingsymbol,
      exchange: (update.exchange != null && update.exchange!.isNotEmpty)
          ? update.exchange!
          : old.exchange,
      lastPrice: update.lastPrice,
      change: update.change ?? old.change,
      changePercent: update.changePercent ?? old.changePercent,
      isLoading: false,
    );

    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> addInstrument(InstrumentResult instrument) async {
    // Prevent duplicates
    if (_items.any((i) => i.instrumentToken == instrument.instrumentToken)) {
      return;
    }

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

  Future<void> reconnectWs() async {
    _subscribeToWsStream();
    if (_items.isNotEmpty) {
      wsService.disconnect();
      await wsService.connect(instrumentTokens);
    }
    await refreshQuotes();
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
        for (int i = 0; i < _items.length; i++) {
          if (_items[i].isLoading) {
            _items[i] = _items[i].copyWith(isLoading: false);
          }
        }
        _persistItems();
        notifyListeners();
      },
      onFailure: (f) {
        debugPrint('[Watchlist] refreshQuotes error: ${f.message}');
        for (int i = 0; i < _items.length; i++) {
          if (_items[i].isLoading) {
            _items[i] = _items[i].copyWith(isLoading: false);
          }
        }
        notifyListeners();
      },
    );

    // Fallback: If price is 0, query latest candle close price
    await _fillMissingQuotesWithCandles();
    // Resolve any legacy 'Token 123...' names to real symbols
    await _resolveUnknownSymbols();
  }

  static const Map<int, Map<String, String>> _knownTokens = {
    256265: {'symbol': 'NIFTY 50', 'exchange': 'NSE'},
    260105: {'symbol': 'NIFTY BANK', 'exchange': 'NSE'},
    257801: {'symbol': 'NIFTY FIN SERVICE', 'exchange': 'NSE'},
    261897: {'symbol': 'NIFTY IT', 'exchange': 'NSE'},
    265: {'symbol': 'SENSEX', 'exchange': 'BSE'},
    738561: {'symbol': 'RELIANCE', 'exchange': 'NSE'},
    2953217: {'symbol': 'TCS', 'exchange': 'NSE'},
    408065: {'symbol': 'INFY', 'exchange': 'NSE'},
    341249: {'symbol': 'HDFCBANK', 'exchange': 'NSE'},
    1270529: {'symbol': 'ICICIBANK', 'exchange': 'NSE'},
    779521: {'symbol': 'SBIN', 'exchange': 'NSE'},
    81153: {'symbol': 'BAJFINANCE', 'exchange': 'NSE'},
    3861249: {'symbol': 'KOTAKBANK', 'exchange': 'NSE'},
    3452673: {'symbol': 'BHARTIARTL', 'exchange': 'NSE'},
    895745: {'symbol': 'TATAMOTORS', 'exchange': 'NSE'},
    897537: {'symbol': 'TATASTEEL', 'exchange': 'NSE'},
    340481: {'symbol': 'HCLTECH', 'exchange': 'NSE'},
    2939649: {'symbol': 'LT', 'exchange': 'NSE'},
    3771393: {'symbol': 'WIPRO', 'exchange': 'NSE'},
    134657: {'symbol': 'ITC', 'exchange': 'NSE'},
  };

  Future<void> _fillMissingQuotesWithCandles() async {
    bool hasUpdates = false;
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].lastPrice <= 0) {
        final candleResult =
            await _api.getRecentCandles(_items[i].instrumentToken);
        candleResult.fold(
          onSuccess: (candles) {
            if (candles.isNotEmpty) {
              final last = candles.last;
              final close = (last['close'] as num?)?.toDouble();
              final open = (last['open'] as num?)?.toDouble();
              if (close != null && close > 0) {
                final change =
                    (open != null && open > 0) ? (close - open) : 0.0;
                final changePercent = (open != null && open > 0)
                    ? (change / open) * 100
                    : 0.0;
                final exchange = last['exchange']?.toString();
                _items[i] = _items[i].copyWith(
                  lastPrice: close,
                  change: change,
                  changePercent: changePercent,
                  exchange: (exchange != null && exchange.isNotEmpty)
                      ? exchange
                      : (_items[i].exchange.isNotEmpty
                          ? _items[i].exchange
                          : 'NSE'),
                  isLoading: false,
                );
                hasUpdates = true;
              }
            } else {
              if (_items[i].isLoading) {
                _items[i] = _items[i].copyWith(isLoading: false);
                hasUpdates = true;
              }
            }
          },
          onFailure: (_) {
            if (_items[i].isLoading) {
              _items[i] = _items[i].copyWith(isLoading: false);
              hasUpdates = true;
            }
          },
        );
      }
    }
    if (hasUpdates) {
      await _persistItems();
      notifyListeners();
    }
  }

  Future<void> _resolveUnknownSymbols() async {
    bool hasUpdates = false;
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].tradingsymbol.startsWith('Token ') ||
          _items[i].tradingsymbol.isEmpty) {
        final token = _items[i].instrumentToken;
        if (_knownTokens.containsKey(token)) {
          final info = _knownTokens[token]!;
          _items[i] = _items[i].copyWith(
            tradingsymbol: info['symbol']!,
            exchange: info['exchange']!,
          );
          hasUpdates = true;
          continue;
        }

        final resolved = await _api.resolveTradingSymbol(token);
        if (resolved != null &&
            resolved['symbol'] != null &&
            resolved['symbol']!.isNotEmpty) {
          _items[i] = _items[i].copyWith(
            tradingsymbol: resolved['symbol']!,
            exchange: (resolved['exchange'] != null &&
                    resolved['exchange']!.isNotEmpty)
                ? resolved['exchange']!
                : (_items[i].exchange.isNotEmpty ? _items[i].exchange : 'NSE'),
          );
          hasUpdates = true;
        }
      }
    }
    if (hasUpdates) {
      await _persistItems();
      notifyListeners();
    }
  }

  void _applyQuote(Map<String, dynamic> q) {
    final token = (q['instrumentToken'] as num?)?.toInt() ??
        (q['instrument_token'] as num?)?.toInt();
    if (token == null) return;

    final idx = _items.indexWhere((i) => i.instrumentToken == token);
    if (idx == -1) return;

    final old = _items[idx];
    final serverSymbol = q['tradingsymbol']?.toString();
    final tradingsymbol = (serverSymbol != null &&
            serverSymbol.isNotEmpty &&
            serverSymbol != 'Loading...' &&
            !serverSymbol.startsWith('Token '))
        ? serverSymbol
        : old.tradingsymbol;

    final serverExchange = q['exchange']?.toString();
    final exchange = (serverExchange != null && serverExchange.isNotEmpty)
        ? serverExchange
        : old.exchange;

    final incomingPrice = (q['lastPrice'] as num?)?.toDouble() ??
        (q['last_price'] as num?)?.toDouble();
    final lastPrice = (incomingPrice != null && incomingPrice > 0)
        ? incomingPrice
        : old.lastPrice;

    final change = (q['change'] as num?)?.toDouble() ?? old.change;
    final changePercent = (q['changePercent'] as num?)?.toDouble() ??
        (q['change_percent'] as num?)?.toDouble() ??
        old.changePercent;

    _items[idx] = WatchlistItem(
      instrumentToken: token,
      tradingsymbol: tradingsymbol,
      exchange: exchange,
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
    final jsonList = _items.map((i) => i.toJson()).toList();
    await secureStorage.saveWatchlistJson(jsonEncode(jsonList));
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _quoteSub?.cancel();
    super.dispose();
  }
}
