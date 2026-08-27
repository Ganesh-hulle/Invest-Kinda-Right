package com.ganesh.IKR.controller;

import com.ganesh.IKR.dto.kite.HistoricalCandleResponse;
import com.ganesh.IKR.security.CustomUserDetails;
import com.ganesh.IKR.service.HistoricalDataService;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/v1/kite/historical")
public class HistoricalDataController {
    private final HistoricalDataService historicalDataService;
    public HistoricalDataController(HistoricalDataService historicalDataService) { this.historicalDataService = historicalDataService; }

    @GetMapping
    public List<HistoricalCandleResponse> historical(@RequestParam Long instrumentToken,
                                                     @RequestParam String from,
                                                     @RequestParam String to,
                                                     @RequestParam String interval,
                                                     Authentication authentication) {
        var user = (CustomUserDetails) authentication.getPrincipal();
        return historicalDataService.getHistorical(user.getId(), instrumentToken, from, to, interval);
    }
}
