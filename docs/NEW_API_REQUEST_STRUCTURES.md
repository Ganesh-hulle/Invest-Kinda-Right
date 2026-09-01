# Invest Kinda Right — Newly Added API Request Structures

Updated: 2026-08-31

Base URL:

```text
http://localhost:8080
```

All endpoints require this header unless stated otherwise:

```http
Authorization: Bearer <application-jwt>
Content-Type: application/json
```

## 1. Market data quotes

### Request

```http
GET /api/v1/market-data/quotes?instrumentTokens=738561,408065
Authorization: Bearer <application-jwt>
```

| Parameter | Required | Description |
|---|---:|---|
| `instrumentTokens` | Yes | Comma-separated instrument tokens. |

### Example response

```json
[
  {
    "instrumentToken": 738561,
    "exchange": "NSE",
    "tradingsymbol": "RELIANCE",
    "lastPrice": 1425.50,
    "lastTradedQuantity": 10,
    "cumulativeVolume": 125000,
    "timestamp": "2026-08-31T09:15:00+05:30"
  }
]
```

## 2. Locally persisted candles

### Request

```http
GET /api/v1/market-data/candles?instrumentToken=738561&timeframe=5minute&from=2026-08-25T09:15:00%2B05:30&to=2026-08-31T15:30:00%2B05:30
Authorization: Bearer <application-jwt>
```

| Parameter | Required | Description |
|---|---:|---|
| `instrumentToken` | Yes | Kite instrument token. |
| `timeframe` | Yes | For example `1minute`, `5minute`, or `15minute`. |
| `from` | Yes | ISO-8601 date-time. |
| `to` | Yes | ISO-8601 date-time. |

## 3. Kite market-data connection

### Connect

```http
POST /api/v1/kite/market-data/connect
Authorization: Bearer <application-jwt>
Content-Type: application/json
```

```json
{
  "instrumentTokens": [738561, 408065]
}
```

### Disconnect

```http
POST /api/v1/kite/market-data/disconnect
Authorization: Bearer <application-jwt>
```

## 4. Development synthetic tick

This endpoint is enabled in the `dev` profile and should be disabled in exposed environments using `DEV_TICK_ENDPOINT_ENABLED=false`.

### Request

```http
POST /api/v1/market-data/ticks
Authorization: Bearer <application-jwt>
Content-Type: application/json
```

```json
{
  "instrumentToken": 738561,
  "lastPrice": 1425.50,
  "lastTradedQuantity": 10,
  "cumulativeVolume": 125000,
  "timestamp": "2026-08-31T09:15:00+05:30"
}
```

`timestamp`, `lastTradedQuantity`, and `cumulativeVolume` are optional. `instrumentToken` and positive `lastPrice` are required.

## 5. Internal market WebSocket

### Connect

```text
ws://localhost:8080/ws/market?access_token=<application-jwt>
```

The client may also send the JWT in the `Authorization: Bearer <application-jwt>` handshake header.

### Subscribe message

```json
{
  "action": "subscribe",
  "instrumentTokens": [738561, 408065]
}
```

### Acknowledgement

```json
{
  "status": "subscribed"
}
```

Subsequent messages contain the latest quote for subscribed instrument tokens.

## 6. Latest indicators

### Request

```http
GET /api/v1/indicators/latest?instrumentToken=738561&timeframe=5minute
Authorization: Bearer <application-jwt>
```

| Parameter | Required | Description |
|---|---:|---|
| `instrumentToken` | Yes | Instrument token. |
| `timeframe` | Yes | Candle timeframe. |

### Example response

```json
{
  "instrumentToken": 738561,
  "timeframe": "5minute",
  "candleTime": "2026-08-31T09:25:00+05:30",
  "ema9": 1423.18,
  "ema20": 1420.77,
  "vwap": 1421.55,
  "rsi14": 58.21,
  "macd": 2.41,
  "macdSignal": 1.96,
  "atr14": 5.17,
  "superTrend": 1415.02
}
```

## 7. EMA crossover strategy signal

### Request

```http
GET /api/v1/strategies/ema-crossover/signal?instrumentToken=738561&timeframe=5minute
Authorization: Bearer <application-jwt>
```

The endpoint returns `204 No Content` when no crossover is detected.

### Example response

```json
{
  "instrumentToken": 738561,
  "exchange": "NSE",
  "tradingsymbol": "RELIANCE",
  "side": "BUY",
  "price": 1425.50,
  "strategy": "EMA_CROSSOVER",
  "generatedAt": "2026-08-31T09:25:00+05:30"
}
```

## 8. Risk limits

### Get limits

```http
GET /api/v1/risk/limits
Authorization: Bearer <application-jwt>
```

### Update limits

```http
PUT /api/v1/risk/limits
Authorization: Bearer <application-jwt>
Content-Type: application/json
```

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

All fields are required for update requests. Numeric limits must be positive, except `maxDailyLoss`, which may be zero.

## 9. Paper trading orders

### Place paper order

```http
POST /api/v1/paper/orders
Authorization: Bearer <application-jwt>
Content-Type: application/json
```

```json
{
  "instrumentToken": 738561,
  "side": "BUY",
  "orderType": "LIMIT",
  "quantity": 10,
  "price": 1425.50,
  "stopLoss": 1400.00,
  "idempotencyKey": "reliance-paper-entry-001"
}
```

| Field | Required | Description |
|---|---:|---|
| `instrumentToken` | Yes | Instrument token. |
| `side` | Yes | `BUY` or `SELL`. |
| `orderType` | Yes | `MARKET` or `LIMIT`. |
| `quantity` | Yes | Positive quantity. |
| `price` | Market: optional; Limit: required | Market orders use the latest Redis quote when omitted. |
| `stopLoss` | No | Optional stop-loss validation price. |
| `idempotencyKey` | No | Client-generated duplicate-prevention key. |

### List paper orders

```http
GET /api/v1/paper/orders
Authorization: Bearer <application-jwt>
```

### List open paper positions

```http
GET /api/v1/paper/positions
Authorization: Bearer <application-jwt>
```

## 10. Live order engine

Live trading is disabled by default with `TRADING_LIVE_ENABLED=false`.

### Place live order

```http
POST /api/v1/orders
Authorization: Bearer <application-jwt>
Content-Type: application/json
```

```json
{
  "instrumentToken": 738561,
  "side": "BUY",
  "orderType": "MARKET",
  "quantity": 10,
  "stopLoss": 1400.00,
  "idempotencyKey": "reliance-live-entry-001"
}
```

With live trading disabled, the endpoint returns `409 LIVE_TRADING_DISABLED` and does not call Kite.

### Get live order status

```http
GET /api/v1/orders/{id}
Authorization: Bearer <application-jwt>
```

Example:

```text
GET /api/v1/orders/42
```

### Modify live order

```http
PUT /api/v1/orders/{id}
Authorization: Bearer <application-jwt>
Content-Type: application/json
```

```json
{
  "quantity": 5,
  "price": 1424.00,
  "stopLoss": 1398.00
}
```

All modification fields are optional, but at least one should be supplied. The order must be open and owned by the authenticated user.

### Cancel live order

```http
POST /api/v1/orders/{id}/cancel
Authorization: Bearer <application-jwt>
```

## Common error responses

### Missing or invalid JWT

```http
401 Unauthorized
```

### Validation failure

```json
{
  "status": 400,
  "error": "VALIDATION_FAILED",
  "message": "quantity: must be greater than or equal to 1"
}
```

### Risk rejection

```json
{
  "status": 422,
  "error": "RISK_REJECTED",
  "message": "Capital per trade exceeds the configured limit"
}
```

### Live trading disabled

```json
{
  "status": 409,
  "error": "LIVE_TRADING_DISABLED",
  "message": "Live trading is disabled"
}
```
