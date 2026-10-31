import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/auth/auth_state_provider.dart';
import 'cozy_auth_frame.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authStateProvider);
    return CozyAuthFrame(
      welcome: true,
      pose: 'walk',
      title: 'Small steps.\nLovely possibilities.',
      subtitle: 'Walk, earn points, and enjoy partner discounts.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                state.errorMessage!,
                style: const TextStyle(color: AppTheme.destructive),
              ),
            ),
          GoogleAuthButton(
            onPressed: state.isLoading
                ? null
                : () => ref.read(authStateProvider.notifier).signInWithGoogle(),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: state.isLoading ? null : () => context.go('/login'),
            child: const Text('Continue with email'),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('New here?'),
              TextButton(
                onPressed: () => context.go('/register'),
                child: const Text('Create account'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text('By Hanova Devs', style: AppTheme.captionStyle),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ],
      ),
    );
  }
}
