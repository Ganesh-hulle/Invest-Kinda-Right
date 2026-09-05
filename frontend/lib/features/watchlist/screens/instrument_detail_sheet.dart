import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/pnl_chip.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../model/watchlist_models.dart';
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

  const _IndicatorData({
    required this.ema9,
    required this.ema20,
    required this.vwap,
    required this.rsi14,
    required this.macdLine,
    required this.macdSignal,
  });

  factory _IndicatorData.fromJson(Map<String, dynamic> json) {
    return _IndicatorData(
      ema9: (json['ema9'] as num?)?.toDouble() ?? 0.0,
      ema20: (json['ema20'] as num?)?.toDouble() ?? 0.0,
      vwap: (json['vwap'] as num?)?.toDouble() ?? 0.0,
      rsi14: (json['rsi14'] as num?)?.toDouble() ?? 0.0,
      macdLine: (json['macdLine'] as num?)?.toDouble() ??
          (json['macd_line'] as num?)?.toDouble() ??
          0.0,
      macdSignal: (json['macdSignal'] as num?)?.toDouble() ??
          (json['macd_signal'] as num?)?.toDouble() ??
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
  bool _isLoadingIndicators = true;
  String? _indicatorError;

  @override
  void initState() {
    super.initState();
    _fetchIndicators();
  }

  Future<void> _fetchIndicators() async {
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
        if (signalStr == 'BUY') signal = _SignalType.buy;
        if (signalStr == 'SELL') signal = _SignalType.sell;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _indicators = indicators;
          _signal = signal;
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
    final item = widget.item;

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

              // Price row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${fmt.format(item.lastPrice)}',
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 32,
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
              Text(
                '${item.change >= 0 ? '+' : ''}${fmt.format(item.change)} today',
                style: TextStyle(
                  color: item.change >= 0 ? AppColors.buy : AppColors.sell,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 24),
              Divider(color: AppColors.divider),
              const SizedBox(height: 16),

              // Indicators panel
              const Text(
                'INDICATORS · 5MIN',
                style: TextStyle(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoadingIndicators)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
                  ),
                )
              else if (_indicatorError != null)
                Center(
                  child: Text(
                    _indicatorError!,
                    style: const TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 13),
                  ),
                )
              else if (_indicators != null)
                _IndicatorPanel(indicators: _indicators!),

              const SizedBox(height: 24),

              // Paper Trade button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showPlaceOrderSheet,
                  icon: const Icon(Icons.add_chart_rounded),
                  label: const Text('Paper Trade'),
                ),
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
  const _IndicatorPanel({required this.indicators});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _IndicatorTile(
            label: 'EMA 9',
            value: fmt.format(indicators.ema9),
            color: AppColors.ema9),
        _IndicatorTile(
            label: 'EMA 20',
            value: fmt.format(indicators.ema20),
            color: AppColors.ema20),
        _IndicatorTile(
            label: 'VWAP',
            value: fmt.format(indicators.vwap),
            color: AppColors.vwap),
        _IndicatorTile(
          label: 'RSI 14',
          value: indicators.rsi14.toStringAsFixed(1),
          color: indicators.rsi14 > 70
              ? AppColors.sell
              : indicators.rsi14 < 30
                  ? AppColors.buy
                  : AppColors.onSurface,
        ),
        _IndicatorTile(
          label: 'MACD',
          value: indicators.macdLine.toStringAsFixed(2),
          color: indicators.macdLine > indicators.macdSignal
              ? AppColors.buy
              : AppColors.sell,
        ),
        _IndicatorTile(
          label: 'Signal',
          value: indicators.macdSignal.toStringAsFixed(2),
          color: AppColors.macdSignal,
        ),
      ],
    );
  }
}

class _IndicatorTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _IndicatorTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.onSurfaceMuted, fontSize: 10)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 14)),
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
