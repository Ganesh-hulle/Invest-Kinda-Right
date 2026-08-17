# Kite Connect integration

The backend owns the Kite secret and token exchange. The Flutter app must only open the login URL returned by the backend; it must never contain `KITE_API_SECRET` or an access token.

## Configuration

Set these environment variables for the active Spring profile:

```text
KITE_API_KEY=<Kite app api key>
KITE_API_SECRET=<Kite app api secret>
KITE_REDIRECT_URL=http://localhost:8080/api/v1/kite/callback
KITE_TOKEN_ENCRYPTION_KEY=<base64 encoding of exactly 32 random bytes>
```

The redirect URL must exactly match the URL configured in the Kite developer console. Generate a key, for example, with a secret manager or a local secure utility; do not commit it to this repository.

## Flow

1. Call `GET /api/v1/kite/login-url` with the application JWT.
2. Open the returned `loginUrl` in a browser/web view.
3. Kite redirects to `/api/v1/kite/callback` with a one-time `request_token` and state.
4. The backend computes `SHA-256(api_key + request_token + api_secret)` and POSTs the form fields to `https://api.kite.trade/session/token` with `X-Kite-Version: 3`.
5. The backend calls `GET /user/profile` using `Authorization: token api_key:access_token`, encrypts the access token with AES-GCM, and stores it in `kite_connections`.
6. The callback returns the non-secret Kite profile. Later, `GET /api/v1/kite/profile` reuses the encrypted connection to validate the current trading-day session.

Kite access tokens normally expire at 6 AM the next day or when the session is invalidated, so the user should repeat the login flow after expiry. The API secret and access token are never sent in responses or logs.

For a real connection test, configure the variables, run PostgreSQL and the backend, authenticate to the application, and call the endpoints above. Kite requires an active Zerodha account with 2FA/TOTP and a registered redirect URL.
