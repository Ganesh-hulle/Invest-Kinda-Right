package com.ganesh.IKR.marketdata;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class MarketDataStore {
    private static final Logger log = LoggerFactory.getLogger(MarketDataStore.class);
    private static final Duration TTL = Duration.ofHours(12);
    private final StringRedisTemplate redis;
    private final ObjectMapper objectMapper;
    private final Map<Long, MarketTick> fallback = new ConcurrentHashMap<>();

    public MarketDataStore(StringRedisTemplate redis, ObjectMapper objectMapper) {
        this.redis = redis;
        this.objectMapper = objectMapper;
    }

    public void put(MarketTick tick) {
        fallback.put(tick.instrumentToken(), tick);
        try {
            redis.opsForValue().set(key(tick.instrumentToken()), objectMapper.writeValueAsString(tick), TTL);
        } catch (Exception exception) {
            log.warn("Redis quote write failed; in-memory fallback retained: {}", exception.getMessage());
        }
    }

    public MarketTick get(Long instrumentToken) {
        try {
            String value = redis.opsForValue().get(key(instrumentToken));
            if (value != null) return objectMapper.readValue(value, MarketTick.class);
        } catch (Exception exception) {
            log.debug("Redis quote read failed: {}", exception.getMessage());
        }
        return fallback.get(instrumentToken);
    }

    private String key(Long instrumentToken) { return "ikr:market:quote:" + instrumentToken; }
}
