CREATE TABLE instruments
(
    id               BIGSERIAL PRIMARY KEY,
    instrument_token  BIGINT NOT NULL,
    exchange          VARCHAR(20) NOT NULL,
    tradingsymbol     VARCHAR(100) NOT NULL,
    name              VARCHAR(255),
    segment           VARCHAR(50) NOT NULL,
    instrument_type   VARCHAR(20) NOT NULL,
    expiry            DATE,
    strike            NUMERIC(20, 6),
    tick_size         NUMERIC(20, 6) NOT NULL,
    lot_size          INTEGER NOT NULL,
    created_at        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uk_instruments_token UNIQUE (instrument_token),
    CONSTRAINT uk_instruments_exchange_symbol UNIQUE (exchange, tradingsymbol)
);

CREATE INDEX idx_instruments_symbol ON instruments (tradingsymbol);
CREATE INDEX idx_instruments_name ON instruments (name);
