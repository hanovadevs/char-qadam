import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../data/auth/auth_state_provider.dart';
import '../features/activity/presentation/activity_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/home/presentation/main_scaffold.dart';
import '../features/leaderboard/presentation/leaderboard_screen.dart';
import '../features/merchant/presentation/merchant_pos_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/points/presentation/points_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/rewards/presentation/rewards_screen.dart';
import '../features/wallet/presentation/wallet_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Tracks whether onboarding has been completed (loaded once on app start).
final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  const storage = FlutterSecureStorage();
  final value = await storage.read(key: onboardingCompleteKey);
  return value == 'true';
});

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final onboardingAsync = ref.watch(onboardingCompleteProvider);
  final onboardingComplete = onboardingAsync.valueOrNull ?? true;

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: _RiverpodRefreshListenable(ref, authStateProvider),
    redirect: (context, state) {
      final status = authState.status;
      final isSplash = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (status == AuthStatus.initial) {
        return isSplash ? null : '/splash';
      }

      if (status == AuthStatus.unauthenticated) {
        return isAuthRoute ? null : '/login';
      }

      if (status == AuthStatus.authenticated) {
        // If the authenticated user is a Merchant, route directly to /merchant-pos!
        if (authState.user?.isMerchant == true) {
          if (state.matchedLocation != '/merchant-pos') {
            return '/merchant-pos';
          }
          return null;
        }

        // Customer users should not view merchant POS screen
        if (state.matchedLocation == '/merchant-pos') {
          return '/steps';
        }

        if (isSplash || isAuthRoute) {
          // Check if onboarding needs to be shown
          if (!onboardingComplete) {
            return '/onboarding';
          }
          return '/steps';
        }
        // If on onboarding and already completed, redirect to steps
        if (isOnboarding && onboardingComplete) {
          return '/steps';
        }
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/leaderboard',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/merchant-pos',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MerchantPosScreen(),
      ),
      GoRoute(
        path: '/v/:code',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return VoucherDeepLinkScreen(shortCode: code);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/steps',
                builder: (context, state) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/points',
                builder: (context, state) => const PointsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rewards',
                builder: (context, state) => const RewardsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wallet',
                builder: (context, state) => const WalletScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Dedicated splash screen shown during app startup and auth token resolution (Swiss Light Style).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceMuted,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.hairline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/icon/app_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppTheme.surfaceMuted,
                  child: const Icon(
                    Icons.directions_walk,
                    size: 44,
                    color: AppTheme.accentSolid,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Stepsy',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: AppTheme.inkPrimary,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentSolid),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deep link screen for voucher share links (/v/:code)
class VoucherDeepLinkScreen extends StatelessWidget {
  final String shortCode;
  const VoucherDeepLinkScreen({super.key, required this.shortCode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Voucher Lookup',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: AppTheme.inkPrimary,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppTheme.accentBright.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.qr_code_2,
                        size: 34,
                        color: AppTheme.accentSolid,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Voucher code',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.hairline),
                      ),
                      child: Text(
                        shortCode.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: AppTheme.inkPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Present this code at a partner store for validation and redemption.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.inkSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/wallet'),
                  child: const Text('View in wallet'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/steps'),
                  child: const Text('Go to dashboard'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Listenable bridge connecting Riverpod state changes to GoRouter's refreshListenable.
class _RiverpodRefreshListenable extends ChangeNotifier {
  _RiverpodRefreshListenable(Ref ref, ProviderBase<dynamic> provider) {
    ref.listen(provider, (previous, next) => notifyListeners());
  }
}
