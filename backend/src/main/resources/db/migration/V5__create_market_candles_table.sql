CREATE TABLE market_candles
(
    id               BIGSERIAL PRIMARY KEY,
    instrument_token BIGINT NOT NULL REFERENCES instruments (instrument_token),
    exchange         VARCHAR(20) NOT NULL,
    timeframe        VARCHAR(20) NOT NULL,
    candle_time      TIMESTAMP WITH TIME ZONE NOT NULL,
    open             NUMERIC(20, 6) NOT NULL,
    high             NUMERIC(20, 6) NOT NULL,
    low              NUMERIC(20, 6) NOT NULL,
    close            NUMERIC(20, 6) NOT NULL,
    volume           BIGINT NOT NULL,
    created_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uk_market_candles_identity UNIQUE (instrument_token, timeframe, candle_time)
);

CREATE INDEX idx_market_candles_lookup
    ON market_candles (instrument_token, timeframe, candle_time);
