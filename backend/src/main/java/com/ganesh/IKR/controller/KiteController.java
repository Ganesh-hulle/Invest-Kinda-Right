package com.ganesh.IKR.controller;

import com.ganesh.IKR.dto.kite.KiteLoginUrlResponse;
import com.ganesh.IKR.dto.kite.KiteProfileResponse;
import com.ganesh.IKR.dto.kite.KitePortfolioResponse;
import com.ganesh.IKR.security.CustomUserDetails;
import com.ganesh.IKR.service.KiteService;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/kite")
public class KiteController {
    private final KiteService kiteService;
    public KiteController(KiteService kiteService) { this.kiteService = kiteService; }

    @GetMapping("/login-url")
    public KiteLoginUrlResponse loginUrl(Authentication authentication) {
        var user = (CustomUserDetails) authentication.getPrincipal();
        return new KiteLoginUrlResponse(kiteService.createLoginUrl(user.getId()));
    }

    @GetMapping("/callback")
    public KiteProfileResponse callback(@RequestParam("request_token") String requestToken,
                                        @RequestParam String state,
                                        @RequestParam(defaultValue = "success") String status) {
        return kiteService.handleCallback(requestToken, state, status);
    }

    @GetMapping("/profile")
    public KiteProfileResponse profile(Authentication authentication) {
        var user = (CustomUserDetails) authentication.getPrincipal();
        return kiteService.getProfile(user.getId());
    }

    @GetMapping("/portfolio")
    public KitePortfolioResponse portfolio(Authentication authentication) {
        var user = (CustomUserDetails) authentication.getPrincipal();
        return kiteService.getPortfolio(user.getId());
    }
}
