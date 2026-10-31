import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/background_sync_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/config/env_config.dart';
import 'routing/app_router.dart';
import 'data/auth/auth_state_provider.dart';
import 'data/activity/health_service.dart';
import 'features/activity/providers/activity_provider.dart';
import 'features/points/providers/points_provider.dart';
import 'features/rewards/providers/rewards_provider.dart';
import 'features/wallet/providers/wallet_provider.dart';
import 'features/leaderboard/providers/leaderboard_provider.dart';
import 'features/merchant/providers/merchant_provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  EnvConfig.validateReleaseConfiguration();

  runApp(
    const ProviderScope(
      child: StepsyApp(),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeServices());
  });
}

Future<void> _initializeServices() async {
  try {
    await NotificationService.initialize();
    await BackgroundSyncService.initialize();
  } catch (error) {
    debugPrint('Optional service initialization failed: $error');
  }
}

class StepsyApp extends ConsumerWidget {
  const StepsyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider.select((value) => value.user?.id), (previous, next) {
      if (previous == next) return;
      unawaited(NotificationService.setUser(next));
      ref.invalidate(healthServiceProvider);
      ref.invalidate(activityProvider);
      ref.invalidate(pointsProvider);
      ref.invalidate(rewardsProvider);
      ref.invalidate(walletProvider);
      ref.invalidate(leaderboardProvider);
      ref.invalidate(merchantProvider);
    });
    final router = ref.watch(routerProvider);
    NotificationService.onTap = (route) {
      if (ref.read(authStateProvider).status == AuthStatus.authenticated) router.go(route);
    };
    final pending = NotificationService.pendingRoute;
    if (pending != null && ref.read(authStateProvider).status == AuthStatus.authenticated) {
      NotificationService.pendingRoute = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => router.go(pending));
    }

    return MaterialApp.router(
      title: 'Stepsy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme,
      themeMode: ThemeMode.light, // Default to Swiss Light theme
      routerConfig: router,
    );
  }
}

// Alias for test compatibility
typedef QadamApp = StepsyApp;
