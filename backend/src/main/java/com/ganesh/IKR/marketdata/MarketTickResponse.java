package com.ganesh.IKR.marketdata;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record MarketTickResponse(Long instrumentToken, String exchange, String tradingsymbol,
                                 BigDecimal lastPrice, Long lastTradedQuantity, Long cumulativeVolume,
                                 BigDecimal closePrice, BigDecimal change, BigDecimal changePercent,
                                 OffsetDateTime timestamp) {
    public static MarketTickResponse from(MarketTick tick) {
        return new MarketTickResponse(tick.instrumentToken(), tick.exchange(), tick.tradingsymbol(),
                tick.lastPrice(), tick.lastTradedQuantity(), tick.cumulativeVolume(),
                tick.closePrice(), tick.change(), tick.changePercent(), tick.timestamp());
    }

    public MarketTickResponse(Long instrumentToken, String exchange, String tradingsymbol,
                              BigDecimal lastPrice, Long lastTradedQuantity, Long cumulativeVolume,
                              OffsetDateTime timestamp) {
        this(instrumentToken, exchange, tradingsymbol, lastPrice, lastTradedQuantity, cumulativeVolume,
                null, null, null, timestamp);
    }
}
