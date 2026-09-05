import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../model/order_models.dart';
import '../provider/orders_provider.dart';

/// Modal bottom sheet for placing Paper or Live trading orders.
class PlaceOrderSheet extends StatefulWidget {
  final int? instrumentToken;
  final String? tradingsymbol;
  final String? exchange;
  final double? lastPrice;

  const PlaceOrderSheet({
    super.key,
    this.instrumentToken,
    this.tradingsymbol,
    this.exchange,
    this.lastPrice,
  });

  @override
  State<PlaceOrderSheet> createState() => _PlaceOrderSheetState();
}

class _PlaceOrderSheetState extends State<PlaceOrderSheet> {
  bool _isPaper = true;
  String _side = 'BUY'; // 'BUY' | 'SELL'
  String _orderType = 'LIMIT'; // 'MARKET' | 'LIMIT'

  late final TextEditingController _tokenCtrl;
  late final TextEditingController _symbolCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _stopLossCtrl;

  bool _isLoading = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _tokenCtrl = TextEditingController(
      text: widget.instrumentToken?.toString() ?? '',
    );
    _symbolCtrl = TextEditingController(
      text: widget.tradingsymbol ?? '',
    );
    _qtyCtrl = TextEditingController(text: '1');
    _priceCtrl = TextEditingController(
      text: widget.lastPrice != null ? widget.lastPrice!.toStringAsFixed(2) : '',
    );
    _stopLossCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _symbolCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _stopLossCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    final token = int.tryParse(_tokenCtrl.text.trim());
    if (token == null || token <= 0) {
      setState(() => _inlineError = 'Please enter a valid instrument token.');
      return;
    }

    final qty = int.tryParse(_qtyCtrl.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _inlineError = 'Quantity must be at least 1.');
      return;
    }

    double? price;
    if (_orderType == 'LIMIT') {
      price = double.tryParse(_priceCtrl.text.trim());
      if (price == null || price <= 0) {
        setState(() => _inlineError = 'Please enter a valid limit price.');
        return;
      }
    }

    double? stopLoss;
    if (_stopLossCtrl.text.trim().isNotEmpty) {
      stopLoss = double.tryParse(_stopLossCtrl.text.trim());
    }

    setState(() {
      _isLoading = true;
      _inlineError = null;
    });

    final request = OrderRequest(
      instrumentToken: token,
      side: _side,
      orderType: _orderType,
      quantity: qty,
      price: price,
      stopLoss: stopLoss,
      idempotencyKey: 'ikr-${DateTime.now().millisecondsSinceEpoch}',
    );

    final ordersProvider = context.read<OrdersProvider>();

    if (_isPaper) {
      final result = await ordersProvider.placePaperOrder(request);
      if (!mounted) return;
      setState(() => _isLoading = false);

      result.fold(
        onSuccess: (order) {
          Navigator.of(context).pop();
          showSuccessSnackbar(
            context,
            'Paper order placed: ${order.side} ${order.quantity} @ ${order.price.toStringAsFixed(2)}',
          );
        },
        onFailure: (failure) {
          setState(() => _inlineError = failure.message);
        },
      );
    } else {
      final result = await ordersProvider.placeLiveOrder(request);
      if (!mounted) return;
      setState(() => _isLoading = false);

      result.fold(
        onSuccess: (order) {
          Navigator.of(context).pop();
          showSuccessSnackbar(
            context,
            'Live order submitted (ID: ${order.brokerOrderId ?? order.id})',
          );
        },
        onFailure: (failure) {
          setState(() => _inlineError = failure.message);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isBuy = _side == 'BUY';

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.onSurfaceSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header row with symbol and Paper/Live toggle
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _symbolCtrl.text.isNotEmpty
                            ? _symbolCtrl.text
                            : 'New Order',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      if (widget.exchange != null)
                        Text(
                          widget.exchange!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                // Paper / Live toggle
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isPaper = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isPaper
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'PAPER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isPaper
                                  ? Colors.white
                                  : AppColors.onSurfaceMuted,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isPaper = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: !_isPaper
                                ? AppColors.warning
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: !_isPaper
                                  ? Colors.black
                                  : AppColors.onSurfaceMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // BUY / SELL segmented button
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isBuy
                          ? AppColors.buy
                          : AppColors.surfaceVariant2,
                      foregroundColor: isBuy
                          ? Colors.white
                          : AppColors.onSurfaceMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => setState(() => _side = 'BUY'),
                    child: const Text(
                      'BUY',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: !isBuy
                          ? AppColors.sell
                          : AppColors.surfaceVariant2,
                      foregroundColor: !isBuy
                          ? Colors.white
                          : AppColors.onSurfaceMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => setState(() => _side = 'SELL'),
                    child: const Text(
                      'SELL',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Order type (MARKET / LIMIT)
            Row(
              children: [
                const Text(
                  'Type:',
                  style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('LIMIT'),
                  selected: _orderType == 'LIMIT',
                  onSelected: (val) {
                    if (val) setState(() => _orderType = 'LIMIT');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('MARKET'),
                  selected: _orderType == 'MARKET',
                  onSelected: (val) {
                    if (val) setState(() => _orderType = 'MARKET');
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Instrument token (if not prefilled)
            if (widget.instrumentToken == null) ...[
              TextField(
                controller: _tokenCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Instrument Token',
                  hintText: 'e.g. 738561',
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Quantity and Price row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      hintText: '1',
                    ),
                  ),
                ),
                if (_orderType == 'LIMIT') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price (₹)',
                        hintText: '0.00',
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Stop Loss (Optional)
            TextField(
              controller: _stopLossCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Stop Loss (Optional)',
                hintText: 'Trigger price',
              ),
            ),
            const SizedBox(height: 14),

            // Inline error if any
            if (_inlineError != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.sell.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.sell.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: AppColors.sell,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _inlineError!,
                        style: const TextStyle(
                          color: AppColors.sell,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Submit button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isBuy ? AppColors.buy : AppColors.sell,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isLoading ? null : _submitOrder,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      '${_isPaper ? "Place Paper" : "Place Live"} $_side Order',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
