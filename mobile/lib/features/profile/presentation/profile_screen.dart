import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/auth/auth_state_provider.dart';
import '../../../data/profile/profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUpdating = false;

  void _showEditProfileDialog(BuildContext context) {
    final user = ref.read(authStateProvider).user;
    final countryController = TextEditingController(text: user?.country ?? 'PK');
    final timezoneController = TextEditingController(text: user?.timezone ?? 'Asia/Karachi');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: countryController,
              decoration: const InputDecoration(
                labelText: 'Country Code (ISO-2)',
                hintText: 'e.g. PK, US',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: timezoneController,
              decoration: const InputDecoration(
                labelText: 'Timezone',
                hintText: 'e.g. Asia/Karachi',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
                  const SnackBar(content: Text('Profile updated successfully!')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
                );
              } finally {
                if (mounted) setState(() => _isUpdating = false);
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 48),
        title: const Text('Delete Account?'),
        content: const Text(
          'This action soft-deletes your account and immediately revokes all access. Your points and vouchers will be anonymized per privacy policies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
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
                  SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
                );
              } finally {
                if (mounted) setState(() => _isUpdating = false);
              }
            },
            child: const Text('Yes, Delete Account'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.person, color: Color(0xFF64748B)),
            SizedBox(width: 8),
            Text('Profile & Settings'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (_isUpdating) const LinearProgressIndicator(color: Color(0xFF10B981)),
          if (_isUpdating) const SizedBox(height: 12),
          // Profile User Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: Color(0xFF10B981),
                    child: Icon(Icons.person, size: 40, color: Colors.black),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.email ?? 'User Account',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      user?.status ?? 'ACTIVE',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF334155)),
                  const SizedBox(height: 12),
                  _buildDetailRow('Country', user?.country ?? 'Not set'),
                  const SizedBox(height: 8),
                  _buildDetailRow('Timezone', user?.timezone ?? 'Not set'),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Member Since',
                    user != null
                        ? DateFormat('MMM d, yyyy').format(user.createdAt.toLocal())
                        : '—',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Actions List
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Color(0xFF10B981)),
                  title: const Text('Edit Country & Timezone'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showEditProfileDialog(context),
                ),
                const Divider(height: 1, color: Color(0xFF334155)),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.amber),
                  title: const Text('Sign Out'),
                  onTap: () => ref.read(authStateProvider.notifier).logout(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Dangerous Zone
          Card(
            color: Colors.redAccent.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text(
                'Delete Account',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Soft-delete account & revoke access immediately',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
          style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
