import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
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
    final countryController = TextEditingController(text: user?.country ?? 'PK');
    final timezoneController = TextEditingController(text: user?.timezone ?? 'Asia/Karachi');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMd)),
        side: BorderSide(color: AppTheme.borderDark, width: 1),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppTheme.borderDark,
                    borderRadius: BorderRadius.circular(AppTheme.radiusNone),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'EDIT PREFERENCES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppTheme.grey,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Timezone & region for daily step conversion',
                style: TextStyle(fontSize: 13, color: AppTheme.grey),
              ),
              const SizedBox(height: 18),
              const Text(
                'COUNTRY CODE (ISO-2)',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppTheme.grey),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(
                  hintText: 'e.g. PK, US, GB',
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'TIMEZONE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppTheme.grey),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: timezoneController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Asia/Karachi, UTC',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                            country: countryController.text.trim().toUpperCase(),
                            timezone: timezoneController.text.trim(),
                          );
                          await ref.read(authStateProvider.notifier).refreshProfile();
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Preferences updated successfully')),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: AppTheme.accentRed,
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _isUpdating = false);
                        }
                      },
                      child: const Text('SAVE CHANGES'),
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
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMd)),
        side: BorderSide(color: AppTheme.borderDark, width: 1),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: AppTheme.borderDark,
                  borderRadius: BorderRadius.circular(AppTheme.radiusNone),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'DELETE ACCOUNT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppTheme.accentRed,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Soft-delete account & revoke access?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your activity logs, points, and vouchers will be immediately revoked and anonymized per privacy compliance.',
              style: TextStyle(fontSize: 12, color: AppTheme.grey, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('KEEP ACCOUNT'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentRed,
                      foregroundColor: AppTheme.white,
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
                            backgroundColor: AppTheme.accentRed,
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _isUpdating = false);
                      }
                    },
                    child: const Text('CONFIRM DELETE'),
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

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROFILE & SETTINGS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppTheme.black,
              ),
            ),
            Text(
              'ACCOUNT DETAILS & REGION',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.grey,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        children: [
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.only(bottom: 10.0),
              child: LinearProgressIndicator(
                color: AppTheme.black,
                backgroundColor: AppTheme.border,
                minHeight: 2,
              ),
            ),

          // User Card Block (Swiss Beige Surface #F5F1E8)
          Container(
            decoration: BoxDecoration(
              color: AppTheme.beige,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.borderDark, width: 1),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      user?.email ?? 'USER',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: AppTheme.black,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        border: Border.all(color: AppTheme.borderDark),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        user?.status ?? 'ACTIVE',
                        style: const TextStyle(
                          fontSize: 9,
                          fontFamily: AppTheme.monoFont,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.black,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: AppTheme.borderDark, height: 1),
                const SizedBox(height: 12),
                _buildDetailRow('COUNTRY CODE', user?.country ?? 'PK'),
                const SizedBox(height: 8),
                _buildDetailRow('TIMEZONE', user?.timezone ?? 'Asia/Karachi'),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'JOINED',
                  user != null
                      ? DateFormat('yyyy-MM-dd').format(user.createdAt.toLocal())
                      : '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Actions List
          Container(
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  title: const Text(
                    'EDIT PREFERENCES',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5, color: AppTheme.black),
                  ),
                  subtitle: const Text(
                    'Country code & step reset timezone',
                    style: TextStyle(fontSize: 11, color: AppTheme.grey),
                  ),
                  trailing: const Icon(Icons.arrow_forward, size: 14, color: AppTheme.grey),
                  onTap: () => _showEditProfileBottomSheet(context),
                ),
                const Divider(height: 1, color: AppTheme.border),
                ListTile(
                  dense: true,
                  title: const Text(
                    'MERCHANT POS TERMINAL',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5, color: AppTheme.black),
                  ),
                  subtitle: const Text(
                    'Store cashier scanner & voucher redemption',
                    style: TextStyle(fontSize: 11, color: AppTheme.grey),
                  ),
                  trailing: const Icon(Icons.point_of_sale, size: 16, color: AppTheme.black),
                  onTap: () => context.push('/merchant-pos'),
                ),
                const Divider(height: 1, color: AppTheme.border),
                ListTile(
                  dense: true,
                  title: const Text(
                    '24/7 STEP SENSORS & PERMISSIONS',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5, color: AppTheme.black),
                  ),
                  subtitle: const Text(
                    'Body sensors, physical activity & battery optimization',
                    style: TextStyle(fontSize: 11, color: AppTheme.grey),
                  ),
                  trailing: const Icon(Icons.tune, size: 16, color: AppTheme.black),
                  onTap: () async {
                    HapticsService.light();
                    final healthService = ref.read(healthServiceProvider);
                    await healthService.requestPermissions();
                    if (context.mounted) {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppTheme.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMd)),
                          side: BorderSide(color: AppTheme.borderDark, width: 1),
                        ),
                        builder: (ctx) => Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '24/7 SENSOR PERMISSIONS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Walk n Save runs in the background to count your steps all day without using GPS.\n\nMake sure "Physical Activity", "Body Sensors", and "Notifications" are Allowed in App Permissions.',
                                style: TextStyle(fontSize: 11, color: AppTheme.grey, height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    openAppSettings();
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('OPEN SYSTEM APP SETTINGS'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1, color: AppTheme.border),
                ListTile(
                  dense: true,
                  title: const Text(
                    'SIGN OUT',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5, color: AppTheme.black),
                  ),
                  subtitle: const Text(
                    'Revoke session on this device',
                    style: TextStyle(fontSize: 11, color: AppTheme.grey),
                  ),
                  trailing: const Icon(Icons.logout, size: 14, color: AppTheme.grey),
                  onTap: () => ref.read(authStateProvider.notifier).logout(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Dangerous Zone
          Container(
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.4)),
            ),
            child: ListTile(
              dense: true,
              title: const Text(
                'DELETE ACCOUNT',
                style: TextStyle(
                  color: AppTheme.accentRed,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              subtitle: const Text(
                'Permanently remove user data & ledger access',
                style: TextStyle(fontSize: 11, color: AppTheme.grey),
              ),
              trailing: const Icon(Icons.delete_outline, size: 16, color: AppTheme.accentRed),
              onTap: () => _confirmDeleteAccount(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppTheme.grey,
            letterSpacing: 0.8,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: AppTheme.monoFont,
            fontWeight: FontWeight.w700,
            color: AppTheme.black,
          ),
        ),
      ],
    );
  }
}
