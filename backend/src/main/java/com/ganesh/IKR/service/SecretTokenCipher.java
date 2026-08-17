package com.ganesh.IKR.service;

import com.ganesh.IKR.config.KiteProperties;
import com.ganesh.IKR.exception.KiteConfigurationException;
import org.springframework.stereotype.Component;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;

@Component
public class SecretTokenCipher {
    private static final int IV_LENGTH = 12;
    private final KiteProperties properties;
    private final SecureRandom random = new SecureRandom();

    public SecretTokenCipher(KiteProperties properties) { this.properties = properties; }

    public EncryptedToken encrypt(String token) {
        try {
            byte[] iv = new byte[IV_LENGTH]; random.nextBytes(iv);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key(), new GCMParameterSpec(128, iv));
            byte[] encrypted = cipher.doFinal(token.getBytes(StandardCharsets.UTF_8));
            return new EncryptedToken(Base64.getEncoder().encodeToString(encrypted), Base64.getEncoder().encodeToString(iv));
        } catch (Exception exception) { throw new KiteConfigurationException("Unable to encrypt Kite access token", exception); }
    }

    public String decrypt(String ciphertext, String encodedIv) {
        try {
            byte[] iv = Base64.getDecoder().decode(encodedIv);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key(), new GCMParameterSpec(128, iv));
            return new String(cipher.doFinal(Base64.getDecoder().decode(ciphertext)), StandardCharsets.UTF_8);
        } catch (Exception exception) { throw new KiteConfigurationException("Unable to decrypt Kite access token", exception); }
    }

    private SecretKeySpec key() {
        String configured = properties.getTokenEncryptionKey();
        if (configured == null || configured.isBlank()) {
            throw new KiteConfigurationException("KITE_TOKEN_ENCRYPTION_KEY must be configured");
        }
        byte[] bytes;
        try { bytes = Base64.getDecoder().decode(configured); }
        catch (IllegalArgumentException exception) { throw new KiteConfigurationException("KITE_TOKEN_ENCRYPTION_KEY must be base64 encoded", exception); }
        if (bytes.length != 32) throw new KiteConfigurationException("KITE_TOKEN_ENCRYPTION_KEY must decode to 32 bytes");
        return new SecretKeySpec(bytes, "AES");
    }

    public record EncryptedToken(String ciphertext, String iv) {}
}
