package com.ganesh.IKR.controller;

import com.ganesh.IKR.dto.marketdata.CandleResponse;
import com.ganesh.IKR.entity.Instrument;
import com.ganesh.IKR.entity.MarketCandle;
import com.ganesh.IKR.marketdata.MarketDataStore;
import com.ganesh.IKR.marketdata.MarketTickResponse;
import com.ganesh.IKR.marketdata.MarketTickPipeline;
import com.ganesh.IKR.marketdata.DevTickRequest;
import com.ganesh.IKR.repository.InstrumentRepository;
import com.ganesh.IKR.repository.MarketCandleRepository;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Value;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.Arrays;
import java.util.List;

@RestController
@RequestMapping("/api/v1/market-data")
public class MarketDataController {
    private static final ZoneId ZONE_IST = ZoneId.of("Asia/Kolkata");

    private final MarketDataStore store;
    private final MarketCandleRepository candleRepository;
    private final InstrumentRepository instrumentRepository;
    private final MarketTickPipeline pipeline;
    private final boolean devTickEndpointEnabled;

    public MarketDataController(MarketDataStore store, MarketCandleRepository candleRepository,
                                InstrumentRepository instrumentRepository, MarketTickPipeline pipeline,
                                @Value("${market-data.dev-tick-endpoint-enabled:false}") boolean devTickEndpointEnabled) {
        this.store = store;
        this.candleRepository = candleRepository;
        this.instrumentRepository = instrumentRepository;
        this.pipeline = pipeline;
        this.devTickEndpointEnabled = devTickEndpointEnabled;
    }

    @GetMapping("/quotes")
    public List<MarketTickResponse> quotes(@RequestParam String instrumentTokens) {
        return Arrays.stream(instrumentTokens.split(",")).map(String::trim).filter(value -> !value.isBlank())
                .map(Long::valueOf)
                .map(token -> {
                    com.ganesh.IKR.marketdata.MarketTick tick = store.get(token);
                    if (tick != null) {
                        return MarketTickResponse.from(tick);
                    }
                    // Fallback to latest stored candles if no live tick in memory yet
                    List<MarketCandle> dayCandles = candleRepository.findTop500ByInstrumentTokenAndTimeframeOrderByCandleTimeDesc(token, "day");
                    if (!dayCandles.isEmpty()) {
                        MarketCandle latest = dayCandles.getFirst();
                        BigDecimal lastPrice = latest.getClose();
                        BigDecimal closePrice = dayCandles.size() > 1 ? dayCandles.get(1).getClose() : latest.getOpen();
                        BigDecimal change = lastPrice.subtract(closePrice);
                        BigDecimal changePercent = closePrice.signum() > 0
                                ? change.multiply(BigDecimal.valueOf(100)).divide(closePrice, 4, RoundingMode.HALF_UP)
                                : BigDecimal.ZERO;
                        Instrument inst = instrumentRepository.findByInstrumentToken(token).orElse(null);
                        return new MarketTickResponse(token,
                                inst != null ? inst.getExchange() : null,
                                inst != null ? inst.getTradingsymbol() : null,
                                lastPrice, null, latest.getVolume(),
                                closePrice, change, changePercent, latest.getCandleTime());
                    }
                    List<MarketCandle> minCandles = candleRepository.findTop500ByInstrumentTokenAndTimeframeOrderByCandleTimeDesc(token, "5minute");
                    if (!minCandles.isEmpty()) {
                        MarketCandle latest = minCandles.getFirst();
                        MarketCandle firstOfDay = minCandles.getLast();
                        BigDecimal lastPrice = latest.getClose();
                        BigDecimal closePrice = firstOfDay.getOpen();
                        BigDecimal change = lastPrice.subtract(closePrice);
                        BigDecimal changePercent = closePrice.signum() > 0
                                ? change.multiply(BigDecimal.valueOf(100)).divide(closePrice, 4, RoundingMode.HALF_UP)
                                : BigDecimal.ZERO;
                        Instrument inst = instrumentRepository.findByInstrumentToken(token).orElse(null);
                        return new MarketTickResponse(token,
                                inst != null ? inst.getExchange() : null,
                                inst != null ? inst.getTradingsymbol() : null,
                                lastPrice, null, latest.getVolume(),
                                closePrice, change, changePercent, latest.getCandleTime());
                    }
                    Instrument inst = instrumentRepository.findByInstrumentToken(token).orElse(null);
                    if (inst != null) {
                        return new MarketTickResponse(token, inst.getExchange(), inst.getTradingsymbol(),
                                BigDecimal.ZERO, null, null, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO,
                                OffsetDateTime.now(ZONE_IST));
                    }
                    return null;
                })
                .filter(java.util.Objects::nonNull)
                .toList();
    }

    @GetMapping("/candles")
    public List<CandleResponse> candles(@RequestParam Long instrumentToken,
                                        @RequestParam String timeframe,
                                        @RequestParam(required = false) String from,
                                        @RequestParam(required = false) String to) {
        OffsetDateTime fromDateTime = parseDateTime(from, false, 30);
        OffsetDateTime toDateTime = parseDateTime(to, true, 0);
        return candleRepository.findByInstrumentTokenAndTimeframeAndCandleTimeBetweenOrderByCandleTimeAsc(
                instrumentToken, timeframe, fromDateTime, toDateTime).stream().map(CandleResponse::from).toList();
    }

    @PostMapping("/ticks")
    public java.util.Map<String, String> devTick(@Valid @RequestBody DevTickRequest request) {
        if (!devTickEndpointEnabled) throw new IllegalStateException("Development tick endpoint is disabled");
        pipeline.accept(new com.ganesh.IKR.marketdata.MarketTick(request.instrumentToken(), null, null, request.lastPrice(),
                request.lastTradedQuantity(), request.cumulativeVolume(), request.timestamp() == null
                        ? OffsetDateTime.now(ZoneId.of("Asia/Kolkata")) : request.timestamp()));
        return java.util.Map.of("status", "ACCEPTED");
    }

    private OffsetDateTime parseDateTime(String value, boolean endOfDay, int fallbackDaysBack) {
        if (value == null || value.isBlank()) {
            OffsetDateTime now = OffsetDateTime.now(ZONE_IST);
            return fallbackDaysBack > 0 ? now.minusDays(fallbackDaysBack) : now;
        }
        String trimmed = value.trim();
        try {
            return OffsetDateTime.parse(trimmed);
        } catch (Exception e1) {
            try {
                LocalDateTime ldt = LocalDateTime.parse(trimmed);
                return ldt.atZone(ZONE_IST).toOffsetDateTime();
            } catch (Exception e2) {
                try {
                    LocalDate ld = LocalDate.parse(trimmed);
                    return (endOfDay ? ld.atTime(23, 59, 59) : ld.atStartOfDay()).atZone(ZONE_IST).toOffsetDateTime();
                } catch (Exception e3) {
                    throw new IllegalArgumentException("Invalid date format: " + value + ". Expected ISO-8601 or yyyy-MM-dd");
                }
            }
        }
    }
}

