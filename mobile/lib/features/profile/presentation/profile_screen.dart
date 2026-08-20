import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
      backgroundColor: AppTheme.darkCardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.darkBorderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Edit Preferences',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Customize your region and timezone for accurate step daily caps',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(
                  labelText: 'Country Code (ISO-2)',
                  hintText: 'e.g. PK, US, UK',
                  prefixIcon: Icon(Icons.public_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: timezoneController,
                decoration: const InputDecoration(
                  labelText: 'Timezone',
                  hintText: 'e.g. Asia/Karachi, UTC',
                  prefixIcon: Icon(Icons.schedule_rounded),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
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
                            country: countryController.text.trim().toUpperCase(),
                            timezone: timezoneController.text.trim(),
                          );
                          await ref.read(authStateProvider.notifier).refreshProfile();
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Preferences updated successfully!')),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: AppTheme.accentRose,
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _isUpdating = false);
                        }
                      },
                      child: const Text('Save Changes'),
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
      backgroundColor: AppTheme.darkCardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.accentRose.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: AppTheme.accentRose,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Delete Account?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action soft-deletes your account and revokes access. Your points and vouchers will be anonymized per privacy rules.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Keep Account'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentRose,
                      foregroundColor: Colors.white,
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
                            backgroundColor: AppTheme.accentRose,
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _isUpdating = false);
                      }
                    },
                    child: const Text('Yes, Delete'),
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
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Color(0xFF38BDF8),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile & Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text(
                  'Account management',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: LinearProgressIndicator(
                color: AppTheme.primaryColor,
                backgroundColor: AppTheme.darkCardElevated,
              ),
            ),

          // User Card Header
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.6),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    const CircleAvatar(
                      radius: 38,
                      backgroundColor: Color(0xFF1E293D),
                      child: Icon(Icons.person_rounded, size: 44, color: AppTheme.primaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  user?.email ?? 'Athlete',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user?.status ?? 'ACTIVE',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(color: AppTheme.darkBorder),
                const SizedBox(height: 14),
                _buildDetailRow('Country Code', user?.country ?? 'PK'),
                const SizedBox(height: 10),
                _buildDetailRow('Timezone', user?.timezone ?? 'Asia/Karachi'),
                const SizedBox(height: 10),
                _buildDetailRow(
                  'Member Since',
                  user != null
                      ? DateFormat('MMMM yyyy').format(user.createdAt.toLocal())
                      : '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Actions List
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.tune_rounded, color: AppTheme.primaryColor, size: 20),
                  ),
                  title: const Text('Edit Preferences', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Country code & daily reset timezone', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                  onTap: () => _showEditProfileBottomSheet(context),
                ),
                const Divider(height: 1, color: AppTheme.darkBorder),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.logout_rounded, color: AppTheme.accentGold, size: 20),
                  ),
                  title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Keep token persistent until explicit logout', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                  onTap: () => ref.read(authStateProvider.notifier).logout(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Dangerous Zone
          Container(
            decoration: BoxDecoration(
              color: AppTheme.accentRose.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.3)),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentRose.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentRose, size: 20),
              ),
              title: const Text(
                'Delete Account',
                style: TextStyle(color: AppTheme.accentRose, fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Soft-delete account & revoke access immediately',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
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
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
