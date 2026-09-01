package com.ganesh.IKR.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.ganesh.IKR.config.TradingProperties;
import com.ganesh.IKR.dto.order.OrderRequest;
import com.ganesh.IKR.dto.order.ModifyOrderRequest;
import com.ganesh.IKR.entity.LiveOrder;
import com.ganesh.IKR.exception.LiveTradingDisabledException;
import com.ganesh.IKR.exception.RiskRejectedException;
import com.ganesh.IKR.repository.InstrumentRepository;
import com.ganesh.IKR.repository.KiteConnectionRepository;
import com.ganesh.IKR.repository.LiveOrderRepository;
import com.ganesh.IKR.repository.UserRepository;
import com.ganesh.IKR.marketdata.MarketDataStore;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class LiveOrderService {
    private final TradingProperties properties; private final InstrumentRepository instrumentRepository; private final UserRepository userRepository;
    private final KiteConnectionRepository connectionRepository; private final LiveOrderRepository orderRepository; private final RiskService riskService;
    private final KiteClient kiteClient; private final SecretTokenCipher cipher; private final MarketDataStore marketDataStore;
    public LiveOrderService(TradingProperties properties, InstrumentRepository instrumentRepository, UserRepository userRepository,
                            KiteConnectionRepository connectionRepository, LiveOrderRepository orderRepository, RiskService riskService,
                            KiteClient kiteClient, SecretTokenCipher cipher, MarketDataStore marketDataStore) {
        this.properties = properties; this.instrumentRepository = instrumentRepository; this.userRepository = userRepository; this.connectionRepository = connectionRepository; this.orderRepository = orderRepository; this.riskService = riskService; this.kiteClient = kiteClient; this.cipher = cipher; this.marketDataStore = marketDataStore;
    }

    @Transactional
    public LiveOrder place(Long userId, OrderRequest request) {
        if (!properties.isLiveEnabled()) throw new LiveTradingDisabledException();
        if (request.idempotencyKey() != null) {
            var existing = orderRepository.findByUserIdAndIdempotencyKey(userId, request.idempotencyKey()); if (existing.isPresent()) return existing.get();
        }
        var instrument = instrumentRepository.findByInstrumentToken(request.instrumentToken()).orElseThrow(() -> new RiskRejectedException("Instrument token was not found"));
        if (!("MARKET".equalsIgnoreCase(request.orderType()) || "LIMIT".equalsIgnoreCase(request.orderType()))) throw new RiskRejectedException("orderType must be MARKET or LIMIT");
        if ("LIMIT".equalsIgnoreCase(request.orderType()) && request.price() == null) throw new RiskRejectedException("LIMIT orders require price");
        var quote = marketDataStore.get(request.instrumentToken());
        var executionPrice = request.price() != null ? request.price() : quote == null ? null : quote.lastPrice();
        riskService.validate(userId, request.side().toUpperCase(), request.quantity(), executionPrice, request.stopLoss());
        var connection = connectionRepository.findByUserId(userId).orElseThrow(() -> new RiskRejectedException("Kite account is not connected"));
        var user = userRepository.findById(userId).orElseThrow(() -> new RiskRejectedException("Application user not found"));
        LiveOrder order = new LiveOrder(); order.setUser(user); order.setInstrumentToken(instrument.getInstrumentToken()); order.setExchange(instrument.getExchange()); order.setTradingsymbol(instrument.getTradingsymbol());
        order.setSide(request.side().toUpperCase()); order.setOrderType(request.orderType().toUpperCase()); order.setQuantity(request.quantity()); order.setPrice(request.price()); order.setStopLoss(request.stopLoss()); order.setIdempotencyKey(request.idempotencyKey()); order.setStatus("SUBMITTING");
        order = orderRepository.save(order);
        try {
            JsonNode response = kiteClient.placeOrder(cipher.decrypt(connection.getEncryptedAccessToken(), connection.getAccessTokenIv()), instrument.getExchange(), instrument.getTradingsymbol(), request);
            String brokerId = response.path("data").path("order_id").asText(null);
            if (brokerId == null) throw new IllegalStateException("Kite did not return an order ID");
            order.setBrokerOrderId(brokerId); order.setStatus("OPEN");
        } catch (RuntimeException exception) {
            order.setStatus("REJECTED"); order.setRejectionReason(exception.getMessage()); orderRepository.save(order); throw exception;
        }
        return orderRepository.save(order);
    }

    @Transactional
    public LiveOrder cancel(Long userId, Long id) {
        if (!properties.isLiveEnabled()) throw new LiveTradingDisabledException();
        LiveOrder order = orderRepository.findById(id).filter(value -> value.getId() != null && value.getBrokerOrderId() != null && value.getStatus().equals("OPEN"))
                .orElseThrow(() -> new RiskRejectedException("Open order was not found"));
        if (!order.getUser().getId().equals(userId)) throw new RiskRejectedException("Order does not belong to the current user");
        var connection = connectionRepository.findByUserId(userId).orElseThrow(() -> new RiskRejectedException("Kite account is not connected"));
        kiteClient.cancelOrder(cipher.decrypt(connection.getEncryptedAccessToken(), connection.getAccessTokenIv()), order.getBrokerOrderId()); order.setStatus("CANCELLED"); return orderRepository.save(order);
    }

    @Transactional(readOnly = true)
    public LiveOrder get(Long userId, Long id) {
        LiveOrder order = orderRepository.findById(id).orElseThrow(() -> new RiskRejectedException("Order was not found"));
        if (!order.getUser().getId().equals(userId)) throw new RiskRejectedException("Order does not belong to the current user");
        return order;
    }

    @Transactional
    public LiveOrder modify(Long userId, Long id, ModifyOrderRequest request) {
        if (!properties.isLiveEnabled()) throw new LiveTradingDisabledException();
        LiveOrder order = get(userId, id);
        if (!"OPEN".equals(order.getStatus()) || order.getBrokerOrderId() == null) throw new RiskRejectedException("Only open broker orders can be modified");
        Integer quantity = request.quantity() == null ? order.getQuantity() : request.quantity();
        var price = request.price() == null ? order.getPrice() : request.price();
        riskService.validate(userId, order.getSide(), quantity, price, request.stopLoss() == null ? order.getStopLoss() : request.stopLoss());
        var connection = connectionRepository.findByUserId(userId).orElseThrow(() -> new RiskRejectedException("Kite account is not connected"));
        kiteClient.modifyOrder(cipher.decrypt(connection.getEncryptedAccessToken(), connection.getAccessTokenIv()), order.getBrokerOrderId(), quantity, price, request.stopLoss());
        order.setQuantity(quantity); order.setPrice(price); order.setStopLoss(request.stopLoss() == null ? order.getStopLoss() : request.stopLoss());
        return orderRepository.save(order);
    }
}
