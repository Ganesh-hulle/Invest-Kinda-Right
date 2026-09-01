package com.ganesh.IKR.websocket;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ganesh.IKR.marketdata.MarketDataBroadcaster;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.WebSocketMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.stereotype.Component;

import java.util.HashSet;

@Component
public class MarketWebSocketHandler implements WebSocketHandler {
    private final ObjectMapper objectMapper;
    private final MarketDataBroadcaster broadcaster;

    public MarketWebSocketHandler(ObjectMapper objectMapper, MarketDataBroadcaster broadcaster) {
        this.objectMapper = objectMapper; this.broadcaster = broadcaster;
    }

    @Override public void afterConnectionEstablished(WebSocketSession session) { broadcaster.register(session); }

    @Override
    public void handleMessage(WebSocketSession session, WebSocketMessage<?> message) throws Exception {
        if (!(message instanceof TextMessage textMessage)) return;
        JsonNode command = objectMapper.readTree(textMessage.getPayload());
        if (!"subscribe".equalsIgnoreCase(command.path("action").asText())) {
            session.sendMessage(new TextMessage("{\"error\":\"Only subscribe is supported\"}"));
            return;
        }
        var tokens = new HashSet<Long>();
        command.path("instrumentTokens").forEach(node -> { if (node.canConvertToLong()) tokens.add(node.asLong()); });
        if (tokens.isEmpty()) {
            session.sendMessage(new TextMessage("{\"error\":\"instrumentTokens must not be empty\"}"));
            return;
        }
        broadcaster.subscribe(session, tokens);
        session.sendMessage(new TextMessage("{\"status\":\"subscribed\"}"));
    }

    @Override public void handleTransportError(WebSocketSession session, Throwable exception) { broadcaster.remove(session); }
    @Override public void afterConnectionClosed(WebSocketSession session, CloseStatus status) { broadcaster.remove(session); }
    @Override public boolean supportsPartialMessages() { return false; }
}
