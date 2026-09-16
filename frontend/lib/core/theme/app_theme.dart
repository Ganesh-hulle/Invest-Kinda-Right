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
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: mutedText,
        indicatorColor: AppColors.primary,
        dividerColor: dividerColor,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.onSurface : const Color(0xFF111827),
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: isDark ? AppColors.onSurfaceMuted : const Color(0xFF4B5563),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: cardBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
      extensions: [
        isDark ? IKRColors.dark : IKRColors.light,
      ],
    );
  }
}

/// Dynamic theme tokens for custom IKR surfaces, text, and dividers across both
/// Dark and Light modes.
@immutable
class IKRColors extends ThemeExtension<IKRColors> {
  final Color surface;
  final Color surfaceVariant;
  final Color surfaceVariant2;
  final Color surfaceVariant3;
  final Color navBar;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color onSurfaceSubtle;
  final Color divider;
  final Color card;

  const IKRColors({
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceVariant2,
    required this.surfaceVariant3,
    required this.navBar,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.onSurfaceSubtle,
    required this.divider,
    required this.card,
  });

  static const dark = IKRColors(
    surface: Color(0xFF0A0A0A),
    surfaceVariant: Color(0xFF141414),
    surfaceVariant2: Color(0xFF1E1E1E),
    surfaceVariant3: Color(0xFF282828),
    navBar: Color(0xFF0F0F0F),
    onSurface: Color(0xFFF5F5F5),
    onSurfaceMuted: Color(0xFF888888),
    onSurfaceSubtle: Color(0xFF555555),
    divider: Color(0xFF222222),
    card: Color(0xFF141414),
  );

  static const light = IKRColors(
    surface: Color(0xFFF9FAFB),
    surfaceVariant: Color(0xFFFFFFFF),
    surfaceVariant2: Color(0xFFF3F4F6),
    surfaceVariant3: Color(0xFFE5E7EB),
    navBar: Color(0xFFFFFFFF),
    onSurface: Color(0xFF111827),
    onSurfaceMuted: Color(0xFF6B7280),
    onSurfaceSubtle: Color(0xFF9CA3AF),
    divider: Color(0xFFE5E7EB),
    card: Color(0xFFFFFFFF),
  );

  @override
  IKRColors copyWith({
    Color? surface,
    Color? surfaceVariant,
    Color? surfaceVariant2,
    Color? surfaceVariant3,
    Color? navBar,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? onSurfaceSubtle,
    Color? divider,
    Color? card,
  }) {
    return IKRColors(
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      surfaceVariant2: surfaceVariant2 ?? this.surfaceVariant2,
      surfaceVariant3: surfaceVariant3 ?? this.surfaceVariant3,
      navBar: navBar ?? this.navBar,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      onSurfaceSubtle: onSurfaceSubtle ?? this.onSurfaceSubtle,
      divider: divider ?? this.divider,
      card: card ?? this.card,
    );
  }

  @override
  IKRColors lerp(ThemeExtension<IKRColors>? other, double t) {
    if (other is! IKRColors) return this;
    return IKRColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      surfaceVariant2: Color.lerp(surfaceVariant2, other.surfaceVariant2, t)!,
      surfaceVariant3: Color.lerp(surfaceVariant3, other.surfaceVariant3, t)!,
      navBar: Color.lerp(navBar, other.navBar, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
      onSurfaceSubtle: Color.lerp(onSurfaceSubtle, other.onSurfaceSubtle, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      card: Color.lerp(card, other.card, t)!,
    );
  }
}

/// Convenience context extensions to access theme tokens easily.
extension IKRThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  IKRColors get colors =>
      Theme.of(this).extension<IKRColors>() ??
      (isDarkMode ? IKRColors.dark : IKRColors.light);
}

