package com.ganesh.IKR.strategy;

import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class EmaCrossoverStrategy implements Strategy {
    private final Map<Key, State> states = new ConcurrentHashMap<>();

    @Override
    public Signal evaluate(Candle candle) {
        Key key = new Key(candle.instrumentToken(), candle.timeframe());
        State previous = states.get(key);
        BigDecimal shortEma = ema(previous == null ? null : previous.shortEma, candle.close(), 9);
        BigDecimal longEma = ema(previous == null ? null : previous.longEma, candle.close(), 20);
        states.put(key, new State(shortEma, longEma));
        if (previous == null) return null;
        String side = previous.shortEma.compareTo(previous.longEma) <= 0 && shortEma.compareTo(longEma) > 0 ? "BUY" :
                previous.shortEma.compareTo(previous.longEma) >= 0 && shortEma.compareTo(longEma) < 0 ? "SELL" : null;
        return side == null ? null : new Signal(candle.instrumentToken(), candle.exchange(), null, side,
                candle.close(), "EMA_CROSSOVER", OffsetDateTime.now());
    }

    public Signal evaluateSeries(List<Candle> candles) {
        if (candles == null || candles.isEmpty()) return null;
        State state = null;
        Signal lastSignal = null;
        for (Candle candle : candles) {
            BigDecimal shortEma = ema(state == null ? null : state.shortEma, candle.close(), 9);
            BigDecimal longEma = ema(state == null ? null : state.longEma, candle.close(), 20);
            if (state != null) {
                String side = state.shortEma.compareTo(state.longEma) <= 0 && shortEma.compareTo(longEma) > 0 ? "BUY" :
                        state.shortEma.compareTo(state.longEma) >= 0 && shortEma.compareTo(longEma) < 0 ? "SELL" : null;
                lastSignal = side == null ? null : new Signal(candle.instrumentToken(), candle.exchange(), null, side,
                        candle.close(), "EMA_CROSSOVER", candle.candleTime());
            }
            state = new State(shortEma, longEma);
        }
        return lastSignal;
    }

    public void reset(Long instrumentToken) {
        states.keySet().removeIf(k -> k.instrumentToken().equals(instrumentToken));
    }

    private BigDecimal ema(BigDecimal previous, BigDecimal value, int period) {
        if (previous == null) return value;
        BigDecimal alpha = BigDecimal.valueOf(2).divide(BigDecimal.valueOf(period + 1), 8, RoundingMode.HALF_UP);
        return value.subtract(previous).multiply(alpha).add(previous);
    }

    private record Key(Long instrumentToken, String timeframe) { }
    private record State(BigDecimal shortEma, BigDecimal longEma) { }
}
