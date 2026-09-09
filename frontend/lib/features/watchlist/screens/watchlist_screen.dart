import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../model/watchlist_models.dart';
import '../provider/watchlist_provider.dart';
import '../widgets/live_ticker_price.dart';
import '../widgets/market_indices_bar.dart';
import '../widgets/live_market_status_pill.dart';
import '../widgets/indicator_guide_sheet.dart';
import 'instrument_detail_sheet.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WatchlistProvider>().onWatchlistOpened();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[Watchlist] App resumed: reconnecting live market feeds');
      context.read<WatchlistProvider>().onWatchlistOpened();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await context.read<WatchlistProvider>().onWatchlistOpened();
  }

  Future<void> _confirmDelete(BuildContext context, WatchlistItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: const Text('Remove from Watchlist',
            style: TextStyle(color: AppColors.onSurface)),
        content: Text(
          'Remove ${item.tradingsymbol} from your watchlist?',
          style: const TextStyle(color: AppColors.onSurfaceMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Remove', style: TextStyle(color: AppColors.sell)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context
          .read<WatchlistProvider>()
          .removeInstrument(item.instrumentToken);
      if (context.mounted) {
        showSuccessSnackbar(
            context, '${item.tradingsymbol} removed from watchlist');
      }
    }
  }

  void _openDetailSheet(BuildContext context, WatchlistItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InstrumentDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WatchlistProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Watchlist'),
            Text(
              '${provider.items.length} / 50 items',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.onSurfaceMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          const LiveMarketStatusPill(),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Indicator & Signal Guide',
            onPressed: () => showIndicatorGuideSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Market Feed',
            onPressed: _onRefresh,
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/instrument-search'),
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Zerodha Dual Index Market Bar (NIFTY 50 & SENSEX)
            const SliverToBoxAdapter(
              child: MarketIndicesBar(),
            ),

            // Quick Filter Chips (All, Gainers, Losers, A-Z)
            if (provider.items.isNotEmpty)
              SliverToBoxAdapter(
                child: _FilterChipsBar(
                  currentFilter: provider.currentFilter,
                  onSelectFilter: provider.setFilter,
                  totalCount: provider.items.length,
                  gainersCount:
                      provider.items.where((i) => i.change > 0).length,
                  losersCount:
                      provider.items.where((i) => i.change < 0).length,
                ),
              ),

            // List or Empty / Loading State
            if (provider.isLoading && provider.items.isEmpty)
              const SliverFillRemaining(
                child: ShimmerLoader(itemCount: 8),
              )
            else if (provider.items.isEmpty)
              SliverFillRemaining(
                child: _EmptyState(
                  onAdd: () => context.push('/instrument-search'),
                ),
              )
            else if (provider.filteredItems.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_list_off_rounded,
                          size: 48, color: AppColors.onSurfaceMuted.withAlpha(120)),
                      const SizedBox(height: 12),
                      const Text(
                        'No matching instruments found',
                        style: TextStyle(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            provider.setFilter(WatchlistFilter.all),
                        child: const Text('Clear Filter'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = provider.filteredItems[index];
                    return Dismissible(
                      key: ValueKey(item.instrumentToken),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        await _confirmDelete(context, item);
                        return false;
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: AppColors.sell.withAlpha(30),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.sell),
                      ),
                      child: Column(
                        children: [
                          _WatchlistRow(
                            item: item,
                            onTap: () => _openDetailSheet(context, item),
                            onLongPress: () => _confirmDelete(context, item),
                            onDelete: () => _confirmDelete(context, item),
                          ),
                          const Divider(
                              height: 1, color: AppColors.divider, indent: 16),
                        ],
                      ),
                    );
                  },
                  childCount: provider.filteredItems.length,
                ),
              ),

            // Bottom padding for FAB
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

class _WatchlistRow extends StatelessWidget {
  final WatchlistItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;

  const _WatchlistRow({
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Symbol + exchange
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.tradingsymbol,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (item.exchange.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.exchange,
                        style: const TextStyle(
                            color: AppColors.onSurfaceMuted, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            // Price + PnL / Day Change
            if (item.isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            else if (item.lastPrice <= 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '₹ --',
                    style: TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant2,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Awaiting Feed',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.onSurfaceMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  LiveTickerPrice(
                    price: item.lastPrice,
                    previousPrice: item.previousPrice,
                    direction: item.priceDirection,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.change >= 0
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                        size: 14,
                        color:
                            item.change >= 0 ? AppColors.buy : AppColors.sell,
                      ),
                      Text(
                        '${item.change >= 0 ? '+' : ''}${fmt.format(item.change)} (${item.changePercent >= 0 ? '+' : ''}${item.changePercent.toStringAsFixed(2)}%)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: item.change >= 0
                              ? AppColors.buy
                              : AppColors.sell,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded,
                    size: 16, color: AppColors.onSurfaceMuted),
                tooltip: 'Remove from Watchlist',
                onPressed: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChipsBar extends StatelessWidget {
  final WatchlistFilter currentFilter;
  final ValueChanged<WatchlistFilter> onSelectFilter;
  final int totalCount;
  final int gainersCount;
  final int losersCount;

  const _FilterChipsBar({
    required this.currentFilter,
    required this.onSelectFilter,
    required this.totalCount,
    required this.gainersCount,
    required this.losersCount,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _Chip(
            label: 'All ($totalCount)',
            isSelected: currentFilter == WatchlistFilter.all,
            onTap: () => onSelectFilter(WatchlistFilter.all),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Gainers ($gainersCount)',
            isSelected: currentFilter == WatchlistFilter.gainers,
            activeColor: AppColors.buy,
            onTap: () => onSelectFilter(WatchlistFilter.gainers),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Losers ($losersCount)',
            isSelected: currentFilter == WatchlistFilter.losers,
            activeColor: AppColors.sell,
            onTap: () => onSelectFilter(WatchlistFilter.losers),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'A-Z',
            isSelected: currentFilter == WatchlistFilter.alphabetical,
            onTap: () => onSelectFilter(WatchlistFilter.alphabetical),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? activeColor;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isSelected,
    this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(25) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.divider.withAlpha(60),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (activeColor ?? AppColors.primary)
                : AppColors.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_border_rounded,
                size: 72, color: AppColors.onSurfaceMuted),
            const SizedBox(height: 20),
            const Text(
              'Your watchlist is empty',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add instruments to track prices\nand get real-time signals',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceMuted, height: 1.6),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Instruments'),
            ),
          ],
        ),
      ),
    );
  }
}
