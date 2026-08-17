package com.ganesh.IKR.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ganesh.IKR.config.KiteProperties;
import com.ganesh.IKR.dto.kite.KiteProfileResponse;
import com.ganesh.IKR.dto.kite.KitePortfolioResponse;
import com.ganesh.IKR.entity.KiteConnection;
import com.ganesh.IKR.entity.KiteOAuthState;
import com.ganesh.IKR.entity.User;
import com.ganesh.IKR.exception.KiteApiException;
import com.ganesh.IKR.repository.KiteConnectionRepository;
import com.ganesh.IKR.repository.KiteOAuthStateRepository;
import com.ganesh.IKR.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.util.Base64;
import java.util.UUID;
import java.util.List;
import java.util.Map;
import com.fasterxml.jackson.core.type.TypeReference;

@Service
public class KiteService {
    private final KiteProperties properties;
    private final KiteClient kiteClient;
    private final KiteOAuthStateRepository stateRepository;
    private final KiteConnectionRepository connectionRepository;
    private final UserRepository userRepository;
    private final SecretTokenCipher cipher;
    private final ObjectMapper objectMapper;

    public KiteService(KiteProperties properties, KiteClient kiteClient, KiteOAuthStateRepository stateRepository,
                       KiteConnectionRepository connectionRepository, UserRepository userRepository,
                       SecretTokenCipher cipher, ObjectMapper objectMapper) {
        this.properties = properties; this.kiteClient = kiteClient; this.stateRepository = stateRepository;
        this.connectionRepository = connectionRepository; this.userRepository = userRepository;
        this.cipher = cipher; this.objectMapper = objectMapper;
    }

    @Transactional
    public String createLoginUrl(Long userId) {
        User user = userRepository.findById(userId).orElseThrow(() -> new KiteApiException("Application user not found"));
        if (properties.getApiKey() == null || properties.getRedirectUrl() == null || properties.getApiKey().isBlank() || properties.getRedirectUrl().isBlank())
            throw new KiteApiException("KITE_API_KEY and KITE_REDIRECT_URL must be configured");
        KiteOAuthState state = new KiteOAuthState();
        state.setState(Base64.getUrlEncoder().withoutPadding().encodeToString(UUID.randomUUID().toString().getBytes(StandardCharsets.UTF_8)));
        state.setUser(user); state.setExpiresAt(OffsetDateTime.now().plusMinutes(10)); stateRepository.save(state);
        return "https://kite.zerodha.com/connect/login?v=3&api_key=" + encode(properties.getApiKey())
                + "&redirect_params=" + encode("state=" + state.getState());
    }

    @Transactional
    public KiteProfileResponse handleCallback(String requestToken, String state, String status) {
        if (!"success".equalsIgnoreCase(status)) throw new KiteApiException("Kite login was not successful");
        KiteOAuthState oauthState = stateRepository.findByState(state).orElseThrow(() -> new KiteApiException("Invalid Kite OAuth state"));
        if (oauthState.getConsumedAt() != null || oauthState.getExpiresAt().isBefore(OffsetDateTime.now())) throw new KiteApiException("Expired or already used Kite OAuth state");
        oauthState.setConsumedAt(OffsetDateTime.now()); stateRepository.save(oauthState);

        var session = kiteClient.exchangeRequestToken(requestToken);
        String accessToken = session.path("data").path("access_token").asText(null);
        String kiteUserId = session.path("data").path("user_id").asText(null);
        if (accessToken == null || kiteUserId == null) throw new KiteApiException("Kite did not return a valid session");
        KiteProfileResponse profile = kiteClient.profile(accessToken);
        var encrypted = cipher.encrypt(accessToken);
        KiteConnection connection = connectionRepository.findByUserId(oauthState.getUser().getId()).orElseGet(KiteConnection::new);
        connection.setUser(oauthState.getUser()); connection.setKiteUserId(kiteUserId); connection.setApiKey(properties.getApiKey());
        connection.setEncryptedAccessToken(encrypted.ciphertext()); connection.setAccessTokenIv(encrypted.iv());
        try { connection.setProfileJson(objectMapper.writeValueAsString(profile)); } catch (Exception e) { throw new KiteApiException("Unable to store Kite profile", e); }
        connectionRepository.save(connection);
        return profile;
    }

    @Transactional(readOnly = true)
    public KiteProfileResponse getProfile(Long userId) {
        KiteConnection connection = connectionRepository.findByUserId(userId)
                .orElseThrow(() -> new KiteApiException("Kite account is not connected"));
        return kiteClient.profile(cipher.decrypt(connection.getEncryptedAccessToken(), connection.getAccessTokenIv()));
    }

    @Transactional(readOnly = true)
    public KitePortfolioResponse getPortfolio(Long userId) {
        KiteConnection connection = connectionRepository.findByUserId(userId)
                .orElseThrow(() -> new KiteApiException("Kite account is not connected"));
        String accessToken = cipher.decrypt(connection.getEncryptedAccessToken(), connection.getAccessTokenIv());
        var holdingsResponse = kiteClient.portfolioData(accessToken, "/portfolio/holdings");
        var positionsResponse = kiteClient.portfolioData(accessToken, "/portfolio/positions");
        List<Map<String, Object>> holdings = objectMapper.convertValue(
                holdingsResponse.path("data"), new TypeReference<>() {});
        var positions = positionsResponse.path("data");
        List<Map<String, Object>> netPositions = objectMapper.convertValue(
                positions.path("net"), new TypeReference<>() {});
        List<Map<String, Object>> dayPositions = objectMapper.convertValue(
                positions.path("day"), new TypeReference<>() {});
        return new KitePortfolioResponse(holdings, netPositions, dayPositions);
    }

    private String encode(String value) { return URLEncoder.encode(value, StandardCharsets.UTF_8); }
}
