import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invest_kinda_right/shared/widgets/ikr_app_bar.dart';
import 'package:invest_kinda_right/shared/widgets/pnl_chip.dart';

void main() {
  testWidgets('PnlChip renders positive value correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PnlChip(value: 250.50),
        ),
      ),
    );

    expect(find.text('+₹250.50'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
  });

  testWidgets('IkrLogo renders icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IkrLogo(size: 48),
        ),
      ),
    );

    expect(find.byIcon(Icons.show_chart_rounded), findsOneWidget);
  });
}
