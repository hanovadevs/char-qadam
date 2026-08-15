import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/activity_provider.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  final _manualStepsController = TextEditingController(text: '8500');
  bool _showDevTools = false;

  @override
  void dispose() {
    _manualStepsController.dispose();
    super.dispose();
  }

  void _submitManualSteps() async {
    final steps = int.tryParse(_manualStepsController.text.trim());
    if (steps == null || steps < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid step count')),
      );
      return;
    }

    final success = await ref
        .read(activityProvider.notifier)
        .syncManualSteps(steps: steps);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Successfully synced $steps steps!'
                : 'Failed to sync steps',
          ),
          backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityState = ref.watch(activityProvider);
    final theme = Theme.of(context);

    final displaySteps = activityState.todaySteps > 0
        ? activityState.todaySteps
        : activityState.serverSteps;
    final cap = activityState.dailyCap;
    final progress = (displaySteps / cap).clamp(0.0, 1.0);
    final formattedSteps = NumberFormat('#,###').format(displaySteps);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.directions_walk, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            const Text('Daily Steps'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.developer_mode),
            tooltip: 'Toggle Dev Tools',
            onPressed: () {
              setState(() {
                _showDevTools = !_showDevTools;
              });
            },
          ),
          IconButton(
            icon: activityState.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: () {
              ref.read(activityProvider.notifier).initAndSync();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(activityProvider.notifier).initAndSync(),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Dev Tools Card (When toggled or for emulator testing)
            if (_showDevTools) _buildDevToolsCard(context, activityState),

            // Step Counter Progress Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text(
                      'TODAY\'S ACTIVITY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 14,
                            backgroundColor: const Color(0xFF334155),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF10B981),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formattedSteps,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 32,
                              ),
                            ),
                            const Text(
                              'of 20,000 cap',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatTile(
                          icon: Icons.stars_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          label: 'Earned Today',
                          value: '+${activityState.pointsEarnedToday} pts',
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: const Color(0xFF334155),
                        ),
                        _buildStatTile(
                          icon: Icons.account_balance_wallet,
                          iconColor: const Color(0xFF6366F1),
                          label: 'Total Balance',
                          value: '${activityState.userBalance} pts',
                        ),
                      ],
                    ),
                    if (activityState.lastSyncTime != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Last synced at ${activityState.lastSyncTime}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Earning Rule Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rule: 100 steps = 1 Point (Max 20,000 steps/day)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // History Section & Range Filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Activity History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'today', label: Text('Today')),
                    ButtonSegment(value: 'week', label: Text('7 Days')),
                    ButtonSegment(value: 'month', label: Text('30 Days')),
                  ],
                  selected: {activityState.selectedRange},
                  onSelectionChanged: (Set<String> selection) {
                    ref
                        .read(activityProvider.notifier)
                        .loadHistory(selection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // History Cards
            if (activityState.history != null &&
                activityState.history!.days.isNotEmpty)
              ...activityState.history!.days.map((day) {
                final dateFormatted = _formatDate(day.date);
                final stepsFmt = NumberFormat('#,###').format(day.eligibleSteps);
                final pts = day.eligibleSteps ~/ 100;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF1E293B),
                      child: Icon(Icons.directions_walk,
                          color: Color(0xFF10B981), size: 20),
                    ),
                    title: Text(
                      dateFormatted,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('$stepsFmt steps'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+$pts pts',
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              })
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    'No step records for this period yet.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Privacy Guarantee Note (PRD §5)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFF94A3B8), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Privacy Guarantee: Step count is synced as a daily total to calculate points. No GPS or location data is ever accessed.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDevToolsCard(BuildContext context, ActivityState state) {
    return Card(
      color: const Color(0xFF1E1B4B), // Deep indigo
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bug_report, color: Color(0xFF818CF8), size: 20),
                SizedBox(width: 8),
                Text(
                  'Developer Sandbox: Manual Step Ingestion',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF818CF8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Simulate step counts for emulator/testing without a physical device.',
              style: TextStyle(fontSize: 12, color: Color(0xFFA5B4FC)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualStepsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Manual Steps',
                      hintText: 'e.g. 12000',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: state.isSyncing ? null : _submitManualSteps,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(110, 48),
                  ),
                  child: const Text('Sync Steps'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final parsed = DateTime.parse(isoDate);
      return DateFormat('EEE, MMM d').format(parsed);
    } catch (_) {
      return isoDate;
    }
  }
}
