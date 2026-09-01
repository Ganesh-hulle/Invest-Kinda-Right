package com.ganesh.IKR.entity;

import jakarta.persistence.*;
import java.math.BigDecimal; import java.time.OffsetDateTime;

@Entity @Table(name = "orders")
public class LiveOrder {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "user_id", nullable = false) private User user;
    @Column(name = "instrument_token", nullable = false) private Long instrumentToken; @Column(nullable = false) private String exchange; @Column(nullable = false) private String tradingsymbol;
    @Column(nullable = false) private String side; @Column(name = "order_type", nullable = false) private String orderType; @Column(nullable = false) private Integer quantity;
    @Column(precision = 20, scale = 6) private BigDecimal price; @Column(name = "stop_loss", precision = 20, scale = 6) private BigDecimal stopLoss;
    @Column(nullable = false) private String status; @Column(name = "broker_order_id") private String brokerOrderId; @Column(name = "rejection_reason") private String rejectionReason;
    @Column(name = "idempotency_key") private String idempotencyKey; @Column(name = "created_at", insertable = false, updatable = false) private OffsetDateTime createdAt;
    public LiveOrder() { }
    public Long getId() { return id; } public User getUser() { return user; } public void setUser(User v) { user = v; } public void setInstrumentToken(Long v) { instrumentToken = v; } public void setExchange(String v) { exchange = v; } public void setTradingsymbol(String v) { tradingsymbol = v; }
    public void setSide(String v) { side = v; } public void setOrderType(String v) { orderType = v; } public void setQuantity(Integer v) { quantity = v; } public void setPrice(BigDecimal v) { price = v; } public void setStopLoss(BigDecimal v) { stopLoss = v; }
    public void setStatus(String v) { status = v; } public void setBrokerOrderId(String v) { brokerOrderId = v; } public void setRejectionReason(String v) { rejectionReason = v; } public void setIdempotencyKey(String v) { idempotencyKey = v; }
    public Long getInstrumentToken() { return instrumentToken; } public String getExchange() { return exchange; } public String getTradingsymbol() { return tradingsymbol; } public String getSide() { return side; } public String getOrderType() { return orderType; } public Integer getQuantity() { return quantity; } public BigDecimal getPrice() { return price; } public BigDecimal getStopLoss() { return stopLoss; } public String getStatus() { return status; } public String getBrokerOrderId() { return brokerOrderId; } public String getRejectionReason() { return rejectionReason; } public String getIdempotencyKey() { return idempotencyKey; } public OffsetDateTime getCreatedAt() { return createdAt; }
}
