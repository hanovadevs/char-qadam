import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';

/// Apple-style Translucent Navigation Bar.
///
/// Features:
/// - Translucent backdrop blur with 1px hairline divider
/// - Single-weight outline icons (filled when active)
/// - Brand accentSolid active tint & inkSecondary inactive tint
/// - Clean sentence case typography (Steps, Points, Rewards, Wallet, Profile)
class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    if (index != navigationShell.currentIndex) {
      HapticsService.selection();
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    final navItems = [
      const _NavItem(
        icon: CupertinoIcons.flame,
        selectedIcon: CupertinoIcons.flame_fill,
        label: 'Steps',
      ),
      const _NavItem(
        icon: CupertinoIcons.circle,
        selectedIcon: CupertinoIcons.circle_fill,
        label: 'Points',
      ),
      const _NavItem(
        icon: CupertinoIcons.tag,
        selectedIcon: CupertinoIcons.tag_fill,
        label: 'Rewards',
      ),
      const _NavItem(
        icon: CupertinoIcons.ticket,
        selectedIcon: CupertinoIcons.ticket_fill,
        label: 'Wallet',
      ),
      const _NavItem(
        icon: CupertinoIcons.person,
        selectedIcon: CupertinoIcons.person_fill,
        label: 'Profile',
      ),
    ];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.88),
              border: const Border(
                top: BorderSide(color: AppTheme.hairline, width: 1.0),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                height: 52,
                child: Row(
                  children: List.generate(navItems.length, (index) {
                    final item = navItems[index];
                    final isSelected = index == currentIndex;
                    final tintColor = isSelected ? AppTheme.accentSolid : AppTheme.inkSecondary;

                    return Expanded(
                      child: InkWell(
                        onTap: () => _onTap(index),
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              size: 21,
                              color: tintColor,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                letterSpacing: -0.2,
                                color: tintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
