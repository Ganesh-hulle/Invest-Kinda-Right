import '../../watchlist/model/watchlist_models.dart' show PriceDirection;

/// Portfolio domain models.
class HoldingItem {
  final int? instrumentToken;
  final String tradingsymbol;
  final String exchange;
  final int quantity;
  final double averagePrice;
  final double lastPrice;
  final double closePrice;
  final double pnl;
  final double dayChange;
  final double dayChangePercentage;
  final double? previousPrice;
  final PriceDirection priceDirection;

  const HoldingItem({
    this.instrumentToken,
    required this.tradingsymbol,
    required this.exchange,
    required this.quantity,
    required this.averagePrice,
    required this.lastPrice,
    this.closePrice = 0.0,
    required this.pnl,
    this.dayChange = 0.0,
    this.dayChangePercentage = 0.0,
    this.previousPrice,
    this.priceDirection = PriceDirection.none,
  });

  /// Total unrealised PnL return percentage on invested capital.
  double get totalPnlPercent => (averagePrice > 0 && quantity != 0)
      ? (pnl / (averagePrice * quantity.abs())) * 100.0
      : 0.0;

  factory HoldingItem.fromJson(Map<String, dynamic> json) {
    final token = (json['instrument_token'] ?? json['instrumentToken'] as num?)?.toInt();
    final avg = (json['averagePrice'] ?? json['average_price'] ?? 0).toDouble();
    final ltp = (json['lastPrice'] ?? json['last_price'] ?? 0).toDouble();
    final close = (json['closePrice'] ?? json['close_price'] as num?)?.toDouble() ?? 0.0;
    final dayChg = (json['day_change'] ?? json['dayChange'] as num?)?.toDouble() ??
        (close > 0 && ltp > 0 ? (ltp - close) : 0.0);
    final dayChgPct = (json['day_change_percentage'] ?? json['dayChangePercentage'] as num?)?.toDouble() ??
        (close > 0 ? (dayChg / close) * 100.0 : 0.0);
    final pnlVal = (json['pnl'] ?? json['unrealised_profit'] as num?)?.toDouble() ??
        (ltp > 0 && avg > 0 ? (ltp - avg) * ((json['quantity'] as num?)?.toInt() ?? 0) : 0.0);

    return HoldingItem(
      instrumentToken: token,
      tradingsymbol:
          (json['tradingsymbol'] ?? json['trading_symbol'] ?? '') as String,
      exchange: (json['exchange'] ?? '') as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      averagePrice: avg,
      lastPrice: ltp,
      closePrice: close,
      pnl: pnlVal,
      dayChange: dayChg,
      dayChangePercentage: dayChgPct,
    );
  }

  HoldingItem copyWith({
    int? instrumentToken,
    String? tradingsymbol,
    String? exchange,
    int? quantity,
    double? averagePrice,
    double? lastPrice,
    double? closePrice,
    double? pnl,
    double? dayChange,
    double? dayChangePercentage,
    double? previousPrice,
    PriceDirection? priceDirection,
  }) {
    return HoldingItem(
      instrumentToken: instrumentToken ?? this.instrumentToken,
      tradingsymbol: tradingsymbol ?? this.tradingsymbol,
      exchange: exchange ?? this.exchange,
      quantity: quantity ?? this.quantity,
      averagePrice: averagePrice ?? this.averagePrice,
      lastPrice: lastPrice ?? this.lastPrice,
      closePrice: closePrice ?? this.closePrice,
      pnl: pnl ?? this.pnl,
      dayChange: dayChange ?? this.dayChange,
      dayChangePercentage: dayChangePercentage ?? this.dayChangePercentage,
      previousPrice: previousPrice ?? this.previousPrice,
      priceDirection: priceDirection ?? this.priceDirection,
    );
  }
}

class PositionItem {
  final int? instrumentToken;
  final String tradingsymbol;
  final String exchange;
  final int quantity;
  final double averagePrice;
  final double lastPrice;
  final double closePrice;
  final double pnl;
  final double m2m;
  final double dayChange;
  final double dayChangePercentage;
  final String product;
  final double? previousPrice;
  final PriceDirection priceDirection;

  const PositionItem({
    this.instrumentToken,
    required this.tradingsymbol,
    required this.exchange,
    required this.quantity,
    required this.averagePrice,
    required this.lastPrice,
    this.closePrice = 0.0,
    required this.pnl,
    this.m2m = 0.0,
    this.dayChange = 0.0,
    this.dayChangePercentage = 0.0,
    required this.product,
    this.previousPrice,
    this.priceDirection = PriceDirection.none,
  });

  /// Total unrealised PnL return percentage on invested / margin capital.
  double get totalPnlPercent => (averagePrice > 0 && quantity != 0)
      ? (pnl / (averagePrice * quantity.abs())) * 100.0
      : 0.0;

  factory PositionItem.fromJson(Map<String, dynamic> json) {
    final token = (json['instrument_token'] ?? json['instrumentToken'] as num?)?.toInt();
    final avg = (json['averagePrice'] ?? json['average_price'] ?? 0).toDouble();
    final ltp = (json['lastPrice'] ?? json['last_price'] ?? 0).toDouble();
    final close = (json['closePrice'] ?? json['close_price'] as num?)?.toDouble() ?? 0.0;
    final m2mVal = (json['m2m'] as num?)?.toDouble() ?? 0.0;
    final pnlVal = (json['pnl'] ?? json['unrealised'] ?? json['realised'] ?? 0).toDouble();
    final dayChg = (json['day_change'] ?? json['dayChange'] as num?)?.toDouble() ??
        (close > 0 && ltp > 0 ? (ltp - close) : 0.0);
    final dayChgPct = (json['day_change_percentage'] ?? json['dayChangePercentage'] as num?)?.toDouble() ??
        (close > 0 ? (dayChg / close) * 100.0 : 0.0);

    return PositionItem(
      instrumentToken: token,
      tradingsymbol:
          (json['tradingsymbol'] ?? json['trading_symbol'] ?? '') as String,
      exchange: (json['exchange'] ?? '') as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      averagePrice: avg,
      lastPrice: ltp,
      closePrice: close,
      pnl: pnlVal,
      m2m: m2mVal,
      dayChange: dayChg,
      dayChangePercentage: dayChgPct,
      product: (json['product'] ?? '') as String,
    );
  }

  PositionItem copyWith({
    int? instrumentToken,
    String? tradingsymbol,
    String? exchange,
    int? quantity,
    double? averagePrice,
    double? lastPrice,
    double? closePrice,
    double? pnl,
    double? m2m,
    double? dayChange,
    double? dayChangePercentage,
    String? product,
    double? previousPrice,
    PriceDirection? priceDirection,
  }) {
    return PositionItem(
      instrumentToken: instrumentToken ?? this.instrumentToken,
      tradingsymbol: tradingsymbol ?? this.tradingsymbol,
      exchange: exchange ?? this.exchange,
      quantity: quantity ?? this.quantity,
      averagePrice: averagePrice ?? this.averagePrice,
      lastPrice: lastPrice ?? this.lastPrice,
      closePrice: closePrice ?? this.closePrice,
      pnl: pnl ?? this.pnl,
      m2m: m2m ?? this.m2m,
      dayChange: dayChange ?? this.dayChange,
      dayChangePercentage: dayChangePercentage ?? this.dayChangePercentage,
      product: product ?? this.product,
      previousPrice: previousPrice ?? this.previousPrice,
      priceDirection: priceDirection ?? this.priceDirection,
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

  PortfolioResponse copyWith({
    List<HoldingItem>? holdings,
    List<PositionItem>? netPositions,
    List<PositionItem>? dayPositions,
  }) {
    return PortfolioResponse(
      holdings: holdings ?? this.holdings,
      netPositions: netPositions ?? this.netPositions,
      dayPositions: dayPositions ?? this.dayPositions,
    );
  }
}
