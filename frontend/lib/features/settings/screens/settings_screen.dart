import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _baseUrlCtrl = TextEditingController(text: settings.dioClient.baseUrl);
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
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
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withAlpha(30),
                      child: Text(
                        auth.user!.username[0].toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.user!.username,
                          style: const TextStyle(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(auth.user!.email,
                            style: const TextStyle(
                                color: AppColors.onSurfaceMuted, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Server Configuration',
                  style: TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _baseUrlCtrl,
                  style:
                      const TextStyle(color: AppColors.onSurface, fontSize: 14),
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
          const Divider(height: 1, color: AppColors.divider),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.sell),
            title:
                const Text('Sign Out', style: TextStyle(color: AppColors.sell)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surfaceVariant,
                  title: const Text('Sign Out',
                      style: TextStyle(color: AppColors.onSurface)),
                  content: const Text(
                    'Are you sure you want to sign out?',
                    style: TextStyle(color: AppColors.onSurfaceMuted),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out',
                          style: TextStyle(color: AppColors.sell)),
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
              style: TextStyle(color: AppColors.onSurfaceSubtle, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
