/// Risk management limits returned from / sent to the backend.
class RiskLimits {
  final double maxDailyLoss;
  final int maxTradesPerDay;
  final double maxCapitalPerTrade;
  final int maxOpenPositions;
  final int maxPositionSize;
  final bool tradingEnabled;

  const RiskLimits({
    required this.maxDailyLoss,
    required this.maxTradesPerDay,
    required this.maxCapitalPerTrade,
    required this.maxOpenPositions,
    required this.maxPositionSize,
    required this.tradingEnabled,
  });

  factory RiskLimits.fromJson(Map<String, dynamic> json) {
    return RiskLimits(
      maxDailyLoss: (json['maxDailyLoss'] as num?)?.toDouble() ?? 0.0,
      maxTradesPerDay: (json['maxTradesPerDay'] as num?)?.toInt() ?? 0,
      maxCapitalPerTrade: (json['maxCapitalPerTrade'] as num?)?.toDouble() ?? 0.0,
      maxOpenPositions: (json['maxOpenPositions'] as num?)?.toInt() ?? 0,
      maxPositionSize: (json['maxPositionSize'] as num?)?.toInt() ?? 0,
      tradingEnabled: (json['tradingEnabled'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'maxDailyLoss': maxDailyLoss,
        'maxTradesPerDay': maxTradesPerDay,
        'maxCapitalPerTrade': maxCapitalPerTrade,
        'maxOpenPositions': maxOpenPositions,
        'maxPositionSize': maxPositionSize,
        'tradingEnabled': tradingEnabled,
      };

  RiskLimits copyWith({
    double? maxDailyLoss,
    int? maxTradesPerDay,
    double? maxCapitalPerTrade,
    int? maxOpenPositions,
    int? maxPositionSize,
    bool? tradingEnabled,
  }) {
    return RiskLimits(
      maxDailyLoss: maxDailyLoss ?? this.maxDailyLoss,
      maxTradesPerDay: maxTradesPerDay ?? this.maxTradesPerDay,
      maxCapitalPerTrade: maxCapitalPerTrade ?? this.maxCapitalPerTrade,
      maxOpenPositions: maxOpenPositions ?? this.maxOpenPositions,
      maxPositionSize: maxPositionSize ?? this.maxPositionSize,
      tradingEnabled: tradingEnabled ?? this.tradingEnabled,
    );
  }
}

