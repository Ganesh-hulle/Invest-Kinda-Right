package com.ganesh.IKR.dto.auth;

public record AuthResponse(
        Long userId,
        String username,
        String message
) {
}