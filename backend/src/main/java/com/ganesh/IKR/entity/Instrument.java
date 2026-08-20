package com.ganesh.IKR.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

@Entity
@Table(name = "instruments")
public class Instrument {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "instrument_token", nullable = false, unique = true) private Long instrumentToken;
    @Column(nullable = false, length = 20) private String exchange;
    @Column(nullable = false, length = 100) private String tradingsymbol;
    @Column(length = 255) private String name;
    @Column(nullable = false, length = 50) private String segment;
    @Column(name = "instrument_type", nullable = false, length = 20) private String instrumentType;
    private LocalDate expiry;
    @Column(precision = 20, scale = 6) private BigDecimal strike;
    @Column(name = "tick_size", nullable = false, precision = 20, scale = 6) private BigDecimal tickSize;
    @Column(name = "lot_size", nullable = false) private Integer lotSize;
    @Column(name = "created_at", nullable = false, insertable = false, updatable = false) private OffsetDateTime createdAt;
    @Column(name = "updated_at", nullable = false, insertable = false) private OffsetDateTime updatedAt;

    protected Instrument() { }

    public Long getInstrumentToken() { return instrumentToken; }
    public String getExchange() { return exchange; }
    public String getTradingsymbol() { return tradingsymbol; }
    public String getName() { return name; }
    public String getSegment() { return segment; }
    public String getInstrumentType() { return instrumentType; }
    public LocalDate getExpiry() { return expiry; }
    public BigDecimal getStrike() { return strike; }
    public BigDecimal getTickSize() { return tickSize; }
    public Integer getLotSize() { return lotSize; }
}
