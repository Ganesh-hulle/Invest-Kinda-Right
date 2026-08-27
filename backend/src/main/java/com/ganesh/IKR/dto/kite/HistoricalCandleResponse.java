package com.ganesh.IKR.dto.kite;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record HistoricalCandleResponse(OffsetDateTime candleTime, BigDecimal open, BigDecimal high,
                                       BigDecimal low, BigDecimal close, Long volume) { }
