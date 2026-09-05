import 'package:flutter/foundation.dart';
import '../../../core/network/dio_client.dart';
import '../data/settings_api.dart';
import '../model/risk_limits.dart';

/// Manages settings state: risk limits and server health.
class SettingsProvider extends ChangeNotifier {
  final SettingsApi _api;
  final DioClient dioClient;

  SettingsProvider({required this.dioClient})
      : _api = SettingsApi(dioClient: dioClient);

  // ── State ──────────────────────────────────────────────────────────────────
  RiskLimits? _limits;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  bool _isServerReachable = false;
  Map<String, dynamic>? _healthData;

  RiskLimits? get limits => _limits;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  bool get isServerReachable => _isServerReachable;
  Map<String, dynamic>? get healthData => _healthData;

  // ── Public API ─────────────────────────────────────────────────────────────

  void updateBaseUrl(String url) {
    dioClient.updateBaseUrl(url);
    notifyListeners();
  }

  Future<void> loadRiskLimits() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _api.getRiskLimits();

    result.fold(
      onSuccess: (data) => _limits = data,
      onFailure: (failure) => _error = failure.message,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> saveRiskLimits(RiskLimits limits) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    final result = await _api.updateRiskLimits(limits);

    bool success = false;
    result.fold(
      onSuccess: (data) {
        _limits = data;
        success = true;
      },
      onFailure: (failure) {
        _error = failure.message;
        success = false;
      },
    );

    _isSaving = false;
    notifyListeners();
    return success;
  }

  Future<void> checkHealth() async {
    final result = await _api.getSystemHealth();

    result.fold(
      onSuccess: (data) {
        _healthData = data;
        _isServerReachable = true;
      },
      onFailure: (_) {
        _isServerReachable = false;
        _healthData = null;
      },
    );

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
