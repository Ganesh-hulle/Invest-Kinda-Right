import 'package:flutter/material.dart';
import '../storage/secure_storage.dart';

/// Provider for managing app ThemeMode (Dark, Light, System) and persisting choice.
class ThemeProvider extends ChangeNotifier {
  final SecureStorage secureStorage;

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeProvider({required this.secureStorage});

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Load persisted theme preference from SecureStorage.
  Future<void> init() async {
    final savedMode = await secureStorage.readThemeMode();
    if (savedMode != null) {
      switch (savedMode) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        case 'system':
          _themeMode = ThemeMode.system;
          break;
        default:
          _themeMode = ThemeMode.dark;
      }
      notifyListeners();
    }
  }

  /// Change theme mode and persist to SecureStorage.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    String modeStr = 'dark';
    if (mode == ThemeMode.light) {
      modeStr = 'light';
    } else if (mode == ThemeMode.system) {
      modeStr = 'system';
    }
    await secureStorage.saveThemeMode(modeStr);
  }
}
