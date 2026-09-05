import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../../../core/network/api_exception.dart';
import '../model/order_models.dart';

/// Pure API layer for paper trading endpoints.
class PaperOrdersApi {
  final DioClient dioClient;

  const PaperOrdersApi({required this.dioClient});

  /// Places a paper order. Returns the created [PaperOrder].
  Future<Result<PaperOrder>> placeOrder(OrderRequest request) async {
    try {
      final response = await dioClient.post(
        '/api/v1/paper/orders',
        data: request.toJson(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return Success(PaperOrder.fromJson(data));
      }
      return const Failure(ServerFailure('Unexpected response format.'));
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }

  /// Returns all paper orders (newest first from server, or reverse on client).
  Future<Result<List<PaperOrder>>> getOrders() async {
    try {
      final response = await dioClient.get('/api/v1/paper/orders');
      final data = response.data;
      if (data is List) {
        final orders = data
            .map(
                (e) => PaperOrder.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return Success(orders);
      }
      if (data is Map && data['orders'] is List) {
        final orders = (data['orders'] as List)
            .map(
                (e) => PaperOrder.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return Success(orders);
      }
      return const Success([]);
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }

  /// Returns all open paper positions.
  Future<Result<List<PaperPosition>>> getPositions() async {
    try {
      final response = await dioClient.get('/api/v1/paper/positions');
      final data = response.data;
      if (data is List) {
        final positions = data
            .map((e) =>
                PaperPosition.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return Success(positions);
      }
      if (data is Map && data['positions'] is List) {
        final positions = (data['positions'] as List)
            .map((e) =>
                PaperPosition.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return Success(positions);
      }
      return const Success([]);
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }
}
