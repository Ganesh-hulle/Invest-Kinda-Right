package com.ganesh.IKR.service;

import com.ganesh.IKR.config.KiteProperties;
import com.ganesh.IKR.marketdata.InstrumentTokensRequest;
import com.ganesh.IKR.marketdata.MarketTickPipeline;
import com.ganesh.IKR.marketdata.MarketTick;
import com.ganesh.IKR.repository.KiteConnectionRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
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
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import jakarta.annotation.PreDestroy;

@Service
public class KiteMarketDataService {
    private static final Logger log = LoggerFactory.getLogger(KiteMarketDataService.class);
    private final KiteProperties properties;
    private final KiteConnectionRepository connectionRepository;
    private final SecretTokenCipher cipher;
    private final MarketTickPipeline pipeline;
    private final String websocketUrl;
    private final WebSocketClient webSocketClient = new StandardWebSocketClient();
    private final Map<Long, WebSocketSession> sessions = new ConcurrentHashMap<>();

    public KiteMarketDataService(KiteProperties properties, KiteConnectionRepository connectionRepository,
                                 SecretTokenCipher cipher, MarketTickPipeline pipeline,
                                 @Value("${market-data.websocket-url:wss://ws.kite.trade}") String websocketUrl) {
        this.properties = properties; this.connectionRepository = connectionRepository; this.cipher = cipher;
        this.pipeline = pipeline; this.websocketUrl = websocketUrl;
    }

    public CompletableFuture<Void> connect(Long userId, Set<Long> tokens) {
        disconnect(userId);
        var connection = connectionRepository.findByUserId(userId)
                .orElseThrow(() -> new IllegalStateException("Kite account is not connected"));
        if (properties.getApiKey() == null || properties.getApiKey().isBlank())
            throw new IllegalStateException("KITE_API_KEY must be configured");
        URI uri = UriComponentsBuilder.fromUriString(websocketUrl)
                .queryParam("api_key", properties.getApiKey())
                .queryParam("access_token", cipher.decrypt(connection.getEncryptedAccessToken(), connection.getAccessTokenIv()))
                .build().encode().toUri();
        WebSocketHandler handler = new TickerHandler(userId, tokens);
        return webSocketClient.execute(handler, new WebSocketHttpHeaders(), uri).thenAccept(session -> {
            sessions.put(userId, session);
            send(session, "{\"a\":\"subscribe\",\"v\":[" + tokens.stream().map(String::valueOf).collect(java.util.stream.Collectors.joining(",")) + "]}");
            send(session, "{\"a\":\"mode\",\"v\":[\"quote\",[" + tokens.stream().map(String::valueOf).collect(java.util.stream.Collectors.joining(",")) + "]]}");
            log.info("Kite market data connected for user {} and {} instruments", userId, tokens.size());
        });
    }

    public void disconnect(Long userId) {
        WebSocketSession session = sessions.remove(userId);
        if (session != null) try { session.close(); } catch (Exception exception) { log.debug("Kite ticker close failed: {}", exception.getMessage()); }
    }

    @PreDestroy
    public void closeAll() { sessions.keySet().forEach(this::disconnect); }

    private void send(WebSocketSession session, String value) {
        try { session.sendMessage(new TextMessage(value)); }
        catch (Exception exception) { log.warn("Unable to send Kite ticker command: {}", exception.getMessage()); }
    }

    private final class TickerHandler implements WebSocketHandler {
        private final Long userId; private final Set<Long> subscribedTokens;
        private TickerHandler(Long userId, Set<Long> subscribedTokens) { this.userId = userId; this.subscribedTokens = subscribedTokens; }
        @Override public void afterConnectionEstablished(WebSocketSession session) { }
        @Override public void handleMessage(WebSocketSession session, org.springframework.web.socket.WebSocketMessage<?> message) {
            if (message instanceof BinaryMessage binary) parse(binary.getPayload());
            else if (message instanceof TextMessage text && text.getPayload().contains("error")) log.warn("Kite ticker error for user {}", userId);
        }
        @Override public void handleTransportError(WebSocketSession session, Throwable exception) { sessions.remove(userId, session); log.warn("Kite ticker transport error for user {}: {}", userId, exception.getMessage()); }
        @Override public void afterConnectionClosed(WebSocketSession session, org.springframework.web.socket.CloseStatus status) { sessions.remove(userId, session); }
        @Override public boolean supportsPartialMessages() { return false; }

        private void parse(ByteBuffer payload) {
            ByteBuffer buffer = payload.slice().order(ByteOrder.BIG_ENDIAN);
            if (buffer.remaining() < 2) return;
            int packetCount = Short.toUnsignedInt(buffer.getShort());
            for (int i = 0; i < packetCount && buffer.remaining() >= 2; i++) {
                int packetLength = Short.toUnsignedInt(buffer.getShort());
                if (packetLength > buffer.remaining()) return;
                ByteBuffer packet = buffer.slice(0, packetLength).order(ByteOrder.BIG_ENDIAN);
                buffer.position(buffer.position() + packetLength);
                if (packetLength < 8) continue;
                long token = Integer.toUnsignedLong(packet.getInt(0));
                if (!subscribedTokens.contains(token)) continue;
                long pricePaise = Integer.toUnsignedLong(packet.getInt(4));
                Long quantity = packetLength >= 12 ? Integer.toUnsignedLong(packet.getInt(8)) : null;
                Long volume = packetLength >= 20 ? Integer.toUnsignedLong(packet.getInt(16)) : null;
                pipeline.accept(new MarketTick(token, null, null,
                        java.math.BigDecimal.valueOf(pricePaise, 2), quantity, volume, OffsetDateTime.now()));
            }
        }
    }
}
