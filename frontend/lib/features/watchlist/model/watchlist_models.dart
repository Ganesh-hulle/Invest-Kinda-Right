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

class WatchlistItem {
  final int instrumentToken;
  final String tradingsymbol;
  final String exchange;
  final double lastPrice;
  final double change;
  final double changePercent;
  final bool isLoading;

  const WatchlistItem({
    required this.instrumentToken,
    required this.tradingsymbol,
    required this.exchange,
    this.lastPrice = 0.0,
    this.change = 0.0,
    this.changePercent = 0.0,
    this.isLoading = false,
  });

  WatchlistItem copyWith({
    double? lastPrice,
    double? change,
    double? changePercent,
    bool? isLoading,
  }) {
    return WatchlistItem(
      instrumentToken: instrumentToken,
      tradingsymbol: tradingsymbol,
      exchange: exchange,
      lastPrice: lastPrice ?? this.lastPrice,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
