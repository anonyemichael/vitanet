import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/firebase_options.dart';
import 'package:vitanet/shared/widgets/vitanet_logo.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Animated splash: pulsing logo rings, self-drawing pulse line, ECG trace
/// across the background and a loading bar.
///
/// Returning users (onboarded + signed in) are routed to /home automatically;
/// onboarded users who are signed out go to /login. First-time users stay on
/// the splash and choose "Get started" or "I already have an account".
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _trace; // 3.2s ECG trace
  late final AnimationController _ring; // 2.4s pulsing rings + logo line
  late final AnimationController _beat; // 1.6s heartbeat scale
  late final AnimationController _load; // 2.8s loading bar
  late final AnimationController _rise; // entrance

  late final Future<void> _bootstrapFuture;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    _trace = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat();
    _ring = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
    _beat = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    _load = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat();
    _rise = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..forward();

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

    try {
      if (!dotenv.isInitialized) {
        await dotenv.load(fileName: ".env");
      }
    } catch (e) {
      debugPrint('DotEnv load: $e');
    }
  }

  /// Keeps the original post-splash routing for returning users.
  Future<void> _decideRoute() async {
    await Future.wait([
      _bootstrapFuture.timeout(const Duration(seconds: 2), onTimeout: () {}),
      Future<void>.delayed(const Duration(milliseconds: 1800)),
    ]);
    if (!mounted || _hasNavigated) return;

    final authState = ref.read(authProvider);
    final onboarded = ref.read(onboardingCompleteProvider);

    if (!onboarded) {
      // First run: the user picks from the splash actions.
      return;
    }

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
    _trace.dispose();
    _ring.dispose();
    _beat.dispose();
    _load.dispose();
    _rise.dispose();
    super.dispose();
  }

  /// CSS vnRise: fade + 12px rise over .8s with a delay.
  Widget _riseIn(double delaySeconds, Widget child) {
    return AnimatedBuilder(
      animation: _rise,
      builder: (context, c) {
        final t = ((_rise.value * 1.3 - delaySeconds) / 0.8).clamp(0.0, 1.0);
        final e = Curves.easeOut.transform(t);
        return Opacity(
          opacity: e,
          child: Transform.translate(offset: Offset(0, 12 * (1 - e)), child: c),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Radial teal glow centred on the logo.
          LayoutBuilder(builder: (context, c) {
            final cy = c.maxHeight * (300 / 844);
            return Stack(children: [
              Positioned(
                left: c.maxWidth / 2 - 260,
                top: cy - 260,
                width: 520,
                height: 520,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0x3814B8A6),
                        Color(0x0F14B8A6),
                        Color(0x00040A10),
                      ],
                      stops: [0, 0.4, 0.7],
                    ),
                  ),
                ),
              ),
            ]);
          }),
          // Grid + ECG trace.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _trace,
              builder: (context, _) => CustomPaint(
                painter: _EcgBackgroundPainter(_trace.value),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLogo(),
                          const SizedBox(height: 28),
                          _riseIn(0, _buildWordmark()),
                          const SizedBox(height: 28),
                          _riseIn(0.25, _buildBadges()),
                        ],
                      ),
                    ),
                  ),
                ),
                _riseIn(0.5, _buildFooter()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      width: 128,
      height: 128,
      child: AnimatedBuilder(
        animation: Listenable.merge([_ring, _beat]),
        builder: (context, _) {
          Widget ring(double phase) {
            final t = (_ring.value + phase) % 1.0;
            final e = Curves.easeOut.transform(t);
            return Transform.scale(
              scale: 1 + 0.9 * e,
              child: Opacity(
                opacity: (0.55 * (1 - e)).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(color: AppColors.mint, width: 2),
                  ),
                ),
              ),
            );
          }

          // vnBeat keyframes: 12% 1.06, 24% 1, 36% 1.04.
          final b = _beat.value;
          double scale;
          if (b < 0.12) {
            scale = 1 + 0.06 * (b / 0.12);
          } else if (b < 0.24) {
            scale = 1.06 - 0.06 * ((b - 0.12) / 0.12);
          } else if (b < 0.36) {
            scale = 1 + 0.04 * ((b - 0.24) / 0.12);
          } else {
            scale = 1.04 - 0.04 * ((b - 0.36) / 0.64);
          }
          // vnDraw: draw over 55% of the cycle, then hold.
          final draw = Curves.easeInOut.transform((_ring.value / 0.55).clamp(0.0, 1.0));

          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: ring(0)),
              Positioned.fill(child: ring(0.5)),
              Transform.scale(
                scale: scale,
                child: VitaNetLogo(size: 128, pulseProgress: draw, glow: true),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWordmark() {
    return Column(
      children: [
        Semantics(
          header: true,
          label: 'VitaNet',
          child: ExcludeSemantics(
            child: RichText(
              text: TextSpan(
                style: VnText.heading(46,
                    color: const Color(0xFFF1F5F9), letterSpacing: -1.5, height: 1),
                children: const [
                  TextSpan(text: 'Vita'),
                  TextSpan(text: 'Net', style: TextStyle(color: AppColors.mintLight)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 270),
          child: Text(
            'Know when to rest, when to see a pharmacist, and when to go now.',
            textAlign: TextAlign.center,
            style: VnText.body(16, color: const Color(0xFF94A3B8), height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildBadges() {
    Widget badge(IconData icon, String label) => Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.mintLight),
              const SizedBox(width: 6),
              Text(label,
                  style: VnText.body(12,
                      weight: FontWeight.w600, color: const Color(0xFFCBD5E1))),
            ],
          ),
        );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        badge(Icons.check_rounded, 'Clinician-guided'),
        badge(Icons.lock_outline_rounded, 'Encrypted'),
        badge(Icons.schedule_rounded, '24/7'),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Loading bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 4,
              color: Colors.white.withValues(alpha: 0.08),
              alignment: Alignment.centerLeft,
              child: AnimatedBuilder(
                animation: _load,
                builder: (context, _) {
                  final t = _load.value;
                  final w = t < 0.7
                      ? 0.08 + 0.78 * Curves.easeInOut.transform(t / 0.7)
                      : 0.86 + 0.14 * Curves.easeInOut.transform((t - 0.7) / 0.3);
                  return FractionallySizedBox(
                    widthFactor: w,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF14B8A6), AppColors.mintLight],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Syncing your vitals…',
                  style: VnText.body(12, color: AppColors.inkMuted)),
              Text('v1.0', style: VnText.body(12, color: AppColors.inkMuted)),
            ],
          ),
          const SizedBox(height: 18),
          VnButton(
            label: 'Get started',
            icon: Icons.arrow_forward_rounded,
            iconAfter: true,
            height: 58,
            radius: 18,
            background: AppColors.mint,
            foreground: const Color(0xFF03201C),
            onPressed: () => _go('/onboarding'),
            shadow: const [
              BoxShadow(
                color: Color(0x402DD4BF),
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          const SizedBox(height: 18),
          VnOutlineButton(
            label: 'I already have an account',
            height: 52,
            radius: 18,
            borderColor: Colors.white.withValues(alpha: 0.14),
            foreground: const Color(0xFFF1F5F9),
            onPressed: () => _go('/login'),
          ),
          const SizedBox(height: 18),
          Text(
            'VitaNet gives guidance, not a diagnosis. In an emergency call 112.',
            textAlign: TextAlign.center,
            style: VnText.body(11, color: AppColors.inkMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Faint grid plus the animated ECG trace from the splash spec
/// (viewBox 390 x 844, trace at y = 300).
class _EcgBackgroundPainter extends CustomPainter {
  final double t;
  _EcgBackgroundPainter(this.t);

  static const _points = <Offset>[
    Offset(-20, 300), Offset(96, 300), Offset(108, 300), Offset(118, 282),
    Offset(128, 300), Offset(150, 300), Offset(162, 240), Offset(178, 352),
    Offset(192, 300), Offset(294, 300), Offset(304, 286), Offset(314, 300),
    Offset(410, 300),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390;
    final sy = size.height / 844;
    final scale = math.min(sx, sy);

    final grid = Paint()
      ..color = AppColors.mintLight.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var y = 120.0; y <= 760; y += 80) {
      canvas.drawLine(Offset(0, y * sy), Offset(size.width, y * sy), grid);
    }
    for (final x in const [39.0, 117.0, 195.0, 273.0, 351.0]) {
      canvas.drawLine(Offset(x * sx, 0), Offset(x * sx, size.height), grid);
    }

    final path = Path();
    for (var i = 0; i < _points.length; i++) {
      final p = Offset(_points[i].dx * sx, 300 * sy + (_points[i].dy - 300) * scale);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    // vnTrace: draw over the first 60% of the cycle, then hold.
    final progress = Curves.easeInOut.transform((t / 0.6).clamp(0.0, 1.0));
    final out = Path();
    for (final m in path.computeMetrics()) {
      out.addPath(m.extractPath(0, m.length * progress), Offset.zero);
    }
    canvas.drawPath(
      out,
      Paint()
        ..color = AppColors.mint.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_EcgBackgroundPainter old) => old.t != t;
}
