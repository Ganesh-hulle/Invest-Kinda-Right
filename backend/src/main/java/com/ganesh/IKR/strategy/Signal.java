package com.ganesh.IKR.strategy;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record Signal(Long instrumentToken, String exchange, String tradingsymbol, String side,
                     BigDecimal price, String strategy, OffsetDateTime generatedAt) {
    @JsonProperty("signal")
    public String signal() { return side; }
}
