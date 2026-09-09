package com.ganesh.IKR.service;

import com.ganesh.IKR.entity.MarketCandle;
import com.ganesh.IKR.repository.InstrumentRepository;
import com.ganesh.IKR.repository.MarketCandleRepository;
import com.ganesh.IKR.strategy.Candle;
import com.ganesh.IKR.strategy.EmaCrossoverStrategy;
import com.ganesh.IKR.strategy.Signal;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

@Service
public class StrategyService {
    private final MarketCandleRepository candleRepository;
    private final InstrumentRepository instrumentRepository;
    private final EmaCrossoverStrategy emaCrossoverStrategy;

    public StrategyService(MarketCandleRepository candleRepository, InstrumentRepository instrumentRepository,
                           EmaCrossoverStrategy emaCrossoverStrategy) {
        this.candleRepository = candleRepository; this.instrumentRepository = instrumentRepository; this.emaCrossoverStrategy = emaCrossoverStrategy;
    }

    public Signal evaluateEmaCrossover(Long instrumentToken, String timeframe) {
        var instrument = instrumentRepository.findByInstrumentToken(instrumentToken).orElseThrow(() -> new IllegalArgumentException("Instrument not found"));
        List<MarketCandle> candles = new ArrayList<>(candleRepository.findTop500ByInstrumentTokenAndTimeframeOrderByCandleTimeDesc(instrumentToken, timeframe));
        Collections.reverse(candles);
        List<Candle> domainCandles = candles.stream()
                .map(c -> new Candle(c.getInstrumentToken(), c.getExchange(), c.getTimeframe(), c.getCandleTime(),
                        c.getOpen(), c.getHigh(), c.getLow(), c.getClose(), c.getVolume()))
                .toList();
        Signal signal = emaCrossoverStrategy.evaluateSeries(domainCandles);
        if (signal == null) return null;
        return new Signal(signal.instrumentToken(), signal.exchange(), instrument.getTradingsymbol(), signal.side(), signal.price(), signal.strategy(), signal.generatedAt());
    }
}
