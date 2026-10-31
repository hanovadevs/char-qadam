import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/core/theme/app_theme.dart';
import 'package:qadam/data/api/api_client.dart';
import 'package:qadam/features/support/presentation/support_screen.dart';
import 'package:qadam/features/support/presentation/saved_support_guides.dart';

class SupportApi implements ApiClient {
  Future<dynamic> Function(String path)? load;
  bool failSend = false;
  int sends = 0;
  Map<String, dynamic> detail = {
    'id': 'test-ticket',
    'subject': 'Missing points',
    'status': 'WAITING',
    'messages': [
      {
        'author': 'USER',
        'message': 'My points have not synced today.',
        'created_at': '2026-10-31T10:00:00Z',
      },
      {
        'author': 'ADMIN',
        'message': 'Please refresh Steps once you are connected.',
        'created_at': '2026-10-31T10:10:00Z',
      },
    ],
  };
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final dynamic data = load != null
        ? await load!(path)
        : path == '/support/faqs'
        ? {'faqs': savedSupportGuides, 'ai_available': false}
        : path == '/support/tickets'
        ? <dynamic>[]
        : detail;
    return Response<T>(
      data: data as T,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    sends++;
    if (failSend) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 503,
          data: {'detail': 'Support is temporarily unavailable.'},
        ),
      );
    }
    return Response<T>(
      data:
          {
                'id': 'test-ticket',
                'subject': 'Missing points',
                'status': 'OPEN',
                'category': 'points',
              }
              as T,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> showSupport(
  WidgetTester tester,
  SupportApi api, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const SupportScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

Finder input(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> openForm(WidgetTester tester) async {
  await tester.tap(find.text('My messages'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('New message'));
  await tester.pumpAndSettle();
  await tester.enterText(input('A short subject'), 'Missing points');
  await tester.enterText(
    input('What happened?'),
    'My points have not synced today.',
  );
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Send message'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'saved answers are usable while requests stall and survive independent failures',
    (tester) async {
      final faqs = Completer<dynamic>(), tickets = Completer<dynamic>();
      final api = SupportApi()
        ..load = (path) =>
            path == '/support/faqs' ? faqs.future : tickets.future;
      await showSupport(tester, api);
      expect(find.text('Let’s sort it out.'), findsOneWidget);
      expect(
        find.text('My steps have stopped. What should I check?'),
        findsOneWidget,
      );
      await tester.enterText(input('Search quick answers'), 'voucher');
      await tester.pump();
      expect(
        find.text('My steps have stopped. What should I check?'),
        findsNothing,
      );
      faqs.completeError(Exception('offline'));
      tickets.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Showing saved guidance'), findsOneWidget);
      expect(find.text('Ask an AI helper'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed sends retain the message draft and never retry a write automatically',
    (tester) async {
      final api = SupportApi()..failSend = true;
      await showSupport(tester, api);
      await openForm(tester);
      await tester.tap(find.text('Send message'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(input('A short subject')).controller!.text,
        'Missing points',
      );
      expect(
        tester.widget<TextField>(input('What happened?')).controller!.text,
        'My points have not synced today.',
      );
      expect(api.sends, 1);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Support is temporarily unavailable.'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'confirmed messages open their private conversation and return to message history',
    (tester) async {
      final api = SupportApi();
      await showSupport(tester, api);
      await openForm(tester);
      await tester.tap(find.text('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Your conversation'), findsOneWidget);
      expect(find.text('Stepsy support'), findsOneWidget);
      expect(
        find.text('Please refresh Steps once you are connected.'),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Your conversations'), findsOneWidget);
      expect(find.text('Missing points'), findsOneWidget);
      expect(api.sends, 1);
    },
  );

  testWidgets('support stays usable at a small viewport with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showSupport(tester, SupportApi(), scale: 1.7);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('My messages'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
