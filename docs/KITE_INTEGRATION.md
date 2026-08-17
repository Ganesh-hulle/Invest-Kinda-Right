# Kite Connect Integration — System Design and Operations Guide

## 1. Purpose

This document describes the current Zerodha Kite Connect integration in Invest Kinda Right.

The integration currently supports:

- Kite Connect configuration.
- Application-user-to-Kite-account linking.
- Kite OAuth-style login and callback handling.
- One-time OAuth state validation.
- Kite request-token exchange for an access token.
- AES-GCM encryption of the access token before database storage.
- Kite user profile retrieval.
- Kite holdings retrieval.
- Kite net and day position retrieval.

The integration is read-only from the portfolio perspective. It does not place, modify, cancel, or exit orders.

The backend owns the Kite API secret and access token. The frontend must never contain either secret.

---

## 2. High-level architecture

```text
Flutter / API client
        |
        | Application JWT
        v
KiteController
        |
        v
KiteService
        |
        +--> UserRepository
        +--> KiteOAuthStateRepository
        +--> KiteConnectionRepository
        +--> SecretTokenCipher
        +--> KiteClient
                    |
                    | HTTPS, X-Kite-Version: 3
                    v
             api.kite.trade
```

### Components

| Component | Responsibility |
|---|---|
| `KiteProperties` | Binds `kite.*` configuration properties. |
| `KiteConfig` | Registers Kite configuration, `RestClient.Builder`, and Jackson `ObjectMapper` beans. |
| `KiteController` | Exposes authenticated application endpoints and the public Kite callback endpoint. |
| `KiteService` | Owns OAuth state, token exchange orchestration, connection persistence, profile, and portfolio use cases. |
| `KiteClient` | Makes HTTPS requests to Kite Connect and applies Kite authentication headers. |
| `SecretTokenCipher` | Encrypts and decrypts Kite access tokens using AES-GCM. |
| `KiteOAuthState` | Binds a Kite callback to the application user who started the login flow. |
| `KiteConnection` | Stores the encrypted Kite session and the latest profile metadata. |
| `KiteProfileResponse` | Non-secret profile response DTO. |
| `KitePortfolioResponse` | Holdings and positions response DTO. |

---

## 3. Kite authentication model

Kite Connect does not use the Invest Kinda Right JWT to authenticate with Zerodha. There are two independent authentication layers:

### Application authentication

The client calls protected Invest Kinda Right endpoints with:

```http
Authorization: Bearer <application-jwt>
```

The existing `JwtAuthenticationFilter` validates that JWT and identifies the local application user.

### Kite authentication

The backend calls Kite with:

```http
X-Kite-Version: 3
Authorization: token <kite-api-key>:<kite-access-token>
```

The Kite access token is obtained only after a successful Kite login and request-token exchange.

Kite access tokens are generally valid for the trading day and expire at the next daily session boundary or when invalidated. A new Kite login is required after expiry.

---

## 4. Complete OAuth flow

### Step 1: Start the login flow

The client calls:

```http
GET /api/v1/kite/login-url
Authorization: Bearer <application-jwt>
```

`KiteController` extracts the local user ID from `CustomUserDetails` and passes it to `KiteService`.

`KiteService.createLoginUrl()` then:

1. Loads the local user.
2. Verifies the Kite API key and redirect URL are configured.
3. Generates a cryptographically random state value.
4. Stores that state with the local user and a ten-minute expiry.
5. Builds the Kite login URL.

Example response:

```json
{
  "loginUrl": "https://kite.zerodha.com/connect/login?..."
}
```

The state is passed through Kite's `redirect_params` parameter. The frontend should open the returned URL in a browser or supported web view.

### Step 2: User logs in at Kite

The user completes the Zerodha login and 2FA/TOTP flow at Kite.

Kite redirects the browser to the registered redirect URL:

```text
/api/v1/kite/callback?request_token=<one-time-token>&state=<state>&status=success
```

The request token is short-lived and single-use. It must not be stored by the frontend or retried manually.

### Step 3: Validate callback state

The callback endpoint is intentionally public because Kite redirects the browser without the Invest Kinda Right JWT:

```http
GET /api/v1/kite/callback
```

The callback is still protected by the stored state value. The service:

1. Requires `status=success`.
2. Looks up the state in `kite_oauth_states`.
3. Rejects unknown states.
4. Rejects expired states.
5. Rejects already-consumed states.
6. Marks the state as consumed before continuing.

This prevents a client from supplying an arbitrary local user ID in the callback.

### Step 4: Exchange request token

The backend computes:

```text
SHA-256(api_key + request_token + api_secret)
```

It then sends a form-encoded request to:

```http
POST https://api.kite.trade/session/token
X-Kite-Version: 3
Content-Type: application/x-www-form-urlencoded
```

Form fields:

```text
api_key=<api-key>
request_token=<request-token>
checksum=<sha256-checksum>
```

Kite returns session metadata including:

- Kite user ID.
- Access token.
- User name and email.
- Enabled exchanges.
- Enabled products.
- Enabled order types.

The access token is never returned by the Invest Kinda Right API.

### Step 5: Fetch profile

After the token exchange, the backend calls:

```http
GET https://api.kite.trade/user/profile
X-Kite-Version: 3
Authorization: token <api-key>:<access-token>
```

The profile is converted to `KiteProfileResponse`. Unknown fields from Kite are ignored so additive Kite API changes do not break profile parsing.

### Step 6: Encrypt and persist the token

The access token is encrypted with AES-GCM before persistence.

The database stores:

- Ciphertext.
- Random initialization vector.
- Kite user ID.
- API key.
- Non-secret profile JSON.

The plaintext access token is held only in memory for the duration of the request and is not logged.

### Step 7: Return profile

The callback returns the non-secret Kite profile to the browser/client.

Example shape:

```json
{
  "userId": "AB1234",
  "userName": "Example User",
  "userShortname": "Example",
  "email": "user@example.com",
  "userType": "individual",
  "broker": "ZERODHA",
  "exchanges": ["NSE", "BSE"],
  "products": ["CNC", "MIS"],
  "orderTypes": ["MARKET", "LIMIT"],
  "avatarUrl": "...",
  "loginTime": "2026-08-17 22:30:00"
}
```

---

## 5. Current API endpoints

### 5.1 Generate Kite login URL

```http
GET /api/v1/kite/login-url
Authorization: Bearer <application-jwt>
```

Authentication: required.

Response:

```json
{
  "loginUrl": "https://kite.zerodha.com/connect/login?..."
}
```

### 5.2 Kite callback

```http
GET /api/v1/kite/callback?request_token=<token>&state=<state>&status=success
```

Authentication: public callback; state validation is required.

Response: `KiteProfileResponse`.

Do not invoke this endpoint manually with an old request token. Start a new login flow instead.

### 5.3 Fetch connected profile

```http
GET /api/v1/kite/profile
Authorization: Bearer <application-jwt>
```

Authentication: required.

The service loads the local user's encrypted Kite connection, decrypts the token in memory, calls Kite `/user/profile`, and returns the current profile.

### 5.4 Fetch portfolio

```http
GET /api/v1/kite/portfolio
Authorization: Bearer <application-jwt>
```

Authentication: required.

The service calls both Kite portfolio endpoints:

```http
GET /portfolio/holdings
GET /portfolio/positions
```

Response:

```json
{
  "holdings": [
    {
      "tradingsymbol": "INFY",
      "exchange": "NSE",
      "quantity": 10,
      "average_price": 1500.0,
      "last_price": 1520.5,
      "pnl": 205.0
    }
  ],
  "netPositions": [],
  "dayPositions": []
}
```

The exact fields inside each holding or position are represented as flexible maps because Kite may add fields. The current response separates:

- `holdings`: long-term equity delivery holdings.
- `netPositions`: current net positions.
- `dayPositions`: the current day's position activity.

Kite describes positions as short-to-medium-term or intraday instruments and exposes both `net` and `day` views.

---

## 6. Source code layout

```text
backend/src/main/java/com/ganesh/IKR/
├── config/
│   ├── KiteConfig.java
│   └── KiteProperties.java
├── controller/
│   └── KiteController.java
├── dto/kite/
│   ├── KiteLoginUrlResponse.java
│   ├── KitePortfolioResponse.java
│   └── KiteProfileResponse.java
├── entity/
│   ├── KiteConnection.java
│   └── KiteOAuthState.java
├── exception/
│   ├── KiteApiException.java
│   └── KiteConfigurationException.java
├── repository/
│   ├── KiteConnectionRepository.java
│   └── KiteOAuthStateRepository.java
└── service/
    ├── KiteClient.java
    ├── KiteService.java
    └── SecretTokenCipher.java
```

---

## 7. Database schema

Migration:

```text
backend/src/main/resources/db/migration/V2__create_kite_integration_tables.sql
```

### `kite_oauth_states`

| Column | Purpose |
|---|---|
| `id` | Internal primary key. |
| `state` | Unique random OAuth state value. |
| `user_id` | Local application user who started the flow. |
| `expires_at` | State expiration time. |
| `consumed_at` | Timestamp proving the state has been used. |
| `created_at` | State creation time. |

The state has a unique constraint and a foreign key to `users` with cascade deletion.

### `kite_connections`

| Column | Purpose |
|---|---|
| `id` | Internal primary key. |
| `user_id` | Local application user. One connection per user. |
| `kite_user_id` | Zerodha/Kite user ID. |
| `api_key` | Public Kite API key used for this connection. |
| `encrypted_access_token` | AES-GCM ciphertext. |
| `access_token_iv` | AES-GCM initialization vector. |
| `profile_json` | Latest non-secret profile snapshot. |
| `connected_at` | Initial database creation timestamp. |
| `updated_at` | Database update timestamp. |

The `user_id` column has a unique constraint, so reconnecting a Kite account updates the existing local connection.

---

## 8. Configuration

### Environment variables

```env
KITE_API_KEY=<public Kite API key>
KITE_API_SECRET=<private Kite API secret>
KITE_REDIRECT_URL=http://localhost:8080/api/v1/kite/callback
KITE_API_BASE_URL=https://api.kite.trade
KITE_TOKEN_ENCRYPTION_KEY=<base64 encoding of exactly 32 random bytes>
```

`KITE_API_BASE_URL` is optional and defaults to the production Kite API URL.

### Local `.env` files

The application imports dotenv-style property files from:

```text
./.env
../.env
```

This supports launching from either the project root or the `backend` directory.

`.env` files are ignored by Git. Only `.env.example` should be committed.

Do not put actual API credentials in:

- `application-dev.yaml`.
- `application-prod.yaml`.
- `.env.example`.
- `launch.json`.
- Source code.
- Logs.

### Redirect URL requirements

The redirect URL must exactly match the URL configured in the Kite developer console, including:

- Scheme (`http` or `https`).
- Host.
- Port.
- Path.
- Trailing slash behavior.

For local development:

```text
http://localhost:8080/api/v1/kite/callback
```

For production, use the public HTTPS backend URL.

### Encryption key requirements

`KITE_TOKEN_ENCRYPTION_KEY` must be a Base64-encoded 32-byte key.

The current cipher uses:

```text
AES/GCM/NoPadding
```

with a random 12-byte IV for every encryption operation and a 128-bit authentication tag.

The encryption key must be backed up securely. If it is lost, existing encrypted Kite access tokens cannot be decrypted and users must reconnect. If it is changed without a migration strategy, existing connections become unusable.

Use a separate key from the JWT signing key.

---

## 9. Security controls

### Implemented controls

- Kite API secret is read from environment configuration.
- Kite access tokens are encrypted before database storage.
- Access tokens are not returned in API responses.
- Access tokens are not intentionally logged.
- OAuth state is random, user-bound, time-limited, and one-time use.
- Kite callback does not accept a user ID from the client.
- Kite calls use HTTPS.
- The frontend never needs the Kite API secret.
- Portfolio endpoints require the local application's JWT.

### Security responsibilities still required

- Rotate any credential that was previously committed, pasted into logs, or shared in a chat.
- Use a secret manager for production, such as AWS Secrets Manager.
- Restrict access to the database because encrypted tokens are still sensitive data.
- Use HTTPS for the production callback.
- Do not log full exception bodies if a future Kite response contains sensitive data.
- Add rate limiting to login URL generation and callback handling before production exposure.
- Add cleanup for expired OAuth states.

---

## 10. Error handling

Kite failures are translated into `KiteApiException` and handled by `GlobalExceptionHandler`.

Typical errors include:

### Missing configuration

```text
KITE_API_KEY and KITE_REDIRECT_URL must be configured
```

Check the active process environment and the working directory used to load `.env`.

### Invalid or expired request token

```text
Token is invalid or has expired.
```

Start a new login flow. Do not refresh or replay the callback URL.

### Invalid Kite session

The Kite access token may have expired at the end of the trading session. Reconnect the Kite account.

### Invalid redirect URL

Check that the redirect URL in the local environment exactly matches the developer-console configuration.

### Profile parsing errors

The profile DTO ignores unknown response fields. If required fields such as `user_id` are absent, the response is rejected as invalid.

### Portfolio connection errors

`/api/v1/kite/portfolio` returns an integration error if:

- No Kite connection exists for the local user.
- The encrypted token cannot be decrypted.
- Kite rejects the access token.
- Kite returns a non-success HTTP response.
- Kite returns malformed JSON.

---

## 11. Testing and verification

### Compile verification

From the backend directory:

```powershell
mvn test -DskipTests
```

### Application verification

1. Start PostgreSQL.
2. Start the backend with valid environment variables.
3. Register or log in to the application.
4. Call `GET /api/v1/kite/login-url` with the application JWT.
5. Complete Kite login and 2FA.
6. Confirm the callback returns a profile without an access token.
7. Call `GET /api/v1/kite/profile`.
8. Call `GET /api/v1/kite/portfolio`.
9. Confirm holdings, net positions, and day positions are returned.
10. Confirm the database contains encrypted token material rather than plaintext access tokens.

### Example PowerShell request

```powershell
$headers = @{ Authorization = "Bearer <application-jwt>" }
Invoke-RestMethod `
  -Uri "http://localhost:8080/api/v1/kite/portfolio" `
  -Headers $headers `
  -Method Get
```

Never paste a real JWT, access token, API secret, or request token into a committed documentation file.

### Current test limitation

A live portfolio test requires:

- A valid Kite developer application.
- A valid Zerodha account.
- 2FA/TOTP enabled.
- A registered redirect URL.
- An active trading-day Kite session.

The project does not currently include a Kite mock server or integration-test fixture. Unit tests should be added around `KiteClient` using mocked HTTP responses before production deployment.

---

## 12. Current limitations

- No automatic token refresh is implemented.
- No Kite logout endpoint is exposed.
- No scheduled cleanup of expired OAuth states exists.
- No token revocation workflow exists when a user disconnects Kite.
- No local portfolio snapshot tables exist; portfolio data is fetched live from Kite.
- No pagination or caching is implemented for portfolio reads.
- No order placement or trading workflow is implemented.
- Error responses currently use a general integration failure category.
- The public callback currently returns JSON directly instead of redirecting to a frontend success/failure page.

These limitations are intentional for the current authentication and read-only portfolio phase.

---

## 13. Recommended next steps

1. Add a `DELETE /api/v1/kite/connection` endpoint that invalidates the Kite session and removes local encrypted credentials.
2. Add a scheduled cleanup job for consumed and expired OAuth states.
3. Add mocked `KiteClient` tests for successful responses and Kite 4xx/5xx responses.
4. Add a frontend callback handoff page suitable for Flutter web views.
5. Add portfolio caching only if repeated dashboard reads require it.
6. Add explicit token-expired error mapping so the frontend can prompt for reconnect.
7. Add an audit event when a local user connects or disconnects a Kite account.
8. Add AWS Secrets Manager integration before production deployment.
9. Add order APIs only after paper-trading and risk-engine phases are complete.

---

## 14. Official Kite API references

- [Kite authentication and user profile](https://www.kite.trade/docs/connect/v3/user/)
- [Kite portfolio APIs](https://kite.trade/docs/connect/v3/portfolio/)
- [Kite response structure](https://kite.trade/docs/connect/v3/response-structure/)
- [Kite API changelog](https://kite.trade/docs/connect/v3/changelog/)

