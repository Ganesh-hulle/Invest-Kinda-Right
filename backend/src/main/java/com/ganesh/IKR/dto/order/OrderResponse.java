package com.ganesh.IKR.dto.order;
import com.ganesh.IKR.entity.PaperOrder;
import java.math.BigDecimal; import java.time.OffsetDateTime;
public record OrderResponse(Long orderId, Long instrumentToken, String exchange, String tradingsymbol, String side,
                            String orderType, Integer quantity, BigDecimal requestedPrice, BigDecimal averagePrice,
                            BigDecimal stopLoss, String status, String rejectionReason, OffsetDateTime createdAt) {
    public static OrderResponse from(PaperOrder order) { return new OrderResponse(order.getId(), order.getInstrumentToken(), order.getExchange(), order.getTradingsymbol(), order.getSide(), order.getOrderType(), order.getQuantity(), order.getRequestedPrice(), order.getAveragePrice(), order.getStopLoss(), order.getStatus(), order.getRejectionReason(), order.getCreatedAt()); }
}
