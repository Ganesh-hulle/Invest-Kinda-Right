package com.ganesh.IKR.controller;
import com.ganesh.IKR.dto.order.*;
import com.ganesh.IKR.security.CustomUserDetails;
import com.ganesh.IKR.service.PaperTradingService;
import jakarta.validation.Valid;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.List;
@RestController @RequestMapping("/api/v1/paper")
public class PaperTradingController {
    private final PaperTradingService service; public PaperTradingController(PaperTradingService service) { this.service = service; }
    @PostMapping("/orders") public OrderResponse place(@Valid @RequestBody OrderRequest r, Authentication a) { return OrderResponse.from(service.place(((CustomUserDetails)a.getPrincipal()).getId(), r)); }
    @GetMapping("/orders") public List<OrderResponse> orders(Authentication a) { return service.orders(((CustomUserDetails)a.getPrincipal()).getId()).stream().map(OrderResponse::from).toList(); }
    @GetMapping("/positions") public List<PositionResponse> positions(Authentication a) { return service.positions(((CustomUserDetails)a.getPrincipal()).getId()).stream().map(PositionResponse::from).toList(); }
}
