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
      backgroundColor: AppTheme.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.borderDark, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/icon/app_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppTheme.beige,
                  child: const Icon(
                    Icons.directions_walk,
                    size: 44,
                    color: AppTheme.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'STEPSY',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'STEP-BASED VALUE NETWORK',
              style: TextStyle(
                fontSize: 10,
                fontFamily: AppTheme.monoFont,
                color: AppTheme.grey,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.black),
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
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VOUCHER LOOKUP',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppTheme.black,
              ),
            ),
            Text(
              'SHARED VOUCHER CODE',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.grey,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.beige,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.borderDark, width: 1.5),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  size: 40,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'VOUCHER CODE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppTheme.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.offWhite,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.borderDark, width: 1.5),
                ),
                child: Text(
                  shortCode.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontFamily: AppTheme.monoFont,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: AppTheme.black,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Present this code at a partner merchant\nfor validation and redemption.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/wallet'),
                  child: const Text('VIEW IN WALLET'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/steps'),
                  child: const Text('GO TO DASHBOARD'),
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
