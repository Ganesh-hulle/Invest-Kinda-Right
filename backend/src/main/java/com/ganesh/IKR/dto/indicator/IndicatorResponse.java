package com.ganesh.IKR.dto.indicator;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record IndicatorResponse(Long instrumentToken, String timeframe, OffsetDateTime candleTime,
                               BigDecimal ema9, BigDecimal ema20, BigDecimal vwap, BigDecimal rsi14,
                               BigDecimal macd, BigDecimal macdSignal, BigDecimal atr14, BigDecimal superTrend) { }
