import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
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
          backgroundColor: AppColors.surfaceVariant,
          title: const Row(
            children: [
              Icon(Icons.dns_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text('Server Settings', style: TextStyle(color: AppColors.onSurface, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configure backend server address:',
                style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'http://127.0.0.1:8080',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              if (isChecking)
                const Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                    SizedBox(width: 8),
                    Text('Testing connection...', style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
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
                          final res = await dioClient.dio.get('$testUrl/api/v1/system/health');
                          setDialogState(() {
                            isChecking = false;
                            isSuccess = res.statusCode == 200;
                            statusMessage = 'Server UP (${res.data['service'] ?? 'IKR-backend'})';
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.dns_outlined, color: AppColors.onSurfaceMuted),
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
                const SizedBox(height: 48),
                // Logo
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.candlestick_chart_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 24),
                Text(
                  'Invest Kinda Right',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to your trading account',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceMuted,
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
                        style: const TextStyle(color: AppColors.onSurface),
                        decoration: const InputDecoration(
                          labelText: 'Email',
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
                        style: const TextStyle(color: AppColors.onSurface),
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
                          if (v == null || v.isEmpty)
                            return 'Password is required';
                          if (v.length < 6)
                            return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
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
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(
                                color: AppColors.onSurfaceMuted, fontSize: 14),
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
