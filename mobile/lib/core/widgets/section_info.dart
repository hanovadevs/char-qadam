import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Keep optional explanations one accessible tap away from the main task.
class SectionInfo extends StatelessWidget {
  final String title, message;
  final List<Widget> actions;
  const SectionInfo({
    super.key,
    required this.title,
    required this.message,
    this.actions = const [],
  });
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: title,
    icon: const Icon(CupertinoIcons.info_circle, size: 18),
    color: AppTheme.inkSecondary,
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTheme.titleStyle),
              const SizedBox(height: 12),
              Text(message, style: AppTheme.bodyStyle),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...actions,
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(sheet),
                child: const Text('Got it'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
