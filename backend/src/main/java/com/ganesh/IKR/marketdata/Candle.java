package com.ganesh.IKR.marketdata;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record Candle(Long instrumentToken, String exchange, String timeframe, OffsetDateTime candleTime,
                     BigDecimal open, BigDecimal high, BigDecimal low, BigDecimal close, long volume) { }
