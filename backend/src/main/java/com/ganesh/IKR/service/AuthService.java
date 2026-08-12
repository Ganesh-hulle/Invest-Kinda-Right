package com.ganesh.IKR.service;

import com.ganesh.IKR.dto.auth.AuthResponse;
import com.ganesh.IKR.dto.auth.LoginRequest;
import com.ganesh.IKR.dto.auth.RegisterRequest;
import com.ganesh.IKR.entity.User;
import com.ganesh.IKR.repository.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public AuthService(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder
    ) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    public AuthResponse register(RegisterRequest request) {

        if (userRepository.existsByUsername(request.username())) {
            throw new IllegalArgumentException(
                    "Username already exists"
            );
        }

        if (userRepository.existsByEmail(request.email())) {
            throw new IllegalArgumentException(
                    "Email already exists"
            );
        }

        String passwordHash =
                passwordEncoder.encode(request.password());

        User user = new User();

        user.setUsername(request.username());
        user.setEmail(request.email());
        user.setPasswordHash(passwordHash);
        user.setFirstName(request.firstname());
        user.setLastName(request.lastname());

        User savedUser = userRepository.save(user);

        return new AuthResponse(
                savedUser.getId(),
                savedUser.getUsername(),
                "User registered successfully"
        );
    }

    public AuthResponse login(LoginRequest request) {

        User user = userRepository
                .findByUsername(request.username())
                .orElseThrow(() ->
                        new IllegalArgumentException(
                                "Invalid username or password"
                        )
                );

        boolean passwordMatches =
                passwordEncoder.matches(
                        request.password(),
                        user.getPasswordHash()
                );

        if (!passwordMatches) {
            throw new IllegalArgumentException(
                    "Invalid username or password"
            );
        }

        return new AuthResponse(
                user.getId(),
                user.getUsername(),
                "Login successful"
        );
    }
}