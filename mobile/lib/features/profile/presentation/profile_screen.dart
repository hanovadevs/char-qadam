import '../../../core/services/health_consent.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../guided_tour/tour_provider.dart';
import '../../guided_tour/tour_targets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cozy_scene.dart';
import '../../../core/widgets/stepsy_ui.dart';
import '../../companion/experience_provider.dart';
import '../../activity/providers/activity_provider.dart';
import '../../companion/experience_sheet.dart';
import '../../../data/activity/health_service.dart';
import '../../../data/auth/auth_state_provider.dart';
import '../../auth/presentation/sign_out_confirmation.dart';
import '../../../data/profile/profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUpdating = false;

  void _showEditProfileBottomSheet(BuildContext context) {
    final user = ref.read(authStateProvider).user;
    final countryController = TextEditingController(
      text: user?.country ?? 'PK',
    );
    final timezoneController = TextEditingController(
      text: user?.timezone ?? 'Asia/Karachi',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.hairline,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Edit preferences',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Country code (ISO-2)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.inkSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(hintText: 'e.g. PK, US, GB'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Timezone',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.inkSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: timezoneController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Asia/Karachi, UTC',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _isUpdating = true);
                        try {
                          final repo = ref.read(profileRepositoryProvider);
                          await repo.updateProfile(
                            country: countryController.text
                                .trim()
                                .toUpperCase(),
                            timezone: timezoneController.text.trim(),
                          );
                          await ref
                              .read(authStateProvider.notifier)
                              .refreshProfile();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Preferences updated successfully'),
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: AppTheme.destructive,
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _isUpdating = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                      ),
                      child: const Text('Save changes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.hairline,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Delete account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.destructive,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This permanently deletes your profile, synced step history and support conversations. Active vouchers are cancelled and you will be signed out. De-identified reward transactions and device records remain for accounting and duplicate-reward prevention. This cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.inkSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    child: const Text('Keep account'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.destructive,
                      foregroundColor: AppTheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _isUpdating = true);
                      try {
                        final repo = ref.read(profileRepositoryProvider);
                        await repo.deleteAccount();
                        await ref.read(authStateProvider.notifier).logout();
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: AppTheme.destructive,
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _isUpdating = false);
                      }
                    },
                    child: const Text('Delete account'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final user = auth.user;
    final goal = ref.watch(experienceProvider).goal;
    final connected = ref.watch(activityProvider).hasPermission;
    return Scaffold(
      appBar: const CozyAppBar(showPoints: false),
      body: ListView(
        key: tourKey(ref, 'page.4'),
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          tourBottomPadding(ref, context),
        ),
        children: [
          const CozyPageHeading(
            title: 'You',
            subtitle: 'Your pace.\nYour space.',
            pose: 'wave',
          ),
          const SizedBox(height: 10),
          SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildAvatar(auth.googlePhotoUrl, auth.googleName, user?.email),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.googleName?.isNotEmpty == true
                            ? auth.googleName!
                            : 'Stepsy member',
                        style: AppTheme.headlineStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Walking member',
                        style: AppTheme.captionStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isUpdating) const LinearProgressIndicator(),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildSettingRow(
                  icon: CupertinoIcons.flag,
                  key: tourKey(ref, 'you.goal'),
                  title: 'Daily goal & companion',
                  trailing: NumberFormat.decimalPattern().format(goal),
                  onTap: () => showExperienceSettings(context),
                ),
                const Divider(),
                _buildSettingRow(
                  icon: CupertinoIcons.chart_bar,
                  title: 'Progress & activity',
                  onTap: () => context.push('/progress'),
                ),
                const Divider(),
                _buildSettingRow(
                  icon: CupertinoIcons.link,
                  title: 'Activity connection',
                  trailing: connected ? 'Connected' : 'Connect',
                  onTap: () async {
                    HapticsService.light();
                    if (!await HealthConsent.request(context)) return;
                    await ref.read(healthServiceProvider).requestPermissions();
                    if (context.mounted) {
                      showModalBottomSheet<void>(
                        context: context,
                        useSafeArea: true,
                        isScrollControlled: true,
                        builder: (ctx) => SafeArea(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Motion & fitness access',
                                  style: AppTheme.titleStyle,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Allow physical activity, notifications and background activity so Stepsy can count your walks. You can stop tracking from its notification and resume in Steps.',
                                  style: AppTheme.bodyStyle,
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: () {
                                    openAppSettings();
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Open device settings'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
                const Divider(),
                _buildSettingRow(
                  icon: CupertinoIcons.slider_horizontal_3,
                  title: 'Preferences',
                  onTap: () => _showEditProfileBottomSheet(context),
                ),
                const Divider(),
                _buildSettingRow(
                  icon: CupertinoIcons.bell,
                  key: tourKey(ref, 'you.notifications'),
                  title: 'Notifications & reminders',
                  onTap: () => context.push('/notifications'),
                ),
                const Divider(),
                _buildSettingRow(
                  icon: CupertinoIcons.lock_shield,
                  title: 'Privacy & your data',
                  onTap: () => context.push('/privacy'),
                ),
                const Divider(),
                _buildSettingRow(
                  icon: CupertinoIcons.shield,
                  key: tourKey(ref, 'you.privacy'),
                  title: 'Help, FAQs & support',
                  onTap: () => context.push('/support'),
                ),
                const Divider(),
                _buildSettingRow(
                  key: tourKey(ref, 'you.tour'),
                  icon: CupertinoIcons.sparkles,
                  title: 'Replay guided tour',
                  onTap: () {
                    context.go('/steps');
                    ref.read(guidedTourProvider.notifier).start();
                  },
                ),
                const Divider(),
                _buildSettingRow(
                  icon: CupertinoIcons.doc_text,
                  title: 'Account details',
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    useSafeArea: true,
                    isScrollControlled: true,
                    builder: (context) => SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Account details',
                              style: AppTheme.titleStyle,
                            ),
                            const SizedBox(height: 16),
                            SelectableText(
                              user?.email ?? 'Email unavailable',
                              style: AppTheme.bodyStyle,
                            ),
                            const SizedBox(height: 16),
                            _buildDetailRow('Country', user?.country ?? 'PK'),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              'Timezone',
                              user?.timezone ?? 'Asia/Karachi',
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              'Member since',
                              user == null
                                  ? '—'
                                  : DateFormat(
                                      'MMMM yyyy',
                                    ).format(user.createdAt.toLocal()),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildSettingRow(
                  icon: CupertinoIcons.square_arrow_right,
                  title: 'Sign out',
                  onTap: () => confirmSignOut(context, ref),
                ),
                const Divider(),
                _buildSettingRow(
                  icon: CupertinoIcons.trash,
                  title: 'Delete account',
                  titleColor: AppTheme.destructive,
                  iconColor: AppTheme.destructive,
                  onTap: () => _confirmDeleteAccount(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Image.asset(
              'assets/icon/Stepsy_Icon_sage.png',
              width: 28,
              height: 28,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Stepsy · By Hanova Devs',
            style: AppTheme.captionStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    Key? key,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? trailing,
    Color? titleColor,
    Color? iconColor,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppTheme.inkSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                  color: titleColor ?? AppTheme.inkPrimary,
                ),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Text(trailing, style: AppTheme.captionStyle),
              ),
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 14,
              color: AppTheme.inkTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String? name, String? email) {
    const double size = 48;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final seed = (name != null && name.isNotEmpty)
        ? name
        : (email != null && email.isNotEmpty ? email : '?');
    final initial = seed.substring(0, 1).toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.sageWash,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.hairline, width: 1),
        image: hasPhoto
            ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : Text(
              initial,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.inkPrimary,
              ),
            ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 6,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.inkSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.inkPrimary,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}
