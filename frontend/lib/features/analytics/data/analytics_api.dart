import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../../../core/network/api_exception.dart';
import '../model/analytics_models.dart';

/// Pure API class — all calls return [Result<T>].
class AnalyticsApi {
  final DioClient _dio;

  const AnalyticsApi({required DioClient dioClient}) : _dio = dioClient;

  /// GET /api/v1/indicators/latest?instrumentToken=X&timeframe=Y
  Future<Result<IndicatorSnapshot>> getLatestIndicators(
    int token,
    String timeframe,
  ) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/indicators/latest',
        queryParameters: {
          'instrumentToken': token,
          'timeframe': timeframe,
        },
      );
      return Success(IndicatorSnapshot.fromJson(resp.data!));
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }

  /// GET /api/v1/market-data/candles?instrumentToken=X&timeframe=Y&from=Z&to=W
  Future<Result<List<CandleData>>> getCandles(
    int token,
    String timeframe,
    String from,
    String to,
  ) async {
    try {
      final resp = await _dio.get<List<dynamic>>(
        '/api/v1/market-data/candles',
        queryParameters: {
          'instrumentToken': token,
          'timeframe': timeframe,
          'from': from,
          'to': to,
        },
      );
      final list = (resp.data ?? [])
          .cast<Map<String, dynamic>>()
          .map(CandleData.fromJson)
          .toList();
      return Success(list);
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }

  /// GET /api/v1/strategies/ema-crossover/signal?instrumentToken=X&timeframe=Y
  /// Returns [null] when the backend responds 204 (no signal).
  Future<Result<SignalResult?>> getEmaCrossoverSignal(
    int token,
    String timeframe,
  ) async {
    try {
      final resp = await _dio.get<dynamic>(
        '/api/v1/strategies/ema-crossover/signal',
        queryParameters: {
          'instrumentToken': token,
          'timeframe': timeframe,
        },
      );
      if (resp.statusCode == 204 || resp.data == null) {
        return const Success(null);
      }
      final data = resp.data as Map<String, dynamic>;
      return Success(SignalResult.fromJson(data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 204) return const Success(null);
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }

  /// GET /api/v1/kite/historical?instrumentToken=X&from=DATE&to=DATE&interval=5minute
  Future<Result<List<Map<String, dynamic>>>> getHistoricalCandles(
    int token,
    String from,
    String to,
    String interval,
  ) async {
    try {
      final resp = await _dio.get<List<dynamic>>(
        '/api/v1/kite/historical',
        queryParameters: {
          'instrumentToken': token,
          'from': from,
          'to': to,
          'interval': interval,
        },
      );
      final list = (resp.data ?? [])
          .cast<Map<String, dynamic>>()
          .toList();
      return Success(list);
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }
}

