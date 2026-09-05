import 'package:dio/dio.dart';
import 'result.dart';

/// Translates [DioException] into a typed [ApiFailure].
ApiFailure mapDioError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const NetworkFailure('Connection timed out. Check your network.');

    case DioExceptionType.connectionError:
      return const NetworkFailure(
        'Could not reach the server. Is the backend running?',
      );

    case DioExceptionType.badResponse:
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;

      if (statusCode == 401) return const UnauthorizedFailure();
      if (statusCode == 404) return const NotFoundFailure();

      if (statusCode == 400) {
        final message = _extractMessage(data) ?? 'Validation failed.';
        return ValidationFailure(message,
            errors: data is Map ? Map<String, dynamic>.from(data) : null);
      }

      if (statusCode == 409) {
        final error = data is Map ? data['error'] as String? : null;
        if (error == 'LIVE_TRADING_DISABLED')
          return const LiveTradingDisabledFailure();
        return ServerFailure(_extractMessage(data) ?? 'Conflict.',
            statusCode: statusCode);
      }

      if (statusCode == 422) {
        final message = _extractMessage(data) ?? 'Risk validation failed.';
        return RiskRejectedFailure(message);
      }

      return ServerFailure(
        _extractMessage(data) ?? 'Server error ($statusCode).',
        statusCode: statusCode,
      );

    case DioExceptionType.cancel:
      return const UnknownFailure('Request cancelled.');

    default:
      return UnknownFailure(e.message ?? 'Unknown error occurred.');
  }
}

String? _extractMessage(dynamic data) {
  if (data is Map) {
    return data['message'] as String? ?? data['error'] as String?;
  }
  if (data is String && data.isNotEmpty) return data;
  return null;
}
