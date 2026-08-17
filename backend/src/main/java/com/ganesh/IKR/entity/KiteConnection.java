package com.ganesh.IKR.entity;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "kite_connections")
public class KiteConnection {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;
    @Column(name = "kite_user_id", nullable = false, length = 50) private String kiteUserId;
    @Column(name = "api_key", nullable = false, length = 100) private String apiKey;
    @Column(name = "encrypted_access_token", nullable = false, columnDefinition = "TEXT") private String encryptedAccessToken;
    @Column(name = "access_token_iv", nullable = false, length = 64) private String accessTokenIv;
    @Column(name = "profile_json", columnDefinition = "TEXT") private String profileJson;
    @Column(name = "connected_at", nullable = false, insertable = false, updatable = false) private OffsetDateTime connectedAt;
    @Column(name = "updated_at", nullable = false, insertable = false) private OffsetDateTime updatedAt;

    public Long getId() { return id; }
    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }
    public String getKiteUserId() { return kiteUserId; }
    public void setKiteUserId(String value) { kiteUserId = value; }
    public String getApiKey() { return apiKey; }
    public void setApiKey(String value) { apiKey = value; }
    public String getEncryptedAccessToken() { return encryptedAccessToken; }
    public void setEncryptedAccessToken(String value) { encryptedAccessToken = value; }
    public String getAccessTokenIv() { return accessTokenIv; }
    public void setAccessTokenIv(String value) { accessTokenIv = value; }
    public String getProfileJson() { return profileJson; }
    public void setProfileJson(String value) { profileJson = value; }
}
