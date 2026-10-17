import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/activity/health_service.dart';
import '../../../data/auth/auth_state_provider.dart';
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
              'Deactivate account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.destructive,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your account will be deactivated and you will be signed out. This phone can then use a different account. Activity and reward records stay with this account; steps already rewarded on this phone cannot earn points again.',
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
                    child: const Text('Deactivate account'),
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
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final isMerchant = user?.role == 'MERCHANT';

    return Scaffold(
      backgroundColor: AppTheme.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceMuted,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppTheme.inkPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const Text(
            'Your corner\nof Stepsy.',
            style: AppTheme.largeTitleStyle,
          ),
          const SizedBox(height: 12),
          const Text('Make yourself at home.', style: AppTheme.captionStyle),
          const SizedBox(height: 24),
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: LinearProgressIndicator(
                color: AppTheme.accentSolid,
                backgroundColor: AppTheme.hairline,
                minHeight: 2,
              ),
            ),

          // User Card Block (Apple Squircle Profile Card)
          Container(
            decoration: BoxDecoration(
              color: AppTheme.mintWash,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.hairline),
            ),
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildAvatar(
                      authState.googlePhotoUrl,
                      authState.googleName,
                      user?.email,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (authState.googleName != null &&
                              authState.googleName!.isNotEmpty)
                            Text(
                              authState.googleName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                                color: AppTheme.inkPrimary,
                              ),
                            ),
                          Text(
                            user?.email ?? 'User',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize:
                                  (authState.googleName != null &&
                                      authState.googleName!.isNotEmpty)
                                  ? 13
                                  : 17,
                              fontWeight:
                                  (authState.googleName != null &&
                                      authState.googleName!.isNotEmpty)
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                              color:
                                  (authState.googleName != null &&
                                      authState.googleName!.isNotEmpty)
                                  ? AppTheme.inkSecondary
                                  : AppTheme.inkPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.hairline, height: 1),
                const SizedBox(height: 14),
                _buildDetailRow('Country', user?.country ?? 'PK'),
                const SizedBox(height: 8),
                _buildDetailRow('Timezone', user?.timezone ?? 'Asia/Karachi'),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Member since',
                  user != null
                      ? DateFormat('MMMM yyyy').format(user.createdAt.toLocal())
                      : '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Grouped Inset List: Preferences & Sensors
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.hairline),
            ),
            child: Column(
              children: [
                _buildSettingRow(
                  icon: CupertinoIcons.slider_horizontal_3,
                  title: 'Edit preferences',
                  onTap: () => _showEditProfileBottomSheet(context),
                ),
                const Divider(height: 1, color: AppTheme.hairline),
                _buildSettingRow(
                  icon: CupertinoIcons.waveform_path,
                  title: 'Motion & fitness access',
                  onTap: () async {
                    HapticsService.light();
                    final healthService = ref.read(healthServiceProvider);
                    await healthService.requestPermissions();
                    if (context.mounted) {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppTheme.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppTheme.radiusLg),
                          ),
                        ),
                        builder: (ctx) => Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Motion & fitness access',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: AppTheme.inkPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Stepsy runs in the background to count your steps throughout the day without using GPS tracking.\n\nMake sure "Physical Activity", "Sensors", and "Notifications" permissions are enabled.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.inkSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    openAppSettings();
                                    Navigator.pop(ctx);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMd,
                                      ),
                                    ),
                                  ),
                                  child: const Text('Open device settings'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                ),
                if (isMerchant) ...[
                  const Divider(height: 1, color: AppTheme.hairline),
                  _buildSettingRow(
                    icon: CupertinoIcons.creditcard,
                    title: 'Merchant POS terminal',
                    onTap: () => context.push('/merchant-pos'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Grouped Inset List: Account Actions
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.hairline),
            ),
            child: Column(
              children: [
                _buildSettingRow(
                  icon: CupertinoIcons.square_arrow_right,
                  title: 'Sign out',
                  onTap: () => ref.read(authStateProvider.notifier).logout(),
                ),
                const Divider(height: 1, color: AppTheme.hairline),
                _buildSettingRow(
                  icon: CupertinoIcons.trash,
                  title: 'Deactivate account',
                  titleColor: AppTheme.destructive,
                  iconColor: AppTheme.destructive,
                  onTap: () => _confirmDeleteAccount(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/icon/Stepsy_Icon1.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Stepsy v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.inkTertiary,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Powered by Hanova Devs',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.inkTertiary,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    return InkWell(
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
        color: AppTheme.surfaceMuted,
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
