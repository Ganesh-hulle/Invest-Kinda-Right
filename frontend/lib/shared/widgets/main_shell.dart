import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

/// Bottom navigation shell wrapping all main tabs.
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(
        icon: Icons.bar_chart_rounded, label: 'Dashboard', path: '/dashboard'),
    _TabItem(
        icon: Icons.list_alt_rounded, label: 'Watchlist', path: '/watchlist'),
    _TabItem(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Portfolio',
        path: '/portfolio'),
    _TabItem(
        icon: Icons.receipt_long_rounded, label: 'Orders', path: '/orders'),
    _TabItem(
        icon: Icons.settings_outlined, label: 'Settings', path: '/settings'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: current,
          onTap: (i) => context.go(_tabs[i].path),
          items: _tabs
              .map(
                (t) => BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  label: t.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  final String path;
  const _TabItem({required this.icon, required this.label, required this.path});
}
