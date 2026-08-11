package com.ganesh.IKR.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class SystemController {

    @GetMapping("/api/v1/system/health")
    public Map<String, Object> health() {
        return Map.of(
                "status", "UP",
                "service", "IKR-backend",
                "version", "0.0.1"
        );
    }
}