package com.ganesh.IKR.dto.auth;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record AuthResponse(
        Long userId,
        String username,
        String token,
        String message
) {

    public AuthResponse(Long userId, String username, String message) {
        this(userId, username, null, message);
    }
}