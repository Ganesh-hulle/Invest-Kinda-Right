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
        Collections.reverse(candles); emaCrossoverStrategy.reset(instrumentToken);
        Signal signal = null;
        for (MarketCandle candle : candles) signal = emaCrossoverStrategy.evaluate(new Candle(candle.getInstrumentToken(), candle.getExchange(), candle.getTimeframe(), candle.getCandleTime(), candle.getOpen(), candle.getHigh(), candle.getLow(), candle.getClose(), candle.getVolume()));
        if (signal == null) return null;
        return new Signal(signal.instrumentToken(), signal.exchange(), instrument.getTradingsymbol(), signal.side(), signal.price(), signal.strategy(), signal.generatedAt());
    }
}
