import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../model/order_models.dart';
import '../provider/orders_provider.dart';
import 'place_order_sheet.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() => context.read<OrdersProvider>().loadAll();

  void _openPlaceOrderSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PlaceOrderSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrdersProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? context.colors.surface,
            title: const Text('Orders'),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: context.colors.onSurfaceMuted,
              tabs: const [
                Tab(text: 'Paper'),
                Tab(text: 'Live'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _openPlaceOrderSheet,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
          body: provider.isLoading
              ? const ShimmerLoader(itemCount: 6)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _PaperTab(provider: provider, onRefresh: _onRefresh),
                    _LiveTab(provider: provider),
                  ],
                ),
        );
      },
    );
  }
}

// ── Paper Tab ─────────────────────────────────────────────────────────────────

class _PaperTab extends StatelessWidget {
  final OrdersProvider provider;
  final Future<void> Function() onRefresh;

  const _PaperTab({required this.provider, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final orders = provider.paperOrders;
    final positions = provider.paperPositions;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: context.colors.surfaceVariant,
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          // Open Positions card
          if (positions.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _PositionsCard(positions: positions),
              ),
            ),
          ],
          if (orders.isEmpty)
            const SliverFillRemaining(
              child: _EmptyOrders(message: 'No paper orders yet.'),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Recent Orders',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.onSurfaceMuted,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final o = orders[index];
                  return Column(
                    children: [
                      _OrderTile(order: o),
                      Divider(height: 1, color: context.colors.divider),
                    ],
                  );
                },
                childCount: orders.length,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

class _PositionsCard extends StatelessWidget {
  final List<PaperPosition> positions;

  const _PositionsCard({required this.positions});

  @override
  Widget build(BuildContext context) {
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return Card(
      color: context.colors.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Open Positions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${positions.length} position${positions.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...positions.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.tradingsymbol,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.colors.onSurface,
                            ),
                          ),
                          Text(
                            'Qty ${p.quantity}  ·  Avg ${fmt.format(p.averagePrice)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.onSurfaceMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          fmt.format(p.lastPrice),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.colors.onSurface,
                          ),
                        ),
                        _PnlText(value: p.unrealizedPnl),
                      ],
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: ctx.colors.surfaceVariant,
                            title: Text('Square Off Position',
                                style: TextStyle(color: ctx.colors.onSurface, fontSize: 16)),
                            content: Text(
                              'Exit ${p.quantity} qty of ${p.tradingsymbol} at market price?',
                              style: TextStyle(color: ctx.colors.onSurfaceMuted, fontSize: 13),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.sell,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Exit'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          final res = await context
                              .read<OrdersProvider>()
                              .squareOffPaperPosition(p.instrumentToken);
                          if (context.mounted) {
                            res.fold(
                              onSuccess: (_) => ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Squared off ${p.tradingsymbol}'),
                                  backgroundColor: context.colors.surfaceVariant,
                                ),
                              ),
                              onFailure: (err) => ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(err.message),
                                  backgroundColor: AppColors.sell,
                                ),
                              ),
                            );
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.sell.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.sell.withAlpha(80)),
                        ),
                        child: const Text(
                          'Exit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.sell,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PnlText extends StatelessWidget {
  final double value;

  const _PnlText({required this.value});

  @override
  Widget build(BuildContext context) {
    final isPos = value >= 0;
    return Text(
      '${isPos ? '+' : ''}₹${value.abs().toStringAsFixed(2)}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isPos ? AppColors.buy : AppColors.sell,
      ),
    );
  }
}

// ── Live Tab ──────────────────────────────────────────────────────────────────

class _LiveTab extends StatelessWidget {
  final OrdersProvider provider;

  const _LiveTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.liveTradingDisabled) {
      return const _LiveDisabledCard();
    }

    final orders = provider.liveOrders;
    if (orders.isEmpty) {
      return const _EmptyOrders(message: 'No live orders placed.');
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: orders.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: context.colors.divider),
      itemBuilder: (_, index) => _LiveOrderTile(order: orders[index]),
    );
  }
}

class _LiveDisabledCard extends StatelessWidget {
  const _LiveDisabledCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Card(
          color: context.colors.surfaceVariant,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Live Trading Disabled',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Live order execution is currently disabled on this account. '
                  'Use Paper trading mode to practice strategies without risk.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 13, color: context.colors.onSurfaceMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Order Tiles ───────────────────────────────────────────────────────────────

class _OrderTile extends StatelessWidget {
  final PaperOrder order;

  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order.tradingsymbol,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SideChip(side: order.side),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.quantity} @ ${fmt.format(order.price)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(status: order.status),
        ],
      ),
    );
  }
}

class _LiveOrderTile extends StatelessWidget {
  final LiveOrder order;

  const _LiveOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order.tradingsymbol,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SideChip(side: order.side),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.quantity} @ ${fmt.format(order.price)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.onSurfaceMuted,
                  ),
                ),
                if (order.brokerOrderId != null)
                  Text(
                    'Broker ID: ${order.brokerOrderId}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.onSurfaceSubtle,
                    ),
                  ),
              ],
            ),
          ),
          _StatusChip(status: order.status),
        ],
      ),
    );
  }
}

// ── Small chips ───────────────────────────────────────────────────────────────

class _SideChip extends StatelessWidget {
  final String side;

  const _SideChip({required this.side});

  @override
  Widget build(BuildContext context) {
    final isBuy = side.toUpperCase() == 'BUY';
    final color = isBuy ? AppColors.buy : AppColors.sell;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        side.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toUpperCase()) {
      case 'FILLED':
      case 'COMPLETE':
        color = AppColors.buy;
        break;
      case 'REJECTED':
      case 'CANCELLED':
        color = AppColors.sell;
        break;
      default:
        color = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  final String message;

  const _EmptyOrders({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 48, color: context.colors.onSurfaceMuted),
          const SizedBox(height: 12),
          Text(
            message,
            style:
                TextStyle(color: context.colors.onSurfaceMuted, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to place an order',
            style:
                TextStyle(color: context.colors.onSurfaceSubtle, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
