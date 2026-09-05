import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../../../core/network/api_exception.dart';
import '../model/risk_limits.dart';

/// Settings API — risk limits and server health.
class SettingsApi {
  final DioClient _dio;

  const SettingsApi({required DioClient dioClient}) : _dio = dioClient;

  /// GET /api/v1/risk/limits
  Future<Result<RiskLimits>> getRiskLimits() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/risk/limits');
      return Success(RiskLimits.fromJson(resp.data!));
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }

  /// PUT /api/v1/risk/limits
  Future<Result<RiskLimits>> updateRiskLimits(RiskLimits limits) async {
    try {
      final resp = await _dio.put<Map<String, dynamic>>(
        '/api/v1/risk/limits',
        data: limits.toJson(),
      );
      return Success(RiskLimits.fromJson(resp.data!));
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }

  /// GET /api/v1/system/health
  Future<Result<Map<String, dynamic>>> getSystemHealth() async {
    try {
      final resp =
          await _dio.get<Map<String, dynamic>>('/api/v1/system/health');
      return Success(Map<String, dynamic>.from(resp.data ?? {}));
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }
}

