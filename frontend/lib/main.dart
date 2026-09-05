import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/network/dio_client.dart';
import 'core/storage/secure_storage.dart';
import 'core/websocket/market_ws_service.dart';
import 'features/auth/provider/auth_provider.dart';
import 'features/kite/provider/kite_provider.dart';
import 'features/watchlist/provider/watchlist_provider.dart';
import 'features/portfolio/provider/portfolio_provider.dart';
import 'features/orders/provider/orders_provider.dart';
import 'features/analytics/provider/analytics_provider.dart';
import 'features/settings/provider/settings_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final secureStorage = SecureStorage(storage);
  final dioClient = DioClient(secureStorage: secureStorage);
  final wsService = MarketWsService(secureStorage: secureStorage);

  runApp(
    MultiProvider(
      providers: [
        Provider<DioClient>.value(value: dioClient),
        Provider<SecureStorage>.value(value: secureStorage),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            dioClient: dioClient,
            secureStorage: secureStorage,
          ),
        ),
        ChangeNotifierProxyProvider<AuthProvider, KiteProvider>(
          create: (ctx) => KiteProvider(dioClient: dioClient),
          update: (ctx, auth, prev) =>
              prev ?? KiteProvider(dioClient: dioClient),
        ),
        ChangeNotifierProxyProvider<AuthProvider, WatchlistProvider>(
          create: (ctx) => WatchlistProvider(
            dioClient: dioClient,
            secureStorage: secureStorage,
            wsService: wsService,
          ),
          update: (ctx, auth, prev) =>
              prev ??
              WatchlistProvider(
                dioClient: dioClient,
                secureStorage: secureStorage,
                wsService: wsService,
              ),
        ),
        ChangeNotifierProvider(
          create: (_) => PortfolioProvider(dioClient: dioClient),
        ),
        ChangeNotifierProvider(
          create: (_) => OrdersProvider(dioClient: dioClient),
        ),
        ChangeNotifierProvider(
          create: (_) => AnalyticsProvider(dioClient: dioClient),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(dioClient: dioClient),
        ),
        Provider<MarketWsService>.value(value: wsService),
        Provider<AppConfig>.value(value: AppConfig.defaultConfig()),
      ],
      child: const IKRApp(),
    ),
  );
}
