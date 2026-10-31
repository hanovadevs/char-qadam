import 'package:flutter/material.dart';
import '../../../core/services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}
class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  NotificationPreferences? _settings;
  bool _saving = false;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final settings = await NotificationService.preferences();
    if (mounted) setState(() { _settings = settings; });
  }
  Future<void> _update({bool? enabled, bool? reminders, bool? milestones, bool? expiry, bool? playful, bool? progress, int? goal}) async {
    if (_saving) return;
    setState(() { _saving = true; });
    try {
      if (enabled == true && !await NotificationService.requestPermissions()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications are blocked in your device settings.')));
        return;
      }
      final old = _settings!;
      final next = NotificationPreferences(enabled: enabled ?? old.enabled, reminders: reminders ?? old.reminders,
        milestones: milestones ?? old.milestones, voucherExpiry: expiry ?? old.voucherExpiry,
        playful: playful ?? old.playful, showProgress: progress ?? old.showProgress, dailyGoal: goal ?? old.dailyGoal);
      await NotificationService.savePreferences(next);
      if (mounted) setState(() { _settings = next; });
    } finally { if (mounted) setState(() { _saving = false; }); }
  }
  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(appBar: AppBar(title: const Text('Notifications & goals')),
      body: settings == null ? const Center(child: CircularProgressIndicator()) : ListView(children: [
        SwitchListTile(title: const Text('Allow Stepsy notifications'), subtitle: const Text('Optional updates. At most two per day, three hours apart.'), value: settings.enabled, onChanged: _saving ? null : (value) => _update(enabled: value)),
        SwitchListTile(title: const Text('Milestones & points'), value: settings.milestones, onChanged: _saving || !settings.enabled ? null : (value) => _update(milestones: value)),
        SwitchListTile(title: const Text('Voucher expiry reminders'), value: settings.voucherExpiry, onChanged: _saving || !settings.enabled ? null : (value) => _update(expiry: value)),
        SwitchListTile(title: const Text('Evening check-in'), subtitle: const Text('Around 6–9 PM when background sync runs. Timing depends on your phone.'), value: settings.reminders, onChanged: _saving || !settings.enabled ? null : (value) => _update(reminders: value)),
        SwitchListTile(title: const Text('Playful tone'), subtitle: const Text('A little personality in your updates.'), value: settings.playful, onChanged: _saving ? null : (value) => _update(playful: value)),
        SwitchListTile(title: const Text('Include progress numbers'), subtitle: const Text('Show step and point totals in notifications. Off by default for privacy.'), value: settings.showProgress, onChanged: _saving ? null : (value) => _update(progress: value)),
        ListTile(title: Text('Your walking goal: ${settings.dailyGoal} steps'), subtitle: const Text('A personal goal, separate from the daily rewards cap.')),
        Slider(value: settings.dailyGoal.toDouble(), min: 1000, max: 20000, divisions: 19, label: '${settings.dailyGoal}', onChanged: _saving ? null : (value) => setState(() { _settings = NotificationPreferences(enabled: settings.enabled, reminders: settings.reminders, milestones: settings.milestones, voucherExpiry: settings.voucherExpiry, playful: settings.playful, showProgress: settings.showProgress, dailyGoal: value.round()); }), onChangeEnd: (value) => _update(goal: value.round())),
        const Padding(padding: EdgeInsets.all(20), child: Text('Quiet hours: 10 PM–9 AM in your local time. No permanent tracking notification. Background syncing is best effort; reminders may be delayed.')),
      ]));
  }
}
