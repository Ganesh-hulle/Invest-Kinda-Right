package com.ganesh.IKR.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.ganesh.IKR.dto.kite.HistoricalCandleResponse;
import com.ganesh.IKR.entity.Instrument;
import com.ganesh.IKR.exception.KiteApiException;
import com.ganesh.IKR.repository.InstrumentRepository;
import com.ganesh.IKR.repository.KiteConnectionRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.*;

@Service
public class HistoricalDataService {
    private static final Set<String> SUPPORTED_INTERVALS = Set.of(
            "minute", "3minute", "5minute", "10minute", "15minute", "30minute", "60minute", "day");
    private static final DateTimeFormatter KITE_DATE_TIME = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static final DateTimeFormatter KITE_TIMESTAMP = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ssZ");

    private final KiteClient kiteClient;
    private final KiteConnectionRepository connectionRepository;
    private final InstrumentRepository instrumentRepository;
    private final SecretTokenCipher cipher;
    private final JdbcTemplate jdbcTemplate;

    public HistoricalDataService(KiteClient kiteClient, KiteConnectionRepository connectionRepository,
                                 InstrumentRepository instrumentRepository, SecretTokenCipher cipher,
                                 JdbcTemplate jdbcTemplate) {
        this.kiteClient = kiteClient;
        this.connectionRepository = connectionRepository;
        this.instrumentRepository = instrumentRepository;
        this.cipher = cipher;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional
    public List<HistoricalCandleResponse> getHistorical(Long userId, Long instrumentToken,
                                                        String from, String to, String interval) {
        if (!SUPPORTED_INTERVALS.contains(interval)) {
            throw new KiteApiException("Unsupported historical interval: " + interval);
        }
        DateRange range = parseRange(from, to);
        Instrument instrument = instrumentRepository.findByInstrumentToken(instrumentToken)
                .orElseThrow(() -> new KiteApiException("Instrument token was not found: " + instrumentToken));
        var connection = connectionRepository.findByUserId(userId)
                .orElseThrow(() -> new KiteApiException("Kite account is not connected"));

        JsonNode response = kiteClient.historicalData(
                cipher.decrypt(connection.getEncryptedAccessToken(), connection.getAccessTokenIv()),
                instrumentToken, KITE_DATE_TIME.format(range.from()), KITE_DATE_TIME.format(range.to()), interval);
        JsonNode candles = response.path("data").path("candles");
        if (!candles.isArray()) throw new KiteApiException("Kite historical response did not contain candles");

        List<CandleRow> rows = new ArrayList<>(candles.size());
        for (JsonNode candle : candles) rows.add(parseCandle(candle));
        jdbcTemplate.batchUpdate("""
                INSERT INTO market_candles (instrument_token, exchange, timeframe, candle_time,
                    open, high, low, close, volume)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (instrument_token, timeframe, candle_time) DO UPDATE SET
                    exchange = EXCLUDED.exchange, open = EXCLUDED.open, high = EXCLUDED.high,
                    low = EXCLUDED.low, close = EXCLUDED.close, volume = EXCLUDED.volume
                """, rows, 500, (statement, row) -> {
            statement.setLong(1, instrumentToken);
            statement.setString(2, instrument.getExchange());
            statement.setString(3, interval);
            statement.setObject(4, row.candleTime());
            statement.setBigDecimal(5, row.open());
            statement.setBigDecimal(6, row.high());
            statement.setBigDecimal(7, row.low());
            statement.setBigDecimal(8, row.close());
            statement.setLong(9, row.volume());
        });
        return rows.stream().map(row -> new HistoricalCandleResponse(row.candleTime(), row.open(), row.high(), row.low(), row.close(), row.volume())).toList();
    }

    private CandleRow parseCandle(JsonNode candle) {
        if (!candle.isArray() || candle.size() < 6) throw new KiteApiException("Invalid candle returned by Kite");
        try {
            return new CandleRow(OffsetDateTime.parse(candle.get(0).asText(), KITE_TIMESTAMP),
                    decimal(candle.get(1)), decimal(candle.get(2)), decimal(candle.get(3)),
                    decimal(candle.get(4)), candle.get(5).asLong());
        } catch (DateTimeParseException | NumberFormatException exception) {
            throw new KiteApiException("Invalid candle returned by Kite", exception);
        }
    }

    private BigDecimal decimal(JsonNode value) { return new BigDecimal(value.asText()); }

    private DateRange parseRange(String from, String to) {
        try {
            LocalDateTime fromTime = parseDate(from, false);
            LocalDateTime toTime = parseDate(to, true);
            if (!fromTime.isBefore(toTime)) throw new KiteApiException("from must be before to");
            return new DateRange(fromTime, toTime);
        } catch (DateTimeParseException exception) {
            throw new KiteApiException("Dates must use yyyy-MM-dd or yyyy-MM-dd HH:mm:ss", exception);
        }
    }

    private LocalDateTime parseDate(String value, boolean endOfDay) {
        if (value.length() == 10) return LocalDate.parse(value).atTime(endOfDay ? LocalTime.MAX : LocalTime.MIN);
        return LocalDateTime.parse(value, KITE_DATE_TIME);
    }

    private record DateRange(LocalDateTime from, LocalDateTime to) { }
    private record CandleRow(OffsetDateTime candleTime, BigDecimal open, BigDecimal high,
                             BigDecimal low, BigDecimal close, Long volume) { }
}
