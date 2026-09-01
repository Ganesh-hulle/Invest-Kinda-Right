package com.ganesh.IKR.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;

@Entity
@Table(name = "risk_limits")
public class RiskLimit {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @OneToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "user_id", nullable = false, unique = true) private User user;
    @Column(name = "max_daily_loss", nullable = false, precision = 20, scale = 6) private BigDecimal maxDailyLoss = new BigDecimal("10000");
    @Column(name = "max_trades_per_day", nullable = false) private Integer maxTradesPerDay = 20;
    @Column(name = "max_capital_per_trade", nullable = false, precision = 20, scale = 6) private BigDecimal maxCapitalPerTrade = new BigDecimal("100000");
    @Column(name = "max_open_positions", nullable = false) private Integer maxOpenPositions = 5;
    @Column(name = "max_position_size", nullable = false) private Integer maxPositionSize = 1000;
    @Column(name = "trading_enabled", nullable = false) private Boolean tradingEnabled = true;

    public RiskLimit() { }
    public Long getId() { return id; } public User getUser() { return user; } public void setUser(User user) { this.user = user; }
    public BigDecimal getMaxDailyLoss() { return maxDailyLoss; } public void setMaxDailyLoss(BigDecimal value) { maxDailyLoss = value; }
    public Integer getMaxTradesPerDay() { return maxTradesPerDay; } public void setMaxTradesPerDay(Integer value) { maxTradesPerDay = value; }
    public BigDecimal getMaxCapitalPerTrade() { return maxCapitalPerTrade; } public void setMaxCapitalPerTrade(BigDecimal value) { maxCapitalPerTrade = value; }
    public Integer getMaxOpenPositions() { return maxOpenPositions; } public void setMaxOpenPositions(Integer value) { maxOpenPositions = value; }
    public Integer getMaxPositionSize() { return maxPositionSize; } public void setMaxPositionSize(Integer value) { maxPositionSize = value; }
    public Boolean getTradingEnabled() { return tradingEnabled; } public void setTradingEnabled(Boolean value) { tradingEnabled = value; }
}
