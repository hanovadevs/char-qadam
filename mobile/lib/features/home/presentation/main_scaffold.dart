import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

/// Minimalist Swiss Light Style navigation bar.
///
/// Features clean geometric layout, 1px precision hairline top border,
/// uppercase tracked typography, and crisp high-contrast active state indicators.
class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
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
        icon: Icons.directions_walk_outlined,
        selectedIcon: Icons.directions_walk,
        label: 'STEPS',
      ),
      const _NavItem(
        icon: Icons.toll_outlined,
        selectedIcon: Icons.toll,
        label: 'POINTS',
      ),
      const _NavItem(
        icon: Icons.local_offer_outlined,
        selectedIcon: Icons.local_offer,
        label: 'REWARDS',
      ),
      const _NavItem(
        icon: Icons.confirmation_number_outlined,
        selectedIcon: Icons.confirmation_number,
        label: 'WALLET',
      ),
      const _NavItem(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'PROFILE',
      ),
    ];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.white,
          border: Border(
            top: BorderSide(color: AppTheme.border, width: 1.0),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 54,
            child: Row(
              children: List.generate(navItems.length, (index) {
                final item = navItems[index];
                final isSelected = index == currentIndex;

                return Expanded(
                  child: InkWell(
                    onTap: () => _onTap(index),
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        // Top hairline active indicator (Black)
                        if (isSelected)
                          Container(
                            height: 2,
                            width: 28,
                            color: AppTheme.black,
                          ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isSelected ? item.selectedIcon : item.icon,
                                size: 19,
                                color: isSelected ? AppTheme.black : AppTheme.grey,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  letterSpacing: 1.0,
                                  color: isSelected ? AppTheme.black : AppTheme.grey,
                                ),
                              ),
                            ],
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
