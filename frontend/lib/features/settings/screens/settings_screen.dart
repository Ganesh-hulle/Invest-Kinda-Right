import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../../auth/provider/auth_provider.dart';
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

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _baseUrlCtrl = TextEditingController(text: settings.dioClient.baseUrl);
    _loadBiometricStatus();
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
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

  Future<void> _showSetupBiometricsDialog() async {
    final auth = context.read<AuthProvider>();
    final storage = context.read<SecureStorage>();
    final bioService = context.read<BiometricService>();

    final idCtrl = TextEditingController(text: auth.user?.username ?? '');
    final passCtrl = TextEditingController();
    bool obscure = true;
    String? formError;
    bool isAuthenticating = false;

    await showDialog(
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
                        Navigator.pop(ctx);
                        await _loadBiometricStatus();
                        if (mounted) {
                          showSuccessSnackbar(
                            context,
                            'Fingerprint login configured for $id',
                          );
                        }
                      },
                child: const Text('Verify & Save'),
              ),
            ],
          );
        },
      ),
    );
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
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
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

          // ── GENERAL SETTINGS ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'GENERAL SETTINGS',
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
                                    : theme.colorScheme.onSurface
                                        .withAlpha(140),
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
      ),
    );
  }
}
