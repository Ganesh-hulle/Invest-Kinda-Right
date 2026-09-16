import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../model/analytics_models.dart';
import '../provider/analytics_provider.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AnalyticsProvider(
        dioClient: ctx.read<DioClient>(),
      ),
      child: const _AnalyticsView(),
    );
  }
}

class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalyticsProvider>();

    if (provider.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) showErrorSnackbar(context, provider.error!);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? context.colors.surface,
        actions: [
          if (provider.selectedToken != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: () => provider.fetchAll(),
            ),
        ],
      ),
      body: Column(
        children: [
          _InstrumentSelector(provider: provider),
          _TimeframeSelector(provider: provider),
          Divider(height: 1, color: context.colors.divider),
          Expanded(child: _AnalyticsBody(provider: provider)),
        ],
      ),
    );
  }
}

// ── Instrument selector ───────────────────────────────────────────────────────

class _InstrumentSelector extends StatelessWidget {
  final AnalyticsProvider provider;
  const _InstrumentSelector({required this.provider});

  @override
  Widget build(BuildContext context) {
    final hasInstrument = provider.selectedSymbol != null;

    return GestureDetector(
      onTap: () async {
        final result =
            await context.push<Map<String, dynamic>>('/instrument-search');
        if (result != null && context.mounted) {
          final token = result['instrumentToken'] as int?;
          final symbol = result['tradingsymbol'] as String?;
          if (token != null && symbol != null) {
            context.read<AnalyticsProvider>().selectInstrument(token, symbol);
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.divider),
        ),
        child: Row(
          children: [
            Icon(
              Icons.candlestick_chart_rounded,
              color:
                  hasInstrument ? AppColors.primary : context.colors.onSurfaceMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasInstrument ? provider.selectedSymbol! : 'Select Instrument',
                style: TextStyle(
                  color: hasInstrument
                      ? context.colors.onSurface
                      : context.colors.onSurfaceMuted,
                  fontSize: 15,
                  fontWeight: hasInstrument ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Icon(Icons.search_rounded,
                color: context.colors.onSurfaceMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Timeframe selector ────────────────────────────────────────────────────────

class _TimeframeSelector extends StatelessWidget {
  final AnalyticsProvider provider;
  const _TimeframeSelector({required this.provider});

  static const _labels = {
    '1minute': '1m',
    '5minute': '5m',
    '15minute': '15m',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: AnalyticsProvider.availableTimeframes.map((tf) {
          final selected = provider.selectedTimeframe == tf;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_labels[tf] ?? tf),
              selected: selected,
              onSelected: (_) => provider.setTimeframe(tf),
              selectedColor: AppColors.primary.withAlpha(40),
              backgroundColor: context.colors.surfaceVariant2,
              side: BorderSide(
                color: selected ? AppColors.primary : context.colors.divider,
              ),
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : context.colors.onSurfaceMuted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 12,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Body dispatcher ───────────────────────────────────────────────────────────

class _AnalyticsBody extends StatelessWidget {
  final AnalyticsProvider provider;
  const _AnalyticsBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.selectedToken == null) return const _EmptyState();
    if (provider.isLoading) return const _LoadingState();
    return _AnalyticsContent(provider: provider);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: context.colors.surfaceVariant,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.auto_graph_rounded,
                  size: 48, color: context.colors.onSurfaceMuted),
            ),
            const SizedBox(height: 20),
            Text(
              'No Instrument Selected',
              style: TextStyle(
                color: context.colors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Select Instrument" above to view\ntechnical indicators and signals.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.onSurfaceMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading state ─────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const ShimmerCard(height: 120),
          const SizedBox(height: 12),
          const ShimmerCard(height: 200),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(6, (_) => const ShimmerCard(height: 80)),
          ),
        ],
      ),
    );
  }
}

// ── Main content ──────────────────────────────────────────────────────────────

class _AnalyticsContent extends StatelessWidget {
  final AnalyticsProvider provider;
  const _AnalyticsContent({required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _SignalCard(signal: provider.signal),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Price & Candles',
              style: TextStyle(
                color: context.colors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                final token = provider.selectedToken;
                final symbol = provider.selectedSymbol ?? 'CHART';
                final queryParams = <String, String>{
                  'symbol': symbol,
                  'exchange': 'NSE',
                };
                if (token != null) {
                  queryParams['token'] = token.toString();
                }
                context.push(
                  Uri(path: '/candles', queryParameters: queryParams).toString(),
                );
              },
              icon: const Icon(Icons.fullscreen_rounded, size: 18),
              label: const Text('Fullscreen (Landscape)'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (provider.candles.isNotEmpty) ...[
          _CandleChart(candles: provider.candles),
          const SizedBox(height: 16),
        ],
        if (provider.indicators != null) ...[
          Text(
            'Technical Indicators',
            style: TextStyle(
              color: context.colors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _IndicatorsGrid(snapshot: provider.indicators!),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Signal card ───────────────────────────────────────────────────────────────

class _SignalCard extends StatelessWidget {
  final SignalResult? signal;
  const _SignalCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final isBuy = signal?.side == 'BUY';
    final isSell = signal?.side == 'SELL';

    final bgGradient = isBuy
        ? AppColors.buyGradient
        : isSell
            ? AppColors.sellGradient
            : LinearGradient(
                colors: [context.colors.surfaceVariant2, context.colors.surfaceVariant],
              );

    final labelColor = isBuy
        ? AppColors.buy
        : isSell
            ? AppColors.sell
            : context.colors.onSurfaceMuted;

    final icon = isBuy
        ? Icons.trending_up_rounded
        : isSell
            ? Icons.trending_down_rounded
            : Icons.remove_rounded;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: labelColor.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded,
                  color: context.colors.onSurfaceMuted, size: 14),
              const SizedBox(width: 6),
              Text(
                signal?.strategy ?? 'EMA Crossover',
                style: TextStyle(
                    color: context.colors.onSurfaceMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: labelColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: labelColor, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signal?.side ?? 'NEUTRAL',
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  if (signal != null)
                    Text(
                      '₹${signal!.price.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: context.colors.onSurfaceMuted, fontSize: 14),
                    ),
                ],
              ),
            ],
          ),
          if (signal != null) ...[
            const SizedBox(height: 12),
            Text(
              signal!.tradingsymbol,
              style: TextStyle(
                  color: context.colors.onSurfaceMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Candle chart (close price line) ──────────────────────────────────────────

class _CandleChart extends StatelessWidget {
  final List<CandleData> candles;
  const _CandleChart({required this.candles});

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) return const SizedBox.shrink();

    final spots = candles
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.close))
        .toList();

    final closes = candles.map((c) => c.close);
    final minY = closes.reduce((a, b) => a < b ? a : b);
    final maxY = closes.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.05;

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Close Price',
              style: TextStyle(color: context.colors.onSurfaceMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minY - padding,
                maxY: maxY + padding,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withAlpha(60),
                          AppColors.primary.withAlpha(0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Indicators grid ───────────────────────────────────────────────────────────

class _IndicatorsGrid extends StatelessWidget {
  final IndicatorSnapshot snapshot;
  const _IndicatorsGrid({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final items = <_IndicatorItem>[
      _IndicatorItem(
          label: 'EMA 9', value: snapshot.ema9, dotColor: AppColors.ema9),
      _IndicatorItem(
          label: 'EMA 20', value: snapshot.ema20, dotColor: AppColors.ema20),
      _IndicatorItem(
          label: 'VWAP', value: snapshot.vwap, dotColor: AppColors.vwap),
      _IndicatorItem(
        label: 'RSI 14',
        value: snapshot.rsi14,
        dotColor: snapshot.rsi14 != null && snapshot.rsi14! > 70
            ? AppColors.sell
            : AppColors.buy,
        cardBackground: snapshot.rsi14 != null
            ? (snapshot.rsi14! > 70
                ? AppColors.sell.withAlpha(20)
                : AppColors.buy.withAlpha(20))
            : null,
      ),
      _IndicatorItem(
          label: 'MACD', value: snapshot.macd, dotColor: AppColors.macdLine),
      _IndicatorItem(
          label: 'MACD Signal',
          value: snapshot.macdSignal,
          dotColor: AppColors.macdSignal),
      _IndicatorItem(
          label: 'ATR 14', value: snapshot.atr14, dotColor: AppColors.warning),
      _IndicatorItem(
          label: 'Super Trend',
          value: snapshot.superTrend,
          dotColor: AppColors.superTrend),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.7,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _IndicatorCard(item: items[i]),
    );
  }
}

class _IndicatorItem {
  final String label;
  final double? value;
  final Color dotColor;
  final Color? cardBackground;

  const _IndicatorItem({
    required this.label,
    required this.value,
    required this.dotColor,
    this.cardBackground,
  });
}

class _IndicatorCard extends StatelessWidget {
  final _IndicatorItem item;
  const _IndicatorCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.cardBackground ?? context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: item.dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: context.colors.onSurfaceMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            item.value != null ? item.value!.toStringAsFixed(2) : '—',
            style: TextStyle(
              color: item.value != null
                  ? context.colors.onSurface
                  : context.colors.onSurfaceSubtle,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
