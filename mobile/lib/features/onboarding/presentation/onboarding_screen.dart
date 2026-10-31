import '../../../core/services/health_consent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cozy_scene.dart';
import '../../../core/widgets/stepsy_ui.dart';
import '../../../data/activity/health_service.dart';
import '../../../routing/app_router.dart';

/// Key used to persist onboarding completion state
const String onboardingCompleteKey = 'qadam_onboarding_complete';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _permissionGranted = false;
  bool _requestingPermission = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (!await HealthConsent.request(context)) return;
    if (!mounted) return;
    setState(() => _requestingPermission = true);
    HapticsService.medium();

    final healthService = ref.read(healthServiceProvider);
    final granted = await healthService.requestPermissions();

    if (!mounted) return;
    setState(() {
      _permissionGranted = granted;
      _requestingPermission = false;
    });

    if (granted) {
      HapticsService.heavy();
    }
  }

  Future<void> _completeOnboarding() async {
    HapticsService.heavy();
    const storage = FlutterSecureStorage();
    await storage.write(key: onboardingCompleteKey, value: 'true');

    if (mounted) {
      ref.invalidate(onboardingCompleteProvider);
      context.go('/steps');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceMuted,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 16),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppTheme.grey,
                    ),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  HapticsService.selection();
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildWelcomePage(),
                  _buildPrivacyPage(),
                  _buildPermissionPage(),
                ],
              ),
            ),

            // Page Indicators
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 3,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppTheme.black
                          : AppTheme.border,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  );
                }),
              ),
            ),

            // Bottom Action
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: _currentPage == 2
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _permissionGranted
                                ? _completeOnboarding
                                : _requestingPermission
                                ? null
                                : _requestPermissions,
                            child: _requestingPermission
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _permissionGranted
                                        ? 'Let’s walk'
                                        : 'Allow step tracking',
                                  ),
                          ),
                        ),
                        if (!_permissionGranted) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _completeOnboarding,
                            child: const Text(
                              'Continue without tracking',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.grey,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _pageController.nextPage(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : AppTheme.motion,
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text('Continue'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _intro(
    String pose,
    String title,
    String description, {
    Widget? child,
  }) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CozyScene(height: 170, pose: pose),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTheme.largeTitleStyle),
              const SizedBox(height: 12),
              Text(description, style: AppTheme.bodyStyle),
              if (child != null) ...[const SizedBox(height: 20), child],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildWelcomePage() => _intro(
    'walk',
    'Every step, closer.',
    'Walk at your own pace, collect points from eligible activity and enjoy partner rewards. Your companion is here for every little win.',
    child: const SurfaceCard(
      color: AppTheme.sageWash,
      child: Text(
        'Your live steps appear straight away. Points are confirmed after syncing.',
        style: AppTheme.bodyStyle,
      ),
    ),
  );

  Widget _buildPrivacyPage() => _intro(
    'wave',
    'Your walk. Your choice.',
    'Choose the activity access that works for you.',
    child: Column(
      children: [
        _privacy(
          Icons.phone_android,
          'Daily totals, not a route',
          'Eligible step totals are synced to award points. An app-scoped device check prevents repeat rewards.',
        ),
        _privacy(
          Icons.location_off_outlined,
          'No GPS route tracking',
          'Motion sensors count your walks and help exclude bike and car movement.',
        ),
        _privacy(
          Icons.pause_circle_outline,
          'You stay in control',
          'Pause from the tracking notification, manage permissions, or delete your account in You.',
        ),
      ],
    ),
  );

  Widget _buildPermissionPage() => _intro(
    'wave',
    _permissionGranted ? 'You’re ready to wander.' : 'Let’s count your walks.',
    _permissionGranted
        ? 'Your activity access is ready. You can manage background tracking and pause it whenever you like.'
        : 'Allow physical activity and notifications so Stepsy can keep counting in the background. Available health integrations depend on your phone.',
    child: SurfaceCard(
      color: AppTheme.sageWash,
      child: Row(
        children: [
          Icon(
            _permissionGranted
                ? Icons.check_circle_outline
                : Icons.directions_walk_rounded,
            color: AppTheme.accentSolid,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _permissionGranted
                  ? 'Activity access is ready.'
                  : 'Your steps belong to your own pace.',
              style: AppTheme.bodyStyle,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _privacy(IconData icon, String title, String detail) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.accentSolid),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.headlineStyle),
              Text(detail, style: AppTheme.captionStyle),
            ],
          ),
        ),
      ],
    ),
  );
}
