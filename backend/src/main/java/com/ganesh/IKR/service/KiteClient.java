package com.ganesh.IKR.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ganesh.IKR.config.KiteProperties;
import com.ganesh.IKR.dto.kite.KiteProfileResponse;
import com.ganesh.IKR.exception.KiteApiException;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;

@Component
public class KiteClient {
    private static final Logger log = LoggerFactory.getLogger(KiteClient.class);
    private final KiteProperties properties;
    private final RestClient client;
    private final ObjectMapper objectMapper;

    public KiteClient(KiteProperties properties, RestClient.Builder builder, ObjectMapper objectMapper) {
        this.properties = properties; this.objectMapper = objectMapper;
        this.client = builder.baseUrl(properties.getApiBaseUrl()).build();
    }

    public JsonNode exchangeRequestToken(String requestToken) {
        requireConfigured();
        var form = new LinkedMultiValueMap<String, String>();
        form.add("api_key", properties.getApiKey()); form.add("request_token", requestToken);
        form.add("checksum", sha256(properties.getApiKey() + requestToken + properties.getApiSecret()));
        return parseJson(call(() -> client.post().uri("/session/token").header("X-Kite-Version", "3")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED).body(form).retrieve().body(String.class)));
    }

    public KiteProfileResponse profile(String accessToken) {
        requireConfigured();
        JsonNode response = parseJson(call(() -> client.get().uri("/user/profile").header("X-Kite-Version", "3")
                .header("Authorization", "token " + properties.getApiKey() + ":" + accessToken)
                .retrieve().body(String.class)));
        try {
            JsonNode data = response.path("data");
            if (!data.isObject() || data.path("user_id").isMissingNode()) {
                throw new KiteApiException("Kite profile response did not contain profile data");
            }
            return objectMapper.treeToValue(data, KiteProfileResponse.class);
        } catch (KiteApiException exception) {
            throw exception;
        } catch (Exception exception) {
            log.error("Kite profile response could not be converted: {}", exception.getMessage(), exception);
            throw new KiteApiException("Invalid profile response from Kite: " + exception.getMessage(), exception);
        }
    }

    private <T> T call(java.util.function.Supplier<T> request) {
        try { return request.get(); }
        catch (RestClientResponseException exception) {
            log.error("Kite API returned HTTP status {}", exception.getStatusCode(), exception);
            throw new KiteApiException("Kite API request failed: " + exception.getStatusCode(), exception);
        }
        catch (RestClientException exception) {
            log.error("Kite API client/network error: {}", exception.getMessage(), exception);
            throw new KiteApiException("Kite API client/network error: " + exception.getMessage(), exception);
        }
        catch (RuntimeException exception) {
            log.error("Unexpected Kite API response error: {}", exception.getMessage(), exception);
            throw new KiteApiException("Unexpected Kite API response error", exception);
        }
    }

    private JsonNode parseJson(String responseBody) {
        try {
            return objectMapper.readTree(responseBody);
        } catch (Exception exception) {
            log.error("Kite API returned an invalid JSON response", exception);
            throw new KiteApiException("Kite API returned an invalid response", exception);
        }
    }

    private void requireConfigured() {
        if (properties.getApiKey() == null || properties.getApiKey().isBlank() || properties.getApiSecret() == null || properties.getApiSecret().isBlank())
            throw new KiteApiException("KITE_API_KEY and KITE_API_SECRET must be configured");
    }

    private String sha256(String value) {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8))); }
        catch (Exception exception) { throw new IllegalStateException("SHA-256 is unavailable", exception); }
    }
}
