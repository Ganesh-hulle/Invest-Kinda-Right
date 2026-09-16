import 'package:flutter_test/flutter_test.dart';
import 'package:invest_kinda_right/features/portfolio/model/portfolio_models.dart';

void main() {
  group('HoldingItem Live Price & Day PnL Logic', () {
    test('Calculates HoldingItem PnL and day change when live quote arrives', () {
      const holding = HoldingItem(
        instrumentToken: 408065,
        tradingsymbol: 'INFY',
        exchange: 'NSE',
        quantity: 10,
        averagePrice: 1400.0,
        lastPrice: 1420.0,
        closePrice: 1400.0,
        pnl: 200.0,
        dayChange: 20.0,
        dayChangePercentage: 1.43,
      );

      // Live tick arrives with new price 1450.0
      const newPrice = 1450.0;
      final newPnl = (newPrice - holding.averagePrice) * holding.quantity;
      final newDayChange = newPrice - holding.closePrice;
      final newDayChangePct = (newDayChange / holding.closePrice) * 100.0;

      final updated = holding.copyWith(
        lastPrice: newPrice,
        pnl: newPnl,
        dayChange: newDayChange,
        dayChangePercentage: newDayChangePct,
      );

      expect(updated.lastPrice, 1450.0);
      expect(updated.pnl, 500.0); // (1450 - 1400) * 10
      expect(updated.dayChange, 50.0);
      expect(updated.dayChangePercentage, closeTo(3.57, 0.01));
    });
  });

  group('PositionItem Live PnL Logic', () {
    test('Calculates PositionItem PnL on live price change', () {
      const position = PositionItem(
        instrumentToken: 738561,
        tradingsymbol: 'RELIANCE',
        exchange: 'NSE',
        quantity: 20,
        averagePrice: 2500.0,
        lastPrice: 2500.0,
        closePrice: 2480.0,
        pnl: 0.0,
        product: 'MIS',
      );

      const newPrice = 2530.0;
      final newPnl = (newPrice - position.averagePrice) * position.quantity;
      final newDayChange = newPrice - position.closePrice;
      final newDayChangePct = (newDayChange / position.closePrice) * 100.0;

      final updated = position.copyWith(
        lastPrice: newPrice,
        pnl: newPnl,
        dayChange: newDayChange,
        dayChangePercentage: newDayChangePct,
      );

      expect(updated.lastPrice, 2530.0);
      expect(updated.pnl, 600.0); // (2530 - 2500) * 20
      expect(updated.dayChange, 50.0);
      expect(updated.dayChangePercentage, closeTo(2.016, 0.01));
    });
  });

  group('Portfolio Day P&L Aggregations', () {
    test('Calculates total holdings day PnL and percentage correctly', () {
      final holdings = [
        const HoldingItem(
          instrumentToken: 1,
          tradingsymbol: 'AAA',
          exchange: 'NSE',
          quantity: 10,
          averagePrice: 100.0,
          lastPrice: 120.0,
          closePrice: 110.0,
          pnl: 200.0,
          dayChange: 10.0, // 10 * 10 = +100
          dayChangePercentage: 9.09,
        ),
        const HoldingItem(
          instrumentToken: 2,
          tradingsymbol: 'BBB',
          exchange: 'NSE',
          quantity: 5,
          averagePrice: 200.0,
          lastPrice: 190.0,
          closePrice: 200.0,
          pnl: -50.0,
          dayChange: -10.0, // -10 * 5 = -50
          dayChangePercentage: -5.0,
        ),
      ];

      final totalDayPnl = holdings.fold(
        0.0,
        (sum, h) => sum + (h.dayChange * h.quantity),
      );
      final prevCloseVal = holdings.fold(
        0.0,
        (sum, h) => sum + (h.closePrice * h.quantity),
      );
      final totalDayPnlPct = (totalDayPnl / prevCloseVal) * 100.0;

      expect(totalDayPnl, 50.0); // +100 - 50 = +50
      expect(prevCloseVal, 2100.0); // (110*10) + (200*5) = 1100 + 1000 = 2100
      expect(totalDayPnlPct, closeTo(2.38, 0.01));
    });

    test('Parses day change and closePrice from JSON correctly', () {
      final json = {
        'instrument_token': 738561,
        'tradingsymbol': 'RELIANCE',
        'exchange': 'NSE',
        'quantity': 15,
        'average_price': 2400.0,
        'last_price': 2450.0,
        'close_price': 2420.0,
        'day_change': 30.0,
        'day_change_percentage': 1.24,
        'pnl': 750.0,
      };

      final item = HoldingItem.fromJson(json);
      expect(item.instrumentToken, 738561);
      expect(item.closePrice, 2420.0);
      expect(item.dayChange, 30.0);
      expect(item.dayChangePercentage, 1.24);
      expect(item.pnl, 750.0);
    });
  });
}
