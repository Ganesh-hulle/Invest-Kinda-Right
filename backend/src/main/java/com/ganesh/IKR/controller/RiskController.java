package com.ganesh.IKR.controller;
import com.ganesh.IKR.dto.risk.*;
import com.ganesh.IKR.security.CustomUserDetails;
import com.ganesh.IKR.service.RiskService;
import jakarta.validation.Valid;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/risk")
public class RiskController {
    private final RiskService service; public RiskController(RiskService service) { this.service = service; }
    @GetMapping("/limits") public RiskLimitResponse get(Authentication a) { return RiskLimitResponse.from(service.getOrCreate(((CustomUserDetails)a.getPrincipal()).getId())); }
    @PutMapping("/limits") public RiskLimitResponse update(@Valid @RequestBody RiskLimitRequest r, Authentication a) { return RiskLimitResponse.from(service.update(((CustomUserDetails)a.getPrincipal()).getId(), r)); }
}
