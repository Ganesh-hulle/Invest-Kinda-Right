import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Enum representing the signal direction of an individual indicator.
enum SignalAction { buy, sell, neutral }

/// Summary of all evaluated technical indicators for an instrument.
class IndicatorSignalSummary {
  final int buyCount;
  final int sellCount;
  final int neutralCount;
  final int totalCount;
  final double score; // 0.0 (Strong Sell) to 1.0 (Strong Buy), 0.5 is Neutral
  final String verdict;
  final Color verdictColor;

  const IndicatorSignalSummary({
    required this.buyCount,
    required this.sellCount,
    required this.neutralCount,
    required this.totalCount,
    required this.score,
    required this.verdict,
    required this.verdictColor,
  });

  factory IndicatorSignalSummary.compute({
    required double lastPrice,
    required double ema9,
    required double ema20,
    required double vwap,
    required double rsi14,
    required double macdLine,
    required double macdSignal,
    double superTrend = 0.0,
    String strategySignal = 'NEUTRAL',
  }) {
    int buy = 0;
    int sell = 0;
    int neutral = 0;

    // 1. EMA 9 vs EMA 20
    if (ema9 > 0 && ema20 > 0) {
      if (ema9 > ema20) {
        buy++;
      } else if (ema9 < ema20) {
        sell++;
      } else {
        neutral++;
      }
    }

    // 2. Price vs VWAP
    if (lastPrice > 0 && vwap > 0) {
      if (lastPrice > vwap) {
        buy++;
      } else if (lastPrice < vwap) {
        sell++;
      } else {
        neutral++;
      }
    }

    // 3. RSI 14
    if (rsi14 > 0) {
      if (rsi14 < 30 || (rsi14 >= 50 && rsi14 < 70)) {
        buy++;
      } else if (rsi14 > 70 || (rsi14 > 30 && rsi14 < 50)) {
        sell++;
      } else {
        neutral++;
      }
    }

    // 4. MACD Line vs Signal Line
    if (macdLine != 0 || macdSignal != 0) {
      if (macdLine > macdSignal) {
        buy++;
      } else if (macdLine < macdSignal) {
        sell++;
      } else {
        neutral++;
      }
    }

    // 5. SuperTrend (if available and positive)
    if (superTrend > 0 && lastPrice > 0) {
      if (lastPrice >= superTrend) {
        buy++;
      } else {
        sell++;
      }
    }

    // 6. Strategy Engine Signal
    final sigUpper = strategySignal.toUpperCase();
    if (sigUpper == 'BUY') {
      buy++;
    } else if (sigUpper == 'SELL') {
      sell++;
    } else {
      neutral++;
    }

    final total = buy + sell + neutral;
    final double computedScore;
    if (total == 0) {
      computedScore = 0.5;
    } else {
      // Net ratio: (buy - sell) / total => range -1.0 to 1.0
      final net = (buy - sell) / total;
      // Map [-1.0, 1.0] to [0.0, 1.0]
      computedScore = ((net + 1.0) / 2.0).clamp(0.0, 1.0);
    }

    final String verdictStr;
    final Color verdictClr;

    if (computedScore >= 0.70) {
      verdictStr = 'STRONG BUY';
      verdictClr = AppColors.buy;
    } else if (computedScore >= 0.58) {
      verdictStr = 'BUY';
      verdictClr = AppColors.buyLight;
    } else if (computedScore <= 0.30) {
      verdictStr = 'STRONG SELL';
      verdictClr = AppColors.sell;
    } else if (computedScore <= 0.42) {
      verdictStr = 'SELL';
      verdictClr = AppColors.sellLight;
    } else {
      verdictStr = 'NEUTRAL';
      verdictClr = AppColors.onSurfaceMuted;
    }

    return IndicatorSignalSummary(
      buyCount: buy,
      sellCount: sell,
      neutralCount: neutral,
      totalCount: total,
      score: computedScore,
      verdict: verdictStr,
      verdictColor: verdictClr,
    );
  }
}

/// Interactive / visual slider gauge showing BUY to SELL sentiment.
class SignalStrengthSlider extends StatelessWidget {
  final IndicatorSignalSummary summary;

  const SignalStrengthSlider({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: summary.verdictColor.withAlpha(80),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Label + Verdict Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.speed_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'SIGNAL CONFLUENCE',
                    style: TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: summary.verdictColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: summary.verdictColor.withAlpha(120)),
                ),
                child: Text(
                  summary.verdict,
                  style: TextStyle(
                    color: summary.verdictColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Count Breakdown Chips
          Row(
            children: [
              _buildCountChip(
                count: summary.buyCount,
                label: 'BUY',
                color: AppColors.buy,
                icon: Icons.arrow_upward_rounded,
              ),
              const SizedBox(width: 8),
              _buildCountChip(
                count: summary.neutralCount,
                label: 'NEUTRAL',
                color: AppColors.onSurfaceMuted,
                icon: Icons.remove_rounded,
              ),
              const SizedBox(width: 8),
              _buildCountChip(
                count: summary.sellCount,
                label: 'SELL',
                color: AppColors.sell,
                icon: Icons.arrow_downward_rounded,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Slider / Gauge Track with animated needle/thumb
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.5, end: summary.score),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, animatedScore, _) {
              return Column(
                children: [
                  // Gauge track container
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final trackWidth = constraints.maxWidth;
                      const thumbRadius = 8.0;
                      // Calculate thumb position along track
                      final thumbPosition =
                          (trackWidth - thumbRadius * 2) * animatedScore;

                      return SizedBox(
                        height: 24,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            // Multi-stop gradient track
                            Container(
                              height: 10,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.sell,
                                    Color(0xFFF97316),
                                    Color(0xFF6B7280),
                                    Color(0xFF84CC16),
                                    AppColors.buy,
                                  ],
                                  stops: [0.0, 0.28, 0.50, 0.72, 1.0],
                                ),
                              ),
                            ),

                            // Neutral center tick mark
                            Positioned(
                              left: trackWidth / 2 - 1,
                              child: Container(
                                width: 2,
                                height: 14,
                                color: Colors.white.withAlpha(160),
                              ),
                            ),

                            // Glowing thumb / pointer indicator
                            Positioned(
                              left: thumbPosition,
                              child: Container(
                                width: thumbRadius * 2,
                                height: thumbRadius * 2,
                                decoration: BoxDecoration(
                                  color: summary.verdictColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: summary.verdictColor.withAlpha(180),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Slider Bottom Labels: STRONG SELL <-> NEUTRAL <-> STRONG BUY
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'STRONG SELL',
                        style: TextStyle(
                          color: AppColors.sell,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'SELL',
                        style: TextStyle(
                          color: Color(0xFFF97316),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'NEUTRAL',
                        style: TextStyle(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'BUY',
                        style: TextStyle(
                          color: Color(0xFF84CC16),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'STRONG BUY',
                        style: TextStyle(
                          color: AppColors.buy,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCountChip({
    required int count,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$count $label',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
