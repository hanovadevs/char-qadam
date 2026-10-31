import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cozy_scene.dart';
import 'cozy_auth_frame.dart';
import '../../../data/auth/auth_state_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _tokenRequested = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestToken() async {
    if (ref.read(authStateProvider).isLoading) return;
    if (!_emailKey.currentState!.validate()) return;

    final token = await ref
        .read(authStateProvider.notifier)
        .forgotPassword(email: _emailController.text.trim());

    if (!mounted) return;
    if (ref.read(authStateProvider).errorMessage != null) return;

    setState(() {
      _tokenRequested = true;
      if (token != null && token.isNotEmpty) {
        _tokenController.text = token;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'If this email is registered, check your inbox and paste the reset token below.',
        ),
      ),
    );
  }

  Future<void> _handleResetPassword() async {
    if (ref.read(authStateProvider).isLoading) return;
    if (!_resetKey.currentState!.validate()) return;

    final success = await ref
        .read(authStateProvider.notifier)
        .resetPassword(
          resetToken: _tokenController.text.trim(),
          newPassword: _passwordController.text,
        );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password reset successfully! Please sign in with your new password.',
          ),
        ),
      );
      context.go('/login');
    } else {
      final error =
          ref.read(authStateProvider).errorMessage ?? 'Password reset failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.accentRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authStateProvider);
    return CozyAuthFrame(
      title: _tokenRequested ? 'A fresh start.' : 'Let’s get you back.',
      subtitle: _tokenRequested
          ? 'Check your inbox for reset instructions. Paste the reset token below and choose a new password.'
          : 'Enter your email to request password reset instructions.',
      pose: 'letter',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                state.errorMessage!,
                style: const TextStyle(color: AppTheme.destructive),
              ),
            ),
          if (!_tokenRequested)
            Form(
              key: _emailKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthLabel('Email address'),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!state.isLoading) _handleRequestToken();
                    },
                    decoration: const InputDecoration(
                      hintText: 'you@example.com',
                    ),
                    validator: (v) =>
                        v == null ||
                            !RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(v.trim())
                        ? 'Please enter a valid email address'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: state.isLoading ? null : _handleRequestToken,
                    child: Text(
                      state.isLoading ? 'Sending…' : 'Send reset instructions',
                    ),
                  ),
                ],
              ),
            )
          else
            Form(
              key: _resetKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthLabel('Reset token from your email'),
                  TextFormField(
                    controller: _tokenController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Paste your reset token',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter the token from your email'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const AuthLabel('New password'),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      hintText: 'At least 8 characters',
                      suffixIcon: IconButton(
                        tooltip: 'Show or hide new password',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (v) => v == null || v.length < 8
                        ? 'Use at least 8 characters'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const AuthLabel('Confirm new password'),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        tooltip: 'Show or hide confirmation',
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (v) => v != _passwordController.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: state.isLoading ? null : _handleResetPassword,
                    child: Text(
                      state.isLoading ? 'Updating…' : 'Update password',
                    ),
                  ),
                  TextButton(
                    onPressed: state.isLoading
                        ? null
                        : () => setState(() => _tokenRequested = false),
                    child: const Text('Resend or change email'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: state.isLoading ? null : () => context.go('/login'),
            child: const Text('Back to sign in'),
          ),
          const SizedBox(height: 8),
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(24)),
            child: CozyScene(height: 160, pose: 'sit'),
          ),
          const SizedBox(height: 12),
          const Text(
            'A little help. A fresh start.',
            textAlign: TextAlign.center,
            style: AppTheme.captionStyle,
          ),
        ],
      ),
    );
  }
}
