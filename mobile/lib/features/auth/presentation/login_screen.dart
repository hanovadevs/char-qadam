import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/config/env_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/auth/auth_state_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authStateProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (!success) {
      final error = ref.read(authStateProvider).errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppTheme.destructive),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: EnvConfig.googleClientId,
        scopes: const ['email', 'profile'],
      );
      await googleSignIn.signOut();

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final token = googleAuth.idToken;
      if (token == null || token.isEmpty) {
        throw Exception('Google did not return an ID token. Please try again.');
      }
      if (!mounted) return;

      final success = await ref
          .read(authStateProvider.notifier)
          .loginWithGoogle(
            idToken: token,
            displayName: googleUser.displayName,
            photoUrl: googleUser.photoUrl,
          );
      if (!success && mounted) {
        throw Exception(
          ref.read(authStateProvider).errorMessage ?? 'Google sign-in failed',
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Google sign-in failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: AppTheme.destructive,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceMuted,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stepsy Brand Header Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(color: AppTheme.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceMuted,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            border: Border.all(color: AppTheme.hairline),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/icon/Stepsy_Icon1.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.directions_walk,
                                  size: 28,
                                  color: AppTheme.accentSolid,
                                ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Stepsy',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.0,
                            color: AppTheme.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Turn your daily movement into real rewards.',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppTheme.inkSecondary,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Error banner if any
                  if (authState.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: AppTheme.destructive.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_circle,
                            color: AppTheme.destructive,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              authState.errorMessage!,
                              style: const TextStyle(
                                color: AppTheme.destructive,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Form Container
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(color: AppTheme.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Email address',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'name@example.com',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            final emailRegex = RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            );
                            if (!emailRegex.hasMatch(value.trim())) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.inkSecondary,
                              ),
                            ),
                            InkWell(
                              onTap: () => context.push('/forgot-password'),
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.accentSolid,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? CupertinoIcons.eye_slash
                                    : CupertinoIcons.eye,
                                size: 18,
                                color: AppTheme.inkSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: authState.isLoading ? null : _submit,
                            child: authState.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.surface,
                                      ),
                                    ),
                                  )
                                : const Text('Sign in'),
                          ),
                        ),
                        const SizedBox(height: 18),

                        Row(
                          children: const [
                            Expanded(child: Divider(color: AppTheme.hairline)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.inkTertiary,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: AppTheme.hairline)),
                          ],
                        ),
                        const SizedBox(height: 18),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: authState.isLoading
                                ? null
                                : _handleGoogleSignIn,
                            child: const Text('Continue with Google'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: AppTheme.inkSecondary,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Create account',
                          style: TextStyle(
                            color: AppTheme.accentSolid,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // Agency Branding Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Powered by',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.inkSecondary,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Image.asset(
                        'assets/icon/Software_Agency_bg.png',
                        height: 36,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) =>
                            const Text(
                              'Hanova Devs',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.inkPrimary,
                              ),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
