import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../../../core/network/api_exception.dart';
import '../model/kite_models.dart';

/// Pure API layer for all Kite / Zerodha endpoints. 
class KiteApi {
  final DioClient dioClient;

  const KiteApi({required this.dioClient});

  /// Returns the Zerodha OAuth login URL.
  Future<Result<KiteLoginUrlResponse>> getLoginUrl() async {
    try {
      final response = await dioClient.get('/api/v1/kite/login-url');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return Success(KiteLoginUrlResponse.fromJson(data));
      }
      return const Failure(ServerFailure('Unexpected response format.'));
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }

  /// Returns the authenticated Kite user profile.
  Future<Result<KiteProfile>> getProfile() async {
    try {
      final response = await dioClient.get('/api/v1/kite/profile');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return Success(KiteProfile.fromJson(data));
      }
      return const Failure(ServerFailure('Unexpected response format.'));
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }

  /// Returns portfolio holdings and positions.
  Future<Result<Map<String, dynamic>>> getPortfolio() async {
    try {
      final response = await dioClient.get('/api/v1/kite/portfolio');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return Success(data);
      }
      return const Failure(ServerFailure('Unexpected response format.'));
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }

  /// Triggers a full instrument sync on the backend.
  Future<void> syncInstruments() async {
    try {
      await dioClient.post('/api/v1/kite/instruments/sync');
    } catch (_) {
      // Fire-and-forget; caller should handle errors separately if needed.
    }
  }

  /// Returns the current market-data WebSocket connection status.
  Future<Result<Map<String, dynamic>>> getMarketDataStatus() async {
    try {
      final response = await dioClient.get('/api/v1/kite/market-data/status');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return Success(data);
      }
      return const Success({});
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }

  /// Connects the market-data WebSocket for the given instrument [tokens].
  Future<void> connectMarketData(List<int> tokens) async {
    try {
      await dioClient.post(
        '/api/v1/kite/market-data/connect',
        data: {'instrumentTokens': tokens},
      );
    } catch (_) {}
  }

  /// Disconnects the market-data WebSocket.
  Future<void> disconnectMarketData() async {
    try {
      await dioClient.post('/api/v1/kite/market-data/disconnect');
    } catch (_) {}
  }
}
