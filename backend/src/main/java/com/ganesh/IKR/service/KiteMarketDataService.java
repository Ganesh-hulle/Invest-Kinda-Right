package com.ganesh.IKR.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ganesh.IKR.config.KiteProperties;
// import com.ganesh.IKR.marketdata.InstrumentTokensRequest;
import com.ganesh.IKR.marketdata.MarketTickPipeline;
import com.ganesh.IKR.marketdata.MarketTick;
import com.ganesh.IKR.repository.KiteConnectionRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
// import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Service;
import org.springframework.web.socket.BinaryMessage;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.WebSocketHttpHeaders;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.client.WebSocketClient;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.time.OffsetDateTime;
import java.time.Instant;
import java.time.ZoneId;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import jakarta.annotation.PreDestroy;

@Service
public class KiteMarketDataService {
    private static final Logger log = LoggerFactory.getLogger(KiteMarketDataService.class);
    private static final ZoneId MARKET_ZONE = ZoneId.of("Asia/Kolkata");
    private final KiteProperties properties;
    private final KiteConnectionRepository connectionRepository;
    private final SecretTokenCipher cipher;
    private final MarketTickPipeline pipeline;
    private final ObjectMapper objectMapper;
    private final String websocketUrl;
    private final String websocketMode;
    private final WebSocketClient webSocketClient = new StandardWebSocketClient();
    private final Map<Long, WebSocketSession> sessions = new ConcurrentHashMap<>();
    private final Map<Long, ConnectionState> connectionStates = new ConcurrentHashMap<>();

    public KiteMarketDataService(KiteProperties properties, KiteConnectionRepository connectionRepository,
                                 SecretTokenCipher cipher, MarketTickPipeline pipeline,
                                 ObjectMapper objectMapper,
                                 @Value("${market-data.websocket-url:wss://ws.kite.trade}") String websocketUrl,
                                 @Value("${market-data.websocket-mode:full}") String websocketMode) {
        this.properties = properties; this.connectionRepository = connectionRepository; this.cipher = cipher;
        this.pipeline = pipeline; this.objectMapper = objectMapper; this.websocketUrl = websocketUrl;
        this.websocketMode = normalizeMode(websocketMode);
    }

    public CompletableFuture<Void> connect(Long userId, Set<Long> tokens) {
        if (tokens == null || tokens.isEmpty()) {
            throw new IllegalArgumentException("At least one instrument token is required");
        }
        disconnect(userId);
        var connection = connectionRepository.findByUserId(userId)
                .orElseThrow(() -> new IllegalStateException("Kite account is not connected"));
        if (properties.getApiKey() == null || properties.getApiKey().isBlank())
            throw new IllegalStateException("KITE_API_KEY must be configured");
        URI uri = UriComponentsBuilder.fromUriString(websocketUrl)
                .queryParam("api_key", properties.getApiKey())
                .queryParam("access_token", cipher.decrypt(connection.getEncryptedAccessToken(), connection.getAccessTokenIv()))
                .build().encode().toUri();
        ConnectionState state = new ConnectionState(Set.copyOf(tokens));
        connectionStates.put(userId, state);
        WebSocketHandler handler = new TickerHandler(userId, Set.copyOf(tokens), state);
        return webSocketClient.execute(handler, new WebSocketHttpHeaders(), uri)
                .thenAccept(session -> {
            if (connectionStates.get(userId) != state) {
                closeQuietly(session);
                return;
            }
            sessions.put(userId, session);
            state.connectedAt = OffsetDateTime.now(MARKET_ZONE);
            state.status = "CONNECTED";
            String tokenList = tokens.stream().map(String::valueOf).collect(java.util.stream.Collectors.joining(","));
            send(session, "{\"a\":\"subscribe\",\"v\":[" + tokenList + "]}", state);
            send(session, "{\"a\":\"mode\",\"v\":[\"" + websocketMode + "\",[" + tokenList + "]]}", state);
            log.info("Kite market data connected for user {} and {} instruments", userId, tokens.size());
        })
                .whenComplete((ignored, exception) -> {
                    if (exception != null) {
                        state.fail(exception);
                        log.error("Kite market data connection failed for user {}: {}", userId,
                                safeMessage(exception));
                    }
                });
    }

    public void disconnect(Long userId) {
        WebSocketSession session = sessions.remove(userId);
        ConnectionState state = connectionStates.remove(userId);
        if (state != null) state.markDisconnected();
        if (session != null) closeQuietly(session);
    }

    public KiteMarketDataStatus status(Long userId) {
        ConnectionState state = connectionStates.get(userId);
        return state == null ? KiteMarketDataStatus.disconnected() : state.snapshot();
    }

    @PreDestroy
    public void closeAll() {
        Set<Long> userIds = new HashSet<>(connectionStates.keySet());
        userIds.addAll(sessions.keySet());
        userIds.forEach(this::disconnect);
    }

    private void send(WebSocketSession session, String value, ConnectionState state) {
        try {
            session.sendMessage(new TextMessage(value));
        } catch (Exception exception) {
            state.fail(exception);
            log.warn("Unable to send Kite ticker command: {}", safeMessage(exception));
        }
    }

    private void closeQuietly(WebSocketSession session) {
        try {
            session.close();
        } catch (Exception exception) {
            log.debug("Kite ticker close failed: {}", safeMessage(exception));
        }
    }

    private static String rootMessage(Throwable exception) {
        Throwable current = exception;
        while (current.getCause() != null) current = current.getCause();
        return current.getMessage() == null ? current.getClass().getSimpleName() : current.getMessage();
    }

    private static String safeMessage(Throwable exception) {
        return rootMessage(exception)
                .replaceAll("(?i)(access_token=)[^&\\s]+", "$1[REDACTED]")
                .replaceAll("(?i)(token\\s+[^:\\s]+:)[^\\s]+", "$1[REDACTED]");
    }

    private String normalizeMode(String mode) {
        String normalized = mode == null ? "full" : mode.trim().toLowerCase();
        if (!Set.of("ltp", "quote", "full").contains(normalized)) {
            throw new IllegalArgumentException("market-data.websocket-mode must be ltp, quote, or full");
        }
        return normalized;
    }

    private final class TickerHandler implements WebSocketHandler {
        private final Long userId; private final Set<Long> subscribedTokens;
        private final ConnectionState state;
        private TickerHandler(Long userId, Set<Long> subscribedTokens, ConnectionState state) {
            this.userId = userId; this.subscribedTokens = subscribedTokens; this.state = state;
        }
        @Override public void afterConnectionEstablished(WebSocketSession session) {
            log.debug("Kite ticker WebSocket handshake established for user {}", userId);
        }
        @Override public void handleMessage(WebSocketSession session, org.springframework.web.socket.WebSocketMessage<?> message) {
            if (message instanceof BinaryMessage binary) {
                parse(binary.getPayload());
            } else if (message instanceof TextMessage text) {
                handleTextMessage(text.getPayload());
            } else {
                log.debug("Ignoring unsupported Kite ticker message type {} for user {}", message.getClass().getSimpleName(), userId);
            }
        }
        @Override public void handleTransportError(WebSocketSession session, Throwable exception) {
            sessions.remove(userId, session);
            state.fail(exception);
            log.warn("Kite ticker transport error for user {}: {}", userId, safeMessage(exception));
        }
        @Override public void afterConnectionClosed(WebSocketSession session, org.springframework.web.socket.CloseStatus status) {
            sessions.remove(userId, session);
            state.closedAt = OffsetDateTime.now(MARKET_ZONE);
            if (!"DISCONNECTED".equals(state.status)) state.status = status.getCode() == 1000 ? "CLOSED" : "ERROR";
            if (status.getCode() == 1000) {
                log.info("Kite ticker connection closed for user {} normally", userId);
            } else {
                log.warn("Kite ticker connection closed for user {}: code={}, reason={}", userId,
                        status.getCode(), status.getReason());
            }
        }
        @Override public boolean supportsPartialMessages() { return false; }

        private void parse(ByteBuffer payload) {
            state.binaryFrames.incrementAndGet();
            ByteBuffer buffer = payload.slice().order(ByteOrder.BIG_ENDIAN);
            if (buffer.remaining() == 1) {
                state.heartbeats.incrementAndGet();
                return;
            }
            if (buffer.remaining() < 2) {
                state.malformedFrames.incrementAndGet();
                log.warn("Malformed Kite binary frame for user {}: {} bytes", userId, buffer.remaining());
                return;
            }
            int packetCount = Short.toUnsignedInt(buffer.getShort());
            state.packetsReceived.addAndGet(packetCount);
            log.debug("Kite binary frame received for user {}: bytes={}, packets={}", userId, payload.remaining(), packetCount);
            for (int i = 0; i < packetCount && buffer.remaining() >= 2; i++) {
                int packetLength = Short.toUnsignedInt(buffer.getShort());
                if (packetLength > buffer.remaining()) {
                    state.malformedFrames.incrementAndGet();
                    log.warn("Malformed Kite packet for user {}: declaredLength={}, remainingBytes={}", userId,
                            packetLength, buffer.remaining());
                    return;
                }
                // slice() starts at the current position. Using slice(0, length) here
                // would restart at the frame header and read the count/length bytes
                // as the instrument token.
                ByteBuffer packet = buffer.slice().order(ByteOrder.BIG_ENDIAN);
                packet.limit(packetLength);
                buffer.position(buffer.position() + packetLength);
                if (packetLength < 8) {
                    state.shortPackets.incrementAndGet();
                    log.debug("Ignoring short Kite packet for user {}: length={}", userId, packetLength);
                    continue;
                }
                long token = Integer.toUnsignedLong(packet.getInt(0));
                state.lastPacketToken = token;
                if (!subscribedTokens.contains(token)) {
                    state.unmatchedPackets.incrementAndGet();
                    state.lastUnmatchedToken = token;
                    log.warn("Kite packet token {} was not in the requested subscription for user {}", token, userId);
                    continue;
                }
                long pricePaise = Integer.toUnsignedLong(packet.getInt(4));
                Long quantity = packetLength >= 12 ? Integer.toUnsignedLong(packet.getInt(8)) : null;
                Long volume = packetLength >= 20 ? Integer.toUnsignedLong(packet.getInt(16)) : null;
                try {
                    OffsetDateTime tickTimestamp = exchangeTimestamp(packet);
                    pipeline.accept(new MarketTick(token, null, null,
                            java.math.BigDecimal.valueOf(pricePaise, 2), quantity, volume, tickTimestamp));
                    state.ticksAccepted.incrementAndGet();
                    state.lastTickAt = tickTimestamp;
                    log.debug("Kite tick accepted for user {}: token={}, packetLength={}, price={}, quantity={}, volume={}",
                            userId, token, packetLength, java.math.BigDecimal.valueOf(pricePaise, 2), quantity, volume);
                } catch (RuntimeException exception) {
                    state.ticksRejected.incrementAndGet();
                    state.lastError = safeMessage(exception);
                    log.error("Kite tick processing failed for user {}: token={}, packetLength={}, error={}",
                            userId, token, packetLength, safeMessage(exception));
                }
            }
        }

        private OffsetDateTime exchangeTimestamp(ByteBuffer packet) {
            // Kite includes the exchange timestamp in full packets at bytes 60-64.
            // Quote/LTP packets do not contain it, so use receipt time as a fallback.
            if (packet.remaining() >= 64) {
                long epochSeconds = Integer.toUnsignedLong(packet.getInt(60));
                if (epochSeconds > 0) {
                    return OffsetDateTime.ofInstant(Instant.ofEpochSecond(epochSeconds), MARKET_ZONE);
                }
            }
            return OffsetDateTime.now(MARKET_ZONE);
        }

        private void handleTextMessage(String payload) {
            try {
                JsonNode message = objectMapper.readTree(payload);
                String type = message.path("type").asText("unknown");
                String data = message.path("data").isValueNode() ? message.path("data").asText() : message.path("data").toString();
                if ("error".equalsIgnoreCase(type)) {
                    state.lastError = data;
                    state.status = "ERROR";
                    log.error("Kite ticker error for user {}: type={}, data={}", userId, type, data);
                } else {
                    log.debug("Kite ticker message for user {}: type={}, data={}", userId, type, data);
                }
            } catch (Exception exception) {
                state.lastError = safeMessage(exception);
                log.warn("Unparseable Kite ticker text message for user {}: {}", userId, payload);
            }
        }
    }

    private static final class ConnectionState {
        private final Set<Long> requestedInstrumentTokens;
        private volatile String status = "CONNECTING";
        private volatile String lastError;
        private volatile OffsetDateTime connectedAt;
        private volatile OffsetDateTime lastTickAt;
        private volatile OffsetDateTime closedAt;
        private volatile Long lastPacketToken;
        private volatile Long lastUnmatchedToken;
        private final AtomicLong binaryFrames = new AtomicLong();
        private final AtomicLong heartbeats = new AtomicLong();
        private final AtomicLong packetsReceived = new AtomicLong();
        private final AtomicLong ticksAccepted = new AtomicLong();
        private final AtomicLong ticksRejected = new AtomicLong();
        private final AtomicLong unmatchedPackets = new AtomicLong();
        private final AtomicLong malformedFrames = new AtomicLong();
        private final AtomicLong shortPackets = new AtomicLong();

        private ConnectionState(Set<Long> requestedInstrumentTokens) {
            this.requestedInstrumentTokens = requestedInstrumentTokens;
        }

        private void fail(Throwable exception) {
            status = "ERROR";
            lastError = safeMessage(exception);
        }

        private void markDisconnected() {
            status = "DISCONNECTED";
            closedAt = OffsetDateTime.now();
        }

        private KiteMarketDataStatus snapshot() {
            return new KiteMarketDataStatus(status, requestedInstrumentTokens, binaryFrames.get(), heartbeats.get(),
                    packetsReceived.get(), ticksAccepted.get(), ticksRejected.get(), unmatchedPackets.get(),
                    malformedFrames.get(), shortPackets.get(), lastPacketToken, lastUnmatchedToken,
                    connectedAt, lastTickAt, closedAt, lastError);
        }
    }
}
