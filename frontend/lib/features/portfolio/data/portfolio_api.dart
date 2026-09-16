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

  /// Fetch live quotes snapshot for a list of instrument tokens.
  Future<Result<List<Map<String, dynamic>>>> getQuotes(List<int> tokens) async {
    if (tokens.isEmpty) return const Success([]);
    try {
      final response = await dioClient.get(
        '/api/v1/market-data/quotes',
        queryParameters: {'instrumentTokens': tokens.join(',')},
      );
      final data = response.data;
      final List<dynamic> list = data is List
          ? data
          : (data as Map<String, dynamic>)['quotes'] as List<dynamic>? ?? [];
      return Success(list.whereType<Map<String, dynamic>>().toList());
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }

  /// Connects the backend Kite market-data ticker stream for the given tokens.
  Future<Result<bool>> connectKiteMarketData(List<int> tokens) async {
    if (tokens.isEmpty) return const Success(true);
    try {
      await dioClient.post(
        '/api/v1/kite/market-data/connect',
        data: {'instrumentTokens': tokens},
      );
      return const Success(true);
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }
}
