import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/pnl_chip.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../data/watchlist_api.dart';
import '../model/watchlist_models.dart';
import '../provider/watchlist_provider.dart';
import '../widgets/live_ticker_price.dart';
import '../widgets/indicator_guide_sheet.dart';
import '../widgets/signal_strength_slider.dart';
import '../../orders/model/order_models.dart';
import '../../orders/provider/orders_provider.dart';

// ── Indicator / Signal models ─────────────────────────────────────────────

class _IndicatorData {
  final double ema9;
  final double ema20;
  final double vwap;
  final double rsi14;
  final double macdLine;
  final double macdSignal;
  final double superTrend;
  final double atr14;

  const _IndicatorData({
    required this.ema9,
    required this.ema20,
    required this.vwap,
    required this.rsi14,
    required this.macdLine,
    required this.macdSignal,
    this.superTrend = 0.0,
    this.atr14 = 0.0,
  });

  factory _IndicatorData.fromJson(Map<String, dynamic> json) {
    return _IndicatorData(
      ema9: (json['ema9'] as num?)?.toDouble() ?? 0.0,
      ema20: (json['ema20'] as num?)?.toDouble() ?? 0.0,
      vwap: (json['vwap'] as num?)?.toDouble() ?? 0.0,
      rsi14: (json['rsi14'] as num?)?.toDouble() ?? 0.0,
      macdLine: (json['macd'] as num?)?.toDouble() ??
          (json['macdLine'] as num?)?.toDouble() ??
          (json['macd_line'] as num?)?.toDouble() ??
          0.0,
      macdSignal: (json['macdSignal'] as num?)?.toDouble() ??
          (json['macd_signal'] as num?)?.toDouble() ??
          0.0,
      superTrend: (json['superTrend'] as num?)?.toDouble() ??
          (json['super_trend'] as num?)?.toDouble() ??
          0.0,
      atr14: (json['atr14'] as num?)?.toDouble() ??
          (json['atr_14'] as num?)?.toDouble() ??
          0.0,
    );
  }
}

enum _SignalType { buy, sell, neutral }

// ── Main bottom sheet ─────────────────────────────────────────────────────

class InstrumentDetailSheet extends StatefulWidget {
  final WatchlistItem item;

  const InstrumentDetailSheet({super.key, required this.item});

  @override
  State<InstrumentDetailSheet> createState() => _InstrumentDetailSheetState();
}

class _InstrumentDetailSheetState extends State<InstrumentDetailSheet> {
  _IndicatorData? _indicators;
  _SignalType _signal = _SignalType.neutral;
  String _strategySignalStr = 'NEUTRAL';
  bool _isLoadingIndicators = true;
  String? _indicatorError;
  bool _isFetchingHistory = false;

  @override
  void initState() {
    super.initState();
    _fetchIndicators();
  }

  Future<void> _fetchIndicators() async {
    if (mounted) {
      setState(() {
        _isLoadingIndicators = true;
        _indicatorError = null;
      });
    }
    final dioClient = context.read<DioClient>();
    try {
      final response = await dioClient.get(
        '/api/v1/indicators/latest',
        queryParameters: {
          'instrumentToken': widget.item.instrumentToken,
          'timeframe': '5minute',
        },
      );
      final data = response.data as Map<String, dynamic>;
      final indicators = _IndicatorData.fromJson(data);
      _SignalType signal = _SignalType.neutral;
      String strategySignal = 'NEUTRAL';

      // Fetch EMA crossover signal
      try {
        final signalResp = await dioClient.get(
          '/api/v1/strategies/ema-crossover/signal',
          queryParameters: {
            'instrumentToken': widget.item.instrumentToken,
            'timeframe': '5minute',
          },
        );
        final signalData = signalResp.data as Map<String, dynamic>;
        final signalStr =
            signalData['signal']?.toString().toUpperCase() ?? 'NONE';
        strategySignal = signalStr;
        if (signalStr == 'BUY') signal = _SignalType.buy;
        if (signalStr == 'SELL') signal = _SignalType.sell;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _indicators = indicators;
          _signal = signal;
          _strategySignalStr = strategySignal;
          _isLoadingIndicators = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _indicatorError = mapDioError(e).message;
          _isLoadingIndicators = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _indicatorError = 'Failed to load indicators';
          _isLoadingIndicators = false;
        });
      }
    }
  }

  Future<void> _autoFetchHistory() async {
    if (_isFetchingHistory) return;
    setState(() => _isFetchingHistory = true);

    try {
      final dioClient = context.read<DioClient>();
      final api = WatchlistApi(dioClient: dioClient);

      final result = await api.fetchAndStoreHistoricalCandles(
        widget.item.instrumentToken,
        interval: '5minute',
        daysBack: 21,
      );

      if (!mounted) return;

      switch (result) {
        case Success(:final data):
          showSuccessSnackbar(
            context,
            'Synced ${data.length} 5-min candles for ${widget.item.tradingsymbol}. Indicators updated!',
          );
          await _fetchIndicators();
        case Failure(:final failure):
          final errorMsg = failure.message;
          if (errorMsg.toLowerCase().contains('kite') &&
              (errorMsg.toLowerCase().contains('not connected') ||
                  errorMsg.toLowerCase().contains('connect'))) {
            _showKiteConnectDialog();
          } else {
            showErrorSnackbar(context, errorMsg);
          }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(context, 'Failed to fetch historical data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingHistory = false);
      }
    }
  }

  void _showKiteConnectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: const Row(
          children: [
            Icon(Icons.link_off_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text(
              'Kite Not Connected',
              style: TextStyle(color: AppColors.onSurface, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Zerodha Kite account is required to fetch historical candle data from Kite Connect API. Would you like to connect your Kite account now?',
          style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.onSurfaceMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/kite-connect');
            },
            child: const Text('Connect Kite'),
          ),
        ],
      ),
    );
  }

  void _showPlaceOrderSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaceOrderSheet(item: widget.item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final liveItems = context.watch<WatchlistProvider>().items;
    final item = liveItems.firstWhere(
      (i) => i.instrumentToken == widget.item.instrumentToken,
      orElse: () => widget.item,
    );

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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header: Symbol + Exchange
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.tradingsymbol,
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (item.exchange.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant2,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.exchange,
                                style: const TextStyle(
                                    color: AppColors.onSurfaceMuted,
                                    fontSize: 11),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _signalBadge(_signal),
                ],
              ),

              const SizedBox(height: 16),

              // Price row with Live Flash
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  LiveTickerPrice(
                    price: item.lastPrice,
                    previousPrice: item.previousPrice,
                    direction: item.priceDirection,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child:
                        PnlChip(value: item.changePercent, showPercent: true),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Text(
                  '${item.change >= 0 ? '+' : ''}${fmt.format(item.change)} today',
                  style: TextStyle(
                    color: item.change >= 0 ? AppColors.buy : AppColors.sell,
                    fontSize: 13,
                  ),
                ),
              ),

              if (_indicators != null) ...[
                const SizedBox(height: 16),
                SignalStrengthSlider(
                  summary: IndicatorSignalSummary.compute(
                    lastPrice: item.lastPrice,
                    ema9: _indicators!.ema9,
                    ema20: _indicators!.ema20,
                    vwap: _indicators!.vwap,
                    rsi14: _indicators!.rsi14,
                    macdLine: _indicators!.macdLine,
                    macdSignal: _indicators!.macdSignal,
                    superTrend: _indicators!.superTrend,
                    strategySignal: _strategySignalStr,
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 16),

              // Indicators panel
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'INDICATORS · 5MIN',
                        style: TextStyle(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: AppColors.onSurfaceMuted,
                        ),
                        tooltip: 'Indicator & Signal Guide',
                        onPressed: () => showIndicatorGuideSheet(context),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _isFetchingHistory ? null : _autoFetchHistory,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                    ),
                    icon: _isFetchingHistory
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.sync_rounded,
                            size: 14, color: AppColors.primary),
                    label: Text(
                      _isFetchingHistory ? 'Syncing...' : 'Sync 5m History',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_isLoadingIndicators)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
                  ),
                )
              else if (_indicatorError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.candlestick_chart_outlined,
                        size: 30,
                        color: AppColors.onSurfaceMuted,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _indicatorError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _isFetchingHistory ? null : _autoFetchHistory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary.withAlpha(30),
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                        icon: _isFetchingHistory
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Icon(Icons.cloud_download_rounded,
                                size: 16),
                        label: Text(
                          _isFetchingHistory
                              ? 'Fetching 5m History...'
                              : 'Auto-Fetch 5m History & Signals',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_indicators != null)
                _IndicatorPanel(
                  indicators: _indicators!,
                  lastPrice: item.lastPrice,
                ),

              const SizedBox(height: 24),

              // Action buttons: Auto-Fetch 5m + Paper Trade
              Row(
                children: [
                  // Expanded(
                  //   child: OutlinedButton.icon(
                  //     onPressed: _isFetchingHistory ? null : _autoFetchHistory,
                  //     icon: _isFetchingHistory
                  //         ? const SizedBox(
                  //             width: 14,
                  //             height: 14,
                  //             child: CircularProgressIndicator(
                  //               strokeWidth: 2,
                  //               color: AppColors.primary,
                  //             ),
                  //           )
                  //         : const Icon(Icons.cloud_download_outlined, size: 18),
                  //     label: Text(
                  //         _isFetchingHistory ? 'Syncing...' : 'Auto-Fetch 5m'),
                  //   ),
                  // ),
                  // const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showPlaceOrderSheet,
                      icon: const Icon(Icons.add_chart_rounded, size: 18),
                      label: const Text('Paper Trade'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _signalBadge(_SignalType signal) {
    Color color;
    String label;
    switch (signal) {
      case _SignalType.buy:
        color = AppColors.buy;
        label = 'BUY';
        break;
      case _SignalType.sell:
        color = AppColors.sell;
        label = 'SELL';
        break;
      case _SignalType.neutral:
        color = AppColors.onSurfaceMuted;
        label = 'NEUTRAL';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }
}

// ── Indicator panel widget ────────────────────────────────────────────────

class _IndicatorPanel extends StatelessWidget {
  final _IndicatorData indicators;
  final double lastPrice;

  const _IndicatorPanel({
    required this.indicators,
    required this.lastPrice,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    // 1. EMA 9 vs EMA 20
    final emaAction = indicators.ema9 > 0 && indicators.ema20 > 0
        ? (indicators.ema9 > indicators.ema20
            ? SignalAction.buy
            : (indicators.ema9 < indicators.ema20
                ? SignalAction.sell
                : SignalAction.neutral))
        : SignalAction.neutral;

    // 2. Price vs VWAP
    final vwapAction = lastPrice > 0 && indicators.vwap > 0
        ? (lastPrice > indicators.vwap
            ? SignalAction.buy
            : (lastPrice < indicators.vwap
                ? SignalAction.sell
                : SignalAction.neutral))
        : SignalAction.neutral;

    // 3. RSI 14
    final rsiAction = indicators.rsi14 > 0
        ? (indicators.rsi14 < 30 || (indicators.rsi14 >= 50 && indicators.rsi14 < 70)
            ? SignalAction.buy
            : (indicators.rsi14 > 70 || (indicators.rsi14 > 30 && indicators.rsi14 < 50)
                ? SignalAction.sell
                : SignalAction.neutral))
        : SignalAction.neutral;

    // 4. MACD vs Signal
    final macdAction = indicators.macdLine != 0 || indicators.macdSignal != 0
        ? (indicators.macdLine > indicators.macdSignal
            ? SignalAction.buy
            : (indicators.macdLine < indicators.macdSignal
                ? SignalAction.sell
                : SignalAction.neutral))
        : SignalAction.neutral;

    // 5. SuperTrend
    final superTrendAction = indicators.superTrend > 0 && lastPrice > 0
        ? (lastPrice >= indicators.superTrend
            ? SignalAction.buy
            : SignalAction.sell)
        : SignalAction.neutral;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _IndicatorTile(
          label: 'EMA 9',
          value: fmt.format(indicators.ema9),
          color: AppColors.ema9,
          signalAction: emaAction,
        ),
        _IndicatorTile(
          label: 'EMA 20',
          value: fmt.format(indicators.ema20),
          color: AppColors.ema20,
          signalAction: emaAction,
        ),
        _IndicatorTile(
          label: 'VWAP',
          value: fmt.format(indicators.vwap),
          color: AppColors.vwap,
          signalAction: vwapAction,
        ),
        _IndicatorTile(
          label: 'RSI 14',
          value: indicators.rsi14.toStringAsFixed(1),
          color: indicators.rsi14 > 70
              ? AppColors.sell
              : indicators.rsi14 < 30
                  ? AppColors.buy
                  : AppColors.onSurface,
          signalAction: rsiAction,
        ),
        _IndicatorTile(
          label: 'MACD',
          value: indicators.macdLine.toStringAsFixed(2),
          color: indicators.macdLine > indicators.macdSignal
              ? AppColors.buy
              : AppColors.sell,
          signalAction: macdAction,
        ),
        _IndicatorTile(
          label: 'Signal',
          value: indicators.macdSignal.toStringAsFixed(2),
          color: AppColors.macdSignal,
          signalAction: macdAction,
        ),
        if (indicators.superTrend > 0)
          _IndicatorTile(
            label: 'SuperTrend',
            value: fmt.format(indicators.superTrend),
            color: AppColors.superTrend,
            signalAction: superTrendAction,
          ),
      ],
    );
  }
}

class _IndicatorTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final SignalAction signalAction;

  const _IndicatorTile({
    required this.label,
    required this.value,
    required this.color,
    this.signalAction = SignalAction.neutral,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color bgColor;
    Color tagColor;
    String tagLabel;
    IconData? tagIcon;

    switch (signalAction) {
      case SignalAction.buy:
        borderColor = AppColors.buy;
        bgColor = AppColors.buy.withAlpha(14);
        tagColor = AppColors.buy;
        tagLabel = 'BUY';
        tagIcon = Icons.arrow_upward_rounded;
        break;
      case SignalAction.sell:
        borderColor = AppColors.sell;
        bgColor = AppColors.sell.withAlpha(14);
        tagColor = AppColors.sell;
        tagLabel = 'SELL';
        tagIcon = Icons.arrow_downward_rounded;
        break;
      case SignalAction.neutral:
        borderColor = AppColors.divider;
        bgColor = AppColors.surfaceVariant2;
        tagColor = AppColors.onSurfaceMuted;
        tagLabel = '—';
        tagIcon = null;
        break;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final tileWidth = (screenWidth - 60) / 3;

    return Container(
      width: tileWidth > 90 ? tileWidth : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
          width: signalAction == SignalAction.neutral ? 1.0 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: tagColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tagIcon != null) ...[
                      Icon(tagIcon, size: 8, color: tagColor),
                      const SizedBox(width: 1),
                    ],
                    Text(
                      tagLabel,
                      style: TextStyle(
                        color: tagColor,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Place order bottom sheet ──────────────────────────────────────────────

class _PlaceOrderSheet extends StatefulWidget {
  final WatchlistItem item;
  const _PlaceOrderSheet({required this.item});

  @override
  State<_PlaceOrderSheet> createState() => _PlaceOrderSheetState();
}

class _PlaceOrderSheetState extends State<_PlaceOrderSheet> {
  String _transactionType = 'BUY';
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final fmt = NumberFormat('#0.00');
    _priceCtrl.text = fmt.format(widget.item.lastPrice);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;

    if (qty <= 0) {
      showErrorSnackbar(context, 'Enter a valid quantity');
      return;
    }
    if (price <= 0) {
      showErrorSnackbar(context, 'Enter a valid price');
      return;
    }

    setState(() => _isLoading = true);

    final request = OrderRequest(
      instrumentToken: widget.item.instrumentToken,
      side: _transactionType,
      orderType: 'LIMIT',
      quantity: qty,
      price: price,
      idempotencyKey: 'ikr-${DateTime.now().millisecondsSinceEpoch}',
    );

    final result =
        await context.read<OrdersProvider>().placePaperOrder(request);

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      onSuccess: (_) {
        showSuccessSnackbar(context,
            '$_transactionType order placed for ${widget.item.tradingsymbol}');
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      },
      onFailure: (f) => showErrorSnackbar(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBuy = _transactionType == 'BUY';

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Paper Trade · ${widget.item.tradingsymbol}',
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            // BUY / SELL toggle
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _TypeButton(
                    label: 'BUY',
                    isSelected: isBuy,
                    color: AppColors.buy,
                    onTap: () => setState(() => _transactionType = 'BUY'),
                  ),
                  _TypeButton(
                    label: 'SELL',
                    isSelected: !isBuy,
                    color: AppColors.sell,
                    onTap: () => setState(() => _transactionType = 'SELL'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.onSurface),
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppColors.onSurface),
                    decoration: const InputDecoration(labelText: 'Price (₹)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isBuy ? AppColors.buy : AppColors.sell,
                ),
                onPressed: _isLoading ? null : _placeOrder,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Place $_transactionType Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: color.withAlpha(80)) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : AppColors.onSurfaceMuted,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
