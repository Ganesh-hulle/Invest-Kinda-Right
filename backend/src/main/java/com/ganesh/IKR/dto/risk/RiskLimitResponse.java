package com.ganesh.IKR.dto.risk;
import com.ganesh.IKR.entity.RiskLimit;
import java.math.BigDecimal;
public record RiskLimitResponse(BigDecimal maxDailyLoss, Integer maxTradesPerDay, BigDecimal maxCapitalPerTrade,
                                Integer maxOpenPositions, Integer maxPositionSize, Boolean tradingEnabled) {
    public static RiskLimitResponse from(RiskLimit value) { return new RiskLimitResponse(value.getMaxDailyLoss(), value.getMaxTradesPerDay(), value.getMaxCapitalPerTrade(), value.getMaxOpenPositions(), value.getMaxPositionSize(), value.getTradingEnabled()); }
}
