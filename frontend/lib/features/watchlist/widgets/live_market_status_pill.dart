import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/websocket/market_ws_service.dart';
import '../../kite/provider/kite_provider.dart';
import '../provider/watchlist_provider.dart';

/// Zerodha-style live market connection status indicator pill and diagnostics sheet.
class LiveMarketStatusPill extends StatefulWidget {
  const LiveMarketStatusPill({super.key});

  @override
  State<LiveMarketStatusPill> createState() => _LiveMarketStatusPillState();
}

class _LiveMarketStatusPillState extends State<LiveMarketStatusPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wsService = context.watch<MarketWsService>();
    final isConnected = wsService.isConnected;
    final isConnecting = wsService.state == WsConnectionState.connecting;

    final Color color;
    final String label;

    if (isConnected) {
      color = AppColors.buy;
      label = 'LIVE';
    } else if (isConnecting) {
      color = const Color(0xFFF59E0B);
      label = 'CONNECTING';
    } else {
      color = AppColors.sell;
      label = 'OFFLINE';
    }

    return GestureDetector(
      onTap: () => _showDiagnosticsSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: isConnected ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: isConnected
                          ? [
                              BoxShadow(
                                color: color.withAlpha(160),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiagnosticsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _MarketFeedDiagnosticsSheet(),
    );
  }
}

class _MarketFeedDiagnosticsSheet extends StatefulWidget {
  const _MarketFeedDiagnosticsSheet();

  @override
  State<_MarketFeedDiagnosticsSheet> createState() =>
      _MarketFeedDiagnosticsSheetState();
}

class _MarketFeedDiagnosticsSheetState
    extends State<_MarketFeedDiagnosticsSheet> {
  bool _isReconnecting = false;

  Future<void> _handleReconnect(BuildContext context) async {
    setState(() => _isReconnecting = true);
    try {
      await context.read<WatchlistProvider>().reconnectWs();
    } finally {
      if (mounted) {
        setState(() => _isReconnecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<MarketWsService>();
    final watchlist = context.watch<WatchlistProvider>();
    final kite = context.watch<KiteProvider>();

    final timeFmt = DateFormat('hh:mm:ss a');
    final lastTickStr = ws.lastTickAt != null
        ? timeFmt.format(ws.lastTickAt!.toLocal())
        : 'None received yet';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Row(
                children: [
                  const Icon(Icons.hub_rounded,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Live Market Feed Status',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_isReconnecting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: AppColors.divider.withAlpha(60)),
              const SizedBox(height: 12),

              // Status rows
              _StatusRow(
                title: 'Internal WebSocket',
                value: ws.isConnected
                    ? 'CONNECTED'
                    : (ws.state == WsConnectionState.connecting
                        ? 'CONNECTING'
                        : 'DISCONNECTED'),
                color: ws.isConnected ? AppColors.buy : AppColors.sell,
                subtitle: 'Streaming quotes at /ws/market',
              ),
              const SizedBox(height: 12),

              _StatusRow(
                title: 'Zerodha Kite Ticker',
                value: kite.isConnected
                    ? (watchlist.kiteFeedStatus ?? 'CONNECTED')
                    : 'NOT LINKED',
                color: kite.isConnected ? AppColors.buy : const Color(0xFFF59E0B),
                subtitle: kite.isConnected
                    ? 'Live binary tick ingestion from Kite'
                    : 'Link account to stream broker ticks directly',
              ),
              const SizedBox(height: 12),

              _StatusRow(
                title: 'Subscribed Instruments',
                value: '${watchlist.allStreamingTokens.length} tokens',
                color: AppColors.onSurface,
                subtitle: 'Watchlist items + NIFTY 50 & SENSEX',
              ),
              const SizedBox(height: 12),

              _StatusRow(
                title: 'Last Tick Received',
                value: lastTickStr,
                color: AppColors.onSurface,
                subtitle: 'Real-time WebSocket heartbeat',
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isReconnecting
                          ? null
                          : () => _handleReconnect(context),
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: const Text('Reconnect Feed'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.divider),
                      ),
                    ),
                  ),
                  if (!kite.isConnected) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/kite-connect');
                        },
                        icon: const Icon(Icons.cable_rounded, size: 18),
                        label: const Text('Connect Kite'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final String subtitle;

  const _StatusRow({
    required this.title,
    required this.value,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withAlpha(60)),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
