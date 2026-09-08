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

  /// Returns status of backend Kite market-data connection.
  Future<Result<Map<String, dynamic>>> getKiteMarketDataStatus() async {
    try {
      final response = await dioClient.get('/api/v1/kite/market-data/status');
      if (response.data is Map<String, dynamic>) {
        return Success(response.data as Map<String, dynamic>);
      }
      return const Success({});
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }

  /// Fetch recent candles for an instrument token from market-data engine.
  /// Uses ISO 8601 UTC formatting so Spring Boot parses OffsetDateTime properly.
  Future<Result<List<Map<String, dynamic>>>> getRecentCandles(
    int token, {
    String timeframe = '5minute',
    int daysBack = 14,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final from = now.subtract(Duration(days: daysBack)).toIso8601String();
      final to = now.toIso8601String();
      final response = await dioClient.get(
        '/api/v1/market-data/candles',
        queryParameters: {
          'instrumentToken': token,
          'timeframe': timeframe,
          'from': from,
          'to': to,
        },
      );
      final data = response.data;
      if (data is List) {
        final list = data.whereType<Map<String, dynamic>>().toList();
        if (list.isNotEmpty) return Success(list);
      }

      // Fallback: If 5minute had no data, try 'day' timeframe
      if (timeframe != 'day') {
        final dayFrom = now.subtract(const Duration(days: 30)).toIso8601String();
        final dayResp = await dioClient.get(
          '/api/v1/market-data/candles',
          queryParameters: {
            'instrumentToken': token,
            'timeframe': 'day',
            'from': dayFrom,
            'to': to,
          },
        );
        if (dayResp.data is List) {
          return Success(
              (dayResp.data as List).whereType<Map<String, dynamic>>().toList());
        }
      }

      return const Success([]);
    } on DioException catch (e) {
      return Failure(mapDioError(e));
    } catch (e) {
      return Failure(UnknownFailure(e.toString()));
    }
  }

  /// Try resolving tradingsymbol and exchange from portfolio, paper trading, or signals.
  Future<Map<String, String>?> resolveTradingSymbol(int token) async {
    // 1. Check Kite Portfolio holdings & positions
    try {
      final portResp = await dioClient.get('/api/v1/kite/portfolio');
      if (portResp.data is Map<String, dynamic>) {
        final map = portResp.data as Map<String, dynamic>;
        final holdings = (map['holdings'] as List?) ?? [];
        for (final h in holdings) {
          if (h is Map && (h['instrument_token'] ?? h['instrumentToken']) == token) {
            final sym = h['tradingsymbol']?.toString();
            if (sym != null && sym.isNotEmpty && !sym.startsWith('Token ')) {
              return {
                'symbol': sym,
                'exchange': h['exchange']?.toString() ?? 'NSE',
              };
            }
          }
        }
        final positions = (map['netPositions'] ?? map['positions'] as List?) ?? [];
        for (final p in positions) {
          if (p is Map && (p['instrument_token'] ?? p['instrumentToken']) == token) {
            final sym = p['tradingsymbol']?.toString();
            if (sym != null && sym.isNotEmpty && !sym.startsWith('Token ')) {
              return {
                'symbol': sym,
                'exchange': p['exchange']?.toString() ?? 'NSE',
              };
            }
          }
        }
      }
    } catch (_) {}

    // 2. Check Paper Positions
    try {
      final posResp = await dioClient.get('/api/v1/paper/positions');
      if (posResp.data is List) {
        for (final p in posResp.data as List) {
          if (p is Map && (p['instrumentToken'] ?? p['instrument_token']) == token) {
            final sym = p['tradingsymbol']?.toString();
            if (sym != null && sym.isNotEmpty && !sym.startsWith('Token ')) {
              return {
                'symbol': sym,
                'exchange': p['exchange']?.toString() ?? 'NSE',
              };
            }
          }
        }
      }
    } catch (_) {}

    // 3. Check Paper Orders
    try {
      final ordResp = await dioClient.get('/api/v1/paper/orders');
      if (ordResp.data is List) {
        for (final ord in ordResp.data as List) {
          if (ord is Map && (ord['instrumentToken'] ?? ord['instrument_token']) == token) {
            final sym = ord['tradingsymbol']?.toString();
            if (sym != null && sym.isNotEmpty && !sym.startsWith('Token ')) {
              return {
                'symbol': sym,
                'exchange': ord['exchange']?.toString() ?? 'NSE',
              };
            }
          }
        }
      }
    } catch (_) {}

    // 4. Check Strategy Signal
    try {
      final resp = await dioClient.get(
        '/api/v1/strategies/ema-crossover/signal',
        queryParameters: {
          'instrumentToken': token,
          'timeframe': '5minute',
        },
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final sym = resp.data['tradingsymbol'] as String?;
        if (sym != null && sym.isNotEmpty && !sym.startsWith('Token ')) {
          return {
            'symbol': sym,
            'exchange': resp.data['exchange']?.toString() ?? 'NSE',
          };
        }
      }
    } catch (_) {}

    return null;
  }
}
