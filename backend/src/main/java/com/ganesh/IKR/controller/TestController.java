package com.ganesh.IKR.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class TestController {

    @GetMapping("/test")
    public Map<String, Object> health() {
        return Map.of(
                "status", "Calamitous"
        );
    }
}