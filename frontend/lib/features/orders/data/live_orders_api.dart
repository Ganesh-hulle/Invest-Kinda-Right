import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../../../core/network/api_exception.dart';
import '../model/order_models.dart';

/// Pure API layer for live trading endpoints.
class LiveOrdersApi {
  final DioClient dioClient;

  const LiveOrdersApi({required this.dioClient});

  /// Places a live order through the broker. Returns [LiveTradingDisabledFailure]
  /// gracefully when the server responds with 409 LIVE_TRADING_DISABLED.
  Future<Result<LiveOrder>> placeOrder(OrderRequest request) async {
    try {
      final response = await dioClient.post(
        '/api/v1/orders',
        data: request.toJson(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return Success(LiveOrder.fromJson(data));
      }
      return const Failure(ServerFailure('Unexpected response format.'));
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }

  /// Retrieves a single live order by [id].
  Future<Result<LiveOrder>> getOrder(int id) async {
    try {
      final response = await dioClient.get('/api/v1/orders/$id');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return Success(LiveOrder.fromJson(data));
      }
      return const Failure(ServerFailure('Unexpected response format.'));
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }

  /// Cancels a live order by [id].
  Future<Result<LiveOrder>> cancelOrder(int id) async {
    try {
      final response = await dioClient.post('/api/v1/orders/$id/cancel');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return Success(LiveOrder.fromJson(data));
      }
      return const Failure(ServerFailure('Unexpected response format.'));
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }
}
