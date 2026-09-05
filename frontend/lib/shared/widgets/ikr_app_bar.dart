import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Standard IKR app bar with consistent styling.
class IkrAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;

  const IkrAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
    this.leading,
    this.bottom,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: centerTitle,
      automaticallyImplyLeading: showBack,
      leading: leading,
      actions: actions,
      bottom: bottom,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );
}

/// Orange gradient logo widget for splash / headers.
class IkrLogo extends StatelessWidget {
  final double size;

  const IkrLogo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.orangeGradient,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Icon(
        Icons.show_chart_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}

/// Section header used in settings and detail screens.
class SectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.fromLTRB(16, 24, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Status dot indicator (connected / disconnected).
class StatusDot extends StatelessWidget {
  final bool isActive;
  final String? label;

  const StatusDot({super.key, required this.isActive, this.label});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.buy : AppColors.onSurfaceMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [BoxShadow(color: color.withAlpha(100), blurRadius: 4)]
                : null,
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: 6),
          Text(
            label!,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// Side badge chip for BUY or SELL.
class SideBadge extends StatelessWidget {
  final String side;
  final bool compact;

  const SideBadge({super.key, required this.side, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isBuy = side.toUpperCase() == 'BUY';
    final color = isBuy ? AppColors.buy : AppColors.sell;
    final bgColor =
        isBuy ? AppColors.buy.withAlpha(25) : AppColors.sell.withAlpha(25);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        side.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Exchange label chip.
class ExchangeChip extends StatelessWidget {
  final String exchange;

  const ExchangeChip({super.key, required this.exchange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        exchange,
        style: TextStyle(
          color: AppColors.onSurfaceMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
