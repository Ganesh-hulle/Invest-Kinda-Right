import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../storage/secure_storage.dart';

/// Quote update pushed over the internal market WebSocket.
class QuoteUpdate {
  final int instrumentToken;
  final double lastPrice;
  final String? tradingsymbol;
  final String? exchange;
  final double? closePrice;
  final double? change;
  final double? changePercent;
  final DateTime receivedAt;

  QuoteUpdate({
    required this.instrumentToken,
    required this.lastPrice,
    this.tradingsymbol,
    this.exchange,
    this.closePrice,
    this.change,
    this.changePercent,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory QuoteUpdate.fromJson(Map<String, dynamic> json) {
    return QuoteUpdate(
      instrumentToken: (json['instrumentToken'] as num).toInt(),
      lastPrice: (json['lastPrice'] as num).toDouble(),
      tradingsymbol: json['tradingsymbol'] as String?,
      exchange: json['exchange'] as String?,
      closePrice: json['closePrice'] != null
          ? (json['closePrice'] as num).toDouble()
          : (json['close_price'] != null
              ? (json['close_price'] as num).toDouble()
              : null),
      change:
          json['change'] != null ? (json['change'] as num).toDouble() : null,
      changePercent: json['changePercent'] != null
          ? (json['changePercent'] as num).toDouble()
          : (json['change_percent'] != null
              ? (json['change_percent'] as num).toDouble()
              : null),
    );
  }
}

enum WsConnectionState { disconnected, connecting, connected, error }

/// Manages the authenticated internal WebSocket at `ws://host/ws/market`.
class MarketWsService extends ChangeNotifier {
  final SecureStorage secureStorage;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;

  WsConnectionState _state = WsConnectionState.disconnected;
  String? _lastError;
  String _wsBaseUrl = 'ws://127.0.0.1:8080';
  DateTime? _lastTickAt;
  bool _explicitlyDisconnected = false;
  int _reconnectAttempts = 0;

  // Set of currently subscribed instrument tokens for auto-resubscription
  final Set<int> _subscribedTokens = {};

  // Stream controller for quote updates
  final _quoteController = StreamController<QuoteUpdate>.broadcast();

  // In-memory latest quotes keyed by instrument token
  final Map<int, QuoteUpdate> _latestQuotes = {};

  MarketWsService({required this.secureStorage});

  WsConnectionState get state => _state;
  String? get lastError => _lastError;
  bool get isConnected => _state == WsConnectionState.connected;
  DateTime? get lastTickAt => _lastTickAt;
  Set<int> get subscribedTokens => Set.unmodifiable(_subscribedTokens);
  Stream<QuoteUpdate> get quoteStream => _quoteController.stream;
  Map<int, QuoteUpdate> get latestQuotes => Map.unmodifiable(_latestQuotes);

  void updateWsBaseUrl(String url) => _wsBaseUrl = url;

  Future<void> connect(List<int> instrumentTokens) async {
    _explicitlyDisconnected = false;
    _subscribedTokens.addAll(instrumentTokens);

    if (_state == WsConnectionState.connected) {
      if (instrumentTokens.isNotEmpty) {
        _sendSubscribe(instrumentTokens);
      }
      return;
    }

    if (_state == WsConnectionState.connecting) return;

    _reconnectTimer?.cancel();
    _setState(WsConnectionState.connecting);
    _lastError = null;

    try {
      final token = await secureStorage.readToken();
      if (token == null) {
        _setError('Not authenticated');
        return;
      }

      final uri = Uri.parse('$_wsBaseUrl/ws/market?access_token=$token');
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;

      _channel = channel;
      _reconnectAttempts = 0;
      _setState(WsConnectionState.connected);

      // Subscribe to all tracked tokens
      if (_subscribedTokens.isNotEmpty) {
        _sendSubscribe(_subscribedTokens.toList());
      }

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (e) {
          debugPrint('[WS] Error: $e');
          _setError(e.toString());
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[WS] Connection closed');
          if (_state != WsConnectionState.disconnected) {
            _setState(WsConnectionState.disconnected);
          }
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('[WS] Connection failure: $e');
      _setError(e.toString());
      _scheduleReconnect();
    }
  }

  void subscribe(List<int> instrumentTokens) {
    if (instrumentTokens.isEmpty) return;
    _subscribedTokens.addAll(instrumentTokens);
    if (isConnected) {
      _sendSubscribe(instrumentTokens);
    } else if (!_explicitlyDisconnected) {
      connect(_subscribedTokens.toList());
    }
  }

  void _sendSubscribe(List<int> tokens) {
    if (_channel == null || !isConnected || tokens.isEmpty) return;
    try {
      _channel!.sink.add(jsonEncode({
        'action': 'subscribe',
        'instrumentTokens': tokens,
      }));
    } catch (e) {
      debugPrint('[WS] Error sending subscribe: $e');
    }
  }

  Future<void> forceReconnect() async {
    disconnect();
    _explicitlyDisconnected = false;
    await connect(_subscribedTokens.toList());
  }

  void disconnect() {
    _explicitlyDisconnected = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _setState(WsConnectionState.disconnected);
  }

  void _scheduleReconnect() {
    if (_explicitlyDisconnected) return;
    _reconnectTimer?.cancel();

    // Exponential backoff: 2s, 4s, 8s, up to 15s max
    final delaySeconds = (2 * (1 << _reconnectAttempts)).clamp(2, 15);
    _reconnectAttempts++;

    debugPrint('[WS] Scheduling reconnect attempt $_reconnectAttempts in ${delaySeconds}s');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_explicitlyDisconnected && !isConnected) {
        connect(_subscribedTokens.toList());
      }
    });
  }

  void _onMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      // Ignore ack messages
      if (json.containsKey('status')) return;

      final update = QuoteUpdate.fromJson(json);
      _lastTickAt = DateTime.now();
      _reconnectAttempts = 0;
      _latestQuotes[update.instrumentToken] = update;
      _quoteController.add(update);
    } catch (e) {
      debugPrint('[WS] Failed to parse message: $e');
    }
  }

  void _setState(WsConnectionState state) {
    _state = state;
    notifyListeners();
  }

  void _setError(String message) {
    _lastError = message;
    _state = WsConnectionState.error;
    notifyListeners();
  }

  @override
  void dispose() {
    _explicitlyDisconnected = true;
    _reconnectTimer?.cancel();
    disconnect();
    _quoteController.close();
    super.dispose();
  }
}
