import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pnl_chip.dart';
import '../../orders/screens/place_order_sheet.dart';
import '../model/portfolio_models.dart';

/// Modal bottom sheet displaying detailed stats for a holding or position item.
class PortfolioDetailSheet extends StatelessWidget {
  final int? instrumentToken;
  final String tradingsymbol;
  final String exchange;
  final String product;
  final int quantity;
  final double averagePrice;
  final double lastPrice;
  final double pnl;

  const PortfolioDetailSheet({
    super.key,
    this.instrumentToken,
    required this.tradingsymbol,
    required this.exchange,
    required this.product,
    required this.quantity,
    required this.averagePrice,
    required this.lastPrice,
    required this.pnl,
  });

  factory PortfolioDetailSheet.fromHolding(HoldingItem holding) {
    return PortfolioDetailSheet(
      instrumentToken: holding.instrumentToken,
      tradingsymbol: holding.tradingsymbol,
      exchange: holding.exchange,
      product: 'CNC',
      quantity: holding.quantity,
      averagePrice: holding.averagePrice,
      lastPrice: holding.lastPrice,
      pnl: holding.pnl,
    );
  }

  factory PortfolioDetailSheet.fromPosition(PositionItem position) {
    return PortfolioDetailSheet(
      instrumentToken: position.instrumentToken,
      tradingsymbol: position.tradingsymbol,
      exchange: position.exchange,
      product: position.product.isNotEmpty ? position.product : 'MIS',
      quantity: position.quantity,
      averagePrice: position.averagePrice,
      lastPrice: position.lastPrice,
      pnl: position.pnl,
    );
  }

  static void show(BuildContext context, {HoldingItem? holding, PositionItem? position}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        if (holding != null) {
          return PortfolioDetailSheet.fromHolding(holding);
        } else if (position != null) {
          return PortfolioDetailSheet.fromPosition(position);
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final invested = quantity * averagePrice;
    final currentValue = quantity * lastPrice;
    final pnlPercent = invested != 0 ? (pnl / invested.abs()) * 100 : 0.0;
    final isProfit = pnl >= 0;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header: Symbol, Exchange & Product tags
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tradingsymbol,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.colors.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            exchange.isNotEmpty ? exchange : 'NSE',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.colors.surfaceVariant2,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: context.colors.divider),
                          ),
                          child: Text(
                            product,
                            style: TextStyle(
                              fontSize: 10,
                              color: context.colors.onSurfaceMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: context.colors.onSurfaceMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Divider(height: 1, color: context.colors.divider),
          const SizedBox(height: 16),

          // Price & P&L Hero section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LAST TRADED PRICE',
                    style: TextStyle(
                      color: context.colors.onSurfaceMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${fmt.format(lastPrice)}',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: context.colors.onSurface,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'TOTAL P&L',
                    style: TextStyle(
                      color: context.colors.onSurfaceMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PnlChip(value: pnl),
                      const SizedBox(width: 6),
                      Text(
                        '(${isProfit ? '+' : ''}${pnlPercent.toStringAsFixed(2)}%)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isProfit ? AppColors.buy : AppColors.sell,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 2x2 Metric Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.divider),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _DetailMetric(
                      label: 'Quantity',
                      value: quantity.toString(),
                    ),
                    _DetailMetric(
                      label: 'Avg. Buy Price',
                      value: '₹${fmt.format(averagePrice)}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _DetailMetric(
                      label: 'Invested Amount',
                      value: '₹${fmt.format(invested)}',
                    ),
                    _DetailMetric(
                      label: 'Current Value',
                      value: '₹${fmt.format(currentValue)}',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    final queryParams = <String, String>{
                      'symbol': tradingsymbol,
                      'exchange': exchange,
                    };
                    if (instrumentToken != null) {
                      queryParams['token'] = instrumentToken.toString();
                    }
                    context.push(
                      Uri(path: '/candles', queryParameters: queryParams).toString(),
                    );
                  },
                  icon: const Icon(Icons.show_chart_rounded, size: 18),
                  label: const Text('Chart & Stats'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => PlaceOrderSheet(
                        tradingsymbol: tradingsymbol,
                        exchange: exchange,
                        lastPrice: lastPrice,
                      ),
                    );
                  },
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('Trade'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  final String label;
  final String value;

  const _DetailMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: context.colors.onSurfaceMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
