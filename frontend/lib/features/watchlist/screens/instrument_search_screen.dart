import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../data/watchlist_api.dart';
import '../model/watchlist_models.dart';
import '../provider/watchlist_provider.dart';

class InstrumentSearchScreen extends StatefulWidget {
  const InstrumentSearchScreen({super.key});

  @override
  State<InstrumentSearchScreen> createState() => _InstrumentSearchScreenState();
}

class _InstrumentSearchScreenState extends State<InstrumentSearchScreen> {
  final _searchCtrl = SearchController();
  Timer? _debounce;
  List<InstrumentResult> _results = [];
  bool _isSearching = false;
  String _lastQuery = '';
  late WatchlistApi _api;

  @override
  void initState() {
    super.initState();
    _api = WatchlistApi(dioClient: context.read<WatchlistProvider>().dioClient);
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim();
    if (query == _lastQuery) return;
    _lastQuery = query;

    _debounce?.cancel();

    if (query.length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    final result = await _api.searchInstruments(query);
    if (!mounted) return;
    result.fold(
      onSuccess: (instruments) {
        setState(() {
          _results = instruments;
          _isSearching = false;
        });
      },
      onFailure: (f) {
        setState(() => _isSearching = false);
        showErrorSnackbar(context, f.message);
      },
    );
  }

  Future<void> _addInstrument(InstrumentResult instrument) async {
    await context.read<WatchlistProvider>().addInstrument(instrument);
    if (!mounted) return;
    showSuccessSnackbar(
        context, '${instrument.tradingsymbol} added to watchlist');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: SearchBar(
          controller: _searchCtrl,
          hintText: 'Search instruments (e.g. RELIANCE, NIFTY)',
          autoFocus: true,
          backgroundColor: WidgetStateProperty.all(AppColors.surfaceVariant),
          shadowColor: WidgetStateProperty.all(Colors.transparent),
          side: WidgetStateProperty.all(BorderSide(color: AppColors.divider)),
          hintStyle: WidgetStateProperty.all(
            const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(color: AppColors.onSurface, fontSize: 14),
          ),
          leading: const Icon(Icons.search_rounded,
              color: AppColors.onSurfaceMuted, size: 20),
          trailing: [
            if (_searchCtrl.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_rounded,
                    size: 18, color: AppColors.onSurfaceMuted),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {
                    _results = [];
                    _isSearching = false;
                    _lastQuery = '';
                  });
                },
              ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final query = _searchCtrl.text.trim();

          if (_isSearching) {
            return const ShimmerLoader(itemCount: 6);
          }

          if (query.length >= 2 && _results.isEmpty && !_isSearching) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded,
                      size: 56, color: AppColors.onSurfaceMuted),
                  const SizedBox(height: 16),
                  Text(
                    'No results for "$query"',
                    style: const TextStyle(
                        color: AppColors.onSurface, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try a different symbol or name',
                    style: TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          if (query.length < 2) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.manage_search_rounded,
                      size: 56, color: AppColors.onSurfaceMuted),
                  const SizedBox(height: 16),
                  const Text(
                    'Search for stocks, ETFs, F&O',
                    style: TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          final watchlist = context.read<WatchlistProvider>();
          final watchlistTokens = watchlist.instrumentTokens.toSet();

          return ListView.separated(
            itemCount: _results.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) {
              final instrument = _results[index];
              final alreadyAdded =
                  watchlistTokens.contains(instrument.instrumentToken);

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        instrument.tradingsymbol,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant2,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        instrument.exchange,
                        style: const TextStyle(
                            color: AppColors.onSurfaceMuted, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    instrument.name.isNotEmpty
                        ? instrument.name
                        : instrument.instrumentType,
                    style: const TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: alreadyAdded
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.buy, size: 22)
                    : IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded,
                            color: AppColors.primary, size: 22),
                        onPressed: () => _addInstrument(instrument),
                      ),
                onTap: alreadyAdded ? null : () => _addInstrument(instrument),
              );
            },
          );
        },
      ),
    );
  }
}
