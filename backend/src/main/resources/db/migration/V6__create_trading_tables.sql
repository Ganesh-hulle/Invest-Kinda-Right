CREATE TABLE risk_limits
(
    id                  BIGSERIAL PRIMARY KEY,
    user_id             BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    max_daily_loss      NUMERIC(20, 6) NOT NULL DEFAULT 10000,
    max_trades_per_day  INTEGER NOT NULL DEFAULT 20,
    max_capital_per_trade NUMERIC(20, 6) NOT NULL DEFAULT 100000,
    max_open_positions  INTEGER NOT NULL DEFAULT 5,
    max_position_size   INTEGER NOT NULL DEFAULT 1000,
    trading_enabled     BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_risk_limits_user UNIQUE (user_id)
);

CREATE TABLE paper_orders
(
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    instrument_token BIGINT NOT NULL REFERENCES instruments (instrument_token),
    exchange         VARCHAR(20) NOT NULL,
    tradingsymbol    VARCHAR(100) NOT NULL,
    side             VARCHAR(10) NOT NULL,
    order_type       VARCHAR(10) NOT NULL,
    quantity         INTEGER NOT NULL,
    requested_price  NUMERIC(20, 6) NOT NULL,
    average_price    NUMERIC(20, 6),
    stop_loss        NUMERIC(20, 6),
    status           VARCHAR(20) NOT NULL,
    rejection_reason VARCHAR(255),
    created_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_paper_order_side CHECK (side IN ('BUY', 'SELL')),
    CONSTRAINT ck_paper_order_status CHECK (status IN ('PENDING', 'FILLED', 'REJECTED', 'CANCELLED'))
);

CREATE INDEX idx_paper_orders_user_created ON paper_orders (user_id, created_at);

CREATE TABLE paper_positions
(
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    instrument_token BIGINT NOT NULL REFERENCES instruments (instrument_token),
    exchange         VARCHAR(20) NOT NULL,
    tradingsymbol    VARCHAR(100) NOT NULL,
    quantity         INTEGER NOT NULL,
    average_price    NUMERIC(20, 6) NOT NULL,
    realized_pnl     NUMERIC(20, 6) NOT NULL DEFAULT 0,
    updated_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_paper_positions_user_instrument UNIQUE (user_id, instrument_token)
);

CREATE INDEX idx_paper_positions_user ON paper_positions (user_id);

CREATE TABLE paper_trades
(
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    order_id         BIGINT NOT NULL REFERENCES paper_orders (id),
    instrument_token BIGINT NOT NULL,
    side             VARCHAR(10) NOT NULL,
    quantity         INTEGER NOT NULL,
    price            NUMERIC(20, 6) NOT NULL,
    realized_pnl     NUMERIC(20, 6) NOT NULL DEFAULT 0,
    traded_at        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_paper_trades_user_time ON paper_trades (user_id, traded_at);

CREATE TABLE orders
(
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    instrument_token BIGINT NOT NULL REFERENCES instruments (instrument_token),
    exchange         VARCHAR(20) NOT NULL,
    tradingsymbol    VARCHAR(100) NOT NULL,
    side             VARCHAR(10) NOT NULL,
    order_type       VARCHAR(10) NOT NULL,
    quantity         INTEGER NOT NULL,
    price            NUMERIC(20, 6),
    stop_loss        NUMERIC(20, 6),
    status           VARCHAR(20) NOT NULL,
    broker_order_id  VARCHAR(100),
    rejection_reason VARCHAR(255),
    idempotency_key  VARCHAR(100),
    created_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_orders_user_idempotency UNIQUE (user_id, idempotency_key)
);

CREATE INDEX idx_orders_user_created ON orders (user_id, created_at);
