/// Portfolio domain models.
class HoldingItem {
  final String tradingsymbol;
  final String exchange;
  final int quantity;
  final double averagePrice;
  final double lastPrice;
  final double pnl;

  const HoldingItem({
    required this.tradingsymbol,
    required this.exchange,
    required this.quantity,
    required this.averagePrice,
    required this.lastPrice,
    required this.pnl,
  });

  factory HoldingItem.fromJson(Map<String, dynamic> json) {
    return HoldingItem(
      tradingsymbol:
          (json['tradingsymbol'] ?? json['trading_symbol'] ?? '') as String,
      exchange: (json['exchange'] ?? '') as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      averagePrice:
          (json['averagePrice'] ?? json['average_price'] ?? 0).toDouble(),
      lastPrice: (json['lastPrice'] ?? json['last_price'] ?? 0).toDouble(),
      pnl: (json['pnl'] ?? json['unrealised_profit'] ?? 0).toDouble(),
    );
  }
}

class PositionItem {
  final String tradingsymbol;
  final String exchange;
  final int quantity;
  final double averagePrice;
  final double lastPrice;
  final double pnl;
  final String product;

  const PositionItem({
    required this.tradingsymbol,
    required this.exchange,
    required this.quantity,
    required this.averagePrice,
    required this.lastPrice,
    required this.pnl,
    required this.product,
  });

  factory PositionItem.fromJson(Map<String, dynamic> json) {
    return PositionItem(
      tradingsymbol:
          (json['tradingsymbol'] ?? json['trading_symbol'] ?? '') as String,
      exchange: (json['exchange'] ?? '') as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      averagePrice:
          (json['averagePrice'] ?? json['average_price'] ?? 0).toDouble(),
      lastPrice: (json['lastPrice'] ?? json['last_price'] ?? 0).toDouble(),
      pnl: (json['pnl'] ?? json['unrealised'] ?? json['realised'] ?? 0)
          .toDouble(),
      product: (json['product'] ?? '') as String,
    );
  }
}

class PortfolioResponse {
  final List<HoldingItem> holdings;
  final List<PositionItem> netPositions;
  final List<PositionItem> dayPositions;

  const PortfolioResponse({
    required this.holdings,
    required this.netPositions,
    required this.dayPositions,
  });

  factory PortfolioResponse.fromJson(Map<String, dynamic> json) {
    List<HoldingItem> parseHoldings(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw
            .map((e) =>
                HoldingItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    }

    List<PositionItem> parsePositions(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw
            .map((e) =>
                PositionItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    }

    // Support both flat and nested response shapes
    final positionsRaw = json['positions'];
    List<PositionItem> net = [];
    List<PositionItem> day = [];

    if (positionsRaw is Map) {
      net = parsePositions(positionsRaw['net']);
      day = parsePositions(positionsRaw['day']);
    } else {
      net = parsePositions(json['netPositions'] ?? json['net_positions']);
      day = parsePositions(json['dayPositions'] ?? json['day_positions']);
    }

    return PortfolioResponse(
      holdings: parseHoldings(json['holdings']),
      netPositions: net,
      dayPositions: day,
    );
  }

  /// Empty portfolio used for initial / error states.
  factory PortfolioResponse.empty() => const PortfolioResponse(
        holdings: [],
        netPositions: [],
        dayPositions: [],
      );
}
