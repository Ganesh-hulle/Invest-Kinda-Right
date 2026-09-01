package com.ganesh.IKR.dto.risk;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

public record RiskLimitRequest(@NotNull @DecimalMin("0.0") BigDecimal maxDailyLoss,
                               @NotNull @Min(1) Integer maxTradesPerDay,
                               @NotNull @DecimalMin("0.0") BigDecimal maxCapitalPerTrade,
                               @NotNull @Min(1) Integer maxOpenPositions,
                               @NotNull @Min(1) Integer maxPositionSize,
                               @NotNull Boolean tradingEnabled) { }
