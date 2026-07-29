import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/shared/widgets/animated_logo.dart';

/// A premium, snappy splash screen with staggered micro-animations and a sleek background.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;
  late Animation<double> _bgOpacity;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoTranslateY;
  late Animation<double> _titleOpacity;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _loaderOpacity;

  // Track if we've successfully navigated so we don't try again.
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 0. Background fades in to mask the transition from native black splash
    _bgOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // 1. Logo fades in and slides up slightly
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
      ),
    );
    _logoTranslateY = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Title fades in
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // 3. Subtitle fades in
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // 4. Loader fades in at the bottom
    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    _staggerController.forward();

    // Check auth status much sooner (1.5 seconds instead of 2.5)
    Future.delayed(const Duration(milliseconds: 1500), _checkAuthAndNavigate);
  }

  void _checkAuthAndNavigate() {
    if (!mounted || _hasNavigated) return;

    final authState = ref.read(authProvider);
    final onboarded = ref.read(onboardingCompleteProvider);

    if (authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.loading) {
      // Auth isn't ready yet. Check again very shortly.
      Future.delayed(const Duration(milliseconds: 200), _checkAuthAndNavigate);
      return;
    }

    _hasNavigated = true;

    if (!onboarded) {
      context.go('/onboarding');
      return;
    }

    if (authState.status == AuthStatus.authenticated ||
        authState.status == AuthStatus.anonymous) {
      var profile = ref.read(userProfileProvider);
      if (profile == null) {
        if (authState.status == AuthStatus.anonymous) {
          profile = UserProfile(name: 'Guest User', role: 'user');
          ref.read(userProfileProvider.notifier).updateProfile(profile);
          context.go('/home');
        } else {
          // New user, push to the completion form!
          context.go('/login/patient_completion');
        }
      } else {
        context.go('/home');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Solid background matching native splash perfectly
      backgroundColor: const Color(0xFF061017),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image fading in smoothly
          AnimatedBuilder(
            animation: _bgOpacity,
            builder: (context, child) {
              return Opacity(
                opacity: _bgOpacity.value,
                child: Image.asset(
                  'assets/images/splash_bg.png',
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
          
          // Dark Overlay to ensure text readability
          Container(
            color: Colors.black.withValues(alpha: 0.65),
          ),
          
          // Foreground Animated Content
          AnimatedBuilder(
            animation: _staggerController,
            builder: (context, child) {
              return Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Transform.translate(
                          offset: Offset(0, _logoTranslateY.value),
                          child: Opacity(
                            opacity: _logoOpacity.value,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.colorScheme.primary.withOpacity(0.2),
                                    blurRadius: 40,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              child: const AnimatedLogo(size: 110),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        
                        // Title
                        Opacity(
                          opacity: _titleOpacity.value,
                          child: Text(
                            'VitaNet',
                            style: context.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        
                        // Subtitle
                        Opacity(
                          opacity: _subtitleOpacity.value,
                          child: Text(
                            'Your health, instantly.',
                            style: context.textTheme.bodyLarge?.copyWith(
                              color: Colors.white70,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Bottom Loading Indicator
                  Positioned(
                    bottom: 60,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: _loaderOpacity.value,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              context.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
