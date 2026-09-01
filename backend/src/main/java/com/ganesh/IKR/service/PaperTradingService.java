package com.ganesh.IKR.service;

import com.ganesh.IKR.dto.order.OrderRequest;
import com.ganesh.IKR.entity.PaperOrder;
import com.ganesh.IKR.entity.PaperPosition;
import com.ganesh.IKR.entity.User;
import com.ganesh.IKR.exception.RiskRejectedException;
import com.ganesh.IKR.marketdata.MarketDataStore;
import com.ganesh.IKR.repository.InstrumentRepository;
import com.ganesh.IKR.repository.PaperOrderRepository;
import com.ganesh.IKR.repository.PaperPositionRepository;
import com.ganesh.IKR.repository.UserRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
// import java.time.OffsetDateTime;
import java.util.List;

@Service
public class PaperTradingService {
    private final InstrumentRepository instrumentRepository; private final UserRepository userRepository;
    private final PaperOrderRepository orderRepository; private final PaperPositionRepository positionRepository;
    private final RiskService riskService; private final MarketDataStore marketDataStore; private final JdbcTemplate jdbcTemplate;

    public PaperTradingService(InstrumentRepository instrumentRepository, UserRepository userRepository,
                               PaperOrderRepository orderRepository, PaperPositionRepository positionRepository,
                               RiskService riskService, MarketDataStore marketDataStore, JdbcTemplate jdbcTemplate) {
        this.instrumentRepository = instrumentRepository; this.userRepository = userRepository; this.orderRepository = orderRepository;
        this.positionRepository = positionRepository; this.riskService = riskService; this.marketDataStore = marketDataStore; this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional
    public PaperOrder place(Long userId, OrderRequest request) {
        String side = request.side().toUpperCase(); String orderType = request.orderType().toUpperCase();
        if (!("MARKET".equals(orderType) || "LIMIT".equals(orderType))) throw new RiskRejectedException("orderType must be MARKET or LIMIT");
        if ("LIMIT".equals(orderType) && request.price() == null) throw new RiskRejectedException("LIMIT orders require price");
        var instrument = instrumentRepository.findByInstrumentToken(request.instrumentToken()).orElseThrow(() -> new RiskRejectedException("Instrument token was not found"));
        BigDecimal price = request.price();
        if (price == null) { var quote = marketDataStore.get(request.instrumentToken()); price = quote == null ? null : quote.lastPrice(); }
        riskService.validate(userId, side, request.quantity(), price, request.stopLoss());
        User user = userRepository.findById(userId).orElseThrow(() -> new RiskRejectedException("Application user not found"));

        PaperOrder order = new PaperOrder(); order.setUser(user); order.setInstrumentToken(instrument.getInstrumentToken()); order.setExchange(instrument.getExchange());
        order.setTradingsymbol(instrument.getTradingsymbol()); order.setSide(side); order.setOrderType(orderType); order.setQuantity(request.quantity());
        order.setRequestedPrice(price); order.setAveragePrice(price); order.setStopLoss(request.stopLoss()); order.setStatus("FILLED");
        order = orderRepository.save(order);
        BigDecimal tradePnl = realizedPnl(userId, instrument.getInstrumentToken(), side, request.quantity(), price);
        applyPosition(user, instrument, side, request.quantity(), price);
        jdbcTemplate.update("INSERT INTO paper_trades (user_id, order_id, instrument_token, side, quantity, price, realized_pnl) VALUES (?, ?, ?, ?, ?, ?, ?)",
                userId, order.getId(), instrument.getInstrumentToken(), side, request.quantity(), price, tradePnl);
        return order;
    }

    @Transactional(readOnly = true)
    public List<PaperOrder> orders(Long userId) { return orderRepository.findByUserIdOrderByCreatedAtDesc(userId); }
    @Transactional(readOnly = true)
    public List<PaperPosition> positions(Long userId) { return positionRepository.findByUserIdOrderByTradingsymbolAsc(userId).stream().filter(p -> p.getQuantity() > 0).toList(); }

    private void applyPosition(User user, com.ganesh.IKR.entity.Instrument instrument, String side, int quantity, BigDecimal price) {
        PaperPosition position = positionRepository.findByUserIdAndInstrumentToken(user.getId(), instrument.getInstrumentToken()).orElse(null);
        if (position == null) {
            if ("SELL".equals(side)) throw new RiskRejectedException("Cannot sell without an open paper position");
            position = new PaperPosition(); position.setUser(user); position.setInstrumentToken(instrument.getInstrumentToken()); position.setExchange(instrument.getExchange()); position.setTradingsymbol(instrument.getTradingsymbol()); position.setQuantity(quantity); position.setAveragePrice(price); position.setRealizedPnl(BigDecimal.ZERO); positionRepository.save(position); return;
        }
        if ("BUY".equals(side)) {
            int newQuantity = position.getQuantity() + quantity;
            BigDecimal total = position.getAveragePrice().multiply(BigDecimal.valueOf(position.getQuantity())).add(price.multiply(BigDecimal.valueOf(quantity)));
            position.setQuantity(newQuantity); position.setAveragePrice(total.divide(BigDecimal.valueOf(newQuantity), 8, java.math.RoundingMode.HALF_UP));
        } else {
            if (position.getQuantity() < quantity) throw new RiskRejectedException("Sell quantity exceeds the open paper position");
            position.setQuantity(position.getQuantity() - quantity); position.setRealizedPnl(position.getRealizedPnl().add(price.subtract(position.getAveragePrice()).multiply(BigDecimal.valueOf(quantity))));
            if (position.getQuantity() == 0) position.setAveragePrice(BigDecimal.ZERO);
        }
        positionRepository.save(position);
    }

    private BigDecimal realizedPnl(Long userId, Long token, String side, int quantity, BigDecimal price) {
        if ("BUY".equals(side)) return BigDecimal.ZERO;
        return jdbcTemplate.query("SELECT average_price FROM paper_positions WHERE user_id = ? AND instrument_token = ?", rs -> rs.next() ? price.subtract(rs.getBigDecimal(1)).multiply(BigDecimal.valueOf(quantity)) : BigDecimal.ZERO, userId, token);
    }
}
