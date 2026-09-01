# Invest Kinda Right — Phase 5–14 execution and verification guide

Updated: 2026-08-27

## Result

The detailed implementation sequence supplied for this project is complete through Phase 14 at the backend foundation level. Existing Phase 1–4 functionality was preserved. The implementation adds persisted local candles, Redis market state, Kite ticker ingestion, an authenticated internal WebSocket, candle aggregation, indicators, EMA crossover signals, risk limits, paper trading, and a live order adapter guarded by `trading.live-enabled=false`.

The application is still a monolith, uses constructor injection, keeps controllers thin, and routes all execution through services. Strategies emit signals and do not place orders.

## Phase confirmation

| Phase | Status | Implementation evidence |
|---|---|---|
| 1. Instrument Master | Confirmed existing | `instruments` table, `Instrument`, repository, instrument search |
| 2. Instrument Sync | Confirmed existing | `POST /api/v1/kite/instruments/sync` and `InstrumentSyncService` |
| 3. Instrument Lookup | Confirmed existing | `GET /api/v1/instruments/search` |
| 4. Historical Data | Confirmed existing | `GET /api/v1/kite/historical` and Kite client integration |
| 5. Historical Candle Storage | Completed | Existing historical calls upsert into `market_candles`; local `GET /api/v1/market-data/candles` added |
| 6. Redis | Completed | Redis quote cache with TTL and local fallback; Docker Redis service |
| 7. Kite WebSocket | Completed | `KiteMarketDataService` connects to `wss://ws.kite.trade`, subscribes, and parses binary ticker packets |
| 8. Internal WebSocket | Completed | Authenticated `ws://localhost:8080/ws/market` endpoint |
| 9. Candle Engine | Completed | In-memory tick aggregation for `1minute`, `5minute`, and `15minute`; completed candles are upserted |
| 10. Indicators | Completed | EMA 9/20, VWAP, RSI 14, MACD, ATR 14, and SuperTrend calculations |
| 11. Strategy Engine | Completed | `Strategy` contract and EMA crossover signal endpoint |
| 12. Risk Engine | Completed | Per-user daily loss, trade count, capital, position, stop-loss, and enable/disable checks |
| 13. Paper Trading | Completed | Immediate-fill virtual orders, positions, realized P&L, and trade journal |
| 14. Actual Order Engine | Completed safely | Place/modify/cancel adapter, idempotency field, broker order ID tracking; blocked unless `TRADING_LIVE_ENABLED=true` |

## Start the local dependencies

From the repository root:

```powershell
docker compose up -d
docker compose ps
```

Both `ikr-postgres` and `ikr-redis` should show `healthy`/`Up`.

From `backend`:

```powershell
mvn test
mvn spring-boot:run "-Dspring-boot.run.jvmArguments=-Duser.timezone=Asia/Kolkata"
```

The Maven wrapper checked into the repository is currently not usable in this PowerShell environment, so the system Maven command is used above. The Maven test configuration sets `Asia/Kolkata` for test runs. The application also normalizes its JVM timezone when launched normally.

Do not set `TRADING_LIVE_ENABLED=true` during local verification.

## Authentication

Register:

```http
POST http://localhost:8080/api/v1/auth/register
Content-Type: application/json
```

```json
{
  "username": "demo_user",
  "firstname": "Demo",
  "lastname": "User",
  "email": "demo@example.com",
  "password": "Passw0rd!123"
}
```

Login and copy the `token` field:

```http
POST http://localhost:8080/api/v1/auth/login
Content-Type: application/json
```

```json
{
  "username": "demo_user",
  "password": "Passw0rd!123"
}
```

Use it on protected endpoints:

```http
Authorization: Bearer <application-jwt>
```

## Complete API list

All endpoints below require the application JWT unless marked `Public`.

### System and user APIs

| Method | Path | Parameters/body |
|---|---|---|
| GET | `/api/v1/system/health` | None. Public. |
| POST | `/api/v1/auth/register` | `username`, `firstname`, `lastname`, `email`, `password`. Public. |
| POST | `/api/v1/auth/login` | `username`, `password`. Public. |
| GET | `/api/v1/users/getCurrentUser` | None. |

Existing development/compatibility endpoints are unchanged:

| Method | Path | Parameters |
|---|---|---|
| GET | `/` | None. |
| GET | `/test` | None. Public development endpoint. |
| GET | `/test2/{username}` | Path parameter `username`. Public development endpoint. |

### Kite and instruments

| Method | Path | Parameters/body |
|---|---|---|
| GET | `/api/v1/kite/login-url` | None. |
| GET | `/api/v1/kite/callback` | `request_token`, `state`, optional `status=success`. Public Kite redirect. |
| GET | `/api/v1/kite/profile` | None. |
| GET | `/api/v1/kite/portfolio` | None. |
| POST | `/api/v1/kite/instruments/sync` | None. Downloads the Kite CSV and upserts the instrument master in one transaction. Historical instruments referenced by candles are retained. |
| GET | `/api/v1/instruments/search?query=RELIANCE` | `query`; returns up to 20 matches. |
| GET | `/api/v1/kite/historical` | `instrumentToken`, `from`, `to`, `interval`. Supported intervals: `minute`, `3minute`, `5minute`, `10minute`, `15minute`, `30minute`, `60minute`, `day`. |

Historical example:

```text
GET /api/v1/kite/historical?instrumentToken=738561&from=2026-08-20&to=2026-08-27&interval=5minute
```

Each successful historical request returns candles and upserts them into `market_candles` using `(instrument_token, timeframe, candle_time)` as the idempotent key.

### Redis market state, local candles, and streaming

| Method | Path | Parameters/body |
|---|---|---|
| GET | `/api/v1/market-data/quotes?instrumentTokens=738561,408065` | Comma-separated instrument tokens. Reads the latest Redis quote. |
| GET | `/api/v1/market-data/candles` | `instrumentToken`, `timeframe`, ISO-8601 `from`, ISO-8601 `to`. |
| POST | `/api/v1/kite/market-data/connect` | `{ "instrumentTokens": [738561, 408065] }`; starts the Kite binary ticker connection. |
| POST | `/api/v1/kite/market-data/disconnect` | None; disconnects the current user’s ticker session. |
| POST | `/api/v1/market-data/ticks` | Development-only synthetic tick endpoint; enabled in the `dev` profile and disabled by default elsewhere. |
| WebSocket | `/ws/market` | JWT in `Authorization` header or `access_token` query parameter. |

Development tick example:

```json
{
  "instrumentToken": 738561,
  "lastPrice": 1425.50,
  "lastTradedQuantity": 10,
  "cumulativeVolume": 125000,
  "timestamp": "2026-08-27T09:15:00+05:30"
}
```

The internal WebSocket accepts this subscription command after connection:

```json
{
  "action": "subscribe",
  "instrumentTokens": [738561, 408065]
}
```

It responds with a subscription acknowledgement and then sends JSON quote updates for subscribed tokens. The Kite API secret and Kite access token are never sent to this WebSocket.

### Indicators and strategy

| Method | Path | Parameters/body |
|---|---|---|
| GET | `/api/v1/indicators/latest` | `instrumentToken`, `timeframe`; uses the latest 500 persisted candles. |
| GET | `/api/v1/strategies/ema-crossover/signal` | `instrumentToken`, `timeframe`; returns a signal or HTTP 204 when no crossover exists. |

Indicator example:

```text
GET /api/v1/indicators/latest?instrumentToken=738561&timeframe=5minute
```

Signal shape:

```json
{
  "instrumentToken": 738561,
  "exchange": "NSE",
  "tradingsymbol": "RELIANCE",
  "side": "BUY",
  "price": 1425.50,
  "strategy": "EMA_CROSSOVER",
  "generatedAt": "2026-08-27T09:25:00+05:30"
}
```

### Risk configuration

| Method | Path | Parameters/body |
|---|---|---|
| GET | `/api/v1/risk/limits` | None; creates defaults on first access. |
| PUT | `/api/v1/risk/limits` | `maxDailyLoss`, `maxTradesPerDay`, `maxCapitalPerTrade`, `maxOpenPositions`, `maxPositionSize`, `tradingEnabled`. |

Example:

```json
{
  "maxDailyLoss": 10000,
  "maxTradesPerDay": 20,
  "maxCapitalPerTrade": 100000,
  "maxOpenPositions": 5,
  "maxPositionSize": 1000,
  "tradingEnabled": true
}
```

Risk failures return HTTP `422` with `error=RISK_REJECTED`. Risk validation runs before both paper and live order execution.

### Paper trading

| Method | Path | Parameters/body |
|---|---|---|
| POST | `/api/v1/paper/orders` | `instrumentToken`, `side` (`BUY`/`SELL`), `orderType` (`MARKET`/`LIMIT`), `quantity`, optional `price`, optional `stopLoss`, optional `idempotencyKey`. |
| GET | `/api/v1/paper/orders` | None; current user’s paper orders, newest first. |
| GET | `/api/v1/paper/positions` | None; current open paper positions. |

Paper order example:

```json
{
  "instrumentToken": 738561,
  "side": "BUY",
  "orderType": "LIMIT",
  "quantity": 10,
  "price": 1425.50,
  "stopLoss": 1400.00,
  "idempotencyKey": "demo-reliance-entry-001"
}
```

For a `MARKET` paper order, omit `price` only when a current quote exists in Redis. A `SELL` cannot exceed the open paper quantity. Paper fills are immediate and are recorded in `paper_orders`, `paper_positions`, and `paper_trades`.

### Live order engine

| Method | Path | Parameters/body |
|---|---|---|
| POST | `/api/v1/orders` | Same order body as paper trading. Requires live feature flag, risk approval, Kite connection, and a current market price for a market order. |
| GET | `/api/v1/orders/{id}` | Local order status for the current user. |
| PUT | `/api/v1/orders/{id}` | Optional `quantity`, `price`, `stopLoss` for an open order. |
| POST | `/api/v1/orders/{id}/cancel` | None. |

Live order behavior is intentionally fail-closed:

```yaml
trading:
  live-enabled: false
```

With the default setting, `POST /api/v1/orders` returns HTTP `409` and `error=LIVE_TRADING_DISABLED`. Enabling live execution requires an explicit environment setting, a valid Kite session, a synchronized instrument master, and operational testing outside this implementation task.

## Database changes

Flyway migration `V6__create_trading_tables.sql` adds:

- `risk_limits`: per-user risk controls.
- `paper_orders`: virtual order journal.
- `paper_positions`: current virtual long positions.
- `paper_trades`: fill and realized-P&L journal.
- `orders`: broker order lifecycle and idempotency tracking.

Existing `V1`–`V5` migrations are unchanged. The database was verified at schema version `6` with PostgreSQL 16.

## Verification checklist

1. Run `docker compose up -d` and confirm both containers are healthy.
2. Run `mvn test`; the existing Spring context test must pass.
3. Confirm Flyway reports schema version `6`.
4. Call `/api/v1/system/health` and expect `status=UP`.
5. Register, log in, and use the returned JWT.
6. Call `GET /api/v1/risk/limits` and confirm the default limits are returned.
7. Sync instruments after completing Kite login, then search `RELIANCE`.
8. Fetch historical candles; verify rows exist in `market_candles`.
9. In `dev`, post two synthetic ticks in adjacent minute buckets; verify `/quotes` returns the latest price and `/candles` returns the completed first candle.
10. Connect a WebSocket client with the application JWT, subscribe to the test token, and verify quote messages.
11. Place a paper BUY and SELL; verify order status `FILLED`, position quantity, and realized P&L.
12. Call `/api/v1/orders` with live disabled and confirm the safe `LIVE_TRADING_DISABLED` response.

Useful database checks:

```powershell
docker exec ikr-postgres psql -U ikr -d ikr -c "SELECT version, description FROM flyway_schema_history ORDER BY installed_rank;"
docker exec ikr-postgres psql -U ikr -d ikr -c "SELECT COUNT(*) FROM instruments; SELECT COUNT(*) FROM market_candles;"
docker exec ikr-redis redis-cli ping
```

## Operational boundaries

- Kite integration requires real credentials and a valid daily Kite access token; no live Kite call was made during this local smoke test.
- The development tick endpoint must be disabled in any exposed environment with `DEV_TICK_ENDPOINT_ENABLED=false`.
- Live order execution is disabled by default and should remain disabled until paper trading, broker reconciliation, partial-fill handling, and production controls are separately tested.
- Redis is transient market state. PostgreSQL remains the source of truth for instruments, historical candles, risk settings, paper execution, and live-order records.
- The candle engine persists a candle when the next bucket begins; the currently open candle is not treated as completed until rollover.
