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
        MarketTick enriched = instrument == null || tick.tradingsymbol() != null ? tick :
                new MarketTick(tick.instrumentToken(), instrument.getExchange(), instrument.getTradingsymbol(),
                        tick.lastPrice(), tick.lastTradedQuantity(), tick.cumulativeVolume(), tick.timestamp());
        store.put(enriched);
        broadcaster.publish(enriched);
        candleAggregationService.accept(enriched);
    }
}
