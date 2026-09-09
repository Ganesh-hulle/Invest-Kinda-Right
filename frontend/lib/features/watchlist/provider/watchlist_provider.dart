import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/websocket/market_ws_service.dart';
import '../data/watchlist_api.dart';
import '../model/watchlist_models.dart';

enum WatchlistFilter { all, gainers, losers, alphabetical }

class WatchlistProvider extends ChangeNotifier {
  final DioClient dioClient;
  final SecureStorage secureStorage;
  final MarketWsService wsService;

  late final WatchlistApi _api;

  List<WatchlistItem> _items = [];
  bool _isLoading = false;
  bool _isConnectingKite = false;
  String? _kiteFeedStatus;
  StreamSubscription<QuoteUpdate>? _quoteSub;
  WatchlistFilter _currentFilter = WatchlistFilter.all;

  // Zerodha-style top market indices
  WatchlistItem _nifty50 = const WatchlistItem(
    instrumentToken: 256265,
    tradingsymbol: 'NIFTY 50',
    exchange: 'NSE',
    lastPrice: 0.0,
  );

  WatchlistItem _sensex = const WatchlistItem(
    instrumentToken: 265,
    tradingsymbol: 'SENSEX',
    exchange: 'BSE',
    lastPrice: 0.0,
  );

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
  bool get isConnectingKite => _isConnectingKite;
  String? get kiteFeedStatus => _kiteFeedStatus;
  WatchlistFilter get currentFilter => _currentFilter;
  WatchlistItem get nifty50 => _nifty50;
  WatchlistItem get sensex => _sensex;

  /// Returns instrument tokens for all watchlist items (used by dashboard EMA signals).
  List<int> get instrumentTokens =>
      _items.map((i) => i.instrumentToken).toList();

  /// Returns all tokens including market indices for comprehensive streaming.
  List<int> get allStreamingTokens => <int>{
        ...instrumentTokens,
        _nifty50.instrumentToken,
        _sensex.instrumentToken,
      }.toList();

  /// Filtered and sorted watchlist items according to current filter.
  List<WatchlistItem> get filteredItems {
    switch (_currentFilter) {
      case WatchlistFilter.gainers:
        final gainers = _items.where((i) => i.change > 0).toList();
        gainers.sort((a, b) => b.changePercent.compareTo(a.changePercent));
        return gainers;
      case WatchlistFilter.losers:
        final losers = _items.where((i) => i.change < 0).toList();
        losers.sort((a, b) => a.changePercent.compareTo(b.changePercent));
        return losers;
      case WatchlistFilter.alphabetical:
        final sorted = List<WatchlistItem>.from(_items);
        sorted.sort((a, b) => a.tradingsymbol.compareTo(b.tradingsymbol));
        return sorted;
      case WatchlistFilter.all:
        return List.unmodifiable(_items);
    }
  }

  void setFilter(WatchlistFilter filter) {
    if (_currentFilter == filter) return;
    _currentFilter = filter;
    notifyListeners();
  }

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

    await onWatchlistOpened();
  }

  /// Primary orchestration invoked whenever the user opens the Watchlist section.
  /// Connects to existing live market data APIs: REST snapshot quotes, internal
  /// market WebSocket, and backend Kite ticker stream.
  Future<void> onWatchlistOpened() async {
    _subscribeToWsStream();

    final tokens = allStreamingTokens;

    // 1. Fetch REST snapshot quotes immediately so prices appear right away
    unawaited(refreshQuotes());

    // 2. Connect and subscribe the internal WebSocket
    if (!wsService.isConnected) {
      unawaited(wsService.connect(tokens));
    } else {
      wsService.subscribe(tokens);
    }

    // 3. Connect backend Kite market data feed for live binary ticks
    unawaited(_connectKiteFeed(tokens));
  }

  Future<void> _connectKiteFeed(List<int> tokens) async {
    if (tokens.isEmpty) return;
    _isConnectingKite = true;
    notifyListeners();

    try {
      final result = await _api.connectKiteMarketData(tokens);
      result.fold(
        onSuccess: (_) {
          _kiteFeedStatus = 'CONNECTED';
          debugPrint('[Watchlist] Kite market data feed connected for ${tokens.length} instruments');
        },
        onFailure: (f) {
          _kiteFeedStatus = 'DISCONNECTED';
          debugPrint('[Watchlist] Kite market data feed notice: ${f.message}');
        },
      );
    } catch (e) {
      _kiteFeedStatus = 'ERROR';
      debugPrint('[Watchlist] Kite market data connect error: $e');
    } finally {
      _isConnectingKite = false;
      notifyListeners();
    }
  }

  void _subscribeToWsStream() {
    _quoteSub?.cancel();
    _quoteSub = wsService.quoteStream.listen(_onQuoteUpdate);
  }

  // ── Real-time updates ─────────────────────────────────────────────────────

  void _onQuoteUpdate(QuoteUpdate update) {
    final token = update.instrumentToken;
    final newPrice = update.lastPrice;

    // Handle NIFTY 50 index update
    if (token == _nifty50.instrumentToken) {
      final oldPrice = _nifty50.lastPrice;
      PriceDirection dir = PriceDirection.none;
      if (oldPrice > 0) {
        if (newPrice > oldPrice) dir = PriceDirection.up;
        if (newPrice < oldPrice) dir = PriceDirection.down;
      }

      double close = (update.closePrice != null && update.closePrice! > 0)
          ? update.closePrice!
          : _nifty50.closePrice;
      if (close <= 0) {
        close = (_nifty50.change != 0 && oldPrice > 0)
            ? (oldPrice - _nifty50.change)
            : newPrice;
      }

      final change = update.change ??
          (close > 0 ? (newPrice - close) : _nifty50.change);
      final changePercent = update.changePercent ??
          (close > 0 ? (change / close) * 100.0 : _nifty50.changePercent);

      _nifty50 = _nifty50.copyWith(
        lastPrice: newPrice,
        closePrice: close,
        change: change,
        changePercent: changePercent,
        previousPrice: oldPrice > 0 ? oldPrice : newPrice,
        priceDirection: dir,
        lastUpdated: DateTime.now(),
      );
      notifyListeners();
      return;
    }

    // Handle SENSEX index update
    if (token == _sensex.instrumentToken) {
      final oldPrice = _sensex.lastPrice;
      PriceDirection dir = PriceDirection.none;
      if (oldPrice > 0) {
        if (newPrice > oldPrice) dir = PriceDirection.up;
        if (newPrice < oldPrice) dir = PriceDirection.down;
      }

      double close = (update.closePrice != null && update.closePrice! > 0)
          ? update.closePrice!
          : _sensex.closePrice;
      if (close <= 0) {
        close = (_sensex.change != 0 && oldPrice > 0)
            ? (oldPrice - _sensex.change)
            : newPrice;
      }

      final change = update.change ??
          (close > 0 ? (newPrice - close) : _sensex.change);
      final changePercent = update.changePercent ??
          (close > 0 ? (change / close) * 100.0 : _sensex.changePercent);

      _sensex = _sensex.copyWith(
        lastPrice: newPrice,
        closePrice: close,
        change: change,
        changePercent: changePercent,
        previousPrice: oldPrice > 0 ? oldPrice : newPrice,
        priceDirection: dir,
        lastUpdated: DateTime.now(),
      );
      notifyListeners();
      return;
    }

    // Handle regular watchlist item update
    final idx = _items.indexWhere((i) => i.instrumentToken == token);
    if (idx == -1) return;

    final old = _items[idx];
    final oldPrice = old.lastPrice;

    // Detect price movement direction for Zerodha flash animation
    PriceDirection dir = PriceDirection.none;
    if (oldPrice > 0) {
      if (newPrice > oldPrice) {
        dir = PriceDirection.up;
      } else if (newPrice < oldPrice) {
        dir = PriceDirection.down;
      }
    }

    // Determine close/base price to compute dynamic change & change% on raw ticks
    double close = (update.closePrice != null && update.closePrice! > 0)
        ? update.closePrice!
        : old.closePrice;
    if (close <= 0) {
      if (update.change != null && update.change != 0 && newPrice > 0) {
        close = newPrice - update.change!;
      } else if (old.change != 0 && oldPrice > 0) {
        close = oldPrice - old.change;
      } else {
        close = newPrice;
      }
    }

    final change = update.change ??
        (close > 0 && newPrice > 0 && close != newPrice ? (newPrice - close) : old.change);
    final changePercent = update.changePercent ??
        (close > 0 ? (change / close) * 100.0 : old.changePercent);

    final hasValidSymbol = update.tradingsymbol != null &&
        update.tradingsymbol!.isNotEmpty &&
        update.tradingsymbol != 'Loading...';

    _items[idx] = old.copyWith(
      tradingsymbol: hasValidSymbol ? update.tradingsymbol! : old.tradingsymbol,
      exchange: (update.exchange != null && update.exchange!.isNotEmpty)
          ? update.exchange!
          : old.exchange,
      lastPrice: newPrice,
      closePrice: close,
      change: change,
      changePercent: changePercent,
      previousPrice: oldPrice > 0 ? oldPrice : newPrice,
      priceDirection: dir,
      lastUpdated: DateTime.now(),
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
    wsService.subscribe([instrument.instrumentToken]);
    unawaited(_connectKiteFeed(allStreamingTokens));
  }

  Future<void> removeInstrument(int token) async {
    _items.removeWhere((i) => i.instrumentToken == token);
    notifyListeners();
    await _persistItems();
  }

  Future<void> reconnectWs() async {
    _subscribeToWsStream();
    final tokens = allStreamingTokens;
    if (tokens.isNotEmpty) {
      await wsService.forceReconnect();
      unawaited(_connectKiteFeed(tokens));
    }
    await refreshQuotes();
  }

  Future<void> refreshQuotes() async {
    final tokens = allStreamingTokens;
    if (tokens.isEmpty) return;
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

    final incomingPrice = (q['lastPrice'] as num?)?.toDouble() ??
        (q['last_price'] as num?)?.toDouble() ??
        0.0;

    // Check if it's NIFTY 50
    if (token == _nifty50.instrumentToken && incomingPrice > 0) {
      final change = (q['change'] as num?)?.toDouble() ?? _nifty50.change;
      final changePercent = (q['changePercent'] as num?)?.toDouble() ??
          (q['change_percent'] as num?)?.toDouble() ??
          _nifty50.changePercent;
      final close = (change != 0) ? (incomingPrice - change) : incomingPrice;

      _nifty50 = _nifty50.copyWith(
        lastPrice: incomingPrice,
        closePrice: close,
        change: change,
        changePercent: changePercent,
        lastUpdated: DateTime.now(),
      );
      return;
    }

    // Check if it's SENSEX
    if (token == _sensex.instrumentToken && incomingPrice > 0) {
      final change = (q['change'] as num?)?.toDouble() ?? _sensex.change;
      final changePercent = (q['changePercent'] as num?)?.toDouble() ??
          (q['change_percent'] as num?)?.toDouble() ??
          _sensex.changePercent;
      final close = (change != 0) ? (incomingPrice - change) : incomingPrice;

      _sensex = _sensex.copyWith(
        lastPrice: incomingPrice,
        closePrice: close,
        change: change,
        changePercent: changePercent,
        lastUpdated: DateTime.now(),
      );
      return;
    }

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

    final lastPrice = (incomingPrice > 0) ? incomingPrice : old.lastPrice;
    double change = (q['change'] as num?)?.toDouble() ?? old.change;
    double changePercent = (q['changePercent'] as num?)?.toDouble() ??
        (q['change_percent'] as num?)?.toDouble() ??
        old.changePercent;

    double close = (q['closePrice'] as num?)?.toDouble() ??
        (q['close_price'] as num?)?.toDouble() ??
        old.closePrice;
    if (close > 0 && lastPrice > 0 && (change == 0.0 || (q['change'] == null && q['change_percent'] == null))) {
      change = lastPrice - close;
      changePercent = (change / close) * 100.0;
    } else if (close <= 0 && change != 0 && lastPrice > 0) {
      close = lastPrice - change;
    }

    _items[idx] = WatchlistItem(
      instrumentToken: token,
      tradingsymbol: tradingsymbol,
      exchange: exchange,
      lastPrice: lastPrice,
      closePrice: close > 0 ? close : lastPrice,
      change: change,
      changePercent: changePercent,
      previousPrice: old.lastPrice,
      priceDirection: PriceDirection.none,
      lastUpdated: DateTime.now(),
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
