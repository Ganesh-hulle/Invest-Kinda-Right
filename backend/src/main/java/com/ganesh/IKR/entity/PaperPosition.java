package com.ganesh.IKR.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity @Table(name = "paper_positions")
public class PaperPosition {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "user_id", nullable = false) private User user;
    @Column(name = "instrument_token", nullable = false) private Long instrumentToken;
    @Column(nullable = false) private String exchange; @Column(nullable = false) private String tradingsymbol;
    @Column(nullable = false) private Integer quantity;
    @Column(name = "average_price", nullable = false, precision = 20, scale = 6) private BigDecimal averagePrice;
    @Column(name = "realized_pnl", nullable = false, precision = 20, scale = 6) private BigDecimal realizedPnl = BigDecimal.ZERO;
    @Column(name = "updated_at", nullable = false, insertable = false) private OffsetDateTime updatedAt;
    public PaperPosition() { }
    public Long getId() { return id; } public void setUser(User value) { user = value; } public void setInstrumentToken(Long value) { instrumentToken = value; }
    public void setExchange(String value) { exchange = value; } public void setTradingsymbol(String value) { tradingsymbol = value; }
    public void setQuantity(Integer value) { quantity = value; } public void setAveragePrice(BigDecimal value) { averagePrice = value; }
    public void setRealizedPnl(BigDecimal value) { realizedPnl = value; }
    public Long getInstrumentToken() { return instrumentToken; } public String getExchange() { return exchange; } public String getTradingsymbol() { return tradingsymbol; }
    public Integer getQuantity() { return quantity; } public BigDecimal getAveragePrice() { return averagePrice; } public BigDecimal getRealizedPnl() { return realizedPnl; }
}
