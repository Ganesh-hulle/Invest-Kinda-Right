package com.ganesh.IKR.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Table(name = "market_candles")
public class MarketCandle {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "instrument_token", nullable = false) private Long instrumentToken;
    @Column(nullable = false, length = 20) private String exchange;
    @Column(nullable = false, length = 20) private String timeframe;
    @Column(name = "candle_time", nullable = false) private OffsetDateTime candleTime;
    @Column(nullable = false, precision = 20, scale = 6) private BigDecimal open;
    @Column(nullable = false, precision = 20, scale = 6) private BigDecimal high;
    @Column(nullable = false, precision = 20, scale = 6) private BigDecimal low;
    @Column(nullable = false, precision = 20, scale = 6) private BigDecimal close;
    @Column(nullable = false) private Long volume;
    @Column(name = "created_at", nullable = false, insertable = false, updatable = false) private OffsetDateTime createdAt;

    protected MarketCandle() { }
}
