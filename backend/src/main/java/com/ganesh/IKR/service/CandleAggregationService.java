package com.ganesh.IKR.service;

// import com.ganesh.IKR.entity.MarketCandle;
import com.ganesh.IKR.marketdata.Candle;
import com.ganesh.IKR.marketdata.MarketTick;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class CandleAggregationService {
    private static final ZoneId MARKET_ZONE = ZoneId.of("Asia/Kolkata");
    private static final Map<String, Long> TIMEFRAMES = Map.of("1minute", 60L, "5minute", 300L, "15minute", 900L);
    private final JdbcTemplate jdbcTemplate;
    private final Map<Key, MutableCandle> active = new ConcurrentHashMap<>();

    public CandleAggregationService(JdbcTemplate jdbcTemplate) { this.jdbcTemplate = jdbcTemplate; }

    public void accept(MarketTick tick) {
        if (tick.lastPrice() == null || tick.instrumentToken() == null || tick.timestamp() == null) return;
        TIMEFRAMES.forEach((timeframe, seconds) -> acceptForTimeframe(tick, timeframe, seconds));
    }

    private void acceptForTimeframe(MarketTick tick, String timeframe, long seconds) {
        OffsetDateTime bucket = bucket(tick.timestamp(), seconds);
        Key key = new Key(tick.instrumentToken(), timeframe);
        MutableCandle current = active.get(key);
        if (current != null && bucket.isBefore(current.candleTime)) return;
        if (current != null && current.candleTime.isBefore(bucket)) {
            persist(current.toCandle());
            active.remove(key, current);
            current = null;
        }
        if (current == null) {
            current = new MutableCandle(tick.instrumentToken(), tick.exchange(), timeframe, bucket,
                    tick.lastPrice(), tick.cumulativeVolume());
            active.put(key, current);
        } else {
            current.update(tick);
        }
    }

    @Transactional
    protected void persist(Candle candle) {
        jdbcTemplate.update("""
                INSERT INTO market_candles (instrument_token, exchange, timeframe, candle_time,
                    open, high, low, close, volume)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (instrument_token, timeframe, candle_time) DO UPDATE SET
                    exchange = EXCLUDED.exchange, open = EXCLUDED.open, high = EXCLUDED.high,
                    low = EXCLUDED.low, close = EXCLUDED.close, volume = EXCLUDED.volume
                """, candle.instrumentToken(), candle.exchange(), candle.timeframe(), candle.candleTime(),
                candle.open(), candle.high(), candle.low(), candle.close(), candle.volume());
    }

    private OffsetDateTime bucket(OffsetDateTime timestamp, long seconds) {
        long epoch = timestamp.toInstant().getEpochSecond();
        long bucketEpoch = epoch - Math.floorMod(epoch, seconds);
        return OffsetDateTime.ofInstant(java.time.Instant.ofEpochSecond(bucketEpoch), MARKET_ZONE);
    }

    private record Key(Long instrumentToken, String timeframe) { }

    private static final class MutableCandle {
        private final Long instrumentToken; private final String exchange; private final String timeframe;
        private final OffsetDateTime candleTime; private final BigDecimal open;
        private BigDecimal high; private BigDecimal low; private BigDecimal close;
        private long volume; private Long previousCumulativeVolume;

        private MutableCandle(Long instrumentToken, String exchange, String timeframe, OffsetDateTime candleTime,
                              BigDecimal price, Long cumulativeVolume) {
            this.instrumentToken = instrumentToken; this.exchange = exchange; this.timeframe = timeframe;
            this.candleTime = candleTime; this.open = price; this.high = price; this.low = price; this.close = price;
            this.previousCumulativeVolume = cumulativeVolume;
        }

        private synchronized void update(MarketTick tick) {
            close = tick.lastPrice(); high = high.max(close); low = low.min(close);
            if (tick.cumulativeVolume() != null && previousCumulativeVolume != null)
                volume += Math.max(0, tick.cumulativeVolume() - previousCumulativeVolume);
            else if (tick.lastTradedQuantity() != null) volume += Math.max(0, tick.lastTradedQuantity());
            previousCumulativeVolume = tick.cumulativeVolume();
        }

        private Candle toCandle() { return new Candle(instrumentToken, exchange, timeframe, candleTime, open, high, low, close, volume); }
    }
}
