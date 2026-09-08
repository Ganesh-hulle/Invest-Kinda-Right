import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../model/watchlist_models.dart';
import '../provider/watchlist_provider.dart';
import 'live_ticker_price.dart';

/// Zerodha-style dual index market bar (NIFTY 50 and SENSEX) displayed at the
/// top of the Watchlist screen.
class MarketIndicesBar extends StatelessWidget {
  const MarketIndicesBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WatchlistProvider>(
      builder: (context, provider, _) {
        final nifty = provider.nifty50;
        final sensex = provider.sensex;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider.withAlpha(80)),
          ),
          child: Row(
            children: [
              // NIFTY 50
              Expanded(
                child: _IndexCell(
                  item: nifty,
                  onTap: () => _openChart(context, nifty),
                ),
              ),
              // Subtle vertical divider
              Container(
                width: 1,
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: AppColors.divider.withAlpha(60),
              ),
              // SENSEX
              Expanded(
                child: _IndexCell(
                  item: sensex,
                  onTap: () => _openChart(context, sensex),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openChart(BuildContext context, WatchlistItem item) {
    context.push(
      '/candles?token=${item.instrumentToken}&symbol=${Uri.encodeComponent(item.tradingsymbol)}&exchange=${item.exchange}',
    );
  }
}

class _IndexCell extends StatelessWidget {
  final WatchlistItem item;
  final VoidCallback onTap;

  const _IndexCell({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final numFmt = NumberFormat('#,##0.00');
    final isPositive = item.change >= 0;
    final sign = isPositive ? '+' : '';
    final color = isPositive ? AppColors.buy : AppColors.sell;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Index Title & Exchange
            Row(
              children: [
                Flexible(
                  child: Text(
                    item.tradingsymbol,
                    style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  item.exchange,
                  style: TextStyle(
                    color: AppColors.onSurfaceMuted.withAlpha(140),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            // Live Price with Flash Animation
            LiveTickerPrice(
              price: item.lastPrice,
              previousPrice: item.previousPrice,
              direction: item.priceDirection,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            // Change and Percentage
            if (item.lastPrice > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    size: 14,
                    color: color,
                  ),
                  Text(
                    '$sign${numFmt.format(item.change)} ($sign${item.changePercent.toStringAsFixed(2)}%)',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
              Text(
                'Awaiting feed',
                style: TextStyle(
                  color: AppColors.onSurfaceMuted.withAlpha(120),
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
