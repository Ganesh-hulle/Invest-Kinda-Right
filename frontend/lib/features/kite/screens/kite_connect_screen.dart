import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../provider/kite_provider.dart';

class KiteConnectScreen extends StatefulWidget {
  const KiteConnectScreen({super.key});

  @override
  State<KiteConnectScreen> createState() => _KiteConnectScreenState();
}

class _KiteConnectScreenState extends State<KiteConnectScreen> {
  bool _isLaunching = false;

  Future<void> _connectKite() async {
    setState(() => _isLaunching = true);
    final result = await context.read<KiteProvider>().getLoginUrl();
    if (!mounted) return;
    setState(() => _isLaunching = false);
    result.fold(
      onSuccess: (url) async {
        final uri = Uri.parse(url);
        try {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!launched) {
            // Fallback to platform default if externalApplication failed
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
        } catch (e) {
          if (mounted) showErrorSnackbar(context, 'Could not open browser: $e');
        }
      },
      onFailure: (f) => showErrorSnackbar(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kite = context.watch<KiteProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Connect Zerodha'),
        backgroundColor: AppColors.surface,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant2,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  kite.isConnected
                      ? Icons.check_circle_rounded
                      : Icons.link_rounded,
                  color: kite.isConnected ? AppColors.buy : AppColors.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                kite.isConnected ? 'Zerodha Connected' : 'Connect Zerodha Kite',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                kite.isConnected
                    ? 'Your Zerodha account is connected. You can now trade using the app.'
                    : 'Link your Zerodha Kite account to enable live trading, portfolio sync and real-time market data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onSurfaceMuted, height: 1.6),
              ),
              const SizedBox(height: 40),
              if (!kite.isConnected)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLaunching ? null : _connectKite,
                    icon: _isLaunching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.open_in_browser_rounded),
                    label: const Text('Login with Zerodha'),
                  ),
                ),
              if (kite.isConnected && kite.profile != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'User ID', value: kite.profile!.userId),
                      const SizedBox(height: 8),
                      _InfoRow(label: 'Name', value: kite.profile!.name),
                      const SizedBox(height: 8),
                      _InfoRow(label: 'Email', value: kite.profile!.email),
                      if (kite.profile!.broker.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _InfoRow(label: 'Broker', value: kite.profile!.broker),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
        Text(value,
            style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
