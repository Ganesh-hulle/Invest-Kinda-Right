import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

/// Defines Dark and Light Material 3 themes for Invest Kinda Right.
class AppTheme {
  AppTheme._();

  // ── Dark Theme ─────────────────────────────────────────────────────────────
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  // ── Light Theme ────────────────────────────────────────────────────────────
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final base = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: isDark ? AppColors.surface : const Color(0xFFFFFFFF),
      onSurface: isDark ? AppColors.onSurface : const Color(0xFF111827),
      error: AppColors.error,
    ).copyWith(
      surfaceContainer:
          isDark ? AppColors.surfaceVariant : const Color(0xFFF4F5F7),
      surfaceContainerHigh:
          isDark ? AppColors.surfaceVariant2 : const Color(0xFFE9EBF0),
      surfaceContainerHighest:
          isDark ? AppColors.surfaceVariant3 : const Color(0xFFDFE2E8),
    );

    final textTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(
      bodyColor: isDark ? AppColors.onSurface : const Color(0xFF111827),
      displayColor: isDark ? AppColors.onSurface : const Color(0xFF111827),
    );

    final scaffoldBg =
        isDark ? AppColors.surface : const Color(0xFFF9FAFB);
    final cardBg =
        isDark ? AppColors.surfaceVariant : const Color(0xFFFFFFFF);
    final dividerColor =
        isDark ? AppColors.divider : const Color(0xFFE5E7EB);
    final mutedText =
        isDark ? AppColors.onSurfaceMuted : const Color(0xFF6B7280);

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      brightness: brightness,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: isDark ? AppColors.onSurface : const Color(0xFF111827),
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.onSurface : const Color(0xFF111827),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.navBar : const Color(0xFFFFFFFF),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: mutedText,
        type: BottomNavigationBarType.fixed,
        elevation: isDark ? 0 : 4,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: isDark ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isDark ? BorderSide.none : BorderSide(color: dividerColor),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceVariant : const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: dividerColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: mutedText),
        hintStyle: TextStyle(color: mutedText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor:
            isDark ? AppColors.surfaceVariant2 : const Color(0xFFF3F4F6),
        selectedColor: AppColors.primary.withAlpha(40),
        labelStyle: GoogleFonts.inter(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? AppColors.surfaceVariant2 : const Color(0xFF1F2937),
        contentTextStyle: GoogleFonts.inter(
            color: isDark ? AppColors.onSurface : Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return mutedText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withAlpha(80);
          }
          return isDark ? AppColors.surfaceVariant2 : const Color(0xFFE5E7EB);
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        thumbColor: AppColors.primary,
        inactiveTrackColor:
            isDark ? AppColors.surfaceVariant2 : const Color(0xFFE5E7EB),
        overlayColor: AppColors.primary.withAlpha(30),
      ),
    );
  }
}
