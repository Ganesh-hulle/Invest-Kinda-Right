CREATE TABLE kite_oauth_states
(
    id         BIGSERIAL PRIMARY KEY,
    state      VARCHAR(128) NOT NULL,
    user_id    BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    consumed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uk_kite_oauth_states_state UNIQUE (state)
);

CREATE INDEX idx_kite_oauth_states_expiry ON kite_oauth_states (expires_at);

CREATE TABLE kite_connections
(
    id                    BIGSERIAL PRIMARY KEY,
    user_id               BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    kite_user_id          VARCHAR(50) NOT NULL,
    api_key               VARCHAR(100) NOT NULL,
    encrypted_access_token TEXT NOT NULL,
    access_token_iv       VARCHAR(64) NOT NULL,
    profile_json          TEXT,
    connected_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uk_kite_connections_user UNIQUE (user_id)
);
