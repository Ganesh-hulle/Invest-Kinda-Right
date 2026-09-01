package com.ganesh.IKR.strategy;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record Signal(Long instrumentToken, String exchange, String tradingsymbol, String side,
                     BigDecimal price, String strategy, OffsetDateTime generatedAt) { }
