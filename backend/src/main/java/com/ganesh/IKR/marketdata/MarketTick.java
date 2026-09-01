package com.ganesh.IKR.marketdata;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record MarketTick(Long instrumentToken, String exchange, String tradingsymbol,
                         BigDecimal lastPrice, Long lastTradedQuantity, Long cumulativeVolume,
                         OffsetDateTime timestamp) { }
