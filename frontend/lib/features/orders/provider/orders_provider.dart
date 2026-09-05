import 'package:flutter/foundation.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../data/paper_orders_api.dart';
import '../data/live_orders_api.dart';
import '../model/order_models.dart';

/// State provider for all order-related data (paper + live).
class OrdersProvider extends ChangeNotifier {
  final PaperOrdersApi _paperApi;
  final LiveOrdersApi _liveApi;

  List<PaperOrder> _paperOrders = [];
  List<PaperPosition> _paperPositions = [];
  List<LiveOrder> _liveOrders = [];
  bool _isLoading = false;
  String? _error;
  bool _liveTradingDisabled = false;

  OrdersProvider({required DioClient dioClient})
      : _paperApi = PaperOrdersApi(dioClient: dioClient),
        _liveApi = LiveOrdersApi(dioClient: dioClient);

  // ── Getters ──────────────────────────────────────────────────────────────

  List<PaperOrder> get paperOrders => _paperOrders;
  List<PaperPosition> get paperPositions => _paperPositions;
  List<LiveOrder> get liveOrders => _liveOrders;
  List<PaperOrder> get recentOrders => _paperOrders.take(5).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get liveTradingDisabled => _liveTradingDisabled;

  // ── Load Actions ─────────────────────────────────────────────────────────

  Future<void> loadPaperOrders() async {
    final result = await _paperApi.getOrders();
    result.fold(
      onSuccess: (orders) {
        // Newest first
        _paperOrders = orders.reversed.toList();
      },
      onFailure: (failure) {
        _error = failure.message;
      },
    );
    notifyListeners();
  }

  Future<void> fetchPaperOrders() => loadPaperOrders();

  Future<void> loadPaperPositions() async {
    final result = await _paperApi.getPositions();
    result.fold(
      onSuccess: (positions) => _paperPositions = positions,
      onFailure: (failure) => _error = failure.message,
    );
    notifyListeners();
  }

  /// Loads paper orders and positions concurrently.
  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future.wait([
      loadPaperOrders(),
      loadPaperPositions(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  // ── Place Orders ─────────────────────────────────────────────────────────

  /// Places a paper order. Refreshes order list on success.
  Future<Result<PaperOrder>> placePaperOrder(OrderRequest request) async {
    final result = await _paperApi.placeOrder(request);
    if (result.isSuccess) {
      await loadPaperOrders();
    }
    return result;
  }

  /// Places a live order. Handles [LiveTradingDisabledFailure] gracefully
  /// by setting [liveTradingDisabled] flag instead of propagating as error.
  Future<Result<LiveOrder>> placeLiveOrder(OrderRequest request) async {
    final result = await _liveApi.placeOrder(request);
    result.fold(
      onSuccess: (_) {
        _liveTradingDisabled = false;
      },
      onFailure: (failure) {
        if (failure is LiveTradingDisabledFailure) {
          _liveTradingDisabled = true;
        }
      },
    );
    notifyListeners();
    return result;
  }

  /// Cancels a live order by id.
  Future<Result<LiveOrder>> cancelLiveOrder(int id) async {
    final result = await _liveApi.cancelOrder(id);
    if (result.isSuccess) {
      _liveOrders = _liveOrders.map((o) {
        if (o.id == id) {
          return result.dataOrNull ?? o;
        }
        return o;
      }).toList();
      notifyListeners();
    }
    return result;
  }
}
