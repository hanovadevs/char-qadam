import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/stepsy_information.dart';
import '../../../data/auth/auth_state_provider.dart';
import 'cozy_auth_frame.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
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
        .register(
          email: _email.text.trim(),
          password: _password.text,
          country: 'PK',
          timezone: 'Asia/Karachi',
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authStateProvider);
    return CozyAuthFrame(
      title: 'Your first step.',
      subtitle: 'Create an account to start your journey.',
      pose: 'wave',
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
                autofillHints: const [AutofillHints.email],
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
              const AuthLabel('Create password'),
              TextFormField(
                controller: _password,
                obscureText: _hidden,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) {
                  if (!state.isLoading) _submit();
                },
                decoration: InputDecoration(
                  hintText: 'At least 8 characters',
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
                validator: (v) => v == null || v.length < 8
                    ? 'Use at least 8 characters'
                    : null,
              ),
              const SizedBox(height: 8),
              const Text(
                'Use a strong, unique password.',
                style: AppTheme.captionStyle,
              ),
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'By creating an account, you agree to the ',
                    style: AppTheme.captionStyle,
                  ),
                  InkWell(
                    onTap: () => showStepsyInformation(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Terms.',
                        style: TextStyle(
                          color: AppTheme.accentSolid,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const Text(' Read our ', style: AppTheme.captionStyle),
                  InkWell(
                    onTap: () => showStepsyInformation(context, privacy: true),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Privacy Policy.',
                        style: TextStyle(
                          color: AppTheme.accentSolid,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: state.isLoading ? null : _submit,
                child: Text(
                  state.isLoading ? 'Creating account…' : 'Create account',
                ),
              ),
              const AuthDivider(),
              GoogleAuthButton(
                onPressed: state.isLoading
                    ? null
                    : () => ref
                          .read(authStateProvider.notifier)
                          .signInWithGoogle(
                            country: 'PK',
                            timezone: 'Asia/Karachi',
                          ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Already have an account?'),
                  TextButton(
                    onPressed: state.isLoading
                        ? null
                        : () => context.go('/login'),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
