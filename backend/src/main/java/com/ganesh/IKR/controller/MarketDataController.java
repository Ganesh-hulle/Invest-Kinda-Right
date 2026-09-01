package com.ganesh.IKR.controller;

import com.ganesh.IKR.dto.marketdata.CandleResponse;
import com.ganesh.IKR.marketdata.MarketDataStore;
import com.ganesh.IKR.marketdata.MarketTickResponse;
import com.ganesh.IKR.marketdata.MarketTickPipeline;
import com.ganesh.IKR.marketdata.DevTickRequest;
import com.ganesh.IKR.repository.MarketCandleRepository;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Value;

import java.time.OffsetDateTime;
import java.util.Arrays;
import java.util.List;

@RestController
@RequestMapping("/api/v1/market-data")
public class MarketDataController {
    private final MarketDataStore store;
    private final MarketCandleRepository candleRepository;
    private final MarketTickPipeline pipeline;
    private final boolean devTickEndpointEnabled;

    public MarketDataController(MarketDataStore store, MarketCandleRepository candleRepository, MarketTickPipeline pipeline,
                                @Value("${market-data.dev-tick-endpoint-enabled:false}") boolean devTickEndpointEnabled) {
        this.store = store; this.candleRepository = candleRepository; this.pipeline = pipeline; this.devTickEndpointEnabled = devTickEndpointEnabled;
    }

    @GetMapping("/quotes")
    public List<MarketTickResponse> quotes(@RequestParam String instrumentTokens) {
        return Arrays.stream(instrumentTokens.split(",")).map(String::trim).filter(value -> !value.isBlank())
                .map(Long::valueOf).map(store::get).filter(java.util.Objects::nonNull)
                .map(MarketTickResponse::from).toList();
    }

    @GetMapping("/candles")
    public List<CandleResponse> candles(@RequestParam Long instrumentToken, @RequestParam String timeframe,
                                        @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
                                        @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to) {
        return candleRepository.findByInstrumentTokenAndTimeframeAndCandleTimeBetweenOrderByCandleTimeAsc(
                instrumentToken, timeframe, from, to).stream().map(CandleResponse::from).toList();
    }

    @PostMapping("/ticks")
    public java.util.Map<String, String> devTick(@Valid @RequestBody DevTickRequest request) {
        if (!devTickEndpointEnabled) throw new IllegalStateException("Development tick endpoint is disabled");
        pipeline.accept(new com.ganesh.IKR.marketdata.MarketTick(request.instrumentToken(), null, null, request.lastPrice(),
                request.lastTradedQuantity(), request.cumulativeVolume(), request.timestamp() == null ? OffsetDateTime.now() : request.timestamp()));
        return java.util.Map.of("status", "ACCEPTED");
    }
}
