import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/merchant/merchant_ledger_repository.dart';

class MerchantLedgersScreen extends ConsumerStatefulWidget {
  const MerchantLedgersScreen({super.key});
  @override
  ConsumerState<MerchantLedgersScreen> createState() =>
      _MerchantLedgersScreenState();
}

class _MerchantLedgersScreenState extends ConsumerState<MerchantLedgersScreen> {
  String _period = 'week';
  late DateTime _anchor;
  List<MerchantLedgerReport> _reports = [];
  bool _loading = true, _busy = false, _hasMore = true;
  String? _error, _requestId;
  int _historyRequest = 0;
  DateTime get _pakistanToday {
    final now = DateTime.now().toUtc().add(const Duration(hours: 5));
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _anchor = _pakistanToday;
    _load();
  }

  String _message(Object error) {
    if (error is PlatformException && error.message != null) {
      return error.message!;
    }
    if (error is StateError) return error.message.toString();
    if (error is DioException) {
      var data = error.response?.data;
      if (data is List<int>) {
        try {
          data = jsonDecode(utf8.decode(data));
        } catch (_) {
          data = null;
        }
      }
      final detail = data is Map ? data['detail'] : null;
      if (detail is String) return detail;
    }
    return 'The ledger could not be loaded or saved. Check your connection and try again.';
  }

  Future<void> _load({bool more = false}) async {
    final request = ++_historyRequest;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await ref
          .read(merchantLedgerRepositoryProvider)
          .history(offset: more ? _reports.length : 0);
      if (!mounted || request != _historyRequest) return;
      setState(() {
        _reports = more ? [..._reports, ...reports] : reports;
        _hasMore = reports.length == 20;
      });
    } catch (e) {
      if (mounted && request == _historyRequest) {
        setState(() => _error = _message(e));
      }
    } finally {
      if (mounted && request == _historyRequest) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save(MerchantLedgerReport report) async {
    final saved = await ref
        .read(merchantLedgerRepositoryProvider)
        .download(report);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'PDF saved to your selected location.'
              : 'Save canceled. The PDF is still available in generation history.',
        ),
      ),
    );
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _requestId ??= const Uuid().v4();
    });
    try {
      final report = await ref
          .read(merchantLedgerRepositoryProvider)
          .generate(_period, _anchor, _requestId!);
      _requestId = null;
      if (!mounted) return;
      await _load();
      if (mounted) await _save(report);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(MerchantLedgerReport report) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _save(report);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _rangeLabel {
    final first = _period == 'week'
        ? _anchor.subtract(Duration(days: _anchor.weekday - 1))
        : DateTime(_anchor.year, _anchor.month);
    final last = _period == 'week'
        ? first.add(const Duration(days: 6))
        : DateTime(_anchor.year, _anchor.month + 1, 0);
    return '${DateFormat('d MMM yyyy').format(first)} – ${DateFormat('d MMM yyyy').format(last)}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Merchant ledgers')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Your store, on record.',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.inkPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Generate a weekly or monthly PDF of redeemed vouchers. Reports use Pakistan time and stay in your store’s history.',
          ),
          const SizedBox(height: 20),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'week', label: Text('Week')),
              ButtonSegment(value: 'month', label: Text('Month')),
            ],
            selected: {_period},
            onSelectionChanged: _busy
                ? null
                : (value) => setState(() {
                    _period = value.first;
                    _requestId = null;
                  }),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(_rangeLabel),
            onPressed: _busy
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _anchor,
                      firstDate: DateTime(2020),
                      lastDate: _pakistanToday,
                    );
                    if (picked != null && mounted) {
                      setState(() {
                        _anchor = picked;
                        _requestId = null;
                      });
                    }
                  },
          ),
          const SizedBox(height: 8),
          const Text(
            'Weeks run Monday–Sunday. Current periods include activity recorded when you generate the report.',
            style: TextStyle(fontSize: 12, color: AppTheme.inkSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _generate,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_busy ? 'Preparing…' : 'Generate & save PDF'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppTheme.destructive)),
            TextButton(
              onPressed: _busy ? null : _load,
              child: const Text('Reload history'),
            ),
          ],
          const SizedBox(height: 28),
          const Text(
            'Generation history',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_loading && _reports.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_reports.isEmpty && _error == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Your generated ledgers will appear here. You can download them again anytime.',
              ),
            ),
          for (final report in _reports)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${report.period == 'week' ? 'Weekly' : 'Monthly'} ledger',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${report.startsOn} – ${report.endsOn}'),
                    Text(
                      '${report.rowCount} redemptions · Fixed discounts: PKR ${report.fixedDiscountTotal}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.inkSecondary,
                      ),
                    ),
                    Text(
                      'Generated ${DateFormat('d MMM yyyy, h:mm a').format(report.createdAt.toUtc().add(const Duration(hours: 5)))} PKT',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.inkSecondary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : () => _download(report),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download PDF'),
                    ),
                  ],
                ),
              ),
            ),
          if (_hasMore && _reports.isNotEmpty)
            TextButton(
              onPressed: _busy || _loading ? null : () => _load(more: true),
              child: Text(_loading ? 'Loading…' : 'Load more'),
            ),
        ],
      ),
    ),
  );
}
