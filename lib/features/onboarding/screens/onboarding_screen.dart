import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/core/constants/app_strings.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/shared/widgets/gradient_background.dart';

/// 3-page onboarding flow with premium realistic imagery.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingData(
      imagePath: 'assets/images/onboarding/1.jpg',
      title: AppStrings.onboardingTitle1,
      subtitle: AppStrings.onboardingSubtext1,
    ),
    _OnboardingData(
      imagePath: 'assets/images/onboarding/2.jpg',
      title: AppStrings.onboardingTitle2,
      subtitle: AppStrings.onboardingSubtext2,
    ),
    _OnboardingData(
      imagePath: 'assets/images/onboarding/3.jpg',
      title: AppStrings.onboardingTitle3,
      subtitle: AppStrings.onboardingSubtext3,
    ),
  ];

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutQuart,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final storage = ref.read(localStorageProvider);
    await storage.setOnboardingComplete();
    ref.read(onboardingCompleteProvider.notifier).state = true;
    
    // Now routes to Login/Role Selection because Onboarding is the true first step.
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;
    final isWide = MediaQuery.sizeOf(context).width > 800;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          const GradientBackground(child: SizedBox.expand()),
          
          // Page view (full screen, bleeds to top)
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return _OnboardingPage(data: page, isWide: isWide);
            },
          ),
          
          // Skip button floating at the top right
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSpacing.md,
            right: AppSpacing.lg,
            child: TextButton(
              onPressed: _completeOnboarding,
              child: Text(
                'Skip',
                style: context.textTheme.labelLarge?.copyWith(
                  color: isWide ? context.colorScheme.primary : Colors.white,
                  shadows: isWide ? null : [
                    Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4),
                  ]
                ),
              ),
            ),
          ),
          
          // Bottom controls
          Positioned(
            left: isWide ? MediaQuery.sizeOf(context).width / 2 : 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xxl,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? AppSpacing.xxl * 2 : AppSpacing.xxl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 32 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? context.colorScheme.primary
                              : context.colorScheme.primary.withValues(
                                  alpha: 0.25,
                                ),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusPill,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // CTA button
                  SizedBox(
                    width: isWide ? 400 : double.infinity,
                    child: ElevatedButton(
                      onPressed: _onNext,
                      child: Text(isLast ? 'Get Started' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ─── Internal Widgets ───

class _OnboardingData {
  final String imagePath;
  final String title;
  final String subtitle;

  const _OnboardingData({
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  final bool isWide;

  const _OnboardingPage({required this.data, required this.isWide});

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return Row(
        children: [
          // Left side: Premium Image blending with background
          Expanded(
            flex: 1,
            child: ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black,
                    Colors.black.withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: Image.asset(
                data.imagePath,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
          
          // Right side: Content
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xl,
                right: AppSpacing.xxl * 3,
                bottom: 120, // space for bottom controls
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        textAlign: TextAlign.left,
                        style: context.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          height: 1.1,
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        data.subtitle,
                        textAlign: TextAlign.left,
                        style: context.textTheme.headlineSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Premium Image fading seamlessly into the background
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: ShaderMask(
            shaderCallback: (rect) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  Colors.black,
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6, 0.85, 1.0],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: Image.asset(
              data.imagePath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ),
        
        // Text Content anchored above the controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 140, // Space for the bottom controls
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  data.subtitle,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
