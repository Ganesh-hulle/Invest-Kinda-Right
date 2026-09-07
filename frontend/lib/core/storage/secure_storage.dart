import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper around [FlutterSecureStorage] with typed accessors.
class SecureStorage {
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'ikr_jwt_token';
  static const _baseUrlKey = 'ikr_base_url';
  static const _watchlistKey = 'ikr_watchlist_tokens';
  static const _watchlistItemsKey = 'ikr_watchlist_items_json';
  static const _biometricEnabledKey = 'ikr_biometric_enabled';
  static const _biometricUserKey = 'ikr_biometric_user';
  static const _biometricPassKey = 'ikr_biometric_pass';
  static const _themeModeKey = 'ikr_theme_mode';

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

  // ── Watchlist ─────────────────────────────────────────────────────────────

  Future<void> saveWatchlistJson(String jsonString) =>
      _storage.write(key: _watchlistItemsKey, value: jsonString);

  Future<String?> readWatchlistJson() =>
      _storage.read(key: _watchlistItemsKey);

  Future<void> saveWatchlistTokens(List<int> tokens) =>
      _storage.write(key: _watchlistKey, value: tokens.join(','));

  Future<List<int>> readWatchlistTokens() async {
    final raw = await _storage.read(key: _watchlistKey);
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').where((s) => s.isNotEmpty).map(int.parse).toList();
  }

  // ── Biometrics & Saved Credentials ────────────────────────────────────────

  Future<void> saveBiometricEnabled(bool enabled) =>
      _storage.write(key: _biometricEnabledKey, value: enabled.toString());

  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _biometricEnabledKey);
    return val == 'true';
  }

  Future<void> saveBiometricCredentials({
    required String username,
    required String password,
  }) async {
    await _storage.write(key: _biometricUserKey, value: username);
    await _storage.write(key: _biometricPassKey, value: password);
    await saveBiometricEnabled(true);
  }

  Future<({String username, String password})?> readBiometricCredentials() async {
    final user = await _storage.read(key: _biometricUserKey);
    final pass = await _storage.read(key: _biometricPassKey);
    if (user != null && pass != null && user.isNotEmpty && pass.isNotEmpty) {
      return (username: user, password: pass);
    }
    return null;
  }

  Future<void> clearBiometricCredentials() async {
    await _storage.delete(key: _biometricUserKey);
    await _storage.delete(key: _biometricPassKey);
    await saveBiometricEnabled(false);
  }

  // ── Theme Mode ────────────────────────────────────────────────────────────

  Future<void> saveThemeMode(String mode) =>
      _storage.write(key: _themeModeKey, value: mode);

  Future<String?> readThemeMode() => _storage.read(key: _themeModeKey);

  // ── Clear all ────────────────────────────────────────────────────────────

  Future<void> clearAll() => _storage.deleteAll();
}
