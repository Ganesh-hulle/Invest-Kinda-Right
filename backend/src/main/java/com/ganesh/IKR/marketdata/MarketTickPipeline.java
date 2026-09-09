package com.ganesh.IKR.marketdata;

import com.ganesh.IKR.entity.Instrument;
import com.ganesh.IKR.repository.InstrumentRepository;
import com.ganesh.IKR.service.CandleAggregationService;
import org.springframework.stereotype.Service;

@Service
public class MarketTickPipeline {
    private final MarketDataStore store;
    private final MarketDataBroadcaster broadcaster;
    private final InstrumentRepository instrumentRepository;
    private final CandleAggregationService candleAggregationService;

    public MarketTickPipeline(MarketDataStore store, MarketDataBroadcaster broadcaster,
                              InstrumentRepository instrumentRepository,
                              CandleAggregationService candleAggregationService) {
        this.store = store; this.broadcaster = broadcaster;
        this.instrumentRepository = instrumentRepository; this.candleAggregationService = candleAggregationService;
    }

    public void accept(MarketTick tick) {
        Instrument instrument = instrumentRepository.findByInstrumentToken(tick.instrumentToken()).orElse(null);
        MarketTick existing = store.get(tick.instrumentToken());

        java.math.BigDecimal closePrice = tick.closePrice() != null ? tick.closePrice() : (existing != null ? existing.closePrice() : null);
        java.math.BigDecimal change = tick.change() != null ? tick.change() : (existing != null ? existing.change() : null);
        java.math.BigDecimal changePercent = tick.changePercent() != null ? tick.changePercent() : (existing != null ? existing.changePercent() : null);

        if (closePrice != null && (change == null || changePercent == null) && tick.lastPrice() != null && closePrice.compareTo(java.math.BigDecimal.ZERO) > 0) {
            change = tick.lastPrice().subtract(closePrice);
            changePercent = change.multiply(java.math.BigDecimal.valueOf(100)).divide(closePrice, 4, java.math.RoundingMode.HALF_UP);
        }

        String exchange = tick.exchange() != null ? tick.exchange() : (instrument != null ? instrument.getExchange() : null);
        String tradingsymbol = tick.tradingsymbol() != null ? tick.tradingsymbol() : (instrument != null ? instrument.getTradingsymbol() : null);

        MarketTick enriched = new MarketTick(
                tick.instrumentToken(),
                exchange,
                tradingsymbol,
                tick.lastPrice(),
                tick.lastTradedQuantity(),
                tick.cumulativeVolume(),
                closePrice,
                change,
                changePercent,
                tick.timestamp()
        );
        store.put(enriched);
        broadcaster.publish(enriched);
        candleAggregationService.accept(enriched);
    }
}
