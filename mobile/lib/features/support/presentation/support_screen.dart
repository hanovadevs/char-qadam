import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/env_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cozy_scene.dart';
import '../../../data/api/api_client.dart';
import 'saved_support_guides.dart';

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
  final _messagesScroll = ScrollController();
  List<dynamic> _faqs = savedSupportGuides;
  List<dynamic> _tickets = [];
  Map<String, dynamic>? _ticket;
  String _category = 'technical', _guideCategory = 'All', _search = '';
  String? _answer, _answeredQuestion, _error, _notice, _ticketsError;
  bool _answerIsAI = false, _reported = false, _busy = false;
  bool _loading = true, _consent = false, _aiAvailable = false;
  bool _hasMore = false, _offlineGuides = false, _formOpen = false;
  int _loadVersion = 0, _conversationVersion = 0;
  int _tabIndex = 0;
  DateTime? _lastAIRequest;
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [_question, _subject, _message, _reply]) {
      controller.dispose();
    }
    _messagesScroll.dispose();
    super.dispose();
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] is String) {
        return data['detail'] as String;
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'We could not connect. Your draft is still here. Check your connection and try again.';
      }
    }
    return 'That request did not finish. Please try again.';
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    if (mounted) {
      setState(() {
        _loading = true;
        _ticketsError = null;
      });
    }
    await Future.wait([
      () async {
        try {
          final response = await _api.get('/support/faqs');
          if (!mounted || version != _loadVersion) return;
          final data = response.data as Map<String, dynamic>;
          final guides = data['faqs'] as List<dynamic>;
          setState(() {
            if (guides.isNotEmpty) {
              final known = guides.map((guide) => guide['id']).toSet();
              _faqs = [
                ...guides,
                ...savedSupportGuides.where(
                  (guide) => !known.contains(guide['id']),
                ),
              ];
            }
            _aiAvailable = data['ai_available'] == true;
            _offlineGuides = false;
          });
        } catch (_) {
          if (mounted && version == _loadVersion) {
            setState(() {
              _offlineGuides = true;
            });
          }
        }
      }(),
      () async {
        try {
          final response = await _api.get(
            '/support/tickets',
            queryParameters: {'limit': 51},
          );
          if (!mounted || version != _loadVersion) return;
          final rows = response.data as List<dynamic>;
          setState(() {
            _tickets = rows.take(50).toList();
            _hasMore = rows.length > 50;
            _loading = false;
          });
        } catch (error) {
          if (mounted && version == _loadVersion) {
            setState(() {
              _ticketsError = _errorMessage(error);
              _loading = false;
            });
          }
        }
      }(),
    ]);
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
      if (mounted) {
        final message = _errorMessage(error);
        setState(() {
          _error = message;
        });
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _askAI() async {
    if (!_consent || _question.text.trim().length < 5) {
      setState(() {
        _error = 'Add your app question and confirm you want an AI answer.';
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
    final question = _question.text.trim();
    await _run(() async {
      final response = await _api.post(
        '/support/chat',
        data: {'message': question, 'consent': true},
      );
      if (!mounted) return;
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _answer = data['answer'] as String;
        _answeredQuestion = question;
        _answerIsAI = data['source'] == 'ai';
        _reported = false;
        if (_answerIsAI) _lastAIRequest = DateTime.now();
        _notice = data['remaining'] == null
            ? null
            : '${data['remaining']} AI questions remaining today.';
      });
    });
  }

  Future<void> _openTicket(String id) async {
    final version = ++_conversationVersion;
    await _run(() async {
      final response = await _api.get('/support/tickets/$id');
      if (mounted && version == _conversationVersion) {
        setState(() {
          _tabIndex = 1;
          _ticket = response.data as Map<String, dynamic>;
        });
      }
    });
  }

  void _closeTicket() {
    _conversationVersion++;
    setState(() {
      _ticket = null;
      _reply.clear();
      _error = null;
    });
  }

  Future<void> _createTicket() async {
    if (_subject.text.trim().length < 5 || _message.text.trim().length < 5) {
      setState(() {
        _error =
            'Add a short subject and a little detail (at least five characters each).';
      });
      return;
    }
    await _run(() async {
      final response = await _api.post(
        '/support/tickets',
        data: {
          'subject': _subject.text.trim(),
          'message': _message.text.trim(),
          'category': _category,
        },
      );
      if (!mounted) return;
      final created = response.data as Map<String, dynamic>;
      _loadVersion++;
      _subject.clear();
      _message.clear();
      setState(() {
        _tabIndex = 1;
        _loading = false;
        _ticketsError = null;
        _tickets = [
          created,
          ..._tickets.where((item) => item['id'] != created['id']),
        ];
        _formOpen = false;
        _notice = 'Message sent. Follow the team’s replies in My messages.';
      });
      // A detail refresh failing after an accepted POST must not invite a duplicate ticket.
      try {
        final detail = await _api.get('/support/tickets/${created['id']}');
        if (mounted) {
          setState(() {
            _ticket = detail.data as Map<String, dynamic>;
          });
        }
      } catch (_) {
        /* The confirmed conversation remains in My messages. */
      }
    });
  }

  Future<void> _sendReply() async {
    if (_reply.text.trim().length < 5) {
      setState(() {
        _error = 'Please add a little more detail.';
      });
      return;
    }
    final id = _ticket!['id'] as String, version = _conversationVersion;
    await _run(() async {
      final response = await _api.post(
        '/support/tickets/$id/messages',
        data: {'message': _reply.text.trim()},
      );
      if (mounted && version == _conversationVersion && _ticket?['id'] == id) {
        setState(() {
          _ticket = response.data as Map<String, dynamic>;
          _reply.clear();
        });
      }
    });
  }

  Future<void> _emailSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: EnvConfig.supportEmail,
      queryParameters: {'subject': 'Stepsy support'},
    );
    try {
      if (await launchUrl(uri)) return;
    } catch (_) {
      /* Show a copyable fallback. */
    }
    if (mounted) {
      setState(() {
        _notice = 'You can email ${EnvConfig.supportEmail} from your mail app.';
      });
    }
  }

  void _writeMessage(BuildContext context, {String? question}) {
    if (_subject.text.isEmpty && question != null) _subject.text = question;
    setState(() {
      _tabIndex = 1;
      _formOpen = true;
    });
    DefaultTabController.of(context).animateTo(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _messagesScroll.hasClients) {
        _messagesScroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _status(dynamic value) => switch (value) {
    'WAITING' => 'Reply from the team',
    'RESOLVED' => 'Resolved',
    _ => 'Sent to the team',
  };
  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? ''
        : DateFormat('d MMM, h:mm a').format(parsed.toLocal());
  }

  Widget _panel(Widget child, {Color color = AppTheme.surface}) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.hairline),
    ),
    child: child,
  );
  Widget _feedback() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _error!,
            semanticsLabel: _error,
            style: const TextStyle(color: AppTheme.destructive),
          ),
        ),
      if (_notice != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _notice!,
            semanticsLabel: _notice,
            style: const TextStyle(color: AppTheme.accentDeep),
          ),
        ),
    ],
  );

  Widget _helpTab(BuildContext context) {
    final query = _search.trim().toLowerCase();
    final guides = _faqs
        .where(
          (item) =>
              (_guideCategory == 'All' ||
                  supportGuideCategory(item['id']?.toString() ?? '') ==
                      _guideCategory) &&
              '${item['question']} ${item['answer']}'.toLowerCase().contains(
                query,
              ),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _panel(
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Let’s sort it out.',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text('Quick answers, or a message to the team.'),
                  ],
                ),
              ),
              const CompanionPortrait(
                pose: 'wave',
                size: 94,
                interactive: true,
              ),
            ],
          ),
          color: AppTheme.sageWash,
        ),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search quick answers',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() {
            _search = value;
          }),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: ['All', 'Steps', 'Points', 'Rewards', 'Account']
              .map(
                (category) => ChoiceChip(
                  label: Text(category),
                  selected: category == _guideCategory,
                  onSelected: (_) => setState(() {
                    _guideCategory = category;
                  }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.push('/tracking-help'),
          icon: const Icon(Icons.directions_walk),
          label: const Text('Fix step tracking'),
        ),
        if (_offlineGuides)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Showing saved guidance. You can still read these answers offline.',
            ),
          ),
        if (guides.isEmpty)
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No matching answer yet.'),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _writeMessage(context),
                  child: const Text('Ask the support team'),
                ),
              ],
            ),
          ),
        ...guides.map(
          (faq) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              key: ValueKey(faq['id'] ?? faq['question']),
              title: Text(
                faq['question'] as String,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              children: [
                SelectableText(faq['answer'] as String),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _writeMessage(
                    context,
                    question: faq['question'] as String,
                  ),
                  child: const Text('Still need help? Message us'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _writeMessage(context),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Write to the team'),
        ),
        TextButton.icon(
          onPressed: _emailSupport,
          icon: const Icon(Icons.mail_outline),
          label: const Text('Email support'),
        ),
        SelectableText(
          EnvConfig.supportEmail,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.inkSecondary),
        ),
        if (_aiAvailable) ...[const SizedBox(height: 20), _aiHelp()],
        _feedback(),
      ],
    );
  }

  Widget _aiHelp() => _panel(
    ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Ask an AI helper'),
      subtitle: const Text(
        'For app guidance; the team handles account issues.',
      ),
      children: [
        const Text(
          'AI answers can be mistaken. This helper cannot change your account, points or vouchers.',
        ),
        TextField(
          controller: _question,
          maxLength: 600,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Your Stepsy question'),
        ),
        CheckboxListTile(
          value: _consent,
          onChanged: (value) => setState(() {
            _consent = value ?? false;
          }),
          contentPadding: EdgeInsets.zero,
          title: const Text('Send this message to OpenAI for an AI answer.'),
          subtitle: const Text(
            'Do not include passwords, voucher codes or sensitive health details.',
          ),
        ),
        FilledButton(
          onPressed: _busy ? null : _askAI,
          child: Text(_busy ? 'Please wait…' : 'Ask AI'),
        ),
        if (_answer != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SelectableText(_answer!),
          ),
        if (_answerIsAI && _answer != null)
          TextButton.icon(
            icon: const Icon(Icons.flag_outlined),
            label: Text(
              _reported ? 'Reported to support' : 'Report this answer',
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
                    if (mounted) {
                      setState(() {
                        _reported = true;
                        _notice =
                            'Reported to the team. Refresh My messages to follow the conversation.';
                      });
                    }
                  }),
          ),
      ],
    ),
  );

  Widget _messagesTab(BuildContext context) => ListView(
    controller: _messagesScroll,
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Your conversations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: _loading || _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _busy
            ? null
            : () => setState(() {
                _formOpen = !_formOpen;
              }),
        icon: Icon(_formOpen ? Icons.close : Icons.edit_outlined),
        label: Text(_formOpen ? 'Close message form' : 'New message'),
      ),
      _feedback(),
      if (_formOpen) _messageForm(),
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(18),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (_ticketsError != null)
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_ticketsError!),
              TextButton(
                onPressed: _load,
                child: const Text('Try loading messages again'),
              ),
            ],
          ),
        ),
      if (!_loading && _ticketsError == null && _tickets.isEmpty)
        _panel(
          const Column(
            children: [
              Icon(Icons.forum_outlined, size: 38, color: AppTheme.accentSolid),
              SizedBox(height: 12),
              Text(
                'A little help is always welcome.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 6),
              Text(
                'Send your first message above. Replies from the team will appear here.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          color: AppTheme.sageWash,
        ),
      ..._tickets.map(
        (ticket) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: AppTheme.sageWash,
              child: Icon(
                ticket['status'] == 'WAITING'
                    ? Icons.mark_chat_unread_outlined
                    : Icons.chat_bubble_outline,
                color: AppTheme.accentDeep,
              ),
            ),
            title: Text(
              ticket['subject'] as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${_status(ticket['status'])}\n${_date(ticket['updated_at'])}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : () => _openTicket(ticket['id'] as String),
          ),
        ),
      ),
      if (_hasMore)
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(() async {
                  final response = await _api.get(
                    '/support/tickets',
                    queryParameters: {'limit': 51, 'offset': _tickets.length},
                  );
                  if (!mounted) return;
                  final next = response.data as List<dynamic>;
                  setState(() {
                    final known = _tickets.map((item) => item['id']).toSet();
                    _tickets.addAll(
                      next
                          .take(50)
                          .where((item) => !known.contains(item['id'])),
                    );
                    _hasMore = next.length > 50;
                  });
                }),
          child: const Text('Load more messages'),
        ),
      TextButton.icon(
        onPressed: _emailSupport,
        icon: const Icon(Icons.mail_outline),
        label: const Text('Prefer email?'),
      ),
    ],
  );

  Widget _messageForm() => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tell us what happened',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _category,
          decoration: const InputDecoration(
            labelText: 'What do you need help with?',
          ),
          items:
              const {
                    'technical': 'Something isn’t working',
                    'steps': 'Steps & tracking',
                    'points': 'Points & syncing',
                    'vouchers': 'Rewards & Wallet',
                    'account': 'My account',
                  }.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
          onChanged: _busy
              ? null
              : (value) => setState(() {
                  _category = value!;
                }),
        ),
        TextField(
          controller: _subject,
          enabled: !_busy,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'A short subject'),
        ),
        TextField(
          controller: _message,
          enabled: !_busy,
          maxLength: 2000,
          minLines: 3,
          maxLines: 7,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'What happened?',
            hintText: 'What were you trying to do? What did you see instead?',
          ),
        ),
        const Text(
          'Your message is private to you and the support team. Please leave out passwords and voucher QR codes.',
          style: TextStyle(fontSize: 12, color: AppTheme.inkSecondary),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _createTicket,
            child: Text(_busy ? 'Sending…' : 'Send message'),
          ),
        ),
      ],
    ),
  );

  Widget _conversation(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _closeTicket();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Your conversation'),
        leading: BackButton(onPressed: _closeTicket),
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            _ticket!['subject'] as String,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            _status(_ticket!['status']),
            style: const TextStyle(color: AppTheme.accentSolid),
          ),
          _feedback(),
          const SizedBox(height: 16),
          ...(_ticket!['messages'] as List<dynamic>).map((message) {
            final team = message['author'] == 'ADMIN';
            return Padding(
              padding: EdgeInsets.only(
                left: team ? 0 : 24,
                right: team ? 24 : 0,
              ),
              child: _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team ? 'Stepsy support' : 'You',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.accentDeep,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(message['message'] as String),
                    const SizedBox(height: 8),
                    Text(
                      _date(message['created_at']),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.inkSecondary,
                      ),
                    ),
                  ],
                ),
                color: team ? AppTheme.surface : AppTheme.sageWash,
              ),
            );
          }),
          TextField(
            controller: _reply,
            enabled: !_busy,
            maxLength: 2000,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Your reply'),
          ),
          FilledButton(
            onPressed: _busy ? null : _sendReply,
            child: Text(
              _busy
                  ? 'Sending…'
                  : _ticket!['status'] == 'RESOLVED'
                  ? 'Reply to reopen'
                  : 'Send reply',
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_ticket != null) return _conversation(context);
    return DefaultTabController(
      length: 2,
      initialIndex: _tabIndex,
      child: Builder(
        builder: (tabContext) => Scaffold(
          appBar: AppBar(
            title: const Text('Help & support'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Quick help'),
                Tab(text: 'My messages'),
              ],
            ),
          ),
          body: TabBarView(
            children: [_helpTab(tabContext), _messagesTab(tabContext)],
          ),
        ),
      ),
    );
  }
}
