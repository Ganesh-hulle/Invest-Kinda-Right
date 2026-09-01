package com.ganesh.IKR.strategy;

import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class EmaCrossoverStrategy implements Strategy {
    private final Map<Long, State> states = new ConcurrentHashMap<>();

    @Override
    public Signal evaluate(Candle candle) {
        State previous = states.get(candle.instrumentToken());
        BigDecimal shortEma = ema(previous == null ? null : previous.shortEma, candle.close(), 9);
        BigDecimal longEma = ema(previous == null ? null : previous.longEma, candle.close(), 20);
        states.put(candle.instrumentToken(), new State(shortEma, longEma));
        if (previous == null) return null;
        String side = previous.shortEma.compareTo(previous.longEma) <= 0 && shortEma.compareTo(longEma) > 0 ? "BUY" :
                previous.shortEma.compareTo(previous.longEma) >= 0 && shortEma.compareTo(longEma) < 0 ? "SELL" : null;
        return side == null ? null : new Signal(candle.instrumentToken(), candle.exchange(), null, side,
                candle.close(), "EMA_CROSSOVER", OffsetDateTime.now());
    }

    public void reset(Long instrumentToken) { states.remove(instrumentToken); }

    private BigDecimal ema(BigDecimal previous, BigDecimal value, int period) {
        if (previous == null) return value;
        BigDecimal alpha = BigDecimal.valueOf(2).divide(BigDecimal.valueOf(period + 1), 8, RoundingMode.HALF_UP);
        return value.subtract(previous).multiply(alpha).add(previous);
    }
    private record State(BigDecimal shortEma, BigDecimal longEma) { }
}
