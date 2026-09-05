import 'package:flutter/foundation.dart';

import '../../../core/network/dio_client.dart';
import '../data/portfolio_api.dart';
import '../model/portfolio_models.dart';

/// State provider for the portfolio feature.
class PortfolioProvider extends ChangeNotifier {
  final PortfolioApi _api;

  PortfolioResponse _portfolio = PortfolioResponse.empty();
  bool _isLoading = false;
  String? _error;

  PortfolioProvider({required DioClient dioClient})
      : _api = PortfolioApi(dioClient: dioClient);

  // ── Getters ──────────────────────────────────────────────────────────────

  PortfolioResponse get portfolio => _portfolio;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<HoldingItem> get holdings => _portfolio.holdings;
  List<PositionItem> get netPositions => _portfolio.netPositions;
  List<PositionItem> get dayPositions => _portfolio.dayPositions;

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

  /// Day P&L = sum of net-position P&Ls (intraday).
  double get dayPnl {
    return _portfolio.dayPositions.fold(0.0, (sum, p) => sum + p.pnl);
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Fetches the full portfolio from the API.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _api.getPortfolio();

    result.fold(
      onSuccess: (data) {
        _portfolio = data;
        _error = null;
      },
      onFailure: (failure) {
        _error = failure.message;
      },
    );

    _isLoading = false;
    notifyListeners();
  }
}
