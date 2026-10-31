import '../../core/services/health_consent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/stepsy_ui.dart';
import '../../data/activity/health_service.dart';
import '../activity/providers/tracking_controller.dart';
import '../activity/presentation/tracking_controls.dart';

class TrackingHelpScreen extends ConsumerWidget {
  const TrackingHelpScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Tracking help')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const Text('Let’s get you counting.', style: AppTheme.largeTitleStyle),
        const SizedBox(height: 12),
        const Text(
          'Your saved steps, points and rewards stay with your account. Opening this guide never resumes an intentional pause.',
          style: AppTheme.bodyStyle,
        ),
        const SizedBox(height: 12),
        const SurfaceCard(color: AppTheme.sageWash, child: TrackingControls()),
        const SectionHeading('Check these settings'),
        _HelpStep(
          '1',
          'Allow physical activity',
          'This gives Stepsy access to the phone’s step counter.',
          action: 'Check activity access',
          onTap: () async {
            if (!await HealthConsent.request(context)) return;
            await ref.read(healthServiceProvider).requestPermissions();
            await ref.read(trackingControllerProvider.notifier).refresh();
          },
        ),
        _HelpStep(
          '2',
          'Allow notifications',
          'Keep the tracking notification visible so its Stop action and reminders are available.',
          action: 'Allow notifications',
          onTap: () => NotificationService.requestPermissions(),
        ),
        _HelpStep(
          '3',
          'Allow background activity',
          'Android battery restrictions can interrupt tracking after the screen is locked.',
          action: 'Background settings',
          onTap: () =>
              ref.read(trackingControllerProvider.notifier).batterySettings(),
        ),
        _HelpStep(
          '4',
          'On Redmi: Autostart and No restrictions',
          'In Settings → Apps → Manage apps → Stepsy, enable Autostart and set Battery saver to No restrictions. Menu names may vary by MIUI version.',
          action: 'Open Stepsy app settings',
          onTap: openAppSettings,
        ),
        const SizedBox(height: 12),
        const Text(
          'After changing settings, return here and use Resume tracking if needed. Walk a few steps to check the live count. Paused walking is not added back on resume.',
          style: AppTheme.captionStyle,
        ),
      ],
    ),
  );
}

class _HelpStep extends StatelessWidget {
  final String number, title, detail, action;
  final Future<dynamic> Function() onTap;
  const _HelpStep(
    this.number,
    this.title,
    this.detail, {
    required this.action,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number. $title', style: AppTheme.headlineStyle),
          const SizedBox(height: 8),
          Text(detail, style: AppTheme.bodyStyle),
          TextButton(
            onPressed: () async {
              try {
                await onTap();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Open Stepsy’s app settings to check this permission.',
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(action),
          ),
        ],
      ),
    ),
  );
}
