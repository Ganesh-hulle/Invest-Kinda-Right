import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invest_kinda_right/features/watchlist/model/watchlist_models.dart';
import 'package:invest_kinda_right/features/watchlist/widgets/live_ticker_price.dart';

void main() {
  group('WatchlistItem Live Price & Day Change Logic', () {
    test('Calculates day change and change percent correctly from closePrice', () {
      // Stock closed yesterday at 100.00
      const item = WatchlistItem(
        instrumentToken: 738561,
        tradingsymbol: 'RELIANCE',
        exchange: 'NSE',
        lastPrice: 100.0,
        closePrice: 100.0,
        change: 0.0,
        changePercent: 0.0,
      );

      // Suppose a live tick arrives at 105.00
      final newPrice = 105.0;
      final change = newPrice - item.closePrice;
      final changePercent = (change / item.closePrice) * 100.0;
      final direction = newPrice > item.lastPrice ? PriceDirection.up : PriceDirection.down;

      final updated = item.copyWith(
        lastPrice: newPrice,
        change: change,
        changePercent: changePercent,
        priceDirection: direction,
      );

      expect(updated.lastPrice, 105.0);
      expect(updated.change, 5.0);
      expect(updated.changePercent, 5.0);
      expect(updated.priceDirection, PriceDirection.up);
    });

    test('Detects PriceDirection.down on downward tick', () {
      const item = WatchlistItem(
        instrumentToken: 738561,
        tradingsymbol: 'RELIANCE',
        exchange: 'NSE',
        lastPrice: 100.0,
        closePrice: 100.0,
      );

      final newPrice = 98.50;
      final change = newPrice - item.closePrice;
      final changePercent = (change / item.closePrice) * 100.0;
      final direction = newPrice < item.lastPrice ? PriceDirection.down : PriceDirection.up;

      final updated = item.copyWith(
        lastPrice: newPrice,
        change: change,
        changePercent: changePercent,
        priceDirection: direction,
      );

      expect(updated.lastPrice, 98.50);
      expect(updated.change, -1.50);
      expect(updated.changePercent, closeTo(-1.5, 0.001));
      expect(updated.priceDirection, PriceDirection.down);
    });

    test('JSON serialization preserves closePrice and restores correctly', () {
      const original = WatchlistItem(
        instrumentToken: 256265,
        tradingsymbol: 'NIFTY 50',
        exchange: 'NSE',
        lastPrice: 24500.50,
        closePrice: 24400.00,
        change: 100.50,
        changePercent: 0.41,
      );

      final json = original.toJson();
      final restored = WatchlistItem.fromJson(json);

      expect(restored.instrumentToken, 256265);
      expect(restored.tradingsymbol, 'NIFTY 50');
      expect(restored.lastPrice, 24500.50);
      expect(restored.closePrice, 24400.00);
      expect(restored.change, 100.50);
    });
  });

  group('LiveTickerPrice Widget', () {
    testWidgets('Renders formatted currency price correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiveTickerPrice(price: 1450.75),
          ),
        ),
      );

      expect(find.text('₹1,450.75'), findsOneWidget);
    });

    testWidgets('Renders placeholder when price is zero or negative', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiveTickerPrice(price: 0.0),
          ),
        ),
      );

      expect(find.text('₹ --'), findsOneWidget);
    });
  });
}
