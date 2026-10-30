import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/auth/auth_state_provider.dart';

/// Confirm deliberate sign-out; expired/revoked sessions are cleared immediately.
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final session = ref.read(authStateProvider);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text(
        'You’ll need to sign in again. Your saved data stays with this account.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final current = ref.read(authStateProvider);
  if (current.token != session.token || current.user?.id != session.user?.id) {
    return;
  }
  await ref.read(authStateProvider.notifier).logout();
}
