package com.ganesh.IKR.marketdata;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record DevTickRequest(@NotNull Long instrumentToken, @NotNull @DecimalMin("0.000001") BigDecimal lastPrice,
                             Long lastTradedQuantity, Long cumulativeVolume, OffsetDateTime timestamp) { }
