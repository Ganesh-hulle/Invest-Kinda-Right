import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../../../core/network/api_exception.dart';
import '../model/watchlist_models.dart';

class WatchlistApi {
  final DioClient dioClient;

  const WatchlistApi({required this.dioClient});

  /// Search instruments by query string.
  Future<Result<List<InstrumentResult>>> searchInstruments(String query) async {
    try {
      final response = await dioClient.get(
        '/api/v1/instruments/search',
        queryParameters: {'query': query},
      );
      final data = response.data;
      final List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        list = (data['instruments'] ?? data['results'] ?? []) as List<dynamic>;
      } else {
        list = [];
      }
      final results = list
          .whereType<Map<String, dynamic>>()
          .map(InstrumentResult.fromJson)
          .toList();
      return Success(results);
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    }
  }

  /// Fetch live quotes for a list of instrument tokens.
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
    }
  }
}
