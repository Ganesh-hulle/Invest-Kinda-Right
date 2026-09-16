import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../model/portfolio_models.dart';
import '../provider/portfolio_provider.dart';
import 'portfolio_detail_sheet.dart';

enum _ImpactDirectionFilter { all, gainers, draggers }

/// Modal bottom drawer displaying real-time Day's P&L attribution and ranking.
class PnlImpactDrawer extends StatefulWidget {
  final int initialScopeTab;

  const PnlImpactDrawer({
    super.key,
    this.initialScopeTab = 0,
  });

  /// Opens the P&L Impact Drawer as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    int initialScopeTab = 0,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => PnlImpactDrawer(initialScopeTab: initialScopeTab),
    );
  }

  @override
  State<PnlImpactDrawer> createState() => _PnlImpactDrawerState();
}

class _PnlImpactDrawerState extends State<PnlImpactDrawer> {
  late int _selectedScopeTab;
  _ImpactDirectionFilter _directionFilter = _ImpactDirectionFilter.all;

  final _currencyFmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    // Clamp initial tab to 0..3 (0: Holdings, 1: Net Positions, 2: Day Positions, 3: All)
    _selectedScopeTab = widget.initialScopeTab.clamp(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxSheetHeight = screenHeight * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: context.colors.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Consumer<PortfolioProvider>(
        builder: (context, provider, _) {
          final summary =
              provider.getImpactSummary(tabIndex: _selectedScopeTab);
          final filteredItems = _filterItems(summary.items);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Drag handle & Header
              _buildHeader(context),

              // 2. Scope selector tabs (Holdings | Net Positions | Day Positions | All)
              _buildScopeSelector(),

              const SizedBox(height: 12),

              // 3. Scrollable content (Macro Hero + Filters + List of Movers)
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  shrinkWrap: true,
                  children: [
                    // Macro Hero Card (Net Day P&L, Tug-of-War Bar, Top Drivers)
                    _MacroHeroCard(
                      summary: summary,
                      fmt: _currencyFmt,
                    ),

                    const SizedBox(height: 16),

                    // Filter row: "All Movers" | "Top Gainers" | "Top Draggers"
                    _buildFilterRow(summary),

                    const SizedBox(height: 12),

                    // Instruments List
                    if (filteredItems.isEmpty)
                      _buildEmptyState()
                    else
                      ...List.generate(filteredItems.length, (index) {
                        final item = filteredItems[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ImpactTile(
                            item: item,
                            rank: index + 1,
                            fmt: _currencyFmt,
                            onTap: () => _onItemTap(context, item),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.divider.withAlpha(150),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pie_chart_outline_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Day's P&L Impact",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.colors.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Live pulse indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.buy.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: AppColors.buy.withAlpha(80), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: AppColors.buy,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.buy,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Real-time profit & loss contribution per instrument',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: context.colors.onSurfaceMuted,
                  size: 22,
                ),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScopeSelector() {
    final scopes = [
      'Holdings',
      'Net Positions',
      'Day Positions',
      'All Portfolio',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(scopes.length, (idx) {
          final isSelected = _selectedScopeTab == idx;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(scopes[idx]),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  setState(() => _selectedScopeTab = idx);
                }
              },
              selectedColor: AppColors.primary.withAlpha(35),
              backgroundColor: context.colors.surfaceVariant2,
              side: BorderSide(
                color: isSelected ? AppColors.primary : context.colors.divider,
                width: 1,
              ),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : context.colors.onSurfaceMuted,
              ),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFilterRow(PortfolioDayImpactSummary summary) {
    final gainersCount = summary.items.where((i) => i.dayPnl > 0).length;
    final draggersCount = summary.items.where((i) => i.dayPnl < 0).length;

    return Row(
      children: [
        Text(
          'Attribution Ranking',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.colors.onSurface,
          ),
        ),
        const Spacer(),
        _FilterTabButton(
          label: 'All (${summary.items.length})',
          isSelected: _directionFilter == _ImpactDirectionFilter.all,
          onTap: () =>
              setState(() => _directionFilter = _ImpactDirectionFilter.all),
        ),
        const SizedBox(width: 6),
        _FilterTabButton(
          label: 'Gainers ($gainersCount)',
          isSelected: _directionFilter == _ImpactDirectionFilter.gainers,
          activeColor: AppColors.buy,
          onTap: () =>
              setState(() => _directionFilter = _ImpactDirectionFilter.gainers),
        ),
        const SizedBox(width: 6),
        _FilterTabButton(
          label: 'Drags ($draggersCount)',
          isSelected: _directionFilter == _ImpactDirectionFilter.draggers,
          activeColor: AppColors.sell,
          onTap: () => setState(
              () => _directionFilter = _ImpactDirectionFilter.draggers),
        ),
      ],
    );
  }

  List<InstrumentImpact> _filterItems(List<InstrumentImpact> items) {
    switch (_directionFilter) {
      case _ImpactDirectionFilter.all:
        return items;
      case _ImpactDirectionFilter.gainers:
        return items.where((item) => item.dayPnl > 0).toList();
      case _ImpactDirectionFilter.draggers:
        return items.where((item) => item.dayPnl < 0).toList();
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.equalizer_rounded,
            size: 42,
            color: context.colors.onSurfaceMuted.withAlpha(120),
          ),
          const SizedBox(height: 12),
          Text(
            'No instruments found in this view',
            style: TextStyle(
              color: context.colors.onSurfaceMuted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _onItemTap(BuildContext context, InstrumentImpact item) {
    if (item.originalHolding != null) {
      PortfolioDetailSheet.show(context, holding: item.originalHolding);
    } else if (item.originalPosition != null) {
      PortfolioDetailSheet.show(context, position: item.originalPosition);
    } else {
      final queryParams = <String, String>{
        'symbol': item.tradingsymbol,
        'exchange': item.exchange,
      };
      if (item.instrumentToken != null) {
        queryParams['token'] = item.instrumentToken.toString();
      }
      context.push(
        Uri(path: '/candles', queryParameters: queryParams).toString(),
      );
    }
  }
}

// ── Filter Tab Button ─────────────────────────────────────────────────────────

class _FilterTabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? activeColor;
  final VoidCallback onTap;

  const _FilterTabButton({
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color.withAlpha(120) : context.colors.divider,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? color : context.colors.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}

// ── Macro Hero Card (Tug of War) ─────────────────────────────────────────────

class _MacroHeroCard extends StatelessWidget {
  final PortfolioDayImpactSummary summary;
  final NumberFormat fmt;

  const _MacroHeroCard({
    required this.summary,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isNetPositive = summary.netDayPnl >= 0;
    final isNetZero = summary.netDayPnl.abs() < 0.01;
    final netColor = isNetZero
        ? context.colors.onSurface
        : (isNetPositive ? AppColors.buy : AppColors.sell);
    final netSign = isNetPositive ? '+' : '-';

    final gainRatio = summary.gainRatio;
    final lossRatio = summary.lossRatio;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Net Day P&L
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TOTAL DAY'S P&L",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.colors.onSurfaceMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isNetZero
                        ? '₹0.00'
                        : '$netSign${fmt.format(summary.netDayPnl.abs())}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: netColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              // Net movement pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: netColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isNetPositive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 14,
                      color: netColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isNetPositive ? 'Net Gain' : 'Net Loss',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: netColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: context.colors.divider),
          const SizedBox(height: 14),

          // Tug of War: Gains vs Losses Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.buy,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Gains: +${fmt.format(summary.totalGrossGains)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.buy,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${(gainRatio * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.onSurfaceMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '(${(lossRatio * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.onSurfaceMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Losses: -${fmt.format(summary.totalGrossLosses)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sell,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.sell,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Tug-of-War animated split bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: summary.totalGrossGains == 0 &&
                      summary.totalGrossLosses == 0
                  ? Container(color: context.colors.divider)
                  : Row(
                      children: [
                        Flexible(
                          flex: (gainRatio * 1000).toInt().clamp(1, 1000),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.buy,
                                  AppColors.buyLight,
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          flex: (lossRatio * 1000).toInt().clamp(1, 1000),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.sellLight,
                                  AppColors.sell,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Top Highlights (Top Gainer & Top Dragger)
          if (summary.topGainer != null || summary.topDragger != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (summary.topGainer != null)
                  Expanded(
                    child: _DriverPill(
                      label: 'Top Driver',
                      symbol: summary.topGainer!.tradingsymbol,
                      amount: summary.topGainer!.dayPnl,
                      isGainer: true,
                      fmt: fmt,
                    ),
                  ),
                if (summary.topGainer != null && summary.topDragger != null)
                  const SizedBox(width: 10),
                if (summary.topDragger != null)
                  Expanded(
                    child: _DriverPill(
                      label: 'Top Drag',
                      symbol: summary.topDragger!.tradingsymbol,
                      amount: summary.topDragger!.dayPnl,
                      isGainer: false,
                      fmt: fmt,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DriverPill extends StatelessWidget {
  final String label;
  final String symbol;
  final double amount;
  final bool isGainer;
  final NumberFormat fmt;

  const _DriverPill({
    required this.label,
    required this.symbol,
    required this.amount,
    required this.isGainer,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final color = isGainer ? AppColors.buy : AppColors.sell;
    final sign = isGainer ? '+' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(
            isGainer
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: context.colors.onSurfaceMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  symbol,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$sign${fmt.format(amount.abs())}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Impact Tile with Real-time Proportional Fill Meter ────────────────────────

class _ImpactTile extends StatelessWidget {
  final InstrumentImpact item;
  final int rank;
  final NumberFormat fmt;
  final VoidCallback onTap;

  const _ImpactTile({
    required this.item,
    required this.rank,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = item.isPositive;
    final isZero = item.isZero;
    final color = isZero
        ? context.colors.onSurfaceMuted
        : (isPositive ? AppColors.buy : AppColors.sell);
    final sign = isPositive ? '+' : '-';
    final pctSign = isPositive ? '+' : '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surfaceVariant2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // ── Background Proportional Fill Meter ──
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final meterWidth =
                      (constraints.maxWidth * item.relativeRatio).clamp(
                    0.0,
                    constraints.maxWidth,
                  );

                  return Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      width: meterWidth,
                      decoration: BoxDecoration(
                        color: color.withAlpha(22),
                        border: Border(
                          left: BorderSide(
                            color: color,
                            width: 3.5,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Foreground Content ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Rank badge
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: context.colors.divider),
                    ),
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.colors.onSurfaceMuted,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Symbol, Exchange, Product & Qty
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.tradingsymbol,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(25),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                item.exchange,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: context.colors.surface,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                item.product,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.onSurfaceMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${item.quantity} Qty · LTP ${fmt.format(item.lastPrice)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Day P&L Amount & Contribution Badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isZero
                            ? '₹0.00'
                            : '$sign${fmt.format(item.dayPnl.abs())}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.contributionPercentage > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: color.withAlpha(20),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${item.contributionPercentage.toStringAsFixed(1)}% share',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            '$pctSign${item.dayChangePercentage.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
