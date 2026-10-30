import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qadam/core/services/background_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/data/merchant/merchant_ledger_repository.dart';
import 'package:qadam/features/merchant/presentation/merchant_ledgers_screen.dart';
import 'package:qadam/features/merchant/voucher_scan_value.dart';

MerchantLedgerReport report() => MerchantLedgerReport.fromJson({
  'id': '12345678-1234-1234-1234-123456789012',
  'period': 'week',
  'starts_on': '2026-10-26',
  'ends_on': '2026-11-01',
  'row_count': 3,
  'fixed_discount_total': '250.00',
  'created_at': '2026-10-30T09:00:00Z',
});

class LedgerFixture implements MerchantLedgerRepository {
  final requests = <String>[];
  bool failOnce = false;
  bool generated = false;
  int downloads = 0;
  @override
  Future<List<MerchantLedgerReport>> history({int offset = 0}) async =>
      generated ? [report()] : [];
  @override
  Future<MerchantLedgerReport> generate(
    String period,
    DateTime date,
    String requestId,
  ) async {
    requests.add(requestId);
    if (failOnce) {
      failOnce = false;
      throw DioException(
        requestOptions: RequestOptions(path: '/partner/v1/ledgers'),
        type: DioExceptionType.receiveTimeout,
      );
    }
    generated = true;
    return report();
  }

  @override
  Future<bool> download(MerchantLedgerReport value) async {
    downloads++;
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'merchant background jobs stop before reading movement or sending steps',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({
        'qadam_access_token': 'merchant-token',
        'qadam_cached_user': jsonEncode({'role': 'MERCHANT'}),
      });
      expect(await BackgroundSyncService.performSync(), isTrue);
    },
  );
  test(
    'QR values accept voucher codes and owned links without opening scanned URLs',
    () {
      expect(voucherScanValue(' sr-ab12-cd34 '), 'SR-AB12-CD34');
      expect(
        voucherScanValue('https://stepsyapp.com/v/SR-AB12-CD34'),
        'SR-AB12-CD34',
      );
      expect(
        voucherScanValue('aBcD_12345678901234567890'),
        'aBcD_12345678901234567890',
      );
      for (final invalid in [
        null,
        '',
        'https://attacker.example/v/SR-AB12-CD34',
        'javascript:alert(1)',
        'https://stepsyapp.com.evil/v/SR-AB12-CD34',
        'not a voucher',
        'x' * 3000,
      ]) {
        expect(voucherScanValue(invalid), isNull);
      }
    },
  );
  testWidgets(
    'canceling Save PDF retains the report and generation history for another download',
    (tester) async {
      final fixture = LedgerFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            merchantLedgerRepositoryProvider.overrideWithValue(fixture),
          ],
          child: const MaterialApp(home: MerchantLedgersScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate & save PDF'));
      await tester.pumpAndSettle();
      expect(fixture.requests, hasLength(1));
      expect(fixture.downloads, 1);
      expect(find.text('Weekly ledger'), findsOneWidget);
      expect(find.textContaining('Save canceled'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.ensureVisible(find.text('Download PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download PDF'));
      await tester.pumpAndSettle();
      expect(fixture.downloads, 2);
      expect(fixture.requests, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('retrying an uncertain generation reuses its request ID', (
    tester,
  ) async {
    final fixture = LedgerFixture()..failOnce = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          merchantLedgerRepositoryProvider.overrideWithValue(fixture),
        ],
        child: const MaterialApp(home: MerchantLedgersScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate & save PDF'));
    await tester.pumpAndSettle();
    expect(fixture.requests, hasLength(1));
    await tester.ensureVisible(find.text('Generate & save PDF'));
    await tester.tap(find.text('Generate & save PDF'));
    await tester.pumpAndSettle();
    expect(fixture.requests, hasLength(2));
    expect(fixture.requests[0], fixture.requests[1]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
