import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../model/watchlist_models.dart';

/// Zerodha-style live price ticker with smooth green/red flash animation
/// on price changes.
class LiveTickerPrice extends StatefulWidget {
  final double price;
  final double? previousPrice;
  final PriceDirection direction;
  final TextStyle? style;
  final bool showCurrency;

  const LiveTickerPrice({
    super.key,
    required this.price,
    this.previousPrice,
    this.direction = PriceDirection.none,
    this.style,
    this.showCurrency = true,
  });

  @override
  State<LiveTickerPrice> createState() => _LiveTickerPriceState();
}

class _LiveTickerPriceState extends State<LiveTickerPrice>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Color _flashColor = Colors.transparent;
  final _numberFormat = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant LiveTickerPrice oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.price != oldWidget.price && widget.price > 0 && oldWidget.price > 0) {
      if (widget.price > oldWidget.price) {
        _triggerFlash(AppColors.buy);
      } else if (widget.price < oldWidget.price) {
        _triggerFlash(AppColors.sell);
      }
    } else if (widget.direction != PriceDirection.none &&
        widget.direction != oldWidget.direction) {
      if (widget.direction == PriceDirection.up) {
        _triggerFlash(AppColors.buy);
      } else if (widget.direction == PriceDirection.down) {
        _triggerFlash(AppColors.sell);
      }
    }
  }

  void _triggerFlash(Color color) {
    _flashColor = color;
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final baseStyle = widget.style ??
        TextStyle(
          color: colors.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        );

    if (widget.price <= 0) {
      return Text(
        '₹ --',
        style: baseStyle.copyWith(color: colors.onSurfaceMuted),
      );
    }

    final priceStr = '${widget.showCurrency ? '₹' : ''}${_numberFormat.format(widget.price)}';

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = _animation.value;
        final isAnimating = _controller.isAnimating;

        // Subtle background tint that smoothly fades out
        final bgColor = isAnimating
            ? Color.lerp(_flashColor.withAlpha(50), Colors.transparent, progress)
            : Colors.transparent;

        // Price text color flashes green/red then blends back to normal
        final textColor = isAnimating
            ? Color.lerp(_flashColor, baseStyle.color ?? colors.onSurface, progress)
            : baseStyle.color ?? colors.onSurface;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            priceStr,
            style: baseStyle.copyWith(
              color: textColor,
              fontWeight: isAnimating ? FontWeight.w800 : baseStyle.fontWeight,
            ),
          ),
        );
      },
    );
  }
}
