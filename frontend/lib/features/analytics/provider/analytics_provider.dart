import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../data/analytics_api.dart';
import '../model/analytics_models.dart';

/// Manages analytics state for a selected instrument + timeframe.
class AnalyticsProvider extends ChangeNotifier {
  final AnalyticsApi _api;

  AnalyticsProvider({required DioClient dioClient})
      : _api = AnalyticsApi(dioClient: dioClient);

  // ── Instrument selection ───────────────────────────────────────────────────
  int? _selectedToken;
  String? _selectedSymbol;
  String _selectedTimeframe = '5minute';

  int? get selectedToken => _selectedToken;
  String? get selectedSymbol => _selectedSymbol;
  String get selectedTimeframe => _selectedTimeframe;

  static const List<String> availableTimeframes = [
    '1minute',
    '5minute',
    '15minute',
  ];

  // ── State ──────────────────────────────────────────────────────────────────
  IndicatorSnapshot? _indicators;
  SignalResult? _signal;
  bool _hasSignal = false;
  List<CandleData> _candles = [];
  bool _isLoading = false;
  String? _error;

  IndicatorSnapshot? get indicators => _indicators;
  SignalResult? get signal => _signal;
  bool get hasCheckedSignal => _hasSignal;
  List<CandleData> get candles => _candles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Select an instrument and immediately fetch all analytics data.
  Future<void> selectInstrument(int token, String symbol) async {
    _selectedToken = token;
    _selectedSymbol = symbol;
    notifyListeners();
    await fetchAll();
  }

  /// Change timeframe and re-fetch if an instrument is already selected.
  Future<void> setTimeframe(String timeframe) async {
    if (_selectedTimeframe == timeframe) return;
    _selectedTimeframe = timeframe;
    notifyListeners();
    if (_selectedToken != null) await fetchAll();
  }

  /// Fetch indicators, signal and candles for the current selection.
  Future<void> fetchAll() async {
    final token = _selectedToken;
    if (token == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    final now = DateTime.now();
    final from = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 3)));
    final to = DateFormat('yyyy-MM-dd').format(now);

    final results = await Future.wait([
      _api.getLatestIndicators(token, _selectedTimeframe),
      _api.getEmaCrossoverSignal(token, _selectedTimeframe),
      _api.getCandles(token, _selectedTimeframe, from, to),
    ]);

    final indResult = results[0] as Result<IndicatorSnapshot>;
    final sigResult = results[1] as Result<SignalResult?>;
    final canResult = results[2] as Result<List<CandleData>>;

    if (indResult is Success<IndicatorSnapshot>) {
      _indicators = indResult.data;
    } else if (indResult is Failure<IndicatorSnapshot>) {
      _error = indResult.failure.message;
    }

    if (sigResult is Success<SignalResult?>) {
      _signal = sigResult.data;
      _hasSignal = true;
    } else if (sigResult is Failure<SignalResult?>) {
      _error ??= sigResult.failure.message;
    }

    if (canResult is Success<List<CandleData>>) {
      _candles = canResult.data;
    } else if (canResult is Failure<List<CandleData>>) {
      _error ??= canResult.failure.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Clear current selection.
  void clearInstrument() {
    _selectedToken = null;
    _selectedSymbol = null;
    _indicators = null;
    _signal = null;
    _hasSignal = false;
    _candles = [];
    _error = null;
    notifyListeners();
  }
}

