package com.ganesh.IKR.dto.order;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

public record OrderRequest(@NotNull Long instrumentToken, @NotBlank String side, @NotBlank String orderType,
                           @NotNull @Min(1) Integer quantity, BigDecimal price, BigDecimal stopLoss,
                           String idempotencyKey) { }
