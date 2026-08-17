package com.ganesh.IKR.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "kite")
public class KiteProperties {

    private String apiKey;
    private String apiSecret;
    private String redirectUrl;
    private String apiBaseUrl = "https://api.kite.trade";
    private String tokenEncryptionKey;

    public String getApiKey() { return apiKey; }
    public void setApiKey(String apiKey) { this.apiKey = apiKey; }
    public String getApiSecret() { return apiSecret; }
    public void setApiSecret(String apiSecret) { this.apiSecret = apiSecret; }
    public String getRedirectUrl() { return redirectUrl; }
    public void setRedirectUrl(String redirectUrl) { this.redirectUrl = redirectUrl; }
    public String getApiBaseUrl() { return apiBaseUrl; }
    public void setApiBaseUrl(String apiBaseUrl) { this.apiBaseUrl = apiBaseUrl; }
    public String getTokenEncryptionKey() { return tokenEncryptionKey; }
    public void setTokenEncryptionKey(String tokenEncryptionKey) { this.tokenEncryptionKey = tokenEncryptionKey; }
}
