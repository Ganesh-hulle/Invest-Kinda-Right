package com.ganesh.IKR.marketdata;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;

public record MarketTick(Long instrumentToken, String exchange, String tradingsymbol,
                         BigDecimal lastPrice, Long lastTradedQuantity, Long cumulativeVolume,
                         BigDecimal closePrice, BigDecimal change, BigDecimal changePercent,
                         OffsetDateTime timestamp) {

    public MarketTick {
        if (closePrice != null && lastPrice != null && closePrice.compareTo(BigDecimal.ZERO) > 0) {
            if (change == null) {
                change = lastPrice.subtract(closePrice);
            }
            if (changePercent == null && change != null) {
                changePercent = change.multiply(BigDecimal.valueOf(100))
                        .divide(closePrice, 4, RoundingMode.HALF_UP);
            }
        }
    }

    public MarketTick(Long instrumentToken, String exchange, String tradingsymbol,
                      BigDecimal lastPrice, Long lastTradedQuantity, Long cumulativeVolume,
                      OffsetDateTime timestamp) {
        this(instrumentToken, exchange, tradingsymbol, lastPrice, lastTradedQuantity, cumulativeVolume,
                null, null, null, timestamp);
    }
}
