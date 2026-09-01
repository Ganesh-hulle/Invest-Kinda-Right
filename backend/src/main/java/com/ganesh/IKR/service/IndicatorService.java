package com.ganesh.IKR.service;

import com.ganesh.IKR.dto.indicator.IndicatorResponse;
import com.ganesh.IKR.entity.MarketCandle;
import com.ganesh.IKR.exception.KiteApiException;
import com.ganesh.IKR.repository.MarketCandleRepository;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

@Service
public class IndicatorService {
    private static final int SCALE = 8;
    private final MarketCandleRepository repository;

    public IndicatorService(MarketCandleRepository repository) { this.repository = repository; }

    public IndicatorResponse latest(Long instrumentToken, String timeframe) {
        List<MarketCandle> candles = new ArrayList<>(repository
                .findTop500ByInstrumentTokenAndTimeframeOrderByCandleTimeDesc(instrumentToken, timeframe));
        if (candles.isEmpty()) throw new KiteApiException("No candles found for the requested instrument and timeframe");
        Collections.reverse(candles);
        return calculate(instrumentToken, timeframe, candles).getLast();
    }

    public List<IndicatorResponse> calculate(Long instrumentToken, String timeframe, List<MarketCandle> candles) {
        if (candles.isEmpty()) return List.of();
        BigDecimal ema9 = null, ema20 = null, macdSignal = null, cumulativePriceVolume = BigDecimal.ZERO, cumulativeVolume = BigDecimal.ZERO;
        BigDecimal averageGain = null, averageLoss = null, previousClose = null, previousAtr = null;
        BigDecimal previousFinalUpper = null, previousFinalLower = null, previousSuperTrend = null;
        List<IndicatorResponse> result = new ArrayList<>();
        for (int index = 0; index < candles.size(); index++) {
            MarketCandle candle = candles.get(index);
            ema9 = ema(ema9, candle.getClose(), 9); ema20 = ema(ema20, candle.getClose(), 20);
            cumulativePriceVolume = cumulativePriceVolume.add(candle.getClose().multiply(BigDecimal.valueOf(candle.getVolume())));
            cumulativeVolume = cumulativeVolume.add(BigDecimal.valueOf(candle.getVolume()));
            BigDecimal vwap = cumulativeVolume.signum() == 0 ? candle.getClose() : cumulativePriceVolume.divide(cumulativeVolume, SCALE, RoundingMode.HALF_UP);

            BigDecimal rsi = null;
            if (previousClose != null) {
                BigDecimal change = candle.getClose().subtract(previousClose);
                BigDecimal gain = change.max(BigDecimal.ZERO); BigDecimal loss = change.negate().max(BigDecimal.ZERO);
                if (averageGain == null) { averageGain = gain; averageLoss = loss; }
                else { averageGain = averageGain.multiply(BigDecimal.valueOf(13)).add(gain).divide(BigDecimal.valueOf(14), SCALE, RoundingMode.HALF_UP); averageLoss = averageLoss.multiply(BigDecimal.valueOf(13)).add(loss).divide(BigDecimal.valueOf(14), SCALE, RoundingMode.HALF_UP); }
                rsi = averageLoss.signum() == 0 ? BigDecimal.valueOf(100) : BigDecimal.valueOf(100).subtract(BigDecimal.valueOf(100).divide(BigDecimal.ONE.add(averageGain.divide(averageLoss, SCALE, RoundingMode.HALF_UP)), SCALE, RoundingMode.HALF_UP));
            }
            BigDecimal trueRange = previousClose == null ? candle.getHigh().subtract(candle.getLow()) : max(candle.getHigh().subtract(candle.getLow()), candle.getHigh().subtract(previousClose).abs(), candle.getLow().subtract(previousClose).abs());
            BigDecimal atr = previousAtr == null ? trueRange : previousAtr.multiply(BigDecimal.valueOf(13)).add(trueRange).divide(BigDecimal.valueOf(14), SCALE, RoundingMode.HALF_UP);
            previousAtr = atr;
            BigDecimal macd = ema9.subtract(ema20); macdSignal = macdSignal == null ? macd : ema(macdSignal, macd, 9);
            BigDecimal midpoint = candle.getHigh().add(candle.getLow()).divide(BigDecimal.valueOf(2), SCALE, RoundingMode.HALF_UP);
            BigDecimal basicUpper = midpoint.add(atr.multiply(BigDecimal.valueOf(3))); BigDecimal basicLower = midpoint.subtract(atr.multiply(BigDecimal.valueOf(3)));
            BigDecimal finalUpper = previousFinalUpper == null ? basicUpper : (basicUpper.min(previousFinalUpper.max(candle.getClose())));
            BigDecimal finalLower = previousFinalLower == null ? basicLower : (basicLower.max(previousFinalLower.min(candle.getClose())));
            BigDecimal superTrend = previousSuperTrend == null ? finalUpper : (previousSuperTrend.compareTo(previousFinalUpper == null ? finalUpper : previousFinalUpper) == 0 ? candle.getClose().compareTo(finalUpper) <= 0 ? finalUpper : finalLower : candle.getClose().compareTo(finalLower) >= 0 ? finalLower : finalUpper);
            result.add(new IndicatorResponse(instrumentToken, timeframe, candle.getCandleTime(), ema9, ema20, vwap, rsi, macd, macdSignal, atr, superTrend));
            previousClose = candle.getClose(); previousFinalUpper = finalUpper; previousFinalLower = finalLower; previousSuperTrend = superTrend;
        }
        return result;
    }

    private BigDecimal ema(BigDecimal previous, BigDecimal value, int period) {
        if (previous == null) return value;
        BigDecimal alpha = BigDecimal.valueOf(2).divide(BigDecimal.valueOf(period + 1), SCALE, RoundingMode.HALF_UP);
        return value.subtract(previous).multiply(alpha).add(previous);
    }
    private BigDecimal max(BigDecimal... values) { BigDecimal result = values[0]; for (BigDecimal value : values) if (value.compareTo(result) > 0) result = value; return result; }
}
