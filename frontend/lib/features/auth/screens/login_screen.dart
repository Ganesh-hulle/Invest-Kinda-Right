import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/websocket/market_ws_service.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../provider/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  bool _canUseBiometrics = false;
  String? _biometricUsername;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final secureStorage = context.read<SecureStorage>();
      final bioService = context.read<BiometricService>();

      final isEnabled = await secureStorage.isBiometricEnabled();
      final creds = await secureStorage.readBiometricCredentials();
      final canAuth = await bioService.canCheckBiometrics();

      if (mounted) {
        setState(() {
          _canUseBiometrics = isEnabled && creds != null && canAuth;
          _biometricUsername = creds?.username;
        });
      }
    } catch (_) {
      // Biometrics unavailable
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final result = await auth.login(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => context.go('/dashboard'),
      onFailure: (f) => showErrorSnackbar(context, f.message),
    );
  }

  Future<void> _loginWithBiometrics() async {
    final auth = context.read<AuthProvider>();
    final bioService = context.read<BiometricService>();
    final result = await auth.loginWithBiometrics(bioService);
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => context.go('/dashboard'),
      onFailure: (f) => showErrorSnackbar(context, f.message),
    );
  }

  void _showServerConfigDialog() {
    final dioClient = context.read<DioClient>();
    final wsService = context.read<MarketWsService>();
    final ctrl = TextEditingController(text: dioClient.baseUrl);
    String? statusMessage;
    bool isChecking = false;
    bool isSuccess = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              const Icon(Icons.dns_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Server Settings',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configure backend server address:',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'http://127.0.0.1:8080',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              if (isChecking)
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Testing connection...',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                )
              else if (statusMessage != null)
                Row(
                  children: [
                    Icon(
                      isSuccess ? Icons.check_circle : Icons.error,
                      color: isSuccess ? AppColors.buy : AppColors.sell,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        statusMessage!,
                        style: TextStyle(
                          color: isSuccess ? AppColors.buy : AppColors.sell,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isChecking
                    ? null
                    : () async {
                        setDialogState(() {
                          isChecking = true;
                          statusMessage = null;
                        });
                        try {
                          final testUrl = ctrl.text.trim();
                          final res = await dioClient.dio
                              .get('$testUrl/api/v1/system/health');
                          setDialogState(() {
                            isChecking = false;
                            isSuccess = res.statusCode == 200;
                            statusMessage =
                                'Server UP (${res.data['service'] ?? 'IKR-backend'})';
                          });
                        } catch (e) {
                          setDialogState(() {
                            isChecking = false;
                            isSuccess = false;
                            statusMessage = 'Connection failed: $e';
                          });
                        }
                      },
                icon: const Icon(Icons.wifi_find_rounded, size: 18),
                label: const Text('Test Connection'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final url = ctrl.text.trim();
                if (url.isNotEmpty) {
                  dioClient.updateBaseUrl(url);
                  wsService.updateWsBaseUrl(url.replaceFirst('http', 'ws'));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Server URL set to: $url')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.dns_outlined,
              color: theme.colorScheme.onSurface.withAlpha(160),
            ),
            tooltip: 'Server Connection',
            onPressed: _showServerConfigDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                // Logo
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.candlestick_chart_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Invest Kinda Right',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to your trading account',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(160),
                  ),
                ),
                const SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: const InputDecoration(
                          labelText: 'Username or Email',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Username or email is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          if (v.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _submit,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Sign In'),
                            ),
                          ),
                          if (_canUseBiometrics) ...[
                            const SizedBox(width: 12),
                            Container(
                              height: 48,
                              width: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(30),
                                border: Border.all(color: AppColors.primary),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                tooltip:
                                    'Sign in with Fingerprint (${_biometricUsername ?? ''})',
                                icon: const Icon(
                                  Icons.fingerprint_rounded,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                                onPressed:
                                    isLoading ? null : _loginWithBiometrics,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_canUseBiometrics && _biometricUsername != null) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isLoading ? null : _loginWithBiometrics,
                            icon: const Icon(Icons.fingerprint_rounded, size: 20),
                            label: Text(
                              'Sign In as $_biometricUsername with Fingerprint',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withAlpha(160),
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/register'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Register'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
