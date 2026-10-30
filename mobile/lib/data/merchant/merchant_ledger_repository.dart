import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

final merchantLedgerRepositoryProvider = Provider(
  (ref) => MerchantLedgerRepository(ref.watch(apiClientProvider)),
);

class MerchantLedgerReport {
  final String id, period, startsOn, endsOn;
  final int rowCount;
  final String fixedDiscountTotal;
  final DateTime createdAt;
  MerchantLedgerReport.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      period = json['period'] as String,
      startsOn = json['starts_on'] as String,
      endsOn = json['ends_on'] as String,
      rowCount = json['row_count'] as int,
      fixedDiscountTotal = json['fixed_discount_total'].toString(),
      createdAt = DateTime.parse(json['created_at'] as String);
  String get filename => 'stepsy-$period-$startsOn-${id.substring(0, 8)}.pdf';
}

class MerchantLedgerRepository {
  final ApiClient api;
  MerchantLedgerRepository(this.api);
  Future<List<MerchantLedgerReport>> history({int offset = 0}) async {
    final response = await api.get<List<dynamic>>(
      '/partner/v1/ledgers',
      queryParameters: {'limit': 20, 'offset': offset},
    );
    return response.data!
        .map(
          (json) => MerchantLedgerReport.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<MerchantLedgerReport> generate(
    String period,
    DateTime date,
    String requestId,
  ) async {
    final response = await api.post<Map<String, dynamic>>(
      '/partner/v1/ledgers',
      data: {
        'period': period,
        'anchor_date': date.toIso8601String().split('T').first,
        'request_id': requestId,
      },
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );
    return MerchantLedgerReport.fromJson(response.data!);
  }

  Future<bool> download(MerchantLedgerReport report) async {
    final response = await api.get<List<int>>(
      '/partner/v1/ledgers/${report.id}/pdf',
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    final data = response.data!;
    if (data.length < 5 || String.fromCharCodes(data.take(5)) != '%PDF-') {
      throw StateError(
        'The server did not return a valid PDF. Please try again.',
      );
    }
    return await const MethodChannel('stepsy/documents').invokeMethod<bool>(
          'savePdf',
          {'bytes': Uint8List.fromList(data), 'filename': report.filename},
        ) ??
        false;
  }
}
