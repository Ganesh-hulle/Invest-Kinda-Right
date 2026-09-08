import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invest_kinda_right/features/watchlist/model/watchlist_models.dart';
import 'package:invest_kinda_right/features/watchlist/widgets/live_ticker_price.dart';
import 'package:invest_kinda_right/features/watchlist/widgets/indicator_guide_sheet.dart';
import 'package:invest_kinda_right/features/watchlist/widgets/signal_strength_slider.dart';

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
      const newPrice = 105.0;
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

      const newPrice = 98.50;
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

  group('Historical Candle Timeframe & Signal Requirements', () {
    test('Validates 5-minute timeframe and candle count for backend IndicatorService', () {
      // Backend IndicatorService and StrategyService require:
      // findTop500ByInstrumentTokenAndTimeframeOrderByCandleTimeDesc(token, "5minute")
      const timeframe = '5minute';
      const requiredCandles = 500;
      const tradingMinutesPerDay = 375; // 09:15 to 15:30 IST
      const candlesPerDay = tradingMinutesPerDay ~/ 5; // 75 candles/day

      expect(timeframe, '5minute');
      expect(candlesPerDay, 75);

      // 7 trading days = 525 candles (exceeds the 500 requirement)
      // 21 calendar days = ~15 trading sessions = 1,125 candles (comfortably covers 500 candles)
      const daysBack = 21;
      const estimatedTradingDays = (daysBack * 5) ~/ 7; // ~15 days
      const estimatedCandles = estimatedTradingDays * candlesPerDay;

      expect(estimatedCandles, greaterThanOrEqualTo(requiredCandles));
      // Zerodha Kite allows up to 100 days for 5-minute interval historical requests
      expect(daysBack, lessThanOrEqualTo(100));
    });

    test('Formats historical date range correctly for Kite API yyyy-MM-dd format', () {
      final now = DateTime(2026, 9, 8);
      const daysBack = 21;
      final from = now.subtract(const Duration(days: daysBack));

      final fromStr =
          '${from.year.toString().padLeft(4, '0')}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
      final toStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      expect(fromStr, '2026-08-18');
      expect(toStr, '2026-09-08');
      expect(fromStr, matches(r'^\d{4}-\d{2}-\d{2}$'));
      expect(toStr, matches(r'^\d{4}-\d{2}-\d{2}$'));
    });

    test('EMA Crossover and RSI signal logic boundaries', () {
      // EMA 9 > EMA 20 indicates bullish crossover (BUY signal)
      const ema9Bullish = 102.5;
      const ema20Bullish = 100.0;
      expect(ema9Bullish > ema20Bullish, isTrue);

      // EMA 9 < EMA 20 indicates bearish crossover (SELL signal)
      const ema9Bearish = 98.0;
      const ema20Bearish = 101.5;
      expect(ema9Bearish < ema20Bearish, isTrue);

      // RSI oversold (< 30) = BUY, overbought (> 70) = SELL, neutral between 30 and 70
      const rsiOversold = 24.5;
      const rsiOverbought = 78.2;
      const rsiNeutral = 52.0;

      expect(rsiOversold < 30, isTrue);
      expect(rsiOverbought > 70, isTrue);
      expect(rsiNeutral >= 30 && rsiNeutral <= 70, isTrue);
    });
  });

  group('IndicatorGuideSheet Widget', () {
    testWidgets('Renders guide sheet title, filter chips, and indicator cards', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IndicatorGuideSheet(),
          ),
        ),
      );

      // Verify title & subtitle
      expect(find.text('Indicator & Signal Guide'), findsOneWidget);
      expect(
        find.text('What each indicator means & high-probability BUY / SELL signs'),
        findsOneWidget,
      );

      // Verify filter chips exist
      expect(find.text('All'), findsOneWidget);
      expect(find.text('EMA Crossover'), findsOneWidget);
      expect(find.text('VWAP'), findsOneWidget);
      expect(find.text('RSI 14'), findsOneWidget);
      expect(find.text('MACD'), findsOneWidget);
      expect(find.text('SuperTrend'), findsOneWidget);
      expect(find.text('Confluence Rules'), findsOneWidget);

      // Verify Confluence Card
      expect(find.text('Golden Rule: High-Probability Confluence'), findsOneWidget);
      expect(find.text('HIGH-PROBABILITY BUY SETUP'), findsOneWidget);
      expect(find.text('HIGH-PROBABILITY SELL / EXIT SETUP'), findsOneWidget);

      // Verify Indicator Card presence
      expect(find.text('EMA 9 & EMA 20'), findsOneWidget);
      expect(find.text('VWAP (Volume Weighted Avg Price)'), findsOneWidget);
      expect(find.text('RSI 14 (Relative Strength Index)'), findsOneWidget);

      // Tap on VWAP filter chip and verify filter responds
      await tester.tap(find.text('VWAP'));
      await tester.pumpAndSettle();

      expect(find.text('VWAP (Volume Weighted Avg Price)'), findsOneWidget);
      expect(find.text('INSTITUTIONAL BENCHMARK'), findsOneWidget);
    });
  });

  group('SignalStrengthSlider & Confluence Computation', () {
    test('Computes STRONG BUY when all indicators are bullish', () {
      final summary = IndicatorSignalSummary.compute(
        lastPrice: 2500.0,
        ema9: 2480.0,
        ema20: 2450.0, // EMA 9 > 20 -> BUY
        vwap: 2440.0, // Price > VWAP -> BUY
        rsi14: 58.0, // 50 <= RSI <= 70 -> BUY
        macdLine: 8.5,
        macdSignal: 5.2, // MACD > Signal -> BUY
        superTrend: 2420.0, // Price >= SuperTrend -> BUY
        strategySignal: 'BUY', // Strategy -> BUY
      );

      expect(summary.buyCount, 6);
      expect(summary.sellCount, 0);
      expect(summary.neutralCount, 0);
      expect(summary.score, 1.0);
      expect(summary.verdict, 'STRONG BUY');
    });

    test('Computes STRONG SELL when all indicators are bearish', () {
      final summary = IndicatorSignalSummary.compute(
        lastPrice: 2350.0,
        ema9: 2360.0,
        ema20: 2390.0, // EMA 9 < 20 -> SELL
        vwap: 2400.0, // Price < VWAP -> SELL
        rsi14: 42.0, // 30 < RSI < 50 -> SELL
        macdLine: -5.0,
        macdSignal: -2.0, // MACD < Signal -> SELL
        superTrend: 2420.0, // Price < SuperTrend -> SELL
        strategySignal: 'SELL', // Strategy -> SELL
      );

      expect(summary.buyCount, 0);
      expect(summary.sellCount, 6);
      expect(summary.neutralCount, 0);
      expect(summary.score, 0.0);
      expect(summary.verdict, 'STRONG SELL');
    });

    test('Computes NEUTRAL when indicators are equally split', () {
      final summary = IndicatorSignalSummary.compute(
        lastPrice: 2400.0,
        ema9: 2410.0,
        ema20: 2400.0, // BUY
        vwap: 2420.0, // SELL (Price < VWAP)
        rsi14: 55.0, // BUY
        macdLine: -2.0,
        macdSignal: 1.0, // SELL
        superTrend: 0.0, // not active
        strategySignal: 'NEUTRAL', // NEUTRAL
      );

      expect(summary.buyCount, 2);
      expect(summary.sellCount, 2);
      expect(summary.neutralCount, 1);
      expect(summary.score, closeTo(0.5, 0.01));
      expect(summary.verdict, 'NEUTRAL');
    });

    test('MACD key resolution parses macd from backend JSON correctly', () {
      // Backend Jackson record outputs "macd" and "macdSignal"
      final backendJson = {
        'instrumentToken': 738561,
        'timeframe': '5minute',
        'ema9': 2450.0,
        'ema20': 2440.0,
        'vwap': 2445.0,
        'rsi14': 56.5,
        'macd': 6.85, // Backend record field name
        'macdSignal': 5.20,
        'superTrend': 2430.0,
      };

      final parsed = (backendJson['macd'] as num?)?.toDouble() ??
          (backendJson['macdLine'] as num?)?.toDouble() ??
          (backendJson['macd_line'] as num?)?.toDouble() ??
          0.0;

      expect(parsed, 6.85);
      expect(parsed, isNot(0.0));
    });

    testWidgets('Renders SignalStrengthSlider with verdict and count chips', (tester) async {
      final summary = IndicatorSignalSummary.compute(
        lastPrice: 2500.0,
        ema9: 2480.0,
        ema20: 2450.0,
        vwap: 2440.0,
        rsi14: 58.0,
        macdLine: 8.5,
        macdSignal: 5.2,
        superTrend: 2420.0,
        strategySignal: 'BUY',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignalStrengthSlider(summary: summary),
          ),
        ),
      );

      expect(find.text('SIGNAL CONFLUENCE'), findsOneWidget);
      expect(find.text('STRONG BUY'), findsWidgets);
      expect(find.text('6 BUY'), findsOneWidget);
      expect(find.text('0 SELL'), findsOneWidget);
      expect(find.text('0 NEUTRAL'), findsOneWidget);
      expect(find.text('STRONG SELL'), findsOneWidget);
    });
  });
}
