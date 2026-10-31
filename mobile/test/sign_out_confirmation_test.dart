import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/data/auth/auth_state_provider.dart';
import 'package:qadam/features/auth/presentation/sign_out_confirmation.dart';

class DialogAuth extends StateNotifier<AuthState> implements AuthNotifier {
  int signOuts = 0;
  DialogAuth()
    : super(
        const AuthState(
          status: AuthStatus.authenticated,
          token: 'original-session',
        ),
      );
  void replaceSession() => state = const AuthState(
    status: AuthStatus.authenticated,
    token: 'new-session',
  );
  @override
  Future<void> logout() async {
    signOuts++;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> showConfirmation(WidgetTester tester, DialogAuth auth) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authStateProvider.overrideWith((ref) => auth)],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              onPressed: () => confirmSignOut(context, ref),
              child: const Text('Account action'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Account action'));
  await tester.pumpAndSettle();
  expect(find.text('Sign out?'), findsOneWidget);
  expect(auth.signOuts, 0);
}

void main() {
  testWidgets('cancel keeps the current account signed in', (tester) async {
    final auth = DialogAuth();
    await showConfirmation(tester, auth);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 0);
    expect(auth.state.token, 'original-session');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('only confirming signs out the current account', (tester) async {
    final auth = DialogAuth();
    await showConfirmation(tester, auth);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 1);
    expect(auth.state.status, AuthStatus.unauthenticated);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('dismissing the prompt keeps the session', (tester) async {
    final auth = DialogAuth();
    await showConfirmation(tester, auth);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 0);
    expect(find.text('Sign out?'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('an old confirmation cannot sign out a replacement session', (
    tester,
  ) async {
    final auth = DialogAuth();
    await showConfirmation(tester, auth);
    auth.replaceSession();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 0);
    expect(auth.state.token, 'new-session');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
