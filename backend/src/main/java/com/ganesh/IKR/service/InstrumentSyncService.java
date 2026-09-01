package com.ganesh.IKR.service;

import com.ganesh.IKR.dto.kite.InstrumentSyncResponse;
import com.ganesh.IKR.entity.Instrument;
import com.ganesh.IKR.exception.KiteApiException;
import com.ganesh.IKR.repository.InstrumentRepository;
import com.ganesh.IKR.repository.KiteConnectionRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
// import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.*;

@Service
public class InstrumentSyncService {
    private final KiteClient kiteClient;
    private final KiteConnectionRepository connectionRepository;
    private final InstrumentRepository instrumentRepository;
    private final SecretTokenCipher cipher;
    private final JdbcTemplate jdbcTemplate;

    public InstrumentSyncService(KiteClient kiteClient, KiteConnectionRepository connectionRepository,
                                 InstrumentRepository instrumentRepository, SecretTokenCipher cipher,
                                 JdbcTemplate jdbcTemplate) {
        this.kiteClient = kiteClient;
        this.connectionRepository = connectionRepository;
        this.instrumentRepository = instrumentRepository;
        this.cipher = cipher;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional
    public InstrumentSyncResponse syncInstruments(Long userId) {
        var connection = connectionRepository.findByUserId(userId)
                .orElseThrow(() -> new KiteApiException("Kite account is not connected"));
        List<InstrumentRow> instruments = parse(kiteClient.instrumentDump(
                cipher.decrypt(connection.getEncryptedAccessToken(), connection.getAccessTokenIv())));
        if (instruments.isEmpty()) throw new KiteApiException("Kite returned an empty instrument dump");

        jdbcTemplate.batchUpdate("""
                INSERT INTO instruments (instrument_token, exchange, tradingsymbol, name, segment,
                    instrument_type, expiry, strike, tick_size, lot_size, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                ON CONFLICT (instrument_token) DO UPDATE SET
                    exchange = EXCLUDED.exchange, tradingsymbol = EXCLUDED.tradingsymbol,
                    name = EXCLUDED.name, segment = EXCLUDED.segment,
                    instrument_type = EXCLUDED.instrument_type, expiry = EXCLUDED.expiry,
                    strike = EXCLUDED.strike, tick_size = EXCLUDED.tick_size,
                    lot_size = EXCLUDED.lot_size, updated_at = CURRENT_TIMESTAMP
                """, instruments, 500, (statement, row) -> {
            statement.setLong(1, row.instrumentToken());
            statement.setString(2, row.exchange());
            statement.setString(3, row.tradingsymbol());
            statement.setString(4, row.name());
            statement.setString(5, row.segment());
            statement.setString(6, row.instrumentType());
            if (row.expiry() == null) statement.setObject(7, null); else statement.setObject(7, row.expiry());
            statement.setBigDecimal(8, row.strike());
            statement.setBigDecimal(9, row.tickSize());
            statement.setInt(10, row.lotSize());
        });
        return new InstrumentSyncResponse(instruments.size(), OffsetDateTime.now());
    }

    @Transactional(readOnly = true)
    public List<Instrument> search(String query) {
        if (!StringUtils.hasText(query)) return List.of();
        return instrumentRepository.search(query.trim(), PageRequest.of(0, 20));
    }

    private List<InstrumentRow> parse(String csv) {
        String[] lines = csv.replace("\r", "").split("\n");
        if (lines.length < 2) return List.of();
        Map<String, Integer> headers = new HashMap<>();
        List<String> header = csvLine(lines[0]);
        for (int i = 0; i < header.size(); i++) headers.put(header.get(i).replace("\uFEFF", "").trim(), i);
        String[] required = {"instrument_token", "exchange", "tradingsymbol", "name", "segment",
                "instrument_type", "expiry", "strike", "tick_size", "lot_size"};
        for (String field : required) if (!headers.containsKey(field)) throw new KiteApiException("Kite instrument dump is missing " + field);

        List<InstrumentRow> result = new ArrayList<>(lines.length - 1);
        for (int lineNumber = 1; lineNumber < lines.length; lineNumber++) {
            if (lines[lineNumber].isBlank()) continue;
            List<String> values = csvLine(lines[lineNumber]);
            try {
                String symbol = value(values, headers, "tradingsymbol");
                if (symbol.isBlank()) continue;
                result.add(new InstrumentRow(Long.parseLong(value(values, headers, "instrument_token")),
                        value(values, headers, "exchange"), symbol, nullable(value(values, headers, "name")),
                        value(values, headers, "segment"), value(values, headers, "instrument_type"),
                        date(value(values, headers, "expiry")), decimal(value(values, headers, "strike")),
                        decimal(value(values, headers, "tick_size")), Integer.parseInt(value(values, headers, "lot_size"))));
            } catch (RuntimeException exception) {
                throw new KiteApiException("Invalid row in Kite instrument dump at line " + (lineNumber + 1), exception);
            }
        }
        return result;
    }

    private String value(List<String> values, Map<String, Integer> headers, String name) {
        int index = headers.get(name);
        return index < values.size() ? values.get(index).trim() : "";
    }
    private String nullable(String value) { return value.isBlank() ? null : value; }
    private LocalDate date(String value) { return value.isBlank() ? null : LocalDate.parse(value); }
    private BigDecimal decimal(String value) { return value.isBlank() ? BigDecimal.ZERO : new BigDecimal(value); }

    private List<String> csvLine(String line) {
        List<String> values = new ArrayList<>(); StringBuilder current = new StringBuilder(); boolean quoted = false;
        for (int i = 0; i < line.length(); i++) {
            char character = line.charAt(i);
            if (character == '"') { if (quoted && i + 1 < line.length() && line.charAt(i + 1) == '"') { current.append('"'); i++; } else quoted = !quoted; }
            else if (character == ',' && !quoted) { values.add(current.toString()); current.setLength(0); }
            else current.append(character);
        }
        values.add(current.toString()); return values;
    }

    private record InstrumentRow(Long instrumentToken, String exchange, String tradingsymbol, String name,
                                 String segment, String instrumentType, LocalDate expiry, BigDecimal strike,
                                 BigDecimal tickSize, Integer lotSize) { }
}
