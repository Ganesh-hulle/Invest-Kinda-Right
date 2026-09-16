import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/websocket/market_ws_service.dart';
import '../../watchlist/model/watchlist_models.dart' show PriceDirection;
import '../data/portfolio_api.dart';
import '../model/portfolio_models.dart';

/// State provider for the portfolio feature.
class PortfolioProvider extends ChangeNotifier {
  final PortfolioApi _api;
  final MarketWsService? _wsService;

  PortfolioResponse _portfolio = PortfolioResponse.empty();
  bool _isLoading = false;
  String? _error;
  StreamSubscription<QuoteUpdate>? _quoteSub;

  PortfolioProvider({
    required DioClient dioClient,
    MarketWsService? wsService,
  })  : _api = PortfolioApi(dioClient: dioClient),
        _wsService = wsService {
    _initWs();
  }

  // ── Getters ──────────────────────────────────────────────────────────────

  PortfolioResponse get portfolio => _portfolio;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<HoldingItem> get holdings => _portfolio.holdings;
  List<PositionItem> get netPositions => _portfolio.netPositions;
  List<PositionItem> get dayPositions => _portfolio.dayPositions;

  /// All unique positive instrument tokens across holdings and positions.
  List<int> get portfolioTokens {
    final tokens = <int>{};
    for (final h in _portfolio.holdings) {
      if (h.instrumentToken != null && h.instrumentToken! > 0) {
        tokens.add(h.instrumentToken!);
      }
    }
    for (final p in _portfolio.netPositions) {
      if (p.instrumentToken != null && p.instrumentToken! > 0) {
        tokens.add(p.instrumentToken!);
      }
    }
    for (final p in _portfolio.dayPositions) {
      if (p.instrumentToken != null && p.instrumentToken! > 0) {
        tokens.add(p.instrumentToken!);
      }
    }
    return tokens.toList();
  }

  /// Total amount invested across all holdings (qty × avg price).
  double get totalInvested {
    return _portfolio.holdings.fold(
      0.0,
      (sum, h) => sum + h.averagePrice * h.quantity,
    );
  }

  /// Current market value of all holdings (qty × last price).
  double get currentValue {
    return _portfolio.holdings.fold(
      0.0,
      (sum, h) => sum + h.lastPrice * h.quantity,
    );
  }

  /// Total unrealised P&L across all holdings.
  double get totalPnl {
    return _portfolio.holdings.fold(0.0, (sum, h) => sum + h.pnl);
  }

  /// Total unrealised P&L percentage across all holdings.
  double get totalPnlPercentage {
    return totalInvested > 0 ? (totalPnl / totalInvested) * 100.0 : 0.0;
  }

  /// Day P&L for Holdings: sum of (dayChange × qty) or ((lastPrice - closePrice) × qty).
  double get holdingsDayPnl {
    return _portfolio.holdings.fold(0.0, (sum, h) {
      final dayChange = h.dayChange != 0
          ? h.dayChange
          : (h.closePrice > 0 ? (h.lastPrice - h.closePrice) : 0.0);
      return sum + (dayChange * h.quantity);
    });
  }

  /// Day P&L percentage for Holdings.
  double get holdingsDayPnlPercentage {
    final prevValue = _portfolio.holdings.fold(0.0, (sum, h) {
      final close = h.closePrice > 0
          ? h.closePrice
          : (h.dayChange != 0 ? h.lastPrice - h.dayChange : h.averagePrice);
      return sum + (close > 0 ? close * h.quantity : h.averagePrice * h.quantity);
    });
    return prevValue > 0 ? (holdingsDayPnl / prevValue) * 100.0 : 0.0;
  }

  /// Day P&L for Day Positions: sum of intraday position P&Ls.
  double get dayPositionsPnl {
    return _portfolio.dayPositions.fold(0.0, (sum, p) => sum + p.pnl);
  }

  /// Day P&L percentage for Day Positions.
  double get dayPositionsPnlPercentage {
    final totalCost = _portfolio.dayPositions.fold(
      0.0,
      (sum, p) => sum + (p.averagePrice * p.quantity.abs()),
    );
    return totalCost > 0 ? (dayPositionsPnl / totalCost) * 100.0 : 0.0;
  }

  /// Net Positions P&L.
  double get netPositionsPnl {
    return _portfolio.netPositions.fold(0.0, (sum, p) => sum + p.pnl);
  }

  /// Net Positions P&L percentage.
  double get netPositionsPnlPercentage {
    final totalCost = _portfolio.netPositions.fold(
      0.0,
      (sum, p) => sum + (p.averagePrice * p.quantity.abs()),
    );
    return totalCost > 0 ? (netPositionsPnl / totalCost) * 100.0 : 0.0;
  }

  /// Overall Day P&L across the portfolio.
  /// If dayPositions is present, uses dayPositions; otherwise defaults to holdingsDayPnl.
  double get dayPnl {
    if (_portfolio.dayPositions.isNotEmpty) {
      return dayPositionsPnl;
    }
    return holdingsDayPnl;
  }

  /// Overall Day P&L percentage.
  double get dayPnlPercentage {
    if (_portfolio.dayPositions.isNotEmpty) {
      return dayPositionsPnlPercentage;
    }
    return holdingsDayPnlPercentage;
  }

  /// Tab-specific Day P&L amount.
  /// Tab 0: Holdings, Tab 1: Net Positions, Tab 2: Day Positions.
  double dayPnlForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return holdingsDayPnl;
      case 1:
        return netPositionsPnl;
      case 2:
        return dayPositionsPnl;
      default:
        return dayPnl;
    }
  }

  /// Tab-specific Day P&L percentage.
  /// Tab 0: Holdings, Tab 1: Net Positions, Tab 2: Day Positions.
  double dayPnlPercentageForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return holdingsDayPnlPercentage;
      case 1:
        return netPositionsPnlPercentage;
      case 2:
        return dayPositionsPnlPercentage;
      default:
        return dayPnlPercentage;
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Fetches the full portfolio from the API and connects live market streaming.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _api.getPortfolio();

    result.fold(
      onSuccess: (data) {
        _portfolio = data;
        _error = null;
        _subscribeMarketData();
      },
      onFailure: (failure) {
        _error = failure.message;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// Orchestrates live market data connections for portfolio items.
  Future<void> _subscribeMarketData() async {
    final tokens = portfolioTokens;
    if (tokens.isEmpty) return;

    // 1. Fetch REST snapshot quotes immediately so prices update without waiting
    unawaited(refreshQuotes());

    // 2. Subscribe internal WebSocket to portfolio tokens
    final ws = _wsService;
    if (ws != null) {
      if (!ws.isConnected) {
        unawaited(ws.connect(tokens));
      } else {
        ws.subscribe(tokens);
      }
    }

    // 3. Connect backend Kite market data feed for live ticks
    unawaited(_connectKiteFeed(tokens));
  }

  /// Fetches latest REST snapshot quotes for all portfolio tokens.
  Future<void> refreshQuotes() async {
    final tokens = portfolioTokens;
    if (tokens.isEmpty) return;

    final result = await _api.getQuotes(tokens);
    result.fold(
      onSuccess: (quotes) {
        bool hasUpdates = false;
        for (final q in quotes) {
          final token = (q['instrumentToken'] as num?)?.toInt() ??
              (q['instrument_token'] as num?)?.toInt();
          if (token == null) continue;

          final ltp = (q['lastPrice'] as num?)?.toDouble() ??
              (q['last_price'] as num?)?.toDouble() ??
              0.0;
          if (ltp <= 0) continue;

          final close = (q['closePrice'] as num?)?.toDouble() ??
              (q['close_price'] as num?)?.toDouble();
          final change = (q['change'] as num?)?.toDouble();
          final changePct = (q['changePercent'] as num?)?.toDouble() ??
              (q['change_percent'] as num?)?.toDouble();

          final updated = _applyQuote(token, ltp, close, change, changePct);
          if (updated) hasUpdates = true;
        }

        if (hasUpdates) {
          notifyListeners();
        }
      },
      onFailure: (f) {
        debugPrint('[Portfolio] refreshQuotes notice: ${f.message}');
      },
    );
  }

  Future<void> _connectKiteFeed(List<int> tokens) async {
    if (tokens.isEmpty) return;
    try {
      await _api.connectKiteMarketData(tokens);
    } catch (e) {
      debugPrint('[Portfolio] connectKiteMarketData notice: $e');
    }
  }

  void _initWs() {
    _quoteSub?.cancel();
    final ws = _wsService;
    if (ws != null) {
      _quoteSub = ws.quoteStream.listen(_onQuoteUpdate);
    }
  }

  void _onQuoteUpdate(QuoteUpdate update) {
    final token = update.instrumentToken;
    final newPrice = update.lastPrice;
    if (newPrice <= 0) return;

    final updated = _applyQuote(
      token,
      newPrice,
      update.closePrice,
      update.change,
      update.changePercent,
    );

    if (updated) {
      notifyListeners();
    }
  }

  /// Applies updated quote data to matching holdings and positions.
  /// Returns true if any item was updated.
  bool _applyQuote(
    int token,
    double newPrice,
    double? closePrice,
    double? change,
    double? changePercent,
  ) {
    bool hasUpdates = false;

    // 1. Update matching Holdings
    final updatedHoldings = List<HoldingItem>.from(_portfolio.holdings);
    for (int i = 0; i < updatedHoldings.length; i++) {
      final h = updatedHoldings[i];
      if (h.instrumentToken == token) {
        final oldPrice = h.lastPrice;
        PriceDirection dir = PriceDirection.none;
        if (oldPrice > 0) {
          if (newPrice > oldPrice) {
            dir = PriceDirection.up;
          } else if (newPrice < oldPrice) {
            dir = PriceDirection.down;
          }
        }

        final close = (closePrice != null && closePrice > 0)
            ? closePrice
            : (h.closePrice > 0 ? h.closePrice : (oldPrice > 0 ? oldPrice : newPrice));
        final dayChg = (close > 0 && newPrice > 0)
            ? (newPrice - close)
            : (change ?? h.dayChange);
        final dayChgPct = (close > 0)
            ? (dayChg / close) * 100.0
            : (changePercent ?? h.dayChangePercentage);
        final pnl = (newPrice - h.averagePrice) * h.quantity;

        updatedHoldings[i] = h.copyWith(
          lastPrice: newPrice,
          previousPrice: oldPrice > 0 ? oldPrice : newPrice,
          priceDirection: dir,
          closePrice: close,
          pnl: pnl,
          dayChange: dayChg,
          dayChangePercentage: dayChgPct,
        );
        hasUpdates = true;
      }
    }

    // 2. Update matching Net Positions
    final updatedNet = List<PositionItem>.from(_portfolio.netPositions);
    for (int i = 0; i < updatedNet.length; i++) {
      final p = updatedNet[i];
      if (p.instrumentToken == token) {
        final oldPrice = p.lastPrice;
        PriceDirection dir = PriceDirection.none;
        if (oldPrice > 0) {
          if (newPrice > oldPrice) {
            dir = PriceDirection.up;
          } else if (newPrice < oldPrice) {
            dir = PriceDirection.down;
          }
        }

        final close = (closePrice != null && closePrice > 0)
            ? closePrice
            : (p.closePrice > 0 ? p.closePrice : (oldPrice > 0 ? oldPrice : newPrice));
        final dayChg = (close > 0 && newPrice > 0)
            ? (newPrice - close)
            : (change ?? p.dayChange);
        final dayChgPct = (close > 0)
            ? (dayChg / close) * 100.0
            : (changePercent ?? p.dayChangePercentage);
        final pnl = p.quantity != 0
            ? (newPrice - p.averagePrice) * p.quantity
            : p.pnl;

        updatedNet[i] = p.copyWith(
          lastPrice: newPrice,
          previousPrice: oldPrice > 0 ? oldPrice : newPrice,
          priceDirection: dir,
          closePrice: close > 0 ? close : p.closePrice,
          pnl: pnl,
          dayChange: dayChg,
          dayChangePercentage: dayChgPct,
        );
        hasUpdates = true;
      }
    }

    // 3. Update matching Day Positions
    final updatedDay = List<PositionItem>.from(_portfolio.dayPositions);
    for (int i = 0; i < updatedDay.length; i++) {
      final p = updatedDay[i];
      if (p.instrumentToken == token) {
        final oldPrice = p.lastPrice;
        PriceDirection dir = PriceDirection.none;
        if (oldPrice > 0) {
          if (newPrice > oldPrice) {
            dir = PriceDirection.up;
          } else if (newPrice < oldPrice) {
            dir = PriceDirection.down;
          }
        }

        final close = (closePrice != null && closePrice > 0)
            ? closePrice
            : (p.closePrice > 0 ? p.closePrice : (oldPrice > 0 ? oldPrice : newPrice));
        final dayChg = (close > 0 && newPrice > 0)
            ? (newPrice - close)
            : (change ?? p.dayChange);
        final dayChgPct = (close > 0)
            ? (dayChg / close) * 100.0
            : (changePercent ?? p.dayChangePercentage);
        final pnl = p.quantity != 0
            ? (newPrice - p.averagePrice) * p.quantity
            : p.pnl;

        updatedDay[i] = p.copyWith(
          lastPrice: newPrice,
          previousPrice: oldPrice > 0 ? oldPrice : newPrice,
          priceDirection: dir,
          closePrice: close > 0 ? close : p.closePrice,
          pnl: pnl,
          dayChange: dayChg,
          dayChangePercentage: dayChgPct,
        );
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      _portfolio = _portfolio.copyWith(
        holdings: updatedHoldings,
        netPositions: updatedNet,
        dayPositions: updatedDay,
      );
    }

    return hasUpdates;
  }

  @override
  void dispose() {
    _quoteSub?.cancel();
    super.dispose();
  }
}
