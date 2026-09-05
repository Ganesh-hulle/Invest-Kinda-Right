import 'package:flutter/foundation.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../data/kite_api.dart';
import '../model/kite_models.dart';

/// State provider for Zerodha Kite connection and market-data.
class KiteProvider extends ChangeNotifier {
  final KiteApi _api;

  KiteProfile? _profile;
  KitePortfolioSummary? _portfolio;
  bool _isConnected = false;
  bool _isLoading = false;
  bool _isPortfolioLoading = false;
  String? _error;
  bool _isSyncing = false;
  String? _syncError;

  KiteProvider({required DioClient dioClient})
      : _api = KiteApi(dioClient: dioClient);

  // ── Getters ──────────────────────────────────────────────────────────────

  KiteProfile? get profile => _profile;
  KitePortfolioSummary? get portfolio => _portfolio;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  bool get isPortfolioLoading => _isPortfolioLoading;
  String? get error => _error;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Fetches the Kite profile. Sets [isConnected] on success.
  Future<void> fetchProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _api.getProfile();

    result.fold(
      onSuccess: (profile) {
        _profile = profile;
        _isConnected = true;
        _error = null;
      },
      onFailure: (failure) {
        _error = failure.message;
        _isConnected = false;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// Alias for dashboard initialization.
  Future<void> checkConnectionStatus() => fetchProfile();

  /// Fetches the user's Kite portfolio summary for the dashboard.
  Future<void> fetchPortfolio() async {
    _isPortfolioLoading = true;
    notifyListeners();

    final result = await _api.getPortfolio();

    result.fold(
      onSuccess: (data) {
        _portfolio = KitePortfolioSummary.fromJson(data);
      },
      onFailure: (failure) {
        // Do not crash dashboard if portfolio fetch fails
      },
    );

    _isPortfolioLoading = false;
    notifyListeners();
  }

  /// Returns the Zerodha login URL wrapped in [Result<String>].
  Future<Result<String>> getLoginUrl() async {
    final result = await _api.getLoginUrl();
    return result.map((r) => r.loginUrl);
  }

  /// Triggers a full instrument sync. Returns typed [Result].
  Future<Result<void>> syncInstruments() async {
    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      await _api.syncInstruments();
      _isSyncing = false;
      notifyListeners();
      return const Success(null);
    } catch (e) {
      _syncError = e.toString();
      _isSyncing = false;
      notifyListeners();
      return Failure(UnknownFailure(_syncError!));
    }
  }

  /// Connects the market-data WebSocket for the given instrument [tokens].
  Future<void> connectMarketData(List<int> tokens) async {
    await _api.connectMarketData(tokens);
  }

  /// Disconnects the market-data WebSocket.
  Future<void> disconnectMarketData() async {
    await _api.disconnectMarketData();
  }

  /// Checks the current market-data connection status.
  Future<Map<String, dynamic>> getMarketDataStatus() async {
    final result = await _api.getMarketDataStatus();
    return result.dataOrNull ?? {};
  }
}
