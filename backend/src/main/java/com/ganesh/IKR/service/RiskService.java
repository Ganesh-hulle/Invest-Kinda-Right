package com.ganesh.IKR.service;

import com.ganesh.IKR.dto.risk.RiskLimitRequest;
import com.ganesh.IKR.entity.RiskLimit;
import com.ganesh.IKR.entity.User;
import com.ganesh.IKR.exception.RiskRejectedException;
import com.ganesh.IKR.repository.PaperOrderRepository;
import com.ganesh.IKR.repository.PaperPositionRepository;
import com.ganesh.IKR.repository.RiskLimitRepository;
import com.ganesh.IKR.repository.UserRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.*;

@Service
public class RiskService {
    private static final ZoneId MARKET_ZONE = ZoneId.of("Asia/Kolkata");
    private final RiskLimitRepository limitRepository; private final PaperOrderRepository orderRepository;
    private final PaperPositionRepository positionRepository; private final UserRepository userRepository; private final JdbcTemplate jdbcTemplate;

    public RiskService(RiskLimitRepository limitRepository, PaperOrderRepository orderRepository,
                       PaperPositionRepository positionRepository, UserRepository userRepository, JdbcTemplate jdbcTemplate) {
        this.limitRepository = limitRepository; this.orderRepository = orderRepository; this.positionRepository = positionRepository;
        this.userRepository = userRepository; this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional
    public RiskLimit getOrCreate(Long userId) {
        return limitRepository.findByUserId(userId).orElseGet(() -> {
            User user = userRepository.findById(userId).orElseThrow(() -> new RiskRejectedException("Application user not found"));
            RiskLimit value = new RiskLimit(); value.setUser(user); return limitRepository.save(value);
        });
    }

    @Transactional
    public void validate(Long userId, String side, int quantity, BigDecimal price, BigDecimal stopLoss) {
        if (!("BUY".equals(side) || "SELL".equals(side))) throw new RiskRejectedException("side must be BUY or SELL");
        if (price == null || price.signum() <= 0) throw new RiskRejectedException("A positive execution price is required");
        RiskLimit limit = getOrCreate(userId);
        if (!Boolean.TRUE.equals(limit.getTradingEnabled())) throw new RiskRejectedException("Trading is disabled by risk settings");
        if (quantity > limit.getMaxPositionSize()) throw new RiskRejectedException("Position size exceeds the configured limit");
        if (price.multiply(BigDecimal.valueOf(quantity)).compareTo(limit.getMaxCapitalPerTrade()) > 0) throw new RiskRejectedException("Capital per trade exceeds the configured limit");
        OffsetDateTime start = LocalDate.now(MARKET_ZONE).atStartOfDay(MARKET_ZONE).toOffsetDateTime();
        if (orderRepository.countByUserIdAndStatusAndCreatedAtGreaterThanEqual(userId, "FILLED", start) >= limit.getMaxTradesPerDay()) throw new RiskRejectedException("Maximum daily trades exceeded");
        if (positionRepository.countByUserIdAndQuantityGreaterThan(userId, 0) >= limit.getMaxOpenPositions() && "BUY".equals(side)) throw new RiskRejectedException("Maximum open positions exceeded");
        BigDecimal realized = jdbcTemplate.queryForObject("SELECT COALESCE(SUM(realized_pnl), 0) FROM paper_trades WHERE user_id = ? AND traded_at >= ?", BigDecimal.class, userId, start);
        if (realized != null && realized.negate().max(BigDecimal.ZERO).compareTo(limit.getMaxDailyLoss()) >= 0) throw new RiskRejectedException("Maximum daily loss has been reached");
        if ("BUY".equals(side) && stopLoss != null && stopLoss.compareTo(price) >= 0) throw new RiskRejectedException("For BUY, stopLoss must be below price");
        if ("SELL".equals(side) && stopLoss != null && stopLoss.compareTo(price) <= 0) throw new RiskRejectedException("For SELL, stopLoss must be above price");
    }

    @Transactional
    public RiskLimit update(Long userId, RiskLimitRequest request) {
        RiskLimit value = getOrCreate(userId); value.setMaxDailyLoss(request.maxDailyLoss()); value.setMaxTradesPerDay(request.maxTradesPerDay());
        value.setMaxCapitalPerTrade(request.maxCapitalPerTrade()); value.setMaxOpenPositions(request.maxOpenPositions());
        value.setMaxPositionSize(request.maxPositionSize()); value.setTradingEnabled(request.tradingEnabled()); return limitRepository.save(value);
    }
}
