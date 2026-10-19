import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'companion.dart';
import 'experience_provider.dart';

Future<void> showExperienceSettings(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ExperienceSheet(),
    );

class _ExperienceSheet extends ConsumerStatefulWidget {
  const _ExperienceSheet();
  @override
  ConsumerState<_ExperienceSheet> createState() => _ExperienceSheetState();
}

class _ExperienceSheetState extends ConsumerState<_ExperienceSheet> {
  late final _goal = TextEditingController(
    text: '${ref.read(experienceProvider).goal}',
  );
  String? _error;
  bool _saving = false;
  Future<void> _toggle({bool? animations, bool? tips}) async {
    try {
      await ref
          .read(experienceProvider.notifier)
          .update(animations: animations, tips: tips);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Please try again.');
    }
  }

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(experienceProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Companion(size: 64),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your pace, your way.',
                    style: AppTheme.titleStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _goal,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Personal daily step goal',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '1,000–50,000 steps. This personal goal does not change point earnings or the streak rule.',
              style: AppTheme.captionStyle,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Companion animations'),
              subtitle: const Text(
                'System reduced motion always takes priority.',
              ),
              value: prefs.animations,
              onChanged: prefs.loaded ? (v) => _toggle(animations: v) : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Companion tips'),
              value: prefs.tips,
              onChanged: prefs.loaded ? (v) => _toggle(tips: v) : null,
            ),
            const Text(
              'Goals and companion preferences are saved for your account on this phone.',
              style: AppTheme.captionStyle,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving || !prefs.loaded
                    ? null
                    : () async {
                        final value = int.tryParse(_goal.text);
                        if (value == null || value < 1000 || value > 50000) {
                          setState(() => _error = 'Enter 1,000–50,000 steps');
                          return;
                        }
                        setState(() => _saving = true);
                        try {
                          await ref
                              .read(experienceProvider.notifier)
                              .update(goal: value);
                          if (context.mounted) Navigator.pop(context);
                        } catch (_) {
                          if (mounted) {
                            setState(() {
                              _saving = false;
                              _error = 'Could not save. Please try again.';
                            });
                          }
                        }
                      },
                child: const Text('Save preferences'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
