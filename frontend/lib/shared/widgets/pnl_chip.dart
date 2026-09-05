import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Reusable P&L chip that shows green for profit and red for loss.
class PnlChip extends StatelessWidget {
  final double value;
  final bool showPercent;
  final bool compact;

  const PnlChip({
    super.key,
    required this.value,
    this.showPercent = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = value >= 0;
    final color = isPositive ? AppColors.buy : AppColors.sell;
    final bgColor =
        isPositive ? AppColors.buy.withAlpha(25) : AppColors.sell.withAlpha(25);
    final icon = isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down;

    final text = showPercent
        ? '${isPositive ? '+' : ''}${value.toStringAsFixed(2)}%'
        : '${isPositive ? '+' : ''}₹${value.abs().toStringAsFixed(2)}';

    if (compact) {
      return Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
