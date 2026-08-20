ALTER TABLE instruments
    DROP CONSTRAINT uk_instruments_exchange_symbol;

CREATE INDEX idx_instruments_exchange_symbol
    ON instruments (exchange, tradingsymbol);
