package com.ganesh.IKR.controller;

import com.ganesh.IKR.dto.instrument.InstrumentResponse;
import com.ganesh.IKR.security.CustomUserDetails;
import com.ganesh.IKR.service.InstrumentSyncService;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/v1/instruments")
public class InstrumentController {
    private final InstrumentSyncService instrumentSyncService;
    public InstrumentController(InstrumentSyncService instrumentSyncService) { this.instrumentSyncService = instrumentSyncService; }

    @GetMapping("/search")
    public List<InstrumentResponse> search(@RequestParam String query) {
        return instrumentSyncService.search(query).stream().map(InstrumentResponse::from).toList();
    }
}
