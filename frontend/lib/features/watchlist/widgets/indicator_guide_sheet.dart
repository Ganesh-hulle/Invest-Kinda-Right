import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Opens the Indicator and Signal Guide bottom sheet.
void showIndicatorGuideSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const IndicatorGuideSheet(),
  );
}

class IndicatorGuideSheet extends StatefulWidget {
  const IndicatorGuideSheet({super.key});

  @override
  State<IndicatorGuideSheet> createState() => _IndicatorGuideSheetState();
}

class _IndicatorGuideSheetState extends State<IndicatorGuideSheet> {
  int _selectedFilterIndex = 0; // 0: All, 1: EMA, 2: VWAP, 3: RSI, 4: MACD, 5: SuperTrend, 6: Confluence

  static const List<String> _filters = [
    'All',
    'EMA Crossover',
    'VWAP',
    'RSI 14',
    'MACD',
    'SuperTrend',
    'Confluence Rules',
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Top Drag Handle & Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.auto_graph_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Indicator & Signal Guide',
                                style: TextStyle(
                                  color: AppColors.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'What each indicator means & high-probability BUY / SELL signs',
                                style: TextStyle(
                                  color: AppColors.onSurfaceMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.onSurfaceMuted),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Filter Category Chips
              SizedBox(
                height: 42,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final isSelected = _selectedFilterIndex == index;
                    return ChoiceChip(
                      label: Text(
                        _filters[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.black : AppColors.onSurfaceMuted,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceVariant2,
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.divider,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedFilterIndex = index);
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
              const Divider(color: AppColors.divider, height: 1),

              // Guide content list
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    if (_selectedFilterIndex == 0 || _selectedFilterIndex == 6)
                      const _ConfluenceCard(),

                    if (_selectedFilterIndex == 0 || _selectedFilterIndex == 1)
                      const _IndicatorCard(
                        indicatorName: 'EMA 9 & EMA 20',
                        badgeText: 'TREND & MOMENTUM',
                        badgeColor: AppColors.ema9,
                        timeframeNote: 'Evaluated on 5-min candles by Strategy Engine',
                        summary:
                            'Exponential Moving Averages calculate the average price giving greater weight to recent periods. EMA 9 measures fast intraday momentum, while EMA 20 represents the short-term baseline trend.',
                        buySign:
                            'Golden Crossover: EMA 9 crosses ABOVE EMA 20, and price sustains above both lines. Signals upward acceleration and buyers taking control.',
                        sellSign:
                            'Death Crossover: EMA 9 crosses BELOW EMA 20, and price breaks below both lines. Signals downward momentum and sellers in control.',
                        proTip:
                            'Avoid trading crossovers during low-volume choppy consolidations. Look for crossovers that occur when price is also above VWAP.',
                      ),

                    if (_selectedFilterIndex == 0 || _selectedFilterIndex == 2)
                      const _IndicatorCard(
                        indicatorName: 'VWAP (Volume Weighted Avg Price)',
                        badgeText: 'INSTITUTIONAL BENCHMARK',
                        badgeColor: AppColors.vwap,
                        timeframeNote: 'Intraday cumulative calculation from market open (09:15)',
                        summary:
                            'The true intraday volume-weighted average price across all executed trades. Large institutional buyers and hedge fund algorithms use VWAP to evaluate trade quality.',
                        buySign:
                            'Price trading solidly ABOVE VWAP, or pulling back to touch VWAP from above and printing a strong bullish rejection candle (VWAP acting as dynamic support).',
                        sellSign:
                            'Price trading BELOW VWAP, or attempting to rally up to VWAP and getting rejected with long upper wicks (VWAP acting as dynamic resistance).',
                        proTip:
                            'Never go long when price is deeply below VWAP, and never short when price is trending strongly above VWAP.',
                      ),

                    if (_selectedFilterIndex == 0 || _selectedFilterIndex == 3)
                      const _IndicatorCard(
                        indicatorName: 'RSI 14 (Relative Strength Index)',
                        badgeText: 'MOMENTUM OSCILLATOR',
                        badgeColor: Color(0xFF00B4D8),
                        timeframeNote: 'Oscillates between 0 and 100 on 14-period lookback',
                        summary:
                            'Measures the speed and velocity of price movements. Identifies whether an instrument has been bought or sold too aggressively and is due for a reversal or trend extension.',
                        buySign:
                            '• Oversold Bounce: RSI dips below 30 and hooks back UP above 30.\n• Trend Continuation: RSI breaks above 50 with expanding volume, indicating bullish momentum dominance.',
                        sellSign:
                            '• Overbought Reversal: RSI climbs above 70 and rolls back DOWN below 70.\n• Trend Breakdown: RSI drops below 50, indicating sellers are overwhelming buyers.',
                        proTip:
                            'In strong trending markets, RSI can stay overbought (>70) or oversold (<30) for extended periods. Wait for the exit from the extreme zone before taking counter-trend trades.',
                      ),

                    if (_selectedFilterIndex == 0 || _selectedFilterIndex == 4)
                      const _IndicatorCard(
                        indicatorName: 'MACD (Moving Avg Convergence Divergence)',
                        badgeText: 'TREND FOLLOW & MOMENTUM',
                        badgeColor: AppColors.macdLine,
                        timeframeNote: '12 EMA, 26 EMA, and 9 EMA Signal Line',
                        summary:
                            'Tracks the relationship between two exponential moving averages. The difference is plotted as the MACD Line, compared against its 9-period Signal Line and histogram.',
                        buySign:
                            '• Bullish Crossover: MACD Line crosses ABOVE Signal Line from below the zero line.\n• Histogram turning from red to green and expanding upward.',
                        sellSign:
                            '• Bearish Crossover: MACD Line crosses BELOW Signal Line from above.\n• Histogram turning from green to red and expanding downward.',
                        proTip:
                            'Watch for Bullish Divergence: when price makes a lower low but MACD makes a higher low, a sharp upward rally is often imminent.',
                      ),

                    if (_selectedFilterIndex == 0 || _selectedFilterIndex == 5)
                      const _IndicatorCard(
                        indicatorName: 'SuperTrend & ATR 14',
                        badgeText: 'VOLATILITY & TRAILING STOP',
                        badgeColor: AppColors.superTrend,
                        timeframeNote: 'Period 10, Multiplier 3 with Average True Range',
                        summary:
                            'A volatility-based trend-following indicator. It plots a continuous dynamic boundary line that automatically tracks stop-loss levels and direction.',
                        buySign:
                            'SuperTrend flips BELOW the price candles and turns GREEN. As long as candles remain above the green band, stay long or enter buy positions.',
                        sellSign:
                            'SuperTrend flips ABOVE the price candles and turns RED. Exit long positions immediately or look for short opportunities.',
                        proTip:
                            'Use the green SuperTrend line as your trailing stop-loss level to ride entire intraday trends without second-guessing.',
                      ),

                    const SizedBox(height: 12),
                    const _SignalBadgeCheatSheet(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Confluence Summary Card ───────────────────────────────────────────────

class _ConfluenceCard extends StatelessWidget {
  const _ConfluenceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(90)),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withAlpha(25),
            AppColors.surfaceVariant2,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bolt_rounded, size: 16, color: Colors.black),
              ),
              const SizedBox(width: 8),
              const Text(
                'Golden Rule: High-Probability Confluence',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Never trade off any single indicator in isolation. High-probability trades happen when multiple indicators agree simultaneously:',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),

          // Perfect BUY vs Perfect SELL row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.buy.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.buy.withAlpha(60)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.buy, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'HIGH-PROBABILITY BUY SETUP',
                      style: TextStyle(
                        color: AppColors.buy,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  '1. Price is trading ABOVE VWAP (Institutional momentum)\n'
                  '2. EMA 9 crosses ABOVE EMA 20 (Golden Crossover)\n'
                  '3. MACD Line > Signal Line (Expanding bullish histogram)\n'
                  '4. RSI 14 is between 40 and 65 (Room to run upward, not overbought)',
                  style: TextStyle(color: AppColors.onSurface, fontSize: 11, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.sell.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.sell.withAlpha(60)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cancel_rounded, color: AppColors.sell, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'HIGH-PROBABILITY SELL / EXIT SETUP',
                      style: TextStyle(
                        color: AppColors.sell,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  '1. Price breaks and trades BELOW VWAP (Sellers dominant)\n'
                  '2. EMA 9 crosses BELOW EMA 20 (Death Crossover)\n'
                  '3. MACD Line < Signal Line (Negative downward histogram)\n'
                  '4. RSI 14 drops below 50 or reverses downward from > 70',
                  style: TextStyle(color: AppColors.onSurface, fontSize: 11, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual Indicator Card ─────────────────────────────────────────────

class _IndicatorCard extends StatelessWidget {
  final String indicatorName;
  final String badgeText;
  final Color badgeColor;
  final String timeframeNote;
  final String summary;
  final String buySign;
  final String sellSign;
  final String proTip;

  const _IndicatorCard({
    required this.indicatorName,
    required this.badgeText,
    required this.badgeColor,
    required this.timeframeNote,
    required this.summary,
    required this.buySign,
    required this.sellSign,
    required this.proTip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name + Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      indicatorName,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeframeNote,
                      style: const TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withAlpha(80)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Summary
          Text(
            summary,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // BUY Sign Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.buy.withAlpha(12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.buy.withAlpha(50)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.arrow_upward_rounded, size: 16, color: AppColors.buy),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Good BUY Sign: ',
                          style: TextStyle(
                            color: AppColors.buy,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        TextSpan(
                          text: buySign,
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // SELL Sign Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.sell.withAlpha(12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.sell.withAlpha(50)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.sell),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Good SELL Sign: ',
                          style: TextStyle(
                            color: AppColors.sell,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        TextSpan(
                          text: sellSign,
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Pro Tip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant3,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tip: $proTip',
                    style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Signal Badge Cheat Sheet ──────────────────────────────────────────────

class _SignalBadgeCheatSheet extends StatelessWidget {
  const _SignalBadgeCheatSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Strategy Signal Badges Explained',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _badgeRow(
            label: 'BUY',
            color: AppColors.buy,
            description:
                'Strategy Engine identified an active bullish 9/20 EMA crossover with upward momentum on 5-min candles.',
          ),
          const SizedBox(height: 8),
          _badgeRow(
            label: 'SELL',
            color: AppColors.sell,
            description:
                'Strategy Engine identified an active bearish 9/20 EMA crossover indicating downward trend breakdown on 5-min candles.',
          ),
          const SizedBox(height: 8),
          _badgeRow(
            label: 'NEUTRAL',
            color: AppColors.onSurfaceMuted,
            description:
                'No fresh crossover detected. Moving averages are either running parallel or market is consolidating.',
          ),
        ],
      ),
    );
  }

  Widget _badgeRow({
    required String label,
    required Color color,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
