import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invest_kinda_right/core/theme/app_theme.dart';

void main() {
  group('Theme System & IKRColors Extension Tests', () {
    test('IKRColors.light provides high-contrast light palette', () {
      const colors = IKRColors.light;

      expect(colors.surface, const Color(0xFFF9FAFB));
      expect(colors.surfaceVariant, const Color(0xFFFFFFFF));
      expect(colors.onSurface, const Color(0xFF111827));
      expect(colors.onSurfaceMuted, const Color(0xFF6B7280));
      expect(colors.divider, const Color(0xFFE5E7EB));

      // Assert high contrast between surface and onSurface
      expect(colors.surface.computeLuminance(), greaterThan(0.5));
      expect(colors.onSurface.computeLuminance(), lessThan(0.5));
    });

    test('IKRColors.dark provides high-contrast dark palette', () {
      const colors = IKRColors.dark;

      expect(colors.surface, const Color(0xFF0A0A0A));
      expect(colors.surfaceVariant, const Color(0xFF141414));
      expect(colors.onSurface, const Color(0xFFF5F5F5));
      expect(colors.onSurfaceMuted, const Color(0xFF888888));
      expect(colors.divider, const Color(0xFF222222));

      // Assert high contrast between surface and onSurface
      expect(colors.surface.computeLuminance(), lessThan(0.2));
      expect(colors.onSurface.computeLuminance(), greaterThan(0.5));
    });

    testWidgets('Context extension retrieves correct colors in Light mode', (tester) async {
      late IKRColors capturedColors;
      late bool capturedIsDark;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.light,
            extensions: const [IKRColors.light],
          ),
          home: Builder(
            builder: (context) {
              capturedColors = context.colors;
              capturedIsDark = context.isDarkMode;
              return Scaffold(
                backgroundColor: context.colors.surface,
                body: Text(
                  'Light Mode Content',
                  style: TextStyle(color: context.colors.onSurface),
                ),
              );
            },
          ),
        ),
      );

      expect(capturedIsDark, isFalse);
      expect(capturedColors.surface, const Color(0xFFF9FAFB));
      expect(capturedColors.onSurface, const Color(0xFF111827));
      expect(capturedColors.divider, const Color(0xFFE5E7EB));
      expect(find.text('Light Mode Content'), findsOneWidget);
    });

    testWidgets('Context extension retrieves correct colors in Dark mode', (tester) async {
      late IKRColors capturedColors;
      late bool capturedIsDark;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            extensions: const [IKRColors.dark],
          ),
          home: Builder(
            builder: (context) {
              capturedColors = context.colors;
              capturedIsDark = context.isDarkMode;
              return Scaffold(
                backgroundColor: context.colors.surface,
                body: Text(
                  'Dark Mode Content',
                  style: TextStyle(color: context.colors.onSurface),
                ),
              );
            },
          ),
        ),
      );

      expect(capturedIsDark, isTrue);
      expect(capturedColors.surface, const Color(0xFF0A0A0A));
      expect(capturedColors.onSurface, const Color(0xFFF5F5F5));
      expect(capturedColors.divider, const Color(0xFF222222));
      expect(find.text('Dark Mode Content'), findsOneWidget);
    });
  });
}
