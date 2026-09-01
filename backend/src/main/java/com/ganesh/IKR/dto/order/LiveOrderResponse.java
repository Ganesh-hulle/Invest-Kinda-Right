package com.ganesh.IKR.dto.order;
import com.ganesh.IKR.entity.LiveOrder;
import java.math.BigDecimal; import java.time.OffsetDateTime;
public record LiveOrderResponse(Long orderId, Long instrumentToken, String exchange, String tradingsymbol, String side,
                                String orderType, Integer quantity, BigDecimal price, String status, String brokerOrderId,
                                String rejectionReason, OffsetDateTime createdAt) {
    public static LiveOrderResponse from(LiveOrder o) { return new LiveOrderResponse(o.getId(), o.getInstrumentToken(), o.getExchange(), o.getTradingsymbol(), o.getSide(), o.getOrderType(), o.getQuantity(), o.getPrice(), o.getStatus(), o.getBrokerOrderId(), o.getRejectionReason(), o.getCreatedAt()); }
}
