import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/auth/auth_state_provider.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  DateTime? _resendAt;
  int get _remaining {
    final milliseconds = _resendAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    final seconds = (milliseconds / 1000).ceil();
    return seconds.clamp(0, 60);
  }

  @override
  void initState() {
    super.initState();
    _resetTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _resetTimer() {
    final seconds =
        ref.read(authStateProvider).verification?.resendAfterSeconds ?? 60;
    _resendAt = DateTime.now().add(Duration(seconds: seconds));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authStateProvider);
    return Scaffold(
      backgroundColor: AppTheme.surfaceMuted,
      appBar: AppBar(title: const Text('Verify your email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter the six-digit code sent to ${state.verification?.email ?? 'your email'}.',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The code expires in 10 minutes. Check your spam folder too.',
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Verification code',
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (_code.text.length == 6 && !state.isLoading) {
                        ref
                            .read(authStateProvider.notifier)
                            .verifyEmail(_code.text);
                      }
                    },
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage!,
                      style: const TextStyle(color: AppTheme.destructive),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: state.isLoading || _code.text.length != 6
                        ? null
                        : () => ref
                              .read(authStateProvider.notifier)
                              .verifyEmail(_code.text),
                    child: Text(
                      state.isLoading ? 'Please wait…' : 'Verify and continue',
                    ),
                  ),
                  TextButton(
                    onPressed: state.isLoading || _remaining > 0
                        ? null
                        : () async {
                            final sent = await ref
                                .read(authStateProvider.notifier)
                                .resendVerification();
                            if (sent && context.mounted) {
                              _code.clear();
                              setState(_resetTimer);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('A new code has been sent.'),
                                ),
                              );
                            }
                          },
                    child: Text(
                      _remaining > 0
                          ? 'Resend code in ${_remaining}s'
                          : 'Resend code',
                    ),
                  ),
                  TextButton(
                    onPressed: state.isLoading
                        ? null
                        : () => ref.read(authStateProvider.notifier).logout(),
                    child: const Text('Back to sign in'),
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
