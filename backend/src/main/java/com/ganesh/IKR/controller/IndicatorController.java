package com.ganesh.IKR.controller;

import com.ganesh.IKR.dto.indicator.IndicatorResponse;
import com.ganesh.IKR.service.IndicatorService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/indicators")
public class IndicatorController {
    private final IndicatorService service;
    public IndicatorController(IndicatorService service) { this.service = service; }

    @GetMapping("/latest")
    public IndicatorResponse latest(@RequestParam Long instrumentToken, @RequestParam String timeframe) {
        return service.latest(instrumentToken, timeframe);
    }
}
