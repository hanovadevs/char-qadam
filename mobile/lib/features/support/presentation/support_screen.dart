import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/api/api_client.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});
  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _question = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _reply = TextEditingController();
  List<dynamic> _faqs = [];
  List<dynamic> _tickets = [];
  Map<String, dynamic>? _ticket;
  String _category = 'technical';
  String? _answer;
  String? _answeredQuestion;
  bool _answerIsAI = false;
  bool _reported = false;
  String? _error;
  String? _notice;
  bool _busy = false;
  bool _loading = true;
  bool _consent = false;
  bool _aiAvailable = false;
  bool _hasMore = false;
  DateTime? _lastAIRequest;

  ApiClient get _api => ref.read(apiClientProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _question.dispose();
    _subject.dispose();
    _message.dispose();
    _reply.dispose();
    super.dispose();
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] is String)
        return data['detail'] as String;
    }
    return 'Unable to complete the request. Please try again.';
  }

  Future<void> _load() async {
    try {
      final responses = await Future.wait([
        _api.get('/support/faqs'),
        _api.get('/support/tickets', queryParameters: {'limit': 51}),
      ]);
      if (!mounted) return;
      final data = responses[0].data as Map<String, dynamic>;
      final tickets = responses[1].data as List<dynamic>;
      setState(() {
        _faqs = data['faqs'] as List<dynamic>;
        _aiAvailable = data['ai_available'] == true;
        _tickets = tickets.take(50).toList();
        _hasMore = tickets.length > 50;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = _errorMessage(error);
        });
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted)
        setState(() {
          _error = _errorMessage(error);
        });
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
        });
    }
  }

  Future<void> _askAI() async {
    if (!_consent || _question.text.trim().length < 5) {
      setState(() {
        _error =
            'Enter an app support question and confirm you want to send it to AI.';
      });
      return;
    }
    if (_lastAIRequest != null &&
        DateTime.now().difference(_lastAIRequest!) <
            const Duration(minutes: 1)) {
      setState(() {
        _error = 'Please wait one minute between AI questions.';
      });
      return;
    }
    final submittedQuestion = _question.text.trim();
    await _run(() async {
      final response = await _api.post(
        '/support/chat',
        data: {'message': submittedQuestion, 'consent': true},
      );
      if (!mounted) return;
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _answer = data['answer'] as String;
        _answeredQuestion = submittedQuestion;
        _answerIsAI = data['source'] == 'ai';
        _reported = false;
        if (data['source'] == 'ai') _lastAIRequest = DateTime.now();
        _notice = data['remaining'] == null
            ? null
            : '${data['remaining']} AI questions remaining today.';
      });
    });
  }

  Future<void> _openTicket(String id) async {
    await _run(() async {
      final response = await _api.get('/support/tickets/$id');
      if (mounted)
        setState(() {
          _ticket = response.data as Map<String, dynamic>;
        });
    });
  }

  Future<void> _createTicket() async {
    if (_subject.text.trim().length < 5 || _message.text.trim().length < 5) {
      setState(() {
        _error =
            'Add a subject and describe the issue using at least five characters each.';
      });
      return;
    }
    await _run(() async {
      await _api.post(
        '/support/tickets',
        data: {
          'subject': _subject.text.trim(),
          'message': _message.text.trim(),
          'category': _category,
        },
      );
      _subject.clear();
      _message.clear();
      await _load();
      if (mounted)
        setState(() {
          _notice = 'Your support ticket was created. Replies appear here.';
        });
    });
  }

  Widget _errorBanner() => Column(
    children: [
      if (_error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (_notice != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_notice!, semanticsLabel: _notice),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (_ticket != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Support conversation'),
          leading: BackButton(
            onPressed: () => setState(() {
              _ticket = null;
              _reply.clear();
            }),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh replies',
              onPressed: _busy
                  ? null
                  : () => _openTicket(_ticket!['id'] as String),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _ticket!['subject'] as String,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('Status: ${_ticket!['status']}'),
            _errorBanner(),
            ...(_ticket!['messages'] as List<dynamic>).map(
              (message) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message['author'] == 'ADMIN' ? 'Support team' : 'You',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(message['message'] as String),
                    ],
                  ),
                ),
              ),
            ),
            TextField(
              controller: _reply,
              maxLength: 2000,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Reply'),
            ),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      if (_reply.text.trim().length < 5) {
                        setState(() {
                          _error = 'Please add a little more detail.';
                        });
                        return;
                      }
                      final response = await _api.post(
                        '/support/tickets/${_ticket!['id']}/messages',
                        data: {'message': _reply.text.trim()},
                      );
                      if (mounted)
                        setState(() {
                          _ticket = response.data as Map<String, dynamic>;
                          _reply.clear();
                        });
                    }),
              child: const Text('Send reply'),
            ),
          ],
        ),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Help & support'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'FAQs'),
              Tab(text: 'AI help'),
              Tab(text: 'My tickets'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _errorBanner(),
                      if (_faqs.isEmpty)
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry loading FAQs'),
                        ),
                      ..._faqs.map(
                        (faq) => Card(
                          child: ExpansionTile(
                            title: Text(faq['question'] as String),
                            childrenPadding: const EdgeInsets.all(16),
                            children: [Text(faq['answer'] as String)],
                          ),
                        ),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'AI help can explain app features. It cannot change your points, account, or vouchers. Answers can be mistaken; contact the support team for account issues.',
                      ),
                      const SizedBox(height: 12),
                      if (!_aiAvailable)
                        const Text(
                          'AI help is currently unavailable. FAQs and support tickets are available.',
                        ),
                      TextField(
                        controller: _question,
                        maxLength: 600,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Your app support question',
                        ),
                      ),
                      CheckboxListTile(
                        value: _consent,
                        onChanged: (value) => setState(() {
                          _consent = value ?? false;
                        }),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Send this message to OpenAI for an AI answer.',
                        ),
                        subtitle: const Text(
                          'Do not include passwords, voucher codes, or sensitive health details. FAQs do not use AI.',
                        ),
                      ),
                      FilledButton(
                        onPressed: _busy || !_aiAvailable ? null : _askAI,
                        child: Text(_busy ? 'Please wait…' : 'Ask AI'),
                      ),
                      _errorBanner(),
                      if (_answer != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SelectableText(_answer!),
                          ),
                        ),
                      if (_answerIsAI && _answer != null)
                        TextButton.icon(
                          icon: const Icon(Icons.flag_outlined),
                          label: Text(
                            _reported
                                ? 'Reported to support'
                                : 'Report this answer to support',
                          ),
                          onPressed: _busy || _reported
                              ? null
                              : () => _run(() async {
                                  final report =
                                      'Please review this AI answer.\nQuestion: $_answeredQuestion\nAnswer: $_answer';
                                  await _api.post(
                                    '/support/tickets',
                                    data: {
                                      'subject': 'AI answer report',
                                      'category': 'technical',
                                      'message': String.fromCharCodes(
                                        report.runes.take(2000),
                                      ),
                                    },
                                  );
                                  if (mounted)
                                    setState(() {
                                      _reported = true;
                                      _notice = 'Reported to the support team.';
                                    });
                                }),
                        ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text('Contact the support team'),
                      TextField(
                        controller: _subject,
                        maxLength: 120,
                        decoration: const InputDecoration(labelText: 'Subject'),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items:
                            const [
                                  'technical',
                                  'steps',
                                  'points',
                                  'vouchers',
                                  'account',
                                ]
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) => setState(() {
                          _category = value!;
                        }),
                      ),
                      TextField(
                        controller: _message,
                        maxLength: 2000,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Describe the issue',
                        ),
                      ),
                      const Text(
                        'Your message is saved for the support team. Never send passwords or payment details.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy ? null : _createTicket,
                        child: const Text('Create support ticket'),
                      ),
                      _errorBanner(),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Your conversations'),
                          IconButton(
                            tooltip: 'Refresh tickets',
                            onPressed: _busy ? null : _load,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      if (_tickets.isEmpty)
                        const Text('You have no support tickets.'),
                      ..._tickets.map(
                        (ticket) => ListTile(
                          title: Text(ticket['subject'] as String),
                          subtitle: Text(ticket['status'] as String),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _busy
                              ? null
                              : () => _openTicket(ticket['id'] as String),
                        ),
                      ),
                      if (_hasMore)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  final response = await _api.get(
                                    '/support/tickets',
                                    queryParameters: {
                                      'limit': 51,
                                      'offset': _tickets.length,
                                    },
                                  );
                                  if (!mounted) return;
                                  final next = response.data as List<dynamic>;
                                  setState(() {
                                    _tickets.addAll(next.take(50));
                                    _hasMore = next.length > 50;
                                  });
                                }),
                          child: const Text('Load more tickets'),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
