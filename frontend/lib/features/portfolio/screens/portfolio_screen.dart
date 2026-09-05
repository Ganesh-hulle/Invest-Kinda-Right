import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/pnl_chip.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../model/portfolio_models.dart';
import '../provider/portfolio_provider.dart';
import '../../kite/provider/kite_provider.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PortfolioProvider>().load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() => context.read<PortfolioProvider>().load();

  @override
  Widget build(BuildContext context) {
    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                backgroundColor: AppColors.surface,
                title: const Text('Portfolio'),
                pinned: true,
                floating: true,
                forceElevated: innerBoxIsScrolled,
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.onSurfaceMuted,
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
                : _buildBody(provider),
          ),
        );
      },
    );
  }

  Widget _buildBody(PortfolioProvider provider) {
    final kite = context.watch<KiteProvider>();

    if (!kite.isConnected && !provider.isLoading) {
      return _EmptyKiteState();
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
      color: AppColors.surfaceVariant,
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
                    color: AppColors.onSurfaceMuted,
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
                const TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
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
      return _EmptyList(message: 'No holdings yet.');
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: AppColors.divider),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.tradingsymbol,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ExchangeChip(exchange: item.exchange),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantity} × ${fmt.format(item.averagePrice)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmt.format(item.lastPrice),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              PnlChip(value: item.pnl),
            ],
          ),
        ],
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
      return _EmptyList(message: 'No positions open.');
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: AppColors.divider),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.tradingsymbol,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ExchangeChip(exchange: item.exchange),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Qty ${item.quantity}  ·  ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.product,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.onSurfaceMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmt.format(item.lastPrice),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              PnlChip(value: item.pnl),
            ],
          ),
        ],
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
          Icon(Icons.inbox_outlined, size: 48, color: AppColors.onSurfaceMuted),
          const SizedBox(height: 12),
          Text(
            message,
            style:
                const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _EmptyKiteState extends StatelessWidget {
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
            const Text(
              'Zerodha Not Connected',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect your Zerodha account to view your holdings and positions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.onSurfaceMuted),
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
            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.sell),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.onSurfaceMuted, fontSize: 14),
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
