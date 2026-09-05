import 'package:flutter/material.dart';

/// IKR brand colour palette — orange on black, Material 3 dark.
class AppColors {
  AppColors._();

  // ── Brand ───────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFFFF6B00);
  static const Color secondary = Color(0xFFFF8C00);
  static const Color primaryLight = Color(0xFFFFAB66);
  static const Color primaryDark = Color(0xFFCC5500);

  // ── Surfaces ─────────────────────────────────────────────────────────────
  static const Color surface = Color(0xFF0A0A0A);
  static const Color surfaceVariant = Color(0xFF141414);
  static const Color surfaceVariant2 = Color(0xFF1E1E1E);
  static const Color surfaceVariant3 = Color(0xFF282828);
  static const Color navBar = Color(0xFF0F0F0F);

  // ── On-surface ───────────────────────────────────────────────────────────
  static const Color onSurface = Color(0xFFF5F5F5);
  static const Color onSurfaceMuted = Color(0xFF888888);
  static const Color onSurfaceSubtle = Color(0xFF555555);
  static const Color divider = Color(0xFF222222);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color buy = Color(0xFF22C55E);
  static const Color sell = Color(0xFFEF4444);
  static const Color buyLight = Color(0xFF16A34A);
  static const Color sellLight = Color(0xFFDC2626);
  static const Color error = Color(0xFFCF6679);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ── Indicator colours ────────────────────────────────────────────────────
  static const Color ema9 = Color(0xFF3B82F6);
  static const Color ema20 = Color(0xFFF59E0B);
  static const Color vwap = Color(0xFF8B5CF6);
  static const Color macdLine = Color(0xFF22C55E);
  static const Color macdSignal = Color(0xFFEF4444);
  static const Color superTrend = Color(0xFF06B6D4);

  // ── Chart ────────────────────────────────────────────────────────────────
  static const Color candleUp = Color(0xFF22C55E);
  static const Color candleDown = Color(0xFFEF4444);
  static const Color chartGrid = Color(0xFF1A1A1A);

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A0800), Color(0xFF0A0A0A)],
  );

  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFFF6B00), Color(0xFFFF8C00)],
  );

  static LinearGradient buyGradient = LinearGradient(
    colors: [buy.withAlpha(30), buy.withAlpha(5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient sellGradient = LinearGradient(
    colors: [sell.withAlpha(30), sell.withAlpha(5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
