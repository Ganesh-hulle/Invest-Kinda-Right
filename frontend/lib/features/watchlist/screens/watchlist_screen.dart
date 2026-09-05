import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/pnl_chip.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../model/watchlist_models.dart';
import '../provider/watchlist_provider.dart';
import 'instrument_detail_sheet.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  Future<void> _onRefresh() async {
    await context.read<WatchlistProvider>().refreshQuotes();
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Watchlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _onRefresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/instrument-search'),
        child: const Icon(Icons.add_rounded),
      ),
      body: Consumer<WatchlistProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.items.isEmpty) {
            return const ShimmerLoader(itemCount: 8);
          }

          if (provider.items.isEmpty) {
            return _EmptyState(onAdd: () => context.push('/instrument-search'));
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _onRefresh,
            child: ListView.separated(
              itemCount: provider.items.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, index) {
                final item = provider.items[index];
                return Dismissible(
                  key: ValueKey(item.instrumentToken),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    await _confirmDelete(context, item);
                    return false; // We handle delete in the dialog
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: AppColors.sell.withAlpha(30),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.sell),
                  ),
                  child: _WatchlistRow(
                    item: item,
                    onTap: () => _openDetailSheet(context, item),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _WatchlistRow extends StatelessWidget {
  final WatchlistItem item;
  final VoidCallback onTap;

  const _WatchlistRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            // Price + PnL chip
            if (item.isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${fmt.format(item.lastPrice)}',
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  PnlChip(value: item.changePercent, showPercent: true),
                ],
              ),
          ],
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
            Icon(Icons.star_border_rounded,
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
