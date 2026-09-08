import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../../kite/provider/kite_provider.dart';
import '../data/analytics_api.dart';
import '../model/analytics_models.dart';

/// Fullscreen interactive candlestick chart supporting landscape & portrait orientation,
/// indicators (EMA9, EMA20, VWAP), volume bars, crosshair, and pulling historical data from Kite.
class CandleChartScreen extends StatefulWidget {
  final int? instrumentToken;
  final String tradingsymbol;
  final String exchange;

  const CandleChartScreen({
    super.key,
    this.instrumentToken,
    required this.tradingsymbol,
    this.exchange = 'NSE',
  });

  @override
  State<CandleChartScreen> createState() => _CandleChartScreenState();
}

class _CandleChartScreenState extends State<CandleChartScreen> {
  late AnalyticsApi _api;
  int? _token;
  String _selectedTimeframe = '5minute';
  bool _isLoading = false;
  String? _errorMessage;

  List<CandleData> _candles = [];
  bool _isKiteData = false;
  int _kiteCandlesCount = 0;

  // Indicator overlay toggles
  bool _showEma9 = true;
  bool _showEma20 = true;
  bool _showVwap = true;
  bool _showVolume = true;

  // Crosshair state
  int? _hoveredIndex;
  Offset? _touchPosition;

  // Pan & Zoom state
  double _scale = 1.0;
  double _panOffset = 0.0;
  final double _baseCandleWidth = 8.0;

  bool _isLandscape = false;

  final List<String> _timeframes = [
    '1minute',
    '3minute',
    '5minute',
    '15minute',
    '30minute',
    '60minute',
    'day',
  ];

  @override
  void initState() {
    super.initState();
    _token = widget.instrumentToken;
    _api = AnalyticsApi(dioClient: context.read<DioClient>());

    // Enable landscape and portrait for the candles screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  @override
  void dispose() {
    // Restore strict portrait orientation for the rest of the app
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
      if (_isLandscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    });
  }

  Future<void> _initData() async {
    // If token is missing, search to resolve token from tradingsymbol
    if (_token == null) {
      try {
        final dio = context.read<DioClient>();
        final res = await dio.get(
          '/api/v1/instruments/search',
          queryParameters: {'query': widget.tradingsymbol},
        );
        final list = res.data is List ? res.data as List : [];
        if (list.isNotEmpty) {
          final first = list.first as Map<String, dynamic>;
          _token = (first['instrumentToken'] ?? first['instrument_token'] as num?)?.toInt();
        }
      } catch (_) {}
    }

    await _fetchEngineCandles();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _candles.isEmpty) return;
      final screenWidth = MediaQuery.of(context).size.width;
      final candleWidth = _baseCandleWidth * _scale;
      final totalWidth = _candles.length * candleWidth;
      final viewportWidth = screenWidth - 55;
      setState(() {
        if (totalWidth > viewportWidth) {
          _panOffset = -(totalWidth - viewportWidth);
        } else {
          _panOffset = 0.0;
        }
      });
    });
  }

  Future<void> _fetchEngineCandles() async {
    if (_token == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final now = DateTime.now().toUtc();
    final from = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 7)));
    final to = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));

    final result = await _api.getCandles(_token!, _selectedTimeframe, from, to);
    if (!mounted) return;

    result.fold(
      onSuccess: (data) {
        setState(() {
          _candles = data;
          _isKiteData = false;
          _isLoading = false;
          _hoveredIndex = null;
        });
        _scrollToLatest();
        if (data.isEmpty) {
          // If local engine has no candles, auto-suggest pulling from Kite if connected
          final kite = context.read<KiteProvider>();
          if (kite.isConnected) {
            _pullFromKite(silent: true);
          }
        }
      },
      onFailure: (f) {
        setState(() {
          _errorMessage = f.message;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _pullFromKite({int? customDaysBack, bool silent = false}) async {
    if (_token == null) return;
    final kite = context.read<KiteProvider>();
    if (!kite.isConnected) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Connect your Zerodha account to pull Kite historical data'),
            action: SnackBarAction(
              label: 'Connect',
              onPressed: () => context.push('/kite-connect'),
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final now = DateTime.now();
    final daysBack = customDaysBack ??
        (_selectedTimeframe == 'day'
            ? 365
            : (_selectedTimeframe.contains('minute') ? 14 : 30));
    final from = DateFormat('yyyy-MM-dd HH:mm:ss').format(now.subtract(Duration(days: daysBack)));
    final to = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    final result = await _api.getHistoricalCandles(
      _token!,
      from,
      to,
      _selectedTimeframe,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (rawList) {
        final parsed = rawList.map((m) {
          return CandleData(
            open: (m['open'] as num).toDouble(),
            high: (m['high'] as num).toDouble(),
            low: (m['low'] as num).toDouble(),
            close: (m['close'] as num).toDouble(),
            volume: (m['volume'] as num?)?.toDouble() ?? 0.0,
            candleTime: m['candleTime'] != null
                ? DateTime.tryParse(m['candleTime'].toString()) ?? DateTime.now()
                : DateTime.now(),
          );
        }).toList();

        setState(() {
          _candles = parsed;
          _isKiteData = true;
          _kiteCandlesCount = parsed.length;
          _isLoading = false;
          _hoveredIndex = null;
        });
        _scrollToLatest();

        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully loaded ${parsed.length} candles from Zerodha Kite'),
              backgroundColor: AppColors.buy,
            ),
          );
        }
      },
      onFailure: (f) {
        setState(() {
          _errorMessage = f.message;
          _isLoading = false;
        });
        if (!silent && mounted) {
          showErrorSnackbar(context, 'Failed to fetch Kite historical data: ${f.message}');
        }
      },
    );
  }

  void _showKitePullOptions() {
    final kite = context.read<KiteProvider>();
    if (!kite.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please connect your Zerodha account first'),
          action: SnackBarAction(
            label: 'Connect',
            onPressed: () => context.push('/kite-connect'),
          ),
        ),
      );
      return;
    }

    String selectedRange = '5D';
    int days = 5;
    String selectedTf = _selectedTimeframe;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.cloud_download_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Pull Historic Data from Zerodha',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'SELECT DATE RANGE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final entry in [
                      {'label': '1 Day', 'key': '1D', 'days': 1},
                      {'label': '5 Days', 'key': '5D', 'days': 5},
                      {'label': '1 Month', 'key': '1M', 'days': 30},
                      {'label': '3 Months', 'key': '3M', 'days': 90},
                      {'label': '1 Year', 'key': '1Y', 'days': 365},
                    ])
                      ChoiceChip(
                        label: Text(entry['label'] as String, style: const TextStyle(fontSize: 11)),
                        selected: selectedRange == entry['key'],
                        onSelected: (sel) {
                          if (sel) {
                            setSheetState(() {
                              selectedRange = entry['key'] as String;
                              days = entry['days'] as int;
                            });
                          }
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selectedRange == entry['key'] ? Colors.white : AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'TIMEFRAME',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _timeframes.map((tf) {
                      final isSel = tf == selectedTf;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(_formatTimeframe(tf), style: const TextStyle(fontSize: 11)),
                          selected: isSel,
                          onSelected: (sel) {
                            if (sel) {
                              setSheetState(() => selectedTf = tf);
                            }
                          },
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _selectedTimeframe = selectedTf);
                      _pullFromKite(customDaysBack: days);
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: Text('Fetch $selectedRange ($selectedTf) from Kite'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final hoveredCandle = (_hoveredIndex != null &&
            _hoveredIndex! >= 0 &&
            _hoveredIndex! < _candles.length)
        ? _candles[_hoveredIndex!]
        : (_candles.isNotEmpty ? _candles.last : null);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.surface : const Color(0xFFF9FAFB),
        appBar: isLandscape ? null : _buildAppBar(context),
        body: SafeArea(
          child: Column(
            children: [
              if (isLandscape) _buildLandscapeHeader(context),
              _buildControlBar(context),
              if (hoveredCandle != null) _buildHudBanner(hoveredCandle),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : _candles.isEmpty
                        ? _buildEmptyState(context)
                        : _buildInteractiveChart(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.tradingsymbol,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.exchange,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_isKiteData) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.buy.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Kite Live',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.buy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_token != null)
            Text(
              _isKiteData && _kiteCandlesCount > 0
                  ? 'Kite Feed: $_kiteCandlesCount candles'
                  : 'Token: $_token',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(140),
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Rotate Screen (Landscape / Portrait)',
          icon: const Icon(Icons.screen_rotation_rounded),
          onPressed: _toggleOrientation,
        ),
        IconButton(
          tooltip: 'Pull Historic Data from Kite',
          icon: const Icon(Icons.cloud_download_outlined, color: AppColors.primary),
          onPressed: _showKitePullOptions,
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _isKiteData ? () => _pullFromKite() : _fetchEngineCandles,
        ),
      ],
    );
  }

  Widget _buildLandscapeHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Theme.of(context).cardTheme.color ?? AppColors.surfaceVariant,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            onPressed: () {
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
              ]);
              Navigator.pop(context);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          Text(
            widget.tradingsymbol,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.exchange,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Pull Historic Data from Kite',
            icon: const Icon(Icons.cloud_download_outlined, color: AppColors.primary, size: 20),
            onPressed: _showKitePullOptions,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: 'Rotate Portrait',
            icon: const Icon(Icons.screen_rotation_rounded, size: 20),
            onPressed: _toggleOrientation,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? AppColors.surfaceVariant,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Timeframe selection chips
            ..._timeframes.map((tf) {
              final isSelected = tf == _selectedTimeframe;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(_formatTimeframe(tf)),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedTimeframe = tf);
                      if (_isKiteData) {
                        _pullFromKite();
                      } else {
                        _fetchEngineCandles();
                      }
                    }
                  },
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  ),
                  selectedColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              );
            }),
            const SizedBox(width: 8),
            // Indicator toggles
            FilterChip(
              label: const Text('EMA 9'),
              selected: _showEma9,
              onSelected: (v) => setState(() => _showEma9 = v),
              selectedColor: AppColors.ema9.withAlpha(60),
              labelStyle: const TextStyle(fontSize: 11, color: AppColors.ema9),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            FilterChip(
              label: const Text('EMA 20'),
              selected: _showEma20,
              onSelected: (v) => setState(() => _showEma20 = v),
              selectedColor: AppColors.ema20.withAlpha(60),
              labelStyle: const TextStyle(fontSize: 11, color: AppColors.ema20),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            FilterChip(
              label: const Text('VWAP'),
              selected: _showVwap,
              onSelected: (v) => setState(() => _showVwap = v),
              selectedColor: AppColors.vwap.withAlpha(60),
              labelStyle: const TextStyle(fontSize: 11, color: AppColors.vwap),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            FilterChip(
              label: const Text('Volume'),
              selected: _showVolume,
              onSelected: (v) => setState(() => _showVolume = v),
              visualDensity: VisualDensity.compact,
              labelStyle: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHudBanner(CandleData c) {
    final fmt = NumberFormat('#,##0.00');
    final isBull = c.close >= c.open;
    final change = c.close - c.open;
    final changePct = c.open > 0 ? (change / c.open) * 100 : 0.0;
    final timeStr = DateFormat('dd MMM HH:mm').format(c.candleTime);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.surfaceVariant2.withAlpha(100),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('O: ₹${fmt.format(c.open)} ', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted)),
              Text('H: ₹${fmt.format(c.high)} ', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted)),
              Text('L: ₹${fmt.format(c.low)} ', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted)),
              Text(
                'C: ₹${fmt.format(c.close)} ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isBull ? AppColors.buy : AppColors.sell,
                ),
              ),
              Text(
                '(${change >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%)',
                style: TextStyle(
                  fontSize: 10,
                  color: isBull ? AppColors.buy : AppColors.sell,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (c.volume > 0)
                Text('Vol: ${_formatVolume(c.volume)}  ', style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceMuted)),
              Text(timeStr, style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.candlestick_chart_outlined, size: 48, color: AppColors.onSurfaceMuted),
            const SizedBox(height: 16),
            const Text(
              'No candles found in engine',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'Pull historical candles directly from Zerodha Kite to view the chart.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _errorMessage != null ? AppColors.sell : AppColors.onSurfaceMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showKitePullOptions,
              icon: const Icon(Icons.cloud_download_rounded, size: 18),
              label: const Text('Pull Historic Data from Kite'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveChart(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final candleWidth = _baseCandleWidth * _scale;
        final totalWidth = _candles.length * candleWidth;
        final viewportWidth = constraints.maxWidth - 55; // 55 for right Y axis labels

        return Stack(
          children: [
            GestureDetector(
              onScaleUpdate: (details) {
                setState(() {
                  _scale = (_scale * details.scale).clamp(0.5, 3.0);
                  _panOffset = (_panOffset + details.focalPointDelta.dx).clamp(
                    -max(0.0, totalWidth - viewportWidth),
                    0.0,
                  );
                  _touchPosition = details.localFocalPoint;
                  _updateHoveredIndex(details.localFocalPoint.dx, candleWidth, viewportWidth, totalWidth);
                });
              },
              onScaleEnd: (_) {
                setState(() {
                  _touchPosition = null;
                });
              },
              onTapDown: (details) {
                setState(() {
                  _touchPosition = details.localPosition;
                  _updateHoveredIndex(details.localPosition.dx, candleWidth, viewportWidth, totalWidth);
                });
              },
              onTapUp: (_) {
                setState(() {
                  _touchPosition = null;
                });
              },
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: CandleCanvasPainter(
                  candles: _candles,
                  candleWidth: candleWidth,
                  panOffset: _panOffset,
                  touchPosition: _touchPosition,
                  hoveredIndex: _hoveredIndex,
                  showEma9: _showEma9,
                  showEma20: _showEma20,
                  showVwap: _showVwap,
                  showVolume: _showVolume,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
            // Floating chart controls: Zoom In, Zoom Out, Snap to Latest
            Positioned(
              right: 64,
              bottom: 28,
              child: Container(
                decoration: BoxDecoration(
                  color: (Theme.of(context).cardTheme.color ?? AppColors.surfaceVariant)
                      .withAlpha(220),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withAlpha(120),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      tooltip: 'Zoom Out',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _scale = (_scale / 1.25).clamp(0.5, 3.0);
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      tooltip: 'Zoom In',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _scale = (_scale * 1.25).clamp(0.5, 3.0);
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 18),
                      tooltip: 'Snap to Latest',
                      visualDensity: VisualDensity.compact,
                      onPressed: _scrollToLatest,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _updateHoveredIndex(double touchX, double candleWidth, double viewportWidth, double totalWidth) {
    final effectiveX = touchX - _panOffset;
    final index = (effectiveX / candleWidth).floor();
    if (index >= 0 && index < _candles.length) {
      _hoveredIndex = index;
    }
  }

  String _formatTimeframe(String tf) {
    switch (tf) {
      case '1minute':
        return '1m';
      case '3minute':
        return '3m';
      case '5minute':
        return '5m';
      case '15minute':
        return '15m';
      case '30minute':
        return '30m';
      case '60minute':
        return '1h';
      case 'day':
        return '1D';
      default:
        return tf;
    }
  }

  String _formatVolume(num v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

/// Custom Canvas Painter rendering real OHLC candlesticks, volume bars, EMA overlays, and crosshair.
class CandleCanvasPainter extends CustomPainter {
  final List<CandleData> candles;
  final double candleWidth;
  final double panOffset;
  final Offset? touchPosition;
  final int? hoveredIndex;
  final bool showEma9;
  final bool showEma20;
  final bool showVwap;
  final bool showVolume;
  final bool isDark;

  CandleCanvasPainter({
    required this.candles,
    required this.candleWidth,
    required this.panOffset,
    required this.touchPosition,
    required this.hoveredIndex,
    required this.showEma9,
    required this.showEma20,
    required this.showVwap,
    required this.showVolume,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    const double priceAxisWidth = 55.0;
    const double timeAxisHeight = 22.0;
    final double chartWidth = size.width - priceAxisWidth;
    final double chartHeight = size.height - timeAxisHeight;
    final double volumeHeight = showVolume ? chartHeight * 0.20 : 0.0;
    final double candleAreaHeight = chartHeight - volumeHeight;

    // 1. Calculate min/max price in current viewport
    final startIndex = max(0, ((-panOffset) / candleWidth).floor());
    final endIndex = min(candles.length, ((-panOffset + chartWidth) / candleWidth).ceil());

    if (startIndex >= endIndex) return;

    double minPrice = double.infinity;
    double maxPrice = -double.infinity;
    double maxVolume = 0.0;

    for (int i = startIndex; i < endIndex; i++) {
      final c = candles[i];
      if (c.low < minPrice) minPrice = c.low;
      if (c.high > maxPrice) maxPrice = c.high;
      if (c.volume > maxVolume) maxVolume = c.volume;
    }

    if (minPrice == maxPrice) {
      minPrice -= 1.0;
      maxPrice += 1.0;
    }

    // Add 5% vertical padding to price
    final priceRange = maxPrice - minPrice;
    minPrice -= priceRange * 0.05;
    maxPrice += priceRange * 0.05;
    final adjustedRange = maxPrice - minPrice;

    double priceToY(double price) {
      return candleAreaHeight - ((price - minPrice) / adjustedRange) * candleAreaHeight;
    }

    // 2. Draw Price Grid Lines & Labels
    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB)
      ..strokeWidth = 0.8;

    final textStyle = TextStyle(
      color: isDark ? const Color(0xFF888888) : const Color(0xFF6B7280),
      fontSize: 10,
    );

    const int gridDivisions = 5;
    for (int i = 0; i <= gridDivisions; i++) {
      final price = minPrice + (adjustedRange / gridDivisions) * i;
      final y = priceToY(price);

      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);

      final textSpan = TextSpan(text: price.toStringAsFixed(2), style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(chartWidth + 4, y - 6));
    }

    // 3. Draw Candlesticks & Volume Bars
    final bullPaint = Paint()..color = AppColors.buy;
    final bearPaint = Paint()..color = AppColors.sell;
    final wickWidth = max(1.0, candleWidth * 0.15);
    final bodyWidth = max(2.0, candleWidth * 0.75);

    for (int i = startIndex; i < endIndex; i++) {
      final c = candles[i];
      final isBull = c.close >= c.open;
      final paint = isBull ? bullPaint : bearPaint;

      final centerX = i * candleWidth + candleWidth / 2 + panOffset;
      final highY = priceToY(c.high);
      final lowY = priceToY(c.low);
      final openY = priceToY(c.open);
      final closeY = priceToY(c.close);

      // Draw high-low wick
      final wickPaint = Paint()
        ..color = paint.color
        ..strokeWidth = wickWidth;
      canvas.drawLine(Offset(centerX, highY), Offset(centerX, lowY), wickPaint);

      // Draw body
      final topY = min(openY, closeY);
      final bottomY = max(openY, closeY);
      final height = max(1.5, bottomY - topY);

      canvas.drawRect(
        Rect.fromLTWH(centerX - bodyWidth / 2, topY, bodyWidth, height),
        paint,
      );

      // Draw Volume Bar
      if (showVolume && maxVolume > 0 && c.volume > 0) {
        final volH = (c.volume / maxVolume) * volumeHeight;
        final volTop = chartHeight - volH;
        final volPaint = Paint()..color = paint.color.withAlpha(70);
        canvas.drawRect(
          Rect.fromLTWH(centerX - bodyWidth / 2, volTop, bodyWidth, volH),
          volPaint,
        );
      }
    }

    // 4. Calculate and Draw Moving Averages (EMA9, EMA20, VWAP)
    if (showEma9) _drawEma(canvas, 9, AppColors.ema9, startIndex, endIndex, priceToY);
    if (showEma20) _drawEma(canvas, 20, AppColors.ema20, startIndex, endIndex, priceToY);
    if (showVwap) _drawVwap(canvas, AppColors.vwap, startIndex, endIndex, priceToY);

    // 5. Draw Time Axis Divider & Timestamps
    canvas.drawLine(Offset(0, chartHeight), Offset(size.width, chartHeight), gridPaint);
    canvas.drawLine(Offset(chartWidth, 0), Offset(chartWidth, chartHeight), gridPaint);

    final bool isMultiDay = candles.isNotEmpty &&
        candles.last.candleTime.difference(candles.first.candleTime).inHours > 24;

    final step = max(1, (endIndex - startIndex) ~/ 5);
    for (int i = startIndex; i < endIndex; i += step) {
      final x = i * candleWidth + candleWidth / 2 + panOffset;
      final timeStr = isMultiDay
          ? DateFormat('dd MMM').format(candles[i].candleTime)
          : DateFormat('HH:mm').format(candles[i].candleTime);
      final tp = TextPainter(
        text: TextSpan(text: timeStr, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chartHeight + 4));
    }

    // 6. Draw Crosshair
    if (touchPosition != null && hoveredIndex != null && hoveredIndex! >= 0 && hoveredIndex! < candles.length) {
      final crosshairPaint = Paint()
        ..color = isDark ? Colors.white54 : Colors.black45
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      final hX = hoveredIndex! * candleWidth + candleWidth / 2 + panOffset;
      final hY = touchPosition!.dy.clamp(0.0, chartHeight);

      // Vertical line
      canvas.drawLine(Offset(hX, 0), Offset(hX, chartHeight), crosshairPaint);
      // Horizontal line
      canvas.drawLine(Offset(0, hY), Offset(chartWidth, hY), crosshairPaint);

      final bubblePaint = Paint()..color = AppColors.primary;

      // Crosshair Price Bubble on Right
      final hoveredPrice = maxPrice - (hY / candleAreaHeight) * adjustedRange;
      final pText = TextSpan(
        text: hoveredPrice.toStringAsFixed(2),
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      );
      final pTp = TextPainter(text: pText, textDirection: TextDirection.ltr)..layout();
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(chartWidth + 2, hY - 9, pTp.width + 6, 18),
          const Radius.circular(4),
        ),
        bubblePaint,
      );
      pTp.paint(canvas, Offset(chartWidth + 5, hY - 7));

      // Crosshair Time Bubble at Bottom
      final hoveredTime = candles[hoveredIndex!].candleTime;
      final timeLabel = DateFormat('dd MMM HH:mm').format(hoveredTime);
      final tText = TextSpan(
        text: timeLabel,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      );
      final tTp = TextPainter(text: tText, textDirection: TextDirection.ltr)..layout();
      final double bubbleX = (hX - tTp.width / 2 - 4).clamp(0.0, chartWidth - tTp.width - 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bubbleX, chartHeight + 2, tTp.width + 8, 18),
          const Radius.circular(4),
        ),
        bubblePaint,
      );
      tTp.paint(canvas, Offset(bubbleX + 4, chartHeight + 4));
    }
  }

  void _drawEma(
    Canvas canvas,
    int period,
    Color color,
    int startIndex,
    int endIndex,
    double Function(double price) priceToY,
  ) {
    if (candles.length < period) return;

    final multiplier = 2.0 / (period + 1);
    double ema = candles.take(period).map((c) => c.close).reduce((a, b) => a + b) / period;

    final path = Path();
    bool started = false;

    for (int i = 0; i < candles.length; i++) {
      if (i >= period) {
        ema = (candles[i].close - ema) * multiplier + ema;
      }
      if (i >= startIndex && i < endIndex) {
        final x = i * candleWidth + candleWidth / 2 + panOffset;
        final y = priceToY(ema);
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);
  }

  void _drawVwap(
    Canvas canvas,
    Color color,
    int startIndex,
    int endIndex,
    double Function(double price) priceToY,
  ) {
    double cumulativeTypicalPriceVol = 0.0;
    double cumulativeVol = 0.0;

    final path = Path();
    bool started = false;

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final typicalPrice = (c.high + c.low + c.close) / 3.0;
      final vol = c.volume > 0 ? c.volume : 1.0;
      cumulativeTypicalPriceVol += typicalPrice * vol;
      cumulativeVol += vol;

      if (cumulativeVol > 0 && i >= startIndex && i < endIndex) {
        final vwap = cumulativeTypicalPriceVol / cumulativeVol;
        final x = i * candleWidth + candleWidth / 2 + panOffset;
        final y = priceToY(vwap);
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CandleCanvasPainter oldDelegate) => true;
}
