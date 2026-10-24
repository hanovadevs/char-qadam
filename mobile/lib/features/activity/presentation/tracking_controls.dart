import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/background_sync_service.dart';
import '../../../data/activity/health_service.dart';
import '../providers/activity_provider.dart';
import '../providers/tracking_controller.dart';

class TrackingControls extends ConsumerStatefulWidget {
  const TrackingControls({super.key});
  @override
  ConsumerState<TrackingControls> createState() => _TrackingControlsState();
}

class _TrackingControlsState extends ConsumerState<TrackingControls>
    with WidgetsBindingObserver {
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(trackingControllerProvider.notifier).refresh();
    }
  }

  Future<void> _change(bool resume) async {
    setState(() => _busy = true);
    try {
      final control = ref.read(trackingControllerProvider.notifier);
      if (resume) {
        await ref.read(healthServiceProvider).requestPermissions();
        if (!await control.resume()) {
          throw StateError('Allow motion access to resume tracking.');
        }
        await BackgroundSyncService.initialize();
        await ref.read(activityProvider.notifier).initAndSync(force: true);
      } else {
        await control.pause();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not change tracking. Check motion permission and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(trackingControllerProvider);
    if (status == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                status.paused
                    ? 'Tracking paused'
                    : status.running
                    ? 'Background tracking on'
                    : 'Tracking is not running',
                style: AppTheme.captionStyle,
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _change(status.paused || !status.running),
                child: Text(
                  status.paused || !status.running
                      ? 'Resume tracking'
                      : 'Stop tracking',
                ),
              ),
            ],
          ),
          if (status.paused)
            const Text(
              'Your saved progress stays here. Resume when you want to count again.',
              style: AppTheme.captionStyle,
            ),
          if (!status.paused && !status.unrestricted) ...[
            const Text(
              'Allow background activity so tracking can continue after idle. This can use more battery; Stop tracking is always available in the notification.',
              style: AppTheme.captionStyle,
            ),
            TextButton(
              onPressed: () async {
                try {
                  await ref
                      .read(trackingControllerProvider.notifier)
                      .batterySettings();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Open Android Settings → Apps → Stepsy → Battery and allow background activity.',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('Allow background activity'),
            ),
            const Text(
              'On Redmi, also allow Autostart and choose No restrictions in Stepsy’s battery settings.',
              style: AppTheme.captionStyle,
            ),
          ],
        ],
      ),
    );
  }
}
