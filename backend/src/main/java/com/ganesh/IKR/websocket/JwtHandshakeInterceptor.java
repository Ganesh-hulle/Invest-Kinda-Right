package com.ganesh.IKR.websocket;

import com.ganesh.IKR.service.JwtService;
import org.springframework.http.HttpHeaders;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.server.HandshakeInterceptor;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

import java.net.URI;
import java.util.Map;

public class JwtHandshakeInterceptor implements HandshakeInterceptor {
    private final JwtService jwtService;
    private final UserDetailsService userDetailsService;

    public JwtHandshakeInterceptor(JwtService jwtService, UserDetailsService userDetailsService) {
        this.jwtService = jwtService; this.userDetailsService = userDetailsService;
    }

    @Override
    public boolean beforeHandshake(ServerHttpRequest request, ServerHttpResponse response,
                                   WebSocketHandler wsHandler, Map<String, Object> attributes) {
        String token = request.getHeaders().getFirst(HttpHeaders.AUTHORIZATION);
        if (token != null && token.regionMatches(true, 0, "Bearer ", 0, 7)) token = token.substring(7).trim();
        if (token == null || token.isBlank()) token = queryToken(request.getURI());
        try {
            if (token == null || token.isBlank()) return false;
            String username = jwtService.extractUsername(token);
            var details = userDetailsService.loadUserByUsername(username);
            if (!jwtService.isValid(token, details.getUsername())) return false;
            attributes.put("principal", new UsernamePasswordAuthenticationToken(details, null, details.getAuthorities()));
            return true;
        } catch (RuntimeException ignored) { return false; }
    }

    @Override public void afterHandshake(ServerHttpRequest request, ServerHttpResponse response,
                                         WebSocketHandler wsHandler, Exception exception) { }

    private String queryToken(URI uri) {
        if (uri.getQuery() == null) return null;
        for (String part : uri.getQuery().split("&")) {
            if (part.startsWith("access_token=")) return part.substring("access_token=".length());
        }
        return null;
    }
}
