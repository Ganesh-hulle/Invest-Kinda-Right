package com.ganesh.IKR.repository;

import com.ganesh.IKR.entity.MarketCandle;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.OffsetDateTime;
import java.util.List;

public interface MarketCandleRepository extends JpaRepository<MarketCandle, Long> {
    List<MarketCandle> findByInstrumentTokenAndTimeframeAndCandleTimeBetweenOrderByCandleTimeAsc(
            Long instrumentToken, String timeframe, OffsetDateTime from, OffsetDateTime to);
    List<MarketCandle> findTop500ByInstrumentTokenAndTimeframeOrderByCandleTimeDesc(Long instrumentToken, String timeframe);
}
