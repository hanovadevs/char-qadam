import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../points/providers/points_provider.dart';
import '../../rewards/providers/rewards_provider.dart';
import '../../wallet/providers/wallet_provider.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MainScaffold({super.key, required this.navigationShell});
  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Warm the small primary pages after the first frame, without gating
      // navigation on requests or constructing the offscreen widget trees.
      ref.read(pointsProvider);
      ref.read(rewardsProvider);
      ref.read(walletProvider);
    });
  }

  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppTheme.mintWash,
        elevation: 0,
        height: 76,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppTheme.accentDeep
                : AppTheme.inkSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? AppTheme.accentDeep
                : AppTheme.inkSecondary,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        animationDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppTheme.motion,
        onDestinationSelected: (index) {
          if (index != navigationShell.currentIndex) HapticsService.selection();
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_walk_outlined),
            selectedIcon: Icon(Icons.directions_walk_rounded),
            label: 'Steps',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.circle_grid_hex),
            selectedIcon: Icon(CupertinoIcons.circle_grid_hex_fill),
            label: 'Points',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.gift),
            selectedIcon: Icon(CupertinoIcons.gift_fill),
            label: 'Rewards',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.ticket),
            selectedIcon: Icon(CupertinoIcons.ticket_fill),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.person),
            selectedIcon: Icon(CupertinoIcons.person_fill),
            label: 'You',
          ),
        ],
      ),
    ),
  );
}
