/// Models for the Watchlist feature.
library;

class InstrumentResult {
  final int instrumentToken;
  final String tradingsymbol;
  final String name;
  final String exchange;
  final String instrumentType;
  final String segment;
  final int lotSize;

  const InstrumentResult({
    required this.instrumentToken,
    required this.tradingsymbol,
    required this.name,
    required this.exchange,
    required this.instrumentType,
    required this.segment,
    required this.lotSize,
  });

  factory InstrumentResult.fromJson(Map<String, dynamic> json) {
    return InstrumentResult(
      instrumentToken: (json['instrumentToken'] as num?)?.toInt() ??
          (json['instrument_token'] as num?)?.toInt() ??
          0,
      tradingsymbol: json['tradingsymbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      exchange: json['exchange']?.toString() ?? '',
      instrumentType: json['instrumentType']?.toString() ??
          json['instrument_type']?.toString() ??
          '',
      segment: json['segment']?.toString() ?? '',
      lotSize: (json['lotSize'] as num?)?.toInt() ??
          (json['lot_size'] as num?)?.toInt() ??
          1,
    );
  }

  Map<String, dynamic> toJson() => {
        'instrumentToken': instrumentToken,
        'tradingsymbol': tradingsymbol,
        'name': name,
        'exchange': exchange,
        'instrumentType': instrumentType,
        'segment': segment,
        'lotSize': lotSize,
      };
}

enum PriceDirection { none, up, down }

class WatchlistItem {
  final int instrumentToken;
  final String tradingsymbol;
  final String exchange;
  final double lastPrice;
  final double closePrice;
  final double change;
  final double changePercent;
  final bool isLoading;
  final double? previousPrice;
  final PriceDirection priceDirection;
  final DateTime? lastUpdated;

  const WatchlistItem({
    required this.instrumentToken,
    required this.tradingsymbol,
    required this.exchange,
    this.lastPrice = 0.0,
    this.closePrice = 0.0,
    this.change = 0.0,
    this.changePercent = 0.0,
    this.isLoading = false,
    this.previousPrice,
    this.priceDirection = PriceDirection.none,
    this.lastUpdated,
  });

  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    final lastPrice = (json['lastPrice'] as num?)?.toDouble() ??
        (json['last_price'] as num?)?.toDouble() ??
        0.0;
    final change = (json['change'] as num?)?.toDouble() ?? 0.0;
    final parsedClose = (json['closePrice'] as num?)?.toDouble() ??
        (json['close_price'] as num?)?.toDouble();
    final closePrice = parsedClose ??
        ((lastPrice > 0 && change != 0) ? (lastPrice - change) : lastPrice);

    return WatchlistItem(
      instrumentToken: (json['instrumentToken'] as num?)?.toInt() ??
          (json['instrument_token'] as num?)?.toInt() ??
          0,
      tradingsymbol: json['tradingsymbol']?.toString() ?? '',
      exchange: json['exchange']?.toString() ?? '',
      lastPrice: lastPrice,
      closePrice: closePrice,
      change: change,
      changePercent: (json['changePercent'] as num?)?.toDouble() ??
          (json['change_percent'] as num?)?.toDouble() ??
          0.0,
      isLoading: false,
      priceDirection: PriceDirection.none,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'instrumentToken': instrumentToken,
        'tradingsymbol': tradingsymbol,
        'exchange': exchange,
        'lastPrice': lastPrice,
        'closePrice': closePrice,
        'change': change,
        'changePercent': changePercent,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };

  WatchlistItem copyWith({
    double? lastPrice,
    double? closePrice,
    double? change,
    double? changePercent,
    bool? isLoading,
    String? tradingsymbol,
    String? exchange,
    double? previousPrice,
    PriceDirection? priceDirection,
    DateTime? lastUpdated,
  }) {
    return WatchlistItem(
      instrumentToken: instrumentToken,
      tradingsymbol: tradingsymbol ?? this.tradingsymbol,
      exchange: exchange ?? this.exchange,
      lastPrice: lastPrice ?? this.lastPrice,
      closePrice: closePrice ?? this.closePrice,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      isLoading: isLoading ?? this.isLoading,
      previousPrice: previousPrice ?? this.previousPrice,
      priceDirection: priceDirection ?? this.priceDirection,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
