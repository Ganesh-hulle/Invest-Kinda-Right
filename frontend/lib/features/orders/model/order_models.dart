/// Order domain models for paper and live trading.
library;

class OrderRequest {
  final int instrumentToken;
  final String side; // BUY | SELL
  final String orderType; // MARKET | LIMIT
  final int quantity;
  final double? price;
  final double? stopLoss;
  final String? idempotencyKey;

  const OrderRequest({
    required this.instrumentToken,
    required this.side,
    required this.orderType,
    required this.quantity,
    this.price,
    this.stopLoss,
    this.idempotencyKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'instrumentToken': instrumentToken,
      'side': side,
      'orderType': orderType,
      'quantity': quantity,
      if (price != null) 'price': price,
      if (stopLoss != null) 'stopLoss': stopLoss,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    };
  }
}

class PaperOrder {
  final int id;
  final int instrumentToken;
  final String tradingsymbol;
  final String exchange;
  final String side;
  final String orderType;
  final int quantity;
  final double price;
  final String status;
  final DateTime createdAt;

  const PaperOrder({
    required this.id,
    required this.instrumentToken,
    required this.tradingsymbol,
    required this.exchange,
    required this.side,
    required this.orderType,
    required this.quantity,
    required this.price,
    required this.status,
    required this.createdAt,
  });

  String get transactionType => side;

  factory PaperOrder.fromJson(Map<String, dynamic> json) {
    return PaperOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      instrumentToken:
          (json['instrumentToken'] ?? json['instrument_token'] ?? 0 as num)
              .toInt(),
      tradingsymbol:
          (json['tradingsymbol'] ?? json['trading_symbol'] ?? '') as String,
      exchange: (json['exchange'] ?? '') as String,
      side: (json['side'] ?? '') as String,
      orderType: (json['orderType'] ?? json['order_type'] ?? '') as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      status: (json['status'] ?? 'PENDING') as String,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class PaperPosition {
  final int instrumentToken;
  final String tradingsymbol;
  final String exchange;
  final int quantity;
  final double averagePrice;
  final double lastPrice;
  final double unrealizedPnl;

  const PaperPosition({
    required this.instrumentToken,
    required this.tradingsymbol,
    required this.exchange,
    required this.quantity,
    required this.averagePrice,
    required this.lastPrice,
    required this.unrealizedPnl,
  });

  factory PaperPosition.fromJson(Map<String, dynamic> json) {
    return PaperPosition(
      instrumentToken:
          (json['instrumentToken'] ?? json['instrument_token'] ?? 0 as num)
              .toInt(),
      tradingsymbol:
          (json['tradingsymbol'] ?? json['trading_symbol'] ?? '') as String,
      exchange: (json['exchange'] ?? '') as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      averagePrice:
          (json['averagePrice'] ?? json['average_price'] ?? 0).toDouble(),
      lastPrice: (json['lastPrice'] ?? json['last_price'] ?? 0).toDouble(),
      unrealizedPnl:
          (json['unrealizedPnl'] ?? json['unrealized_pnl'] ?? json['pnl'] ?? 0)
              .toDouble(),
    );
  }
}

class LiveOrder {
  final int id;
  final int instrumentToken;
  final String tradingsymbol;
  final String side;
  final String orderType;
  final int quantity;
  final double price;
  final String status;
  final String? brokerOrderId;
  final DateTime createdAt;

  const LiveOrder({
    required this.id,
    required this.instrumentToken,
    required this.tradingsymbol,
    required this.side,
    required this.orderType,
    required this.quantity,
    required this.price,
    required this.status,
    this.brokerOrderId,
    required this.createdAt,
  });

  factory LiveOrder.fromJson(Map<String, dynamic> json) {
    return LiveOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      instrumentToken:
          (json['instrumentToken'] ?? json['instrument_token'] ?? 0 as num)
              .toInt(),
      tradingsymbol:
          (json['tradingsymbol'] ?? json['trading_symbol'] ?? '') as String,
      side: (json['side'] ?? '') as String,
      orderType: (json['orderType'] ?? json['order_type'] ?? '') as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      status: (json['status'] ?? 'PENDING') as String,
      brokerOrderId: json['brokerOrderId'] as String? ??
          json['broker_order_id'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
