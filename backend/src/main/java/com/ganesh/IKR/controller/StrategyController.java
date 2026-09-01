package com.ganesh.IKR.controller;

import com.ganesh.IKR.service.StrategyService;
import com.ganesh.IKR.strategy.Signal;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/strategies")
public class StrategyController {
    private final StrategyService service;
    public StrategyController(StrategyService service) { this.service = service; }

    @GetMapping("/ema-crossover/signal")
    public ResponseEntity<Signal> evaluate(@RequestParam Long instrumentToken, @RequestParam String timeframe) {
        Signal signal = service.evaluateEmaCrossover(instrumentToken, timeframe);
        return signal == null ? ResponseEntity.noContent().build() : ResponseEntity.ok(signal);
    }
}
