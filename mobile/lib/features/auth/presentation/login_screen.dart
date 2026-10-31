import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/auth/auth_state_provider.dart';
import 'cozy_auth_frame.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  bool _hidden = true;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authStateProvider).isLoading) return;
    if (!_form.currentState!.validate()) return;
    await ref
        .read(authStateProvider.notifier)
        .login(email: _email.text.trim(), password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authStateProvider);
    return CozyAuthFrame(
      title: 'Welcome back.',
      subtitle: 'Your next little win is waiting.',
      pose: 'peek',
      child: AutofillGroup(
        child: Form(
          key: _form,
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
              const AuthLabel('Email address'),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                decoration: const InputDecoration(hintText: 'you@example.com'),
                validator: (v) =>
                    v == null ||
                        !RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(v.trim())
                    ? 'Please enter a valid email address'
                    : null,
              ),
              const SizedBox(height: 18),
              const AuthLabel('Password'),
              TextFormField(
                controller: _password,
                obscureText: _hidden,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) {
                  if (!state.isLoading) _submit();
                },
                decoration: InputDecoration(
                  hintText: 'Your password',
                  suffixIcon: IconButton(
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Please enter your password'
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: state.isLoading
                      ? null
                      : () => context.go('/forgot-password'),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: state.isLoading ? null : _submit,
                child: Text(state.isLoading ? 'Signing in…' : 'Sign in'),
              ),
              const AuthDivider(),
              GoogleAuthButton(
                onPressed: state.isLoading
                    ? null
                    : () => ref
                          .read(authStateProvider.notifier)
                          .signInWithGoogle(),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('New to Stepsy?'),
                  TextButton(
                    onPressed: state.isLoading
                        ? null
                        : () => context.go('/register'),
                    child: const Text('Create account'),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => showDeviceAccountInfo(context),
                child: const Text(
                  'About accounts on this phone',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: AppTheme.inkSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
