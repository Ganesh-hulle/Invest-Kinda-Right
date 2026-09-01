package com.ganesh.IKR.dto.order;
import jakarta.validation.constraints.Min;
import java.math.BigDecimal;
public record ModifyOrderRequest(@Min(1) Integer quantity, BigDecimal price, BigDecimal stopLoss) { }
