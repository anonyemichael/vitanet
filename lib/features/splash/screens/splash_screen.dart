import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/core/network/backend.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/firebase_options.dart';
import 'package:vitanet/shared/widgets/vitanet_logo.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Clean, minimal splash: centred logo and wordmark, a thin teal progress
/// line and a short tagline. No buttons — it continues automatically:
/// first-time users go to /onboarding, returning signed-in users to /home,
/// and returning signed-out users to /login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  static const _minDisplay = Duration(milliseconds: 1600);
  static const _bootstrapTimeout = Duration(seconds: 3);

  late final AnimationController _intro; // logo + wordmark fade-in
  late final AnimationController _progress; // thin progress line

  late final Future<void> _bootstrapFuture;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _progress = AnimationController(
      vsync: this,
      duration: _minDisplay,
    )..forward();

    _bootstrapFuture = _bootstrapServices();
    _decideRoute();
  }

  Future<void> _bootstrapServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        ref.read(sharedPreferencesProvider.notifier).state = prefs;
      }
    } catch (e) {
      debugPrint('Bootstrap prefs: $e');
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      if (mounted) {
        ref.read(authProvider.notifier).reinitialize();
      }
    } catch (e) {
      debugPrint('Bootstrap firebase: $e');
    }

    // Current backend address from Firebase (falls back to the cached value).
    await BackendConfig.load();
  }

  Future<void> _decideRoute() async {
    await Future.wait([
      _bootstrapFuture.timeout(_bootstrapTimeout, onTimeout: () {}),
      Future<void>.delayed(_minDisplay),
    ]);
    if (!mounted || _hasNavigated) return;

    final onboarded = ref.read(onboardingCompleteProvider);
    if (!onboarded) {
      _go('/onboarding');
      return;
    }

    final authState = ref.read(authProvider);
    final isAuthed = authState.status == AuthStatus.authenticated ||
        authState.status == AuthStatus.anonymous ||
        authState.user != null ||
        (Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null);

    _go(isAuthed ? '/home' : '/login');
  }

  void _go(String path) {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    FlutterNativeSplash.remove();
    context.go(path);
  }

  @override
  void dispose() {
    _intro.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColors.backgroundDark : Colors.white;
    final ink = dark ? AppColors.onSurfaceDark : AppColors.ink;
    final muted = dark ? AppColors.onSurfaceVariantDark : AppColors.inkMuted;
    final track = dark ? Colors.white.withValues(alpha: 0.10) : AppColors.line;
    final bar = dark ? AppColors.mint : AppColors.brand;

    final fade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
    final scale = Tween<double>(begin: 0.92, end: 1).animate(fade);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: FadeTransition(
                  opacity: fade,
                  child: ScaleTransition(
                    scale: scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const VitaNetLogo(size: 88),
                        const SizedBox(height: 20),
                        Semantics(
                          header: true,
                          child: Text(
                            'VitaNet',
                            style: VnText.heading(30,
                                color: ink, letterSpacing: -0.6, height: 1),
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: 120,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: AnimatedBuilder(
                              animation: _progress,
                              builder: (context, _) => LinearProgressIndicator(
                                value: Curves.easeInOut
                                    .transform(_progress.value),
                                minHeight: 3,
                                backgroundColor: track,
                                valueColor: AlwaysStoppedAnimation(bar),
                                semanticsLabel: 'Loading VitaNet',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: FadeTransition(
                opacity: fade,
                child: Text(
                  'Your health, guided',
                  style: VnText.body(14, color: muted, weight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
