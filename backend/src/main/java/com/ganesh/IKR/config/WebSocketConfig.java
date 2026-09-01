package com.ganesh.IKR.config;

import com.ganesh.IKR.service.JwtService;
import com.ganesh.IKR.websocket.JwtHandshakeInterceptor;
import com.ganesh.IKR.websocket.MarketWebSocketHandler;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;
import org.springframework.beans.factory.annotation.Value;

@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {
    private final MarketWebSocketHandler handler;
    private final JwtService jwtService;
    private final UserDetailsService userDetailsService;
    private final String allowedOrigins;

    public WebSocketConfig(MarketWebSocketHandler handler, JwtService jwtService, UserDetailsService userDetailsService,
                           @Value("${market-data.allowed-origins:http://localhost:3000}") String allowedOrigins) {
        this.handler = handler; this.jwtService = jwtService; this.userDetailsService = userDetailsService; this.allowedOrigins = allowedOrigins;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(handler, "/ws/market")
                .addInterceptors(new JwtHandshakeInterceptor(jwtService, userDetailsService))
                .setAllowedOrigins(allowedOrigins.split(","));
    }
}
