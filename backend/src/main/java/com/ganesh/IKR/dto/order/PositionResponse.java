package com.ganesh.IKR.dto.order;
import com.ganesh.IKR.entity.PaperPosition;
import java.math.BigDecimal;
public record PositionResponse(Long instrumentToken, String exchange, String tradingsymbol, Integer quantity,
                               BigDecimal averagePrice, BigDecimal realizedPnl) {
    public static PositionResponse from(PaperPosition p) { return new PositionResponse(p.getInstrumentToken(), p.getExchange(), p.getTradingsymbol(), p.getQuantity(), p.getAveragePrice(), p.getRealizedPnl()); }
}
