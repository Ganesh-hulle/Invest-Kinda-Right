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
    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(HistoricalDataService.class);
    private static final ZoneId MARKET_ZONE = ZoneId.of("Asia/Kolkata");
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

        String decryptedToken = cipher.decrypt(connection.getEncryptedAccessToken(), connection.getAccessTokenIv());
        int maxDays = maxDaysForInterval(interval);
        List<DateRange> chunks = splitIntoChunks(range.from(), range.to(), maxDays);
        log.info("Fetching historical data for token {} ({}): {} to {} in {} chunk(s)",
                instrumentToken, interval, range.from(), range.to(), chunks.size());

        Map<OffsetDateTime, CandleRow> candleMap = new TreeMap<>();
        for (int i = 0; i < chunks.size(); i++) {
            DateRange chunk = chunks.get(i);
            try {
                JsonNode response = kiteClient.historicalData(
                        decryptedToken,
                        instrumentToken,
                        KITE_DATE_TIME.format(chunk.from()),
                        KITE_DATE_TIME.format(chunk.to()),
                        interval);
                JsonNode candles = response.path("data").path("candles");
                if (candles.isArray()) {
                    for (JsonNode candle : candles) {
                        CandleRow row = parseCandle(candle);
                        candleMap.put(row.candleTime(), row);
                    }
                }
            } catch (KiteApiException e) {
                log.warn("Failed to fetch chunk {}/{} for token {}: {}", i + 1, chunks.size(), instrumentToken, e.getMessage());
                if (candleMap.isEmpty() && chunks.size() == 1) {
                    throw e;
                }
            }
            if (chunks.size() > 1 && i < chunks.size() - 1) {
                try {
                    Thread.sleep(150);
                } catch (InterruptedException ignored) {
                    Thread.currentThread().interrupt();
                }
            }
        }

        List<CandleRow> rows = new ArrayList<>(candleMap.values());
        if (!rows.isEmpty()) {
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
        }
        return rows.stream().map(row -> new HistoricalCandleResponse(
                row.candleTime(), row.open(), row.high(), row.low(), row.close(), row.volume())
        ).toList();
    }

    private static int maxDaysForInterval(String interval) {
        return switch (interval) {
            case "minute" -> 50;
            case "3minute", "5minute", "10minute", "15minute", "30minute" -> 90;
            case "60minute" -> 350;
            default -> 1800;
        };
    }

    private List<DateRange> splitIntoChunks(LocalDateTime start, LocalDateTime end, int chunkDays) {
        List<DateRange> chunks = new ArrayList<>();
        LocalDateTime currentStart = start;
        while (currentStart.isBefore(end)) {
            LocalDateTime currentEnd = currentStart.plusDays(chunkDays);
            if (currentEnd.isAfter(end)) {
                currentEnd = end;
            }
            chunks.add(new DateRange(currentStart, currentEnd));
            if (currentEnd.isEqual(end)) {
                break;
            }
            currentStart = currentEnd;
        }
        return chunks;
    }

    private CandleRow parseCandle(JsonNode candle) {
        if (!candle.isArray() || candle.size() < 6) throw new KiteApiException("Invalid candle returned by Kite");
        try {
            OffsetDateTime candleTime = OffsetDateTime.parse(candle.get(0).asText(), KITE_TIMESTAMP)
                    .atZoneSameInstant(MARKET_ZONE).toOffsetDateTime();
            return new CandleRow(candleTime,
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
