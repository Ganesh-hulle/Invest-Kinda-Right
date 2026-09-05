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
  final double? change;
  final double? changePercent;
  final DateTime receivedAt;

  QuoteUpdate({
    required this.instrumentToken,
    required this.lastPrice,
    this.tradingsymbol,
    this.exchange,
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
      change:
          json['change'] != null ? (json['change'] as num).toDouble() : null,
      changePercent: json['changePercent'] != null
          ? (json['changePercent'] as num).toDouble()
          : null,
    );
  }
}

enum WsConnectionState { disconnected, connecting, connected, error }

/// Manages the authenticated internal WebSocket at `ws://host/ws/market`.
class MarketWsService extends ChangeNotifier {
  final SecureStorage secureStorage;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;

  WsConnectionState _state = WsConnectionState.disconnected;
  String? _lastError;
  String _wsBaseUrl = 'ws://127.0.0.1:8080';

  // Stream controller for quote updates
  final _quoteController = StreamController<QuoteUpdate>.broadcast();

  // In-memory latest quotes keyed by instrument token
  final Map<int, QuoteUpdate> _latestQuotes = {};

  MarketWsService({required this.secureStorage});

  WsConnectionState get state => _state;
  String? get lastError => _lastError;
  bool get isConnected => _state == WsConnectionState.connected;
  Stream<QuoteUpdate> get quoteStream => _quoteController.stream;
  Map<int, QuoteUpdate> get latestQuotes => Map.unmodifiable(_latestQuotes);

  void updateWsBaseUrl(String url) => _wsBaseUrl = url;

  Future<void> connect(List<int> instrumentTokens) async {
    if (_state == WsConnectionState.connected ||
        _state == WsConnectionState.connecting) {
      return;
    }

    _setState(WsConnectionState.connecting);
    _lastError = null;

    try {
      final token = await secureStorage.readToken();
      if (token == null) {
        _setError('Not authenticated');
        return;
      }

      final uri = Uri.parse('$_wsBaseUrl/ws/market?access_token=$token');
      _channel = WebSocketChannel.connect(uri);

      await _channel!.ready;
      _setState(WsConnectionState.connected);

      // Subscribe to instrument tokens
      _channel!.sink.add(jsonEncode({
        'action': 'subscribe',
        'instrumentTokens': instrumentTokens,
      }));

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (e) => _setError(e.toString()),
        onDone: () {
          if (_state != WsConnectionState.disconnected) {
            _setState(WsConnectionState.disconnected);
          }
        },
      );
    } catch (e) {
      _setError(e.toString());
    }
  }

  void subscribe(List<int> instrumentTokens) {
    if (!isConnected) return;
    _channel?.sink.add(jsonEncode({
      'action': 'subscribe',
      'instrumentTokens': instrumentTokens,
    }));
  }

  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _setState(WsConnectionState.disconnected);
  }

  void _onMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      // Ignore ack messages
      if (json.containsKey('status')) return;

      final update = QuoteUpdate.fromJson(json);
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
    disconnect();
    _quoteController.close();
    super.dispose();
  }
}
