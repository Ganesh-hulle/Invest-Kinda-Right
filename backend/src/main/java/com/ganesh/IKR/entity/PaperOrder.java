package com.ganesh.IKR.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity @Table(name = "paper_orders")
public class PaperOrder {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "user_id", nullable = false) private User user;
    @Column(name = "instrument_token", nullable = false) private Long instrumentToken;
    @Column(nullable = false, length = 20) private String exchange;
    @Column(name = "tradingsymbol", nullable = false, length = 100) private String tradingsymbol;
    @Column(nullable = false, length = 10) private String side;
    @Column(name = "order_type", nullable = false, length = 10) private String orderType;
    @Column(nullable = false) private Integer quantity;
    @Column(name = "requested_price", nullable = false, precision = 20, scale = 6) private BigDecimal requestedPrice;
    @Column(name = "average_price", precision = 20, scale = 6) private BigDecimal averagePrice;
    @Column(name = "stop_loss", precision = 20, scale = 6) private BigDecimal stopLoss;
    @Column(nullable = false, length = 20) private String status;
    @Column(name = "rejection_reason") private String rejectionReason;
    @Column(name = "created_at", nullable = false, insertable = false, updatable = false) private OffsetDateTime createdAt;
    @Column(name = "updated_at", nullable = false, insertable = false) private OffsetDateTime updatedAt;
    public PaperOrder() { }
    public Long getId() { return id; } public void setUser(User value) { user = value; } public void setInstrumentToken(Long value) { instrumentToken = value; }
    public void setExchange(String value) { exchange = value; } public void setTradingsymbol(String value) { tradingsymbol = value; }
    public void setSide(String value) { side = value; } public void setOrderType(String value) { orderType = value; } public void setQuantity(Integer value) { quantity = value; }
    public void setRequestedPrice(BigDecimal value) { requestedPrice = value; } public void setAveragePrice(BigDecimal value) { averagePrice = value; }
    public void setStopLoss(BigDecimal value) { stopLoss = value; } public void setStatus(String value) { status = value; }
    public void setRejectionReason(String value) { rejectionReason = value; }
    public Long getInstrumentToken() { return instrumentToken; } public String getExchange() { return exchange; } public String getTradingsymbol() { return tradingsymbol; }
    public String getSide() { return side; } public String getOrderType() { return orderType; } public Integer getQuantity() { return quantity; }
    public BigDecimal getRequestedPrice() { return requestedPrice; } public BigDecimal getAveragePrice() { return averagePrice; } public BigDecimal getStopLoss() { return stopLoss; }
    public String getStatus() { return status; } public String getRejectionReason() { return rejectionReason; } public OffsetDateTime getCreatedAt() { return createdAt; }
}
