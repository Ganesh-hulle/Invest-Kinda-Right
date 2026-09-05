/// Analytics domain models.

// ── IndicatorSnapshot ────────────────────────────────────────────────────────

class IndicatorSnapshot {
  final int instrumentToken;
  final String timeframe;
  final DateTime? candleTime;
  final double? ema9;
  final double? ema20;
  final double? vwap;
  final double? rsi14;
  final double? macd;
  final double? macdSignal;
  final double? atr14;
  final double? superTrend;

  const IndicatorSnapshot({
    required this.instrumentToken,
    required this.timeframe,
    this.candleTime,
    this.ema9,
    this.ema20,
    this.vwap,
    this.rsi14,
    this.macd,
    this.macdSignal,
    this.atr14,
    this.superTrend,
  });

  factory IndicatorSnapshot.fromJson(Map<String, dynamic> json) {
    return IndicatorSnapshot(
      instrumentToken: (json['instrumentToken'] as num).toInt(),
      timeframe: (json['timeframe'] as String?) ?? '',
      candleTime: json['candleTime'] != null
          ? DateTime.tryParse(json['candleTime'] as String)
          : null,
      ema9: json['ema9'] != null ? (json['ema9'] as num).toDouble() : null,
      ema20: json['ema20'] != null ? (json['ema20'] as num).toDouble() : null,
      vwap: json['vwap'] != null ? (json['vwap'] as num).toDouble() : null,
      rsi14: json['rsi14'] != null ? (json['rsi14'] as num).toDouble() : null,
      macd: json['macd'] != null ? (json['macd'] as num).toDouble() : null,
      macdSignal: json['macdSignal'] != null
          ? (json['macdSignal'] as num).toDouble()
          : null,
      atr14: json['atr14'] != null ? (json['atr14'] as num).toDouble() : null,
      superTrend: json['superTrend'] != null
          ? (json['superTrend'] as num).toDouble()
          : null,
    );
  }
}

// ── CandleData ───────────────────────────────────────────────────────────────

class CandleData {
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final DateTime candleTime;

  const CandleData({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.candleTime,
  });

  factory CandleData.fromJson(Map<String, dynamic> json) {
    return CandleData(
      open: (json['open'] as num?)?.toDouble() ?? 0.0,
      high: (json['high'] as num?)?.toDouble() ?? 0.0,
      low: (json['low'] as num?)?.toDouble() ?? 0.0,
      close: (json['close'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
      candleTime: json['candleTime'] != null
          ? (DateTime.tryParse(json['candleTime'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

// ── SignalResult ─────────────────────────────────────────────────────────────

class SignalResult {
  final int instrumentToken;
  final String exchange;
  final String tradingsymbol;
  final String side; // 'BUY' | 'SELL'
  final double price;
  final String strategy;
  final DateTime generatedAt;

  const SignalResult({
    required this.instrumentToken,
    required this.exchange,
    required this.tradingsymbol,
    required this.side,
    required this.price,
    required this.strategy,
    required this.generatedAt,
  });

  factory SignalResult.fromJson(Map<String, dynamic> json) {
    return SignalResult(
      instrumentToken: (json['instrumentToken'] as num?)?.toInt() ?? 0,
      exchange: (json['exchange'] as String?) ?? '',
      tradingsymbol: (json['tradingsymbol'] as String?) ?? '',
      side: (json['side'] as String?) ?? 'NEUTRAL',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      strategy: (json['strategy'] as String?) ?? '',
      generatedAt: json['generatedAt'] != null
          ? (DateTime.tryParse(json['generatedAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

