package com.ganesh.IKR.controller;

import com.ganesh.IKR.marketdata.InstrumentTokensRequest;
import com.ganesh.IKR.security.CustomUserDetails;
import com.ganesh.IKR.service.KiteMarketDataService;
import jakarta.validation.Valid;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/kite/market-data")
public class KiteMarketDataController {
    private final KiteMarketDataService service;
    public KiteMarketDataController(KiteMarketDataService service) { this.service = service; }

    @PostMapping("/connect")
    public Map<String, Object> connect(@Valid @RequestBody InstrumentTokensRequest request, Authentication authentication) {
        Long userId = ((CustomUserDetails) authentication.getPrincipal()).getId();
        service.connect(userId, request.instrumentTokens());
        return Map.of("status", "CONNECTING", "instrumentTokens", request.instrumentTokens());
    }

    @PostMapping("/disconnect")
    public Map<String, String> disconnect(Authentication authentication) {
        service.disconnect(((CustomUserDetails) authentication.getPrincipal()).getId());
        return Map.of("status", "DISCONNECTED");
    }
}
