import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/websocket/market_ws_service.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../auth/provider/auth_provider.dart';
import '../../kite/provider/kite_provider.dart';
import '../../orders/provider/orders_provider.dart';
import '../../watchlist/provider/watchlist_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
  }

  Future<void> _initialLoad() async {
    if (!mounted) return;
    final kite = context.read<KiteProvider>();
    final orders = context.read<OrdersProvider>();
    await Future.wait([
      kite.checkConnectionStatus(),
      orders.fetchPaperOrders(),
    ]);
    if (!mounted) return;
    if (kite.isConnected) {
      await kite.fetchPortfolio();
    }
  }

  Future<void> _onRefresh() async {
    await _initialLoad();
    if (mounted) {
      await context.read<WatchlistProvider>().refreshQuotes();
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(context),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  _KiteConnectionBanner(),
                  _MarketStatusCard(),
                  const SizedBox(height: 16),
                  _PortfolioSummaryStrip(),
                  const SizedBox(height: 16),
                  _EmaSignalStrip(),
                  const SizedBox(height: 16),
                  _RecentOrdersCard(),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final greeting = _getGreeting();
        final username = auth.username;
        return SliverAppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          floating: true,
          snap: true,
          expandedHeight: 80,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Row(
              children: [
                // IKR Logo
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.candlestick_chart_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$greeting,',
                        style: const TextStyle(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        username,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Kite Connection Banner ────────────────────────────────────────────────

class _KiteConnectionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<KiteProvider>(
      builder: (context, kite, _) {
        if (kite.isConnected) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_off_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Connect your Zerodha account to enable live trading & portfolio sync.',
                    style: TextStyle(
                        color: AppColors.onSurface, fontSize: 13, height: 1.5),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => context.push('/kite-connect'),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Connect',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Market Status Card ────────────────────────────────────────────────────

class _MarketStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<MarketWsService>(
      builder: (context, ws, _) {
        final isConnected = ws.isConnected;
        final isConnecting = ws.state == WsConnectionState.connecting;
        final dotColor = isConnected
            ? AppColors.buy
            : isConnecting
                ? AppColors.warning
                : AppColors.onSurfaceMuted;
        final label = isConnected
            ? 'Live Feed Connected'
            : isConnecting
                ? 'Connecting...'
                : 'Feed Disconnected';

        return Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: isConnected
                        ? [
                            BoxShadow(
                                color: AppColors.buy.withAlpha(100),
                                blurRadius: 6)
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  DateFormat('HH:mm').format(DateTime.now()),
                  style: const TextStyle(
                      color: AppColors.onSurfaceMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Portfolio Summary Strip ───────────────────────────────────────────────

class _PortfolioSummaryStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<KiteProvider>(
      builder: (context, kite, _) {
        final fmt = NumberFormat('#,##0.00');

        if (!kite.isConnected) return const SizedBox.shrink();

        if (kite.isPortfolioLoading && kite.portfolio == null) {
          return Row(
            children: List.generate(
              3,
              (_) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ShimmerCard(height: 76),
                ),
              ),
            ),
          );
        }

        if (kite.portfolio == null) return const SizedBox.shrink();

        final p = kite.portfolio!;
        return Row(
          children: [
            _StatTile(label: 'Invested', value: '₹${fmt.format(p.invested)}'),
            const SizedBox(width: 8),
            _StatTile(
                label: 'Current', value: '₹${fmt.format(p.currentValue)}'),
            const SizedBox(width: 8),
            _StatTile(
              label: 'Day P&L',
              value: '₹${fmt.format(p.dayPnl.abs())}',
              valueColor: p.dayPnl >= 0 ? AppColors.buy : AppColors.sell,
              prefix: p.dayPnl >= 0 ? '+' : '-',
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final String prefix;

  const _StatTile({
    required this.label,
    required this.value,
    this.valueColor,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.onSurfaceMuted, fontSize: 11)),
            const SizedBox(height: 6),
            Text(
              '$prefix$value',
              style: TextStyle(
                color: valueColor ?? AppColors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── EMA Signal Strip ─────────────────────────────────────────────────────

class _EmaSignalStrip extends StatefulWidget {
  @override
  State<_EmaSignalStrip> createState() => _EmaSignalStripState();
}

class _EmaSignalStripState extends State<_EmaSignalStrip> {
  /// token → 'BUY' | 'SELL' | 'NONE'
  final Map<int, _SignalChipData> _signals = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchSignals());
  }

  Future<void> _fetchSignals() async {
    final watchlist = context.read<WatchlistProvider>();
    final tokens = watchlist.instrumentTokens;
    if (tokens.isEmpty) return;

    setState(() => _isLoading = true);

    final dioClient = context.read<DioClient>();

    for (final token in tokens) {
      final item = watchlist.items.firstWhere(
        (i) => i.instrumentToken == token,
        orElse: () => throw StateError('not found'),
      );
      try {
        final resp = await dioClient.get(
          '/api/v1/strategies/ema-crossover/signal',
          queryParameters: {'instrumentToken': token, 'timeframe': '5minute'},
        );
        final data = resp.data as Map<String, dynamic>;
        final signalStr = data['signal']?.toString().toUpperCase() ?? 'NONE';
        if (mounted) {
          setState(() {
            _signals[token] = _SignalChipData(
              symbol: item.tradingsymbol,
              signal: signalStr,
            );
          });
        }
      } on DioException catch (e) {
        debugPrint('[Dashboard] EMA signal error: ${mapDioError(e).message}');
        if (mounted) {
          setState(() {
            _signals[token] = _SignalChipData(
              symbol: item.tradingsymbol,
              signal: 'NONE',
            );
          });
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final watchlist = context.watch<WatchlistProvider>();
    final tokens = watchlist.instrumentTokens;

    if (tokens.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'EMA Signals', onRefresh: _fetchSignals),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: _isLoading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, __) => ShimmerCard(height: 40, width: 90),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tokens.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final token = tokens[index];
                    final chip = _signals[token];
                    if (chip == null) return const SizedBox(width: 80);
                    return _SignalChip(data: chip);
                  },
                ),
        ),
      ],
    );
  }
}

class _SignalChipData {
  final String symbol;
  final String signal; // 'BUY' | 'SELL' | 'NONE'
  const _SignalChipData({required this.symbol, required this.signal});
}

class _SignalChip extends StatelessWidget {
  final _SignalChipData data;
  const _SignalChip({required this.data});

  @override
  Widget build(BuildContext context) {
    final isBuy = data.signal == 'BUY';
    final isSell = data.signal == 'SELL';
    final color = isBuy
        ? AppColors.buy
        : isSell
            ? AppColors.sell
            : AppColors.onSurfaceMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.symbol,
            style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Text(
            data.signal,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── Recent Orders Card ────────────────────────────────────────────────────

class _RecentOrdersCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<OrdersProvider>(
      builder: (context, orders, _) {
        final recent = orders.recentOrders;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Recent Paper Orders',
              onAction: () => context.go('/orders'),
              actionLabel: 'See All',
            ),
            const SizedBox(height: 10),
            if (orders.isLoading && recent.isEmpty)
              const ShimmerLoader(itemCount: 3, itemHeight: 60)
            else if (recent.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Center(
                  child: Text(
                    'No recent orders',
                    style: TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 14),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: List.generate(recent.length, (i) {
                    final order = recent[i];
                    final isBuy = order.transactionType.toUpperCase() == 'BUY';
                    final color = isBuy ? AppColors.buy : AppColors.sell;
                    final fmt = NumberFormat('#,##0.00');
                    final timeFmt = DateFormat('HH:mm');
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withAlpha(25),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  order.transactionType,
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  order.tradingsymbol,
                                  style: const TextStyle(
                                    color: AppColors.onSurface,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                '₹${fmt.format(order.price)}',
                                style: const TextStyle(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeFmt.format(order.createdAt),
                                style: const TextStyle(
                                    color: AppColors.onSurfaceMuted,
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        if (i < recent.length - 1)
                          Divider(
                              height: 1,
                              color: AppColors.divider,
                              indent: 14,
                              endIndent: 14),
                      ],
                    );
                  }),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Shared section header ─────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onRefresh;
  final VoidCallback? onAction;
  final String actionLabel;

  const _SectionHeader({
    required this.title,
    this.onRefresh,
    this.onAction,
    this.actionLabel = 'Refresh',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (onRefresh != null)
          GestureDetector(
            onTap: onRefresh,
            child: const Icon(Icons.refresh_rounded,
                color: AppColors.onSurfaceMuted, size: 18),
          ),
        if (onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel, style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
  }
}
