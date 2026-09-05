import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../../../core/network/api_exception.dart';
import '../model/portfolio_models.dart';

/// Pure API layer for portfolio data.
class PortfolioApi {
  final DioClient dioClient;

  const PortfolioApi({required this.dioClient});

  /// Fetches the full portfolio (holdings + positions) from the backend.
  Future<Result<PortfolioResponse>> getPortfolio() async {
    try {
      final response = await dioClient.get('/api/v1/kite/portfolio');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return Success(PortfolioResponse.fromJson(data));
      }
      return const Failure(ServerFailure('Unexpected response format.'));
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }
}
