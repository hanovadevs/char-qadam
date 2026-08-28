import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/background_sync_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  await BackgroundSyncService.initialize();

  runApp(
    const ProviderScope(
      child: WalkNSaveApp(),
    ),
  );
}

class WalkNSaveApp extends ConsumerWidget {
  const WalkNSaveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Walk n Save',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme,
      themeMode: ThemeMode.light, // Default to Swiss Light theme
      routerConfig: router,
    );
  }
}

// Alias for test compatibility
typedef QadamApp = WalkNSaveApp;
