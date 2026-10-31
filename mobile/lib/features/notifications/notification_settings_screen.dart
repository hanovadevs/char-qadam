import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/stepsy_ui.dart';
import 'notification_preferences.dart';
import 'reminder_bridge.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  bool? _permission;
  bool _testing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final allowed = await Permission.notification.isGranted;
    if (mounted) setState(() => _permission = allowed);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _save(String key, Object value) async {
    try {
      await ref.read(notificationPreferencesProvider.notifier).update({
        key: value,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save your notification preference. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _preview() async {
    setState(() => _testing = true);
    try {
      final sent = await ReminderBridge.preview();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sent
                  ? 'Test reminder sent. Open your notification shade and tap it.'
                  : 'Allow Stepsy notifications in Android settings, then try again.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test reminders are available on the Android app.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(notificationPreferencesProvider);
    Widget toggle(String key, String label, String detail, bool value) =>
        SwitchListTile(
          title: Text(label),
          subtitle: Text(detail),
          value: value,
          onChanged: p.loaded && (p.enabled || key == 'enabled')
              ? (v) => _save(key, v)
              : null,
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications & reminders')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const Text(
            'A little encouragement.\nYour choice.',
            style: AppTheme.largeTitleStyle,
          ),
          const SizedBox(height: 16),
          if (_permission != true)
            SurfaceCard(
              color: AppTheme.peachWash,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Allow notifications to receive reminders.',
                    style: AppTheme.bodyStyle,
                  ),
                  TextButton(
                    onPressed: () async {
                      await NotificationService.requestPermissions();
                      await _refreshPermission();
                    },
                    child: const Text('Allow notifications'),
                  ),
                  TextButton(
                    onPressed: openAppSettings,
                    child: const Text('Open Android settings'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                toggle(
                  'enabled',
                  'Stepsy notifications',
                  'Optional reminders and reward updates.',
                  p.enabled,
                ),
                const Divider(),
                toggle(
                  'walking',
                  'Walking encouragement',
                  'One gentle check-in when you are below your personal goal.',
                  p.walking,
                ),
                ListTile(
                  title: const Text('Walking reminder time'),
                  subtitle: const Text('Your phone’s local time'),
                  trailing: Text(
                    TimeOfDay(hour: p.hour, minute: p.minute).format(context),
                    style: AppTheme.headlineStyle,
                  ),
                  enabled: p.loaded && p.enabled && p.walking,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: p.hour, minute: p.minute),
                    );
                    if (picked == null || !context.mounted) return;
                    if (picked.hour < 9 || picked.hour >= 21) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Choose a time between 9 am and 9 pm. Reminders stay quiet overnight.',
                          ),
                        ),
                      );
                      return;
                    }
                    try {
                      await ref
                          .read(notificationPreferencesProvider.notifier)
                          .update({
                            'hour': picked.hour,
                            'minute': picked.minute,
                          });
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not save the reminder time.'),
                          ),
                        );
                      }
                    }
                  },
                ),
                const Divider(),
                toggle(
                  'tracking',
                  'Tracking help',
                  'Help after an interruption; one gentle reminder 24 hours after you pause.',
                  p.tracking,
                ),
                const Divider(),
                toggle(
                  'returning',
                  'Welcome-back reminders',
                  'A hello after 3 and 7 days away, then we leave it with you.',
                  p.returning,
                ),
                const Divider(),
                toggle(
                  'rewards',
                  'Reward updates',
                  'When a reward is ready while you are away from the app.',
                  p.rewards,
                ),
                const Divider(),
                toggle(
                  'points',
                  'Points updates',
                  'Optional confirmations when walking points are added while you are away.',
                  p.points,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'At most one automatic reminder per day, with quiet hours from 9 pm to 9 am. These preferences are saved for your account on this phone.',
            style: AppTheme.captionStyle,
          ),
          const SizedBox(height: 10),
          const Text(
            'Android may delay background reminders. A force-stopped app or blocked notifications cannot send a reminder until Android allows it again. Use tracking help if you need to check your settings.',
            style: AppTheme.captionStyle,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: p.loaded && p.enabled && !_testing ? _preview : null,
            icon: const Icon(Icons.notifications_outlined),
            label: Text(_testing ? 'Sending…' : 'Send a test reminder'),
          ),
        ],
      ),
    );
  }
}
