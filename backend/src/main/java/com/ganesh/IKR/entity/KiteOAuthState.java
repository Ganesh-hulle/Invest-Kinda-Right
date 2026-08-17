package com.ganesh.IKR.entity;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "kite_oauth_states")
public class KiteOAuthState {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(nullable = false, unique = true, length = 128) private String state;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "user_id") private User user;
    @Column(name = "expires_at", nullable = false) private OffsetDateTime expiresAt;
    @Column(name = "consumed_at") private OffsetDateTime consumedAt;

    public String getState() { return state; }
    public void setState(String value) { state = value; }
    public User getUser() { return user; }
    public void setUser(User value) { user = value; }
    public OffsetDateTime getExpiresAt() { return expiresAt; }
    public void setExpiresAt(OffsetDateTime value) { expiresAt = value; }
    public OffsetDateTime getConsumedAt() { return consumedAt; }
    public void setConsumedAt(OffsetDateTime value) { consumedAt = value; }
}
