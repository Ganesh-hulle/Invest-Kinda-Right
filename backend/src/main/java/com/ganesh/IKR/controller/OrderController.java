package com.ganesh.IKR.controller;
import com.ganesh.IKR.dto.order.*;
import com.ganesh.IKR.security.CustomUserDetails;
import com.ganesh.IKR.service.LiveOrderService;
import jakarta.validation.Valid;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/orders")
public class OrderController {
    private final LiveOrderService service; public OrderController(LiveOrderService service) { this.service = service; }
    @PostMapping public LiveOrderResponse place(@Valid @RequestBody OrderRequest r, Authentication a) { return LiveOrderResponse.from(service.place(((CustomUserDetails)a.getPrincipal()).getId(), r)); }
    @GetMapping("/{id}") public LiveOrderResponse get(@PathVariable Long id, Authentication a) { return LiveOrderResponse.from(service.get(((CustomUserDetails)a.getPrincipal()).getId(), id)); }
    @PutMapping("/{id}") public LiveOrderResponse modify(@PathVariable Long id, @Valid @RequestBody ModifyOrderRequest r, Authentication a) { return LiveOrderResponse.from(service.modify(((CustomUserDetails)a.getPrincipal()).getId(), id, r)); }
    @PostMapping("/{id}/cancel") public LiveOrderResponse cancel(@PathVariable Long id, Authentication a) { return LiveOrderResponse.from(service.cancel(((CustomUserDetails)a.getPrincipal()).getId(), id)); }
}
