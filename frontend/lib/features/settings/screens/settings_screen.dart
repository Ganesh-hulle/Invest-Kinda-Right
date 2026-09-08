import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../../../shared/widgets/pnl_chip.dart';
import '../../auth/provider/auth_provider.dart';
import '../../kite/provider/kite_provider.dart';
import '../../orders/provider/orders_provider.dart';
import '../model/risk_limits.dart';
import '../provider/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _baseUrlCtrl;
  bool _biometricEnabled = false;
  String? _biometricUser;
  bool _deviceSupportsBiometrics = false;

  // Controllers for editing risk limits
  late final TextEditingController _maxDailyLossCtrl;
  late final TextEditingController _maxTradesCtrl;
  late final TextEditingController _maxCapitalCtrl;
  late final TextEditingController _maxPositionsCtrl;
  late final TextEditingController _maxSizeCtrl;
  bool _tradingEnabled = true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _baseUrlCtrl = TextEditingController(text: settings.dioClient.baseUrl);

    _maxDailyLossCtrl = TextEditingController();
    _maxTradesCtrl = TextEditingController();
    _maxCapitalCtrl = TextEditingController();
    _maxPositionsCtrl = TextEditingController();
    _maxSizeCtrl = TextEditingController();

    _loadBiometricStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLimitsAndOrders());
  }

  Future<void> _initLimitsAndOrders() async {
    final settings = context.read<SettingsProvider>();
    final orders = context.read<OrdersProvider>();
    await Future.wait([
      settings.loadRiskLimits(),
      orders.loadAll(),
    ]);
    if (mounted && settings.limits != null) {
      _syncLimitControllers(settings.limits!);
    }
  }

  void _syncLimitControllers(RiskLimits limits) {
    _maxDailyLossCtrl.text = limits.maxDailyLoss.toStringAsFixed(0);
    _maxTradesCtrl.text = limits.maxTradesPerDay.toString();
    _maxCapitalCtrl.text = limits.maxCapitalPerTrade.toStringAsFixed(0);
    _maxPositionsCtrl.text = limits.maxOpenPositions.toString();
    _maxSizeCtrl.text = limits.maxPositionSize.toString();
    _tradingEnabled = limits.tradingEnabled;
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _maxDailyLossCtrl.dispose();
    _maxTradesCtrl.dispose();
    _maxCapitalCtrl.dispose();
    _maxPositionsCtrl.dispose();
    _maxSizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricStatus() async {
    final storage = context.read<SecureStorage>();
    final bioService = context.read<BiometricService>();

    final enabled = await storage.isBiometricEnabled();
    final creds = await storage.readBiometricCredentials();
    final supported = await bioService.canCheckBiometrics();

    if (mounted) {
      setState(() {
        _biometricEnabled = enabled && creds != null;
        _biometricUser = creds?.username;
        _deviceSupportsBiometrics = supported;
      });
    }
  }

  void _saveBaseUrl() {
    final url = _baseUrlCtrl.text.trim();
    if (url.isEmpty) {
      showErrorSnackbar(context, 'Base URL cannot be empty');
      return;
    }
    context.read<SettingsProvider>().updateBaseUrl(url);
    showSuccessSnackbar(context, 'Base URL updated');
  }

  Future<void> _syncInstruments() async {
    final kite = context.read<KiteProvider>();
    if (!kite.isConnected) {
      showErrorSnackbar(
        context,
        'Please connect your Zerodha account first to sync instruments.',
      );
      return;
    }

    final result = await kite.syncInstruments();
    if (!mounted) return;
    result.fold(
      onSuccess: (res) {
        showSuccessSnackbar(
          context,
          'Successfully synced ${NumberFormat('#,###').format(res.instrumentCount)} instruments from Zerodha Kite!',
        );
      },
      onFailure: (f) {
        showErrorSnackbar(context, 'Instrument sync failed: ${f.message}');
      },
    );
  }

  Future<void> _saveLimits() async {
    final settings = context.read<SettingsProvider>();
    final limits = RiskLimits(
      maxDailyLoss: double.tryParse(_maxDailyLossCtrl.text.trim()) ?? 5000.0,
      maxTradesPerDay: int.tryParse(_maxTradesCtrl.text.trim()) ?? 20,
      maxCapitalPerTrade: double.tryParse(_maxCapitalCtrl.text.trim()) ?? 50000.0,
      maxOpenPositions: int.tryParse(_maxPositionsCtrl.text.trim()) ?? 5,
      maxPositionSize: int.tryParse(_maxSizeCtrl.text.trim()) ?? 100,
      tradingEnabled: _tradingEnabled,
    );

    final success = await settings.saveRiskLimits(limits);
    if (!mounted) return;
    if (success) {
      showSuccessSnackbar(context, 'Risk limits saved successfully');
    } else {
      showErrorSnackbar(context, settings.error ?? 'Failed to save risk limits');
    }
  }

  Future<void> _showSetupBiometricsDialog() async {
    final auth = context.read<AuthProvider>();
    final storage = context.read<SecureStorage>();
    final bioService = context.read<BiometricService>();

    final idCtrl = TextEditingController(text: auth.user?.username ?? '');
    final passCtrl = TextEditingController();
    bool obscure = true;
    String? formError;
    bool isAuthenticating = false;

    final configuredId = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.fingerprint_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 10),
                Text(
                  'Setup Fingerprint',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your login credentials to associate with your device fingerprint reader for 1-tap sign in.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withAlpha(160),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: idCtrl,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Username or Email',
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: obscure,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  if (formError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      formError!,
                      style: const TextStyle(
                          color: AppColors.sell, fontSize: 12),
                    ),
                  ],
                  if (isAuthenticating) ...[
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Waiting for fingerprint scan...',
                          style: TextStyle(
                              color: AppColors.primary, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isAuthenticating ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isAuthenticating
                    ? null
                    : () async {
                        final id = idCtrl.text.trim();
                        final pass = passCtrl.text;
                        if (id.isEmpty || pass.isEmpty) {
                          setDialogState(() => formError =
                              'Please enter both username and password.');
                          return;
                        }

                        setDialogState(() {
                          formError = null;
                          isAuthenticating = true;
                        });

                        final authenticated = await bioService.authenticate(
                          reason: 'Confirm fingerprint to activate 1-tap login',
                        );

                        if (!authenticated) {
                          setDialogState(() {
                            isAuthenticating = false;
                            formError =
                                'Biometric verification cancelled or failed.';
                          });
                          return;
                        }

                        await storage.saveBiometricCredentials(
                          username: id,
                          password: pass,
                        );

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx, id);
                      },
                child: const Text('Verify & Save'),
              ),
            ],
          );
        },
      ),
    );

    if (configuredId != null) {
      await _loadBiometricStatus();
      if (mounted) {
        showSuccessSnackbar(
          context,
          'Fingerprint login configured for $configuredId',
        );
      }
    }
  }

  Future<void> _disableBiometrics() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Disable Fingerprint Login'),
        content: const Text(
          'Are you sure you want to disable fingerprint login and remove stored credentials?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sell),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final storage = context.read<SecureStorage>();
      await storage.clearBiometricCredentials();
      await _loadBiometricStatus();
      if (mounted) {
        showSuccessSnackbar(context, 'Fingerprint login disabled');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Settings'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceMuted,
            indicatorWeight: 3,
            tabs: [
              Tab(
                icon: Icon(Icons.settings_suggest_rounded, size: 20),
                text: 'General & Security',
              ),
              Tab(
                icon: Icon(Icons.speed_rounded, size: 20),
                text: 'Limits & Margins',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGeneralTab(context),
            _buildLimitsTab(context),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: General & Security ──────────────────────────────────────────────
  Widget _buildGeneralTab(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final kite = context.watch<KiteProvider>();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // User card
        if (auth.user != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withAlpha(30),
                    child: Text(
                      auth.user!.username.isNotEmpty
                          ? auth.user!.username[0].toUpperCase()
                          : 'T',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.user!.username,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          auth.user!.email,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withAlpha(160),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Divider(height: 1, color: theme.dividerColor),

        // ── INSTRUMENTS SYNC ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'MARKET INSTRUMENTS',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withAlpha(150),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_sync_rounded,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zerodha Instruments Dump',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            kite.isConnected
                                ? 'Synchronize all tradable contracts and tokens from Kite'
                                : 'Connect Zerodha account to sync full master instruments',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withAlpha(140),
                              fontSize: 12,
                            ),
                          ),
                          if (kite.lastSyncedCount != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.check_circle_outline, size: 14, color: AppColors.buy),
                                const SizedBox(width: 4),
                                Text(
                                  'Last synced: ${NumberFormat('#,###').format(kite.lastSyncedCount)} instruments (${kite.lastSyncedAt != null ? DateFormat('dd MMM, HH:mm').format(kite.lastSyncedAt!) : 'recently'})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.buy,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!kite.isConnected)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/kite-connect'),
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Connect Zerodha Kite First'),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: kite.isSyncing ? null : _syncInstruments,
                      icon: kite.isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(
                        kite.isSyncing
                            ? 'Syncing Instruments...'
                            : 'Sync Instruments with Zerodha',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),
        Divider(height: 1, color: theme.dividerColor),

        // ── GENERAL SETTINGS ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'APPEARANCE & SECURITY',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withAlpha(150),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),

        // Theme Setting
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.palette_outlined,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'App Theme',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined, size: 16),
                      label: Text('Dark'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined, size: 16),
                      label: Text('Light'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined, size: 16),
                      label: Text('System'),
                    ),
                  ],
                  selected: {themeProvider.themeMode},
                  onSelectionChanged: (Set<ThemeMode> newSelection) {
                    themeProvider.setThemeMode(newSelection.first);
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Biometrics / Fingerprint Setting
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.fingerprint_rounded,
                      color: _biometricEnabled
                          ? AppColors.buy
                          : AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fingerprint Reader',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _biometricEnabled
                                ? 'Active for ${_biometricUser ?? 'saved account'}'
                                : (_deviceSupportsBiometrics
                                    ? 'Not configured'
                                    : 'Not supported on device'),
                            style: TextStyle(
                              color: _biometricEnabled
                                  ? AppColors.buy
                                  : theme.colorScheme.onSurface.withAlpha(140),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _biometricEnabled,
                      onChanged: (val) {
                        if (val) {
                          _showSetupBiometricsDialog();
                        } else {
                          _disableBiometrics();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showSetupBiometricsDialog,
                        icon: Icon(
                          _biometricEnabled
                              ? Icons.edit_outlined
                              : Icons.add_circle_outline_rounded,
                          size: 16,
                        ),
                        label: Text(_biometricEnabled
                            ? 'Change Credentials'
                            : 'Setup Fingerprint'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    if (_biometricEnabled) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Clear Fingerprint',
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.sell, size: 20),
                        onPressed: _disableBiometrics,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),
        Divider(height: 1, color: theme.dividerColor),

        // ── SERVER CONFIGURATION ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SERVER CONFIGURATION',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withAlpha(150),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _baseUrlCtrl,
                style: TextStyle(
                    color: theme.colorScheme.onSurface, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'http://10.0.2.2:8080',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _saveBaseUrl,
                  child: const Text('Save URL'),
                ),
              ),
            ],
          ),
        ),

        Divider(height: 1, color: theme.dividerColor),

        // ── SIGN OUT ─────────────────────────────────────────────────────
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: AppColors.sell),
          title:
              const Text('Sign Out', style: TextStyle(color: AppColors.sell)),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: theme.colorScheme.surface,
                title: Text(
                  'Sign Out',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                content: Text(
                  'Are you sure you want to sign out?',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withAlpha(160),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sell),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              await context.read<AuthProvider>().logout();
            }
          },
        ),
        const SizedBox(height: 32),
        Center(
          child: Text(
            'Invest Kinda Right v1.0.0',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withAlpha(100),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Tab 2: Limits & Margins ────────────────────────────────────────────────
  Widget _buildLimitsTab(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final orders = context.watch<OrdersProvider>();
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,##0.00');

    if (settings.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final limits = settings.limits ??
        const RiskLimits(
          maxDailyLoss: 5000,
          maxTradesPerDay: 20,
          maxCapitalPerTrade: 50000,
          maxOpenPositions: 5,
          maxPositionSize: 100,
          tradingEnabled: true,
        );

    // Calculate today's paper trades
    final today = DateTime.now();
    final todayOrders = orders.paperOrders.where((o) {
      return o.createdAt.year == today.year &&
          o.createdAt.month == today.month &&
          o.createdAt.day == today.day;
    }).toList();

    final todayFilledCount =
        todayOrders.where((o) => o.status == 'FILLED').length;
    final tradesRemaining = max(0, limits.maxTradesPerDay - todayFilledCount);

    final openPositionsCount = orders.paperPositions.length;
    final openPositionsRemaining =
        max(0, limits.maxOpenPositions - openPositionsCount);

    double totalInvestedInPositions = 0.0;
    double currentMarketValue = 0.0;
    double unrealizedPnl = 0.0;
    double totalRealizedPnl = 0.0;

    for (final pos in orders.paperPositions) {
      totalInvestedInPositions += pos.quantity * pos.averagePrice;
      currentMarketValue += pos.quantity * pos.lastPrice;
      unrealizedPnl += pos.unrealizedPnl;
      totalRealizedPnl += pos.realizedPnl;
    }

    // Estimate realized loss today from negative P&L trades
    final double todayRealizedLoss =
        totalRealizedPnl < 0 ? (-totalRealizedPnl) : 0.0;
    final double lossBufferRemaining =
        max(0.0, limits.maxDailyLoss - todayRealizedLoss);
    final double lossProgress = limits.maxDailyLoss > 0
        ? (todayRealizedLoss / limits.maxDailyLoss).clamp(0.0, 1.0)
        : 0.0;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await Future.wait([
          settings.loadRiskLimits(),
          orders.loadAll(),
        ]);
        if (settings.limits != null) {
          _syncLimitControllers(settings.limits!);
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withAlpha(30),
                  AppColors.primary.withAlpha(10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Paper Trading Risk Guard',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: limits.tradingEnabled
                            ? AppColors.buy.withAlpha(30)
                            : AppColors.sell.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        limits.tradingEnabled ? 'ACTIVE' : 'HALTED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: limits.tradingEnabled
                              ? AppColors.buy
                              : AppColors.sell,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Today: ${DateFormat('EEE, dd MMM yyyy').format(today)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Total Limits vs Available Limits Breakdown Table
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'TOTAL LIMITS VS AVAILABLE LIMITS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.2),
                    1: FlexColumnWidth(1.6),
                    2: FlexColumnWidth(1.6),
                    3: FlexColumnWidth(1.8),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: theme.dividerColor)),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('Metric', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withAlpha(150))),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('Total Limit', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withAlpha(150))),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('Used Today', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withAlpha(150))),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('Available', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ),
                      ],
                    ),
                    _buildSummaryTableRow(
                      theme: theme,
                      label: 'Daily Loss',
                      total: '₹${fmt.format(limits.maxDailyLoss)}',
                      used: '₹${fmt.format(todayRealizedLoss)}',
                      available: '₹${fmt.format(lossBufferRemaining)}',
                      availableColor: lossBufferRemaining > 0 ? AppColors.buy : AppColors.sell,
                    ),
                    _buildSummaryTableRow(
                      theme: theme,
                      label: 'Trades / Day',
                      total: '${limits.maxTradesPerDay}',
                      used: '$todayFilledCount',
                      available: '$tradesRemaining',
                      availableColor: tradesRemaining > 0 ? AppColors.buy : AppColors.sell,
                    ),
                    _buildSummaryTableRow(
                      theme: theme,
                      label: 'Open Positions',
                      total: '${limits.maxOpenPositions}',
                      used: '$openPositionsCount',
                      available: '$openPositionsRemaining slots',
                      availableColor: openPositionsRemaining > 0 ? AppColors.buy : AppColors.sell,
                    ),
                    _buildSummaryTableRow(
                      theme: theme,
                      label: 'Capital / Trade',
                      total: '₹${fmt.format(limits.maxCapitalPerTrade)}',
                      used: '-',
                      available: 'Per Order',
                      availableColor: theme.colorScheme.onSurface,
                    ),
                    _buildSummaryTableRow(
                      theme: theme,
                      label: 'Max Size / Order',
                      total: '${limits.maxPositionSize}',
                      used: '-',
                      available: 'Per Order',
                      availableColor: theme.colorScheme.onSurface,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1. Daily Loss Buffer Card
          _buildMetricCapacityCard(
            context,
            icon: Icons.trending_down_rounded,
            title: 'Daily Loss Limit',
            limitLabel: 'Max Loss: ₹${fmt.format(limits.maxDailyLoss)}',
            valueLabel: '₹${fmt.format(lossBufferRemaining)} Available',
            subtitle:
                'Used: ₹${fmt.format(todayRealizedLoss)} / ₹${fmt.format(limits.maxDailyLoss)}',
            progress: lossProgress,
            progressColor: lossProgress > 0.8
                ? AppColors.sell
                : (lossProgress > 0.5 ? AppColors.warning : AppColors.buy),
          ),
          const SizedBox(height: 12),

          // 2. Trades Remaining Today Card
          _buildMetricCapacityCard(
            context,
            icon: Icons.swap_horiz_rounded,
            title: 'Daily Trades Limit',
            limitLabel: 'Max: ${limits.maxTradesPerDay} trades',
            valueLabel: '$tradesRemaining Remaining',
            subtitle:
                'Executed today: $todayFilledCount / ${limits.maxTradesPerDay}',
            progress: limits.maxTradesPerDay > 0
                ? (todayFilledCount / limits.maxTradesPerDay).clamp(0.0, 1.0)
                : 0.0,
            progressColor: AppColors.primary,
          ),
          const SizedBox(height: 12),

          // 3. Open Positions Capacity Card
          _buildMetricCapacityCard(
            context,
            icon: Icons.pie_chart_outline_rounded,
            title: 'Open Positions Capacity',
            limitLabel: 'Max: ${limits.maxOpenPositions} positions',
            valueLabel: '$openPositionsRemaining Slots Free',
            subtitle:
                'Current active: $openPositionsCount / ${limits.maxOpenPositions}',
            progress: limits.maxOpenPositions > 0
                ? (openPositionsCount / limits.maxOpenPositions).clamp(0.0, 1.0)
                : 0.0,
            progressColor: openPositionsCount >= limits.maxOpenPositions
                ? AppColors.sell
                : AppColors.buy,
          ),
          const SizedBox(height: 12),

          // 4. Per-Trade Limits Strip
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Max Capital / Trade',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withAlpha(140),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${fmt.format(limits.maxCapitalPerTrade)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: theme.dividerColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Max Position Size',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withAlpha(140),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${limits.maxPositionSize} shares/lots',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 5. Active Capital in Open Paper Positions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ACTIVE PAPER POSITIONS VALUE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: theme.colorScheme.onSurface.withAlpha(140),
                      ),
                    ),
                    PnlChip(value: unrealizedPnl),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invested Capital',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withAlpha(140),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${fmt.format(totalInvestedInPositions)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Current Value',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withAlpha(140),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${fmt.format(currentMarketValue)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unrealized P&L',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withAlpha(140),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${unrealizedPnl >= 0 ? '+' : ''}₹${fmt.format(unrealizedPnl)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: unrealizedPnl >= 0 ? AppColors.buy : AppColors.sell,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Realized P&L Today',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withAlpha(140),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${totalRealizedPnl >= 0 ? '+' : ''}₹${fmt.format(totalRealizedPnl)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: totalRealizedPnl >= 0 ? AppColors.buy : AppColors.sell,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 6. Edit Risk Limits Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Configure Risk Limits',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    Row(
                      children: [
                        Text(
                          'Trading: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withAlpha(150),
                          ),
                        ),
                        Switch(
                          value: _tradingEnabled,
                          onChanged: (v) => setState(() => _tradingEnabled = v),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _maxDailyLossCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Daily Loss (₹)',
                          prefixText: '₹',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxTradesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Trades/Day',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _maxCapitalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max Capital Per Trade (₹)',
                    prefixText: '₹',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _maxPositionsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Open Positions',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxSizeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Position Size',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: settings.isSaving ? null : _saveLimits,
                    child: settings.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Risk Limits'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMetricCapacityCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String limitLabel,
    required String valueLabel,
    required String subtitle,
    required double progress,
    required Color progressColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                valueLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withAlpha(140),
                ),
              ),
              Text(
                limitLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withAlpha(140),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildSummaryTableRow({
    required ThemeData theme,
    required String label,
    required String total,
    required String used,
    required String available,
    required Color availableColor,
  }) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            total,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            used,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withAlpha(160),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            available,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: availableColor,
            ),
          ),
        ),
      ],
    );
  }
}
