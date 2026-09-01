package com.ganesh.IKR.dto.marketdata;

import com.ganesh.IKR.entity.MarketCandle;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record CandleResponse(Long instrumentToken, String exchange, String timeframe, OffsetDateTime candleTime,
                             BigDecimal open, BigDecimal high, BigDecimal low, BigDecimal close, Long volume) {
    public static CandleResponse from(MarketCandle candle) {
        return new CandleResponse(candle.getInstrumentToken(), candle.getExchange(), candle.getTimeframe(),
                candle.getCandleTime(), candle.getOpen(), candle.getHigh(), candle.getLow(), candle.getClose(), candle.getVolume());
    }
}
