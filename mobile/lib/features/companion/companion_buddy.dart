import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'companion.dart';
import 'experience_provider.dart';

/// An intentional little interaction, with no background animation timer.
class CompanionBuddy extends StatefulWidget {
  final double size;
  final String clip, label;
  final int event;
  const CompanionBuddy({
    super.key,
    this.size = 64,
    this.clip = 'rest',
    this.event = 0,
    this.label = 'Play with Pip',
  });
  @override
  State<CompanionBuddy> createState() => _CompanionBuddyState();
}

class _CompanionBuddyState extends State<CompanionBuddy> {
  int _taps = 0;
  String? _reaction;
  @override
  void didUpdateWidget(covariant CompanionBuddy old) {
    super.didUpdateWidget(old);
    if (old.clip != widget.clip || old.event != widget.event) _reaction = null;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    child: Tooltip(
      message: widget.label,
      child: InkResponse(
        onTap: () => setState(() {
          _reaction = const ['love', 'peek', 'wiggle', 'wave'][_taps % 4];
          _taps++;
        }),
        radius: widget.size / 2,
        child: SizedBox(
          width: widget.size < 48 ? 48 : widget.size,
          height: widget.size < 48 ? 48 : widget.size,
          child: Center(
            child: Companion(
              size: widget.size,
              clip: _reaction ?? widget.clip,
              event: Object.hash(widget.event, _taps),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Guidance occupies its own layout space, never floating over a real control.
class CompanionGuide extends ConsumerWidget {
  final String message, clip;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int event;
  const CompanionGuide({
    super.key,
    required this.message,
    this.clip = 'point',
    this.actionLabel,
    this.onAction,
    this.event = 0,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(experienceProvider.select((s) => s.tips))) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CompanionBuddy(clip: clip, event: event, size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: AppTheme.bodyStyle),
                if (actionLabel != null && onAction != null)
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
