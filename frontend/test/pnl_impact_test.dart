import 'package:flutter_test/flutter_test.dart';
import 'package:invest_kinda_right/features/portfolio/model/portfolio_models.dart';

void main() {
  group('InstrumentImpact Domain Model', () {
    test('Calculates positive and zero states accurately', () {
      const gainer = InstrumentImpact(
        tradingsymbol: 'TCS',
        exchange: 'NSE',
        product: 'CNC',
        quantity: 10,
        averagePrice: 3500.0,
        lastPrice: 3600.0,
        dayPnl: 1000.0,
        dayChangePercentage: 2.85,
        contributionPercentage: 66.67,
        relativeRatio: 1.0,
      );

      expect(gainer.isPositive, isTrue);
      expect(gainer.isZero, isFalse);
      expect(gainer.absoluteImpact, 1000.0);

      const loser = InstrumentImpact(
        tradingsymbol: 'INFY',
        exchange: 'NSE',
        product: 'CNC',
        quantity: 20,
        averagePrice: 1500.0,
        lastPrice: 1475.0,
        dayPnl: -500.0,
        dayChangePercentage: -1.67,
        contributionPercentage: 100.0,
        relativeRatio: 0.5,
      );

      expect(loser.isPositive, isFalse);
      expect(loser.isZero, isFalse);
      expect(loser.absoluteImpact, 500.0);

      const neutral = InstrumentImpact(
        tradingsymbol: 'WIPRO',
        exchange: 'NSE',
        product: 'CNC',
        quantity: 5,
        averagePrice: 400.0,
        lastPrice: 400.0,
        dayPnl: 0.0,
        dayChangePercentage: 0.0,
      );

      expect(neutral.isZero, isTrue);
      expect(neutral.absoluteImpact, 0.0);
    });
  });

  group('PortfolioDayImpactSummary Attribution Calculations', () {
    test('Calculates gainRatio and lossRatio accurately in mixed portfolios', () {
      final items = [
        const InstrumentImpact(
          tradingsymbol: 'RELIANCE',
          exchange: 'NSE',
          product: 'CNC',
          quantity: 10,
          averagePrice: 2400,
          lastPrice: 2500,
          dayPnl: 1000.0,
          dayChangePercentage: 4.16,
          contributionPercentage: 66.67,
          relativeRatio: 1.0,
        ),
        const InstrumentImpact(
          tradingsymbol: 'HDFCBANK',
          exchange: 'NSE',
          product: 'CNC',
          quantity: 5,
          averagePrice: 1600,
          lastPrice: 1700,
          dayPnl: 500.0,
          dayChangePercentage: 6.25,
          contributionPercentage: 33.33,
          relativeRatio: 0.5,
        ),
        const InstrumentImpact(
          tradingsymbol: 'SBIN',
          exchange: 'NSE',
          product: 'CNC',
          quantity: 20,
          averagePrice: 800,
          lastPrice: 775,
          dayPnl: -500.0,
          dayChangePercentage: -3.12,
          contributionPercentage: 100.0,
          relativeRatio: 0.5,
        ),
      ];

      final summary = PortfolioDayImpactSummary(
        netDayPnl: 1000.0, // +1500 - 500 = +1000
        totalGrossGains: 1500.0,
        totalGrossLosses: 500.0,
        items: items,
        topGainer: items[0],
        topDragger: items[2],
      );

      expect(summary.netDayPnl, 1000.0);
      expect(summary.totalGrossGains, 1500.0);
      expect(summary.totalGrossLosses, 500.0);
      // Total movement = 2000. Gains = 1500/2000 = 0.75 (75%), Losses = 500/2000 = 0.25 (25%)
      expect(summary.gainRatio, 0.75);
      expect(summary.lossRatio, 0.25);
      expect(summary.topGainer?.tradingsymbol, 'RELIANCE');
      expect(summary.topDragger?.tradingsymbol, 'SBIN');
    });

    test('Handles edge cases: All Gainers (Zero Losses)', () {
      const summary = PortfolioDayImpactSummary(
        netDayPnl: 2500.0,
        totalGrossGains: 2500.0,
        totalGrossLosses: 0.0,
        items: [],
      );

      expect(summary.gainRatio, 1.0);
      expect(summary.lossRatio, 0.0);
    });

    test('Handles edge cases: All Losers (Zero Gains)', () {
      const summary = PortfolioDayImpactSummary(
        netDayPnl: -1200.0,
        totalGrossGains: 0.0,
        totalGrossLosses: 1200.0,
        items: [],
      );

      expect(summary.gainRatio, 0.0);
      expect(summary.lossRatio, 1.0);
    });

    test('Handles edge cases: Flat Day (Zero movement)', () {
      const summary = PortfolioDayImpactSummary(
        netDayPnl: 0.0,
        totalGrossGains: 0.0,
        totalGrossLosses: 0.0,
        items: [],
      );

      expect(summary.gainRatio, 0.5);
      expect(summary.lossRatio, 0.5);
    });
  });
}
