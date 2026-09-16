import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pnl_chip.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../model/portfolio_models.dart';
import '../provider/portfolio_provider.dart';
import '../widgets/portfolio_detail_sheet.dart';
import '../widgets/pnl_impact_drawer.dart';
import '../../kite/provider/kite_provider.dart';
import '../../watchlist/widgets/live_ticker_price.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _currencyFmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PortfolioProvider>().load();
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() => context.read<PortfolioProvider>().load();

  @override
  Widget build(BuildContext context) {
    final kite = context.watch<KiteProvider>();

    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final hasItems = provider.holdings.isNotEmpty ||
            provider.netPositions.isNotEmpty ||
            provider.dayPositions.isNotEmpty;
        final showBottomBar = kite.isConnected && !provider.isLoading && hasItems;

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? context.colors.surface,
                title: const Text('Portfolio'),
                pinned: true,
                floating: true,
                forceElevated: innerBoxIsScrolled,
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: context.colors.onSurfaceMuted,
                  tabs: const [
                    Tab(text: 'Holdings'),
                    Tab(text: 'Net Positions'),
                    Tab(text: 'Day Positions'),
                  ],
                ),
              ),
              if (!provider.isLoading)
                SliverToBoxAdapter(
                  child: _SummaryBar(provider: provider, fmt: _currencyFmt),
                ),
            ],
            body: provider.isLoading
                ? const ShimmerLoader(itemCount: 8)
                : _buildBody(provider, kite),
          ),
          bottomNavigationBar: showBottomBar
              ? _DayPnlBottomBar(
                  provider: provider,
                  activeTab: _tabController.index,
                  fmt: _currencyFmt,
                )
              : null,
        );
      },
    );
  }

  Widget _buildBody(PortfolioProvider provider, KiteProvider kite) {
    if (!kite.isConnected && !provider.isLoading) {
      return const _EmptyKiteState();
    }

    if (provider.error != null &&
        provider.holdings.isEmpty &&
        provider.netPositions.isEmpty) {
      return _ErrorState(
        message: provider.error!,
        onRetry: _onRefresh,
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _HoldingsList(
          items: provider.holdings,
          onRefresh: _onRefresh,
          fmt: _currencyFmt,
        ),
        _PositionsList(
          items: provider.netPositions,
          onRefresh: _onRefresh,
          fmt: _currencyFmt,
        ),
        _PositionsList(
          items: provider.dayPositions,
          onRefresh: _onRefresh,
          fmt: _currencyFmt,
        ),
      ],
    );
  }
}

// ── Summary Bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final PortfolioProvider provider;
  final NumberFormat fmt;

  const _SummaryBar({required this.provider, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _SummaryItem(
            label: 'Invested',
            value: fmt.format(provider.totalInvested),
          ),
          const SizedBox(width: 16),
          _SummaryItem(
            label: 'Current',
            value: fmt.format(provider.currentValue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total P&L',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 2),
                PnlChip(value: provider.totalPnl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                TextStyle(fontSize: 11, color: context.colors.onSurfaceMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Holdings List ─────────────────────────────────────────────────────────────

class _HoldingsList extends StatelessWidget {
  final List<HoldingItem> items;
  final Future<void> Function() onRefresh;
  final NumberFormat fmt;

  const _HoldingsList({
    required this.items,
    required this.onRefresh,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyList(message: 'No holdings yet.');
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: context.colors.surfaceVariant,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: context.colors.divider),
        itemBuilder: (_, index) => _HoldingTile(item: items[index], fmt: fmt),
      ),
    );
  }
}

class _HoldingTile extends StatelessWidget {
  final HoldingItem item;
  final NumberFormat fmt;

  const _HoldingTile({required this.item, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final hasDayChange = item.dayChangePercentage != 0.0;
    final isDayPositive = item.dayChangePercentage >= 0;
    final dayColor = isDayPositive ? AppColors.buy : AppColors.sell;

    final isPnlPositive = item.pnl >= 0;
    final isPnlZero = item.pnl.abs() < 0.001;
    final pnlColor = isPnlZero
        ? context.colors.onSurfaceMuted
        : (isPnlPositive ? AppColors.buy : AppColors.sell);
    final pnlSign = isPnlPositive ? '+' : '-';
    final pnlPctSign = isPnlPositive ? '+' : '';

    return InkWell(
      onTap: () => PortfolioDetailSheet.show(context, holding: item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Top Row: Instrument Symbol & Exchange on left, Total Unrealised P&L on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.tradingsymbol,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ExchangeChip(exchange: item.exchange),
                  ],
                ),
                // Total Unrealised P&L per instrument (Amount and %)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isPnlZero
                          ? '₹0.00'
                          : '$pnlSign${fmt.format(item.pnl.abs())}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: pnlColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($pnlPctSign${item.totalPnlPercent.toStringAsFixed(2)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pnlColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Bottom Row: Qty & Avg on left, Live Price (with green/red blink) & Day Change on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${item.quantity} Qty. · Avg. ${fmt.format(item.averagePrice)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.onSurfaceMuted,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LTP ',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.colors.onSurfaceMuted,
                        fontWeight: FontWeight.w200,
                      ),
                    ),
                    LiveTickerPrice(
                      price: item.lastPrice,
                      previousPrice: item.previousPrice,
                      direction: item.priceDirection,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: dayColor,
                      ),
                    ),
                    if (hasDayChange) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${isDayPositive ? '+' : ''}${item.dayChangePercentage.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w200,
                          color: dayColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Positions List ────────────────────────────────────────────────────────────

class _PositionsList extends StatelessWidget {
  final List<PositionItem> items;
  final Future<void> Function() onRefresh;
  final NumberFormat fmt;

  const _PositionsList({
    required this.items,
    required this.onRefresh,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyList(message: 'No positions open.');
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: context.colors.surfaceVariant,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: context.colors.divider),
        itemBuilder: (_, index) => _PositionTile(item: items[index], fmt: fmt),
      ),
    );
  }
}

class _PositionTile extends StatelessWidget {
  final PositionItem item;
  final NumberFormat fmt;

  const _PositionTile({required this.item, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final hasDayChange = item.dayChangePercentage != 0.0;
    final isDayPositive = item.dayChangePercentage >= 0;
    final dayColor = isDayPositive ? AppColors.buy : AppColors.sell;

    final isPnlPositive = item.pnl >= 0;
    final isPnlZero = item.pnl.abs() < 0.001;
    final pnlColor = isPnlZero
        ? context.colors.onSurfaceMuted
        : (isPnlPositive ? AppColors.buy : AppColors.sell);
    final pnlSign = isPnlPositive ? '+' : '-';
    final pnlPctSign = isPnlPositive ? '+' : '';

    return InkWell(
      onTap: () => PortfolioDetailSheet.show(context, position: item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Top Row: Symbol, Exchange & Product on left, Total Unrealised P&L on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.tradingsymbol,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ExchangeChip(exchange: item.exchange),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceVariant2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.product,
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colors.onSurfaceMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                // Total Unrealised P&L per position (Amount and %)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isPnlZero
                          ? '₹0.00'
                          : '$pnlSign${fmt.format(item.pnl.abs())}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: pnlColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($pnlPctSign${item.totalPnlPercent.toStringAsFixed(2)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pnlColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Bottom Row: Qty & Avg on left, Live Price (with green/red blink) & Day Change on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${item.quantity} Qty. · Avg. ${fmt.format(item.averagePrice)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.onSurfaceMuted,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LTP ',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.colors.onSurfaceMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    LiveTickerPrice(
                      price: item.lastPrice,
                      previousPrice: item.previousPrice,
                      direction: item.priceDirection,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: dayColor,
                      ),
                    ),
                    if (hasDayChange) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${isDayPositive ? '+' : ''}${item.dayChangePercentage.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: dayColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _ExchangeChip extends StatelessWidget {
  final String exchange;

  const _ExchangeChip({required this.exchange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        exchange,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  final String message;

  const _EmptyList({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: context.colors.onSurfaceMuted),
          const SizedBox(height: 12),
          Text(
            message,
            style:
                TextStyle(color: context.colors.onSurfaceMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _EmptyKiteState extends StatelessWidget {
  const _EmptyKiteState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.orangeGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.link_off, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Zerodha Not Connected',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your Zerodha account to view your holdings and positions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.colors.onSurfaceMuted),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/kite-connect'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.power, size: 18),
              label: const Text('Connect Zerodha'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.sell),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: context.colors.onSurfaceMuted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Day P&L Bottom Bar ────────────────────────────────────────────────────────

class _DayPnlBottomBar extends StatelessWidget {
  final PortfolioProvider provider;
  final int activeTab;
  final NumberFormat fmt;

  const _DayPnlBottomBar({
    required this.provider,
    required this.activeTab,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final dayPnl = provider.dayPnlForTab(activeTab);
    final dayPnlPct = provider.dayPnlPercentageForTab(activeTab);
    final isPositive = dayPnl >= 0;
    final isZero = dayPnl.abs() < 0.001;
    final color = isZero
        ? context.colors.onSurface
        : (isPositive ? AppColors.buy : AppColors.sell);
    final sign = isPositive ? '+' : '-';
    final pctSign = isPositive ? '+' : '';

    String tabLabel;
    switch (activeTab) {
      case 0:
        tabLabel = 'Holdings';
        break;
      case 1:
        tabLabel = 'Net Positions';
        break;
      case 2:
        tabLabel = 'Day Positions';
        break;
      default:
        tabLabel = 'Portfolio';
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        border: Border(
          top: BorderSide(color: context.colors.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => PnlImpactDrawer.show(
              context,
              initialScopeTab: activeTab,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isPositive
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Day's P&L",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.onSurface,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tabLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: context.colors.onSurfaceMuted,
                                ),
                              ),
                              const Text(
                                ' · Impact Analysis',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isZero
                            ? '₹0.00'
                            : '$sign${fmt.format(dayPnl.abs())}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$pctSign${dayPnlPct.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
