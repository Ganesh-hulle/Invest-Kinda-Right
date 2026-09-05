import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper around [FlutterSecureStorage] with typed accessors.
class SecureStorage {
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'ikr_jwt_token';
  static const _baseUrlKey = 'ikr_base_url';
  static const _watchlistKey = 'ikr_watchlist_tokens';

  const SecureStorage(this._storage);

  // ── JWT ──────────────────────────────────────────────────────────────────

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  // ── Base URL ─────────────────────────────────────────────────────────────

  Future<void> saveBaseUrl(String url) =>
      _storage.write(key: _baseUrlKey, value: url);

  Future<String?> readBaseUrl() => _storage.read(key: _baseUrlKey);

  // ── Watchlist (comma-separated instrument tokens) ─────────────────────────

  Future<void> saveWatchlistTokens(List<int> tokens) =>
      _storage.write(key: _watchlistKey, value: tokens.join(','));

  Future<List<int>> readWatchlistTokens() async {
    final raw = await _storage.read(key: _watchlistKey);
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').where((s) => s.isNotEmpty).map(int.parse).toList();
  }

  // ── Clear all ────────────────────────────────────────────────────────────

  Future<void> clearAll() => _storage.deleteAll();
}
