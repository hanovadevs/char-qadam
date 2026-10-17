import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
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
      backgroundColor: AppTheme.white,
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
                    'SKIP',
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
                                        ? 'START EARNING'
                                        : 'ENABLE STEP TRACKING',
                                  ),
                          ),
                        ),
                        if (!_permissionGranted) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _completeOnboarding,
                            child: const Text(
                              'CONTINUE WITHOUT TRACKING',
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
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text('NEXT'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.beige,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.borderDark, width: 1.5),
            ),
            child: const Icon(
              Icons.directions_walk,
              size: 40,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'WELCOME TO STEPSY',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'STEP-BASED VALUE NETWORK',
            style: TextStyle(
              fontSize: 11,
              fontFamily: AppTheme.monoFont,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppTheme.taupe,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Walk. Earn points. Redeem real rewards.\nYour daily steps create tangible value\nat partner brands.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.grey, height: 1.6),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatChip('100 STEPS', '1 POINT'),
              const SizedBox(width: 16),
              _buildStatChip('20K CAP', 'DAILY'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.offWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.borderDark, width: 1.5),
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 40,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'YOUR PRIVACY',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'DATA TRANSPARENCY GUARANTEE',
            style: TextStyle(
              fontSize: 11,
              fontFamily: AppTheme.monoFont,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppTheme.taupe,
            ),
          ),
          const SizedBox(height: 28),
          _buildPrivacyRow(
            Icons.phone_android,
            'STEP DATA STAYS LOCAL',
            'Raw health data never leaves your device.',
          ),
          const SizedBox(height: 14),
          _buildPrivacyRow(
            Icons.cloud_upload_outlined,
            'STEPS & DEVICE CHECK',
            'Daily totals earn points. An app-scoped device identifier prevents repeat rewards across accounts.',
          ),
          const SizedBox(height: 14),
          _buildPrivacyRow(
            Icons.location_off_outlined,
            'ZERO GPS TRACKING',
            'No location, route, or movement data is collected.',
          ),
          const SizedBox(height: 14),
          _buildPrivacyRow(
            Icons.delete_outline,
            'ACCOUNT ACCESS',
            'Deactivate your account from Profile to stop access and tracking.',
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _permissionGranted ? AppTheme.beige : AppTheme.offWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: _permissionGranted
                    ? AppTheme.black
                    : AppTheme.borderDark,
                width: 1.5,
              ),
            ),
            child: Icon(
              _permissionGranted
                  ? Icons.check_circle_outline
                  : Icons.fitness_center,
              size: 40,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _permissionGranted ? 'ALL SET' : 'ENABLE TRACKING',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _permissionGranted
                ? 'STEP TRACKING IS ACTIVE'
                : 'HEALTH DATA ACCESS REQUIRED',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: AppTheme.monoFont,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppTheme.taupe,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _permissionGranted
                ? 'Your device will automatically count your steps in the background. Walk naturally and earn points throughout the day.'
                : 'Stepsy needs access to your step counter to track daily movement. This uses Apple HealthKit (iOS) or Health Connect (Android).',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.grey,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String top, String bottom) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.offWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(
            top,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: AppTheme.monoFont,
              fontWeight: FontWeight.w800,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            bottom,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppTheme.grey,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyRow(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.offWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.black, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppTheme.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
