import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared native surfaces. Motion follows the OS accessibility preference.
Duration motionDuration(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppTheme.motion;

class SectionHeading extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeading(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        Text(title, style: AppTheme.titleStyle),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  const SurfaceCard({
    super.key,
    required this.child,
    this.color = AppTheme.surface,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      border: Border.all(color: AppTheme.hairline),
    ),
    child: child,
  );
}

class StatusNotice extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const StatusNotice(this.message, {super.key, this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: SurfaceCard(
      color: AppTheme.mintWash,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppTheme.bodyStyle),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = CupertinoIcons.ticket,
    this.action,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AppTheme.mintWash,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: AppTheme.accentDeep),
          ),
          const SizedBox(height: 18),
          Text(title, style: AppTheme.titleStyle, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTheme.captionStyle.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    ),
  );
}

class TicketDivider extends StatelessWidget {
  const TicketDivider({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 16,
    width: double.infinity,
    child: CustomPaint(painter: _Perforation()),
  );
}

class _Perforation extends CustomPainter {
  const _Perforation();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.hairline
      ..strokeWidth = 1;
    for (double x = 12; x < size.width - 12; x += 9) {
      canvas.drawLine(Offset(x, 8), Offset(x + 4, 8), paint);
    }
    paint.color = AppTheme.surfaceMuted;
    canvas.drawCircle(Offset(0, 8), 8, paint);
    canvas.drawCircle(Offset(size.width, 8), 8, paint);
  }

  @override
  bool shouldRepaint(covariant _Perforation oldDelegate) => false;
}

class FilterPills extends StatelessWidget {
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  const FilterPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: options.entries
        .map(
          (entry) => ChoiceChip(
            label: Text(entry.value),
            selected: selected == entry.key,
            onSelected: (_) => onSelected(entry.key),
            showCheckmark: false,
            selectedColor: AppTheme.accentDeep,
            backgroundColor: AppTheme.surface,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected == entry.key
                  ? AppTheme.surface
                  : AppTheme.inkSecondary,
            ),
            side: BorderSide(
              color: selected == entry.key
                  ? AppTheme.accentDeep
                  : AppTheme.hairline,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: const StadiumBorder(),
          ),
        )
        .toList(),
  );
}
