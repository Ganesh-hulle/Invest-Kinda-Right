package com.ganesh.IKR.marketdata;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class MarketDataBroadcaster {
    private final ObjectMapper objectMapper;
    private final Map<WebSocketSession, Set<Long>> subscriptions = new ConcurrentHashMap<>();

    public MarketDataBroadcaster(ObjectMapper objectMapper) { this.objectMapper = objectMapper; }

    public void register(WebSocketSession session) { subscriptions.put(session, ConcurrentHashMap.newKeySet()); }
    public void remove(WebSocketSession session) { subscriptions.remove(session); }
    public void subscribe(WebSocketSession session, Set<Long> tokens) {
        subscriptions.computeIfAbsent(session, ignored -> ConcurrentHashMap.newKeySet()).addAll(tokens);
    }

    public void publish(MarketTick tick) {
        subscriptions.forEach((session, tokens) -> {
            if (session.isOpen() && tokens.contains(tick.instrumentToken())) {
                try { synchronized (session) { session.sendMessage(new TextMessage(objectMapper.writeValueAsString(MarketTickResponse.from(tick)))); } }
                catch (Exception ignored) { remove(session); }
            }
        });
    }
}
