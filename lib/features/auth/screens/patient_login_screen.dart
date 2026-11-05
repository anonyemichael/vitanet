import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/shared/widgets/vitanet_logo.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Redesigned executive-grade patient authentication screen.
///
/// Responsive:
/// - Desktop (>= 960px): Split screen with clinical brand hero on the left
///   and clean, high-density authentication card on the right.
/// - Mobile / Tablet (< 960px): Focused single-column card with top navigation.
///
/// Eliminates awkward cropped stock images and provides seamless toggle
/// between Sign In and Account Creation.
class PatientLoginScreen extends ConsumerStatefulWidget {
  const PatientLoginScreen({super.key});

  @override
  ConsumerState<PatientLoginScreen> createState() => _PatientLoginScreenState();
}

class _PatientLoginScreenState extends ConsumerState<PatientLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isFetchingProfile = false;
  bool _obscure = true;
  bool _createMode = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submitEmail() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final notifier = ref.read(authProvider.notifier);
    if (_createMode) {
      notifier.signUpWithEmail(email, password);
    } else {
      notifier.signInWithEmail(email, password);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      context.showSnack('Enter your email above, then tap Forgot password.');
      return;
    }
    try {
      if (Firebase.apps.isEmpty) {
        if (mounted) context.showSnack('Password reset is currently unavailable in offline mode.');
        return;
      }
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) context.showSnack('Password reset link sent to $email');
    } catch (e) {
      if (mounted) context.showSnack('Could not send reset email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) async {
      if (next.status == AuthStatus.authenticated ||
          next.status == AuthStatus.anonymous) {
        await ref.read(activeWorkspaceProvider.notifier).setWorkspace(AppWorkspace.personal);
        if (next.status == AuthStatus.anonymous) {
          const profile = UserProfile(name: 'Guest User', role: 'user');
          ref.read(userProfileProvider.notifier).updateProfile(profile);
          if (context.mounted) context.go('/home');
          return;
        }

        // Authenticated user: check the backend profile.
        if (mounted) setState(() => _isFetchingProfile = true);
        try {
          if (next.user != null) {
            final userProfile = await ref
                .read(firestoreServiceProvider)
                .getUserProfile(next.user!.uid);

            if (!context.mounted) return;

            if (userProfile != null) {
              ref.read(userProfileProvider.notifier).updateProfile(userProfile);
              context.go('/home');
            } else {
              // New user, push to the completion form.
              context.go('/login/patient_completion');
            }
          } else {
            if (context.mounted) context.go('/home');
          }
        } catch (e) {
          if (context.mounted) context.showSnack('Failed to fetch profile: $e');
        } finally {
          if (mounted) setState(() => _isFetchingProfile = false);
        }
      } else if (next.status == AuthStatus.error) {
        if (mounted) setState(() => _isFetchingProfile = false);
        context.showSnack(next.errorMessage ?? 'Authentication failed');
      }
    });

    final p = VnPalette.of(context);
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading || _isFetchingProfile;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 960;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: p.page,
        body: Row(
          children: [
            // Left: Enterprise Hero Panel (440px)
            const SizedBox(
              width: 440,
              child: _PatientHeroPanel(),
            ),
            // Right: Clean Auth Form
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                    child: _buildAuthCard(p, isLoading, isDesktop: true),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile / Tablet layout
    return Scaffold(
      backgroundColor: p.page,
      appBar: AppBar(
        backgroundColor: p.page,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: p.ink),
          tooltip: 'Workspaces',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const VitaNetLogo(size: 26),
            const SizedBox(width: 8),
            Text(
              'VitaNet',
              style: VnText.heading(18, weight: FontWeight.w800, color: p.ink),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: _buildAuthCard(p, isLoading, isDesktop: false),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthCard(VnPalette p, bool isLoading, {required bool isDesktop}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isDesktop) ...[
            // Top back button
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/login');
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 16, color: p.muted),
                      const SizedBox(width: 6),
                      Text(
                        'Change workspace',
                        style: VnText.body(13, weight: FontWeight.w500, color: p.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Role Badge & Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brandWash,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: p.brandBorder),
                ),
                child: Text(
                  'PERSONAL HEALTH',
                  style: VnText.heading(10, weight: FontWeight.w700, color: AppColors.brandDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              _createMode ? 'Create your personal account' : 'Welcome back',
              style: VnText.heading(26, weight: FontWeight.w800, color: p.ink),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _createMode
                ? 'Sign up to track vitals, send ER pre-arrivals, and review hospital stays.'
                : 'Sign in to access your health checks, vitals history, and hospital records.',
            style: VnText.body(14, color: p.muted, height: 1.45),
          ),
          const SizedBox(height: 20),

          // Executive Segmented Mode Switcher (Sign In vs Create Account)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ModeSwitchButton(
                    label: 'Sign In',
                    active: !_createMode,
                    onTap: () {
                      if (_createMode) setState(() => _createMode = false);
                    },
                  ),
                ),
                Expanded(
                  child: _ModeSwitchButton(
                    label: 'Create Account',
                    active: _createMode,
                    onTap: () {
                      if (!_createMode) setState(() => _createMode = true);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_isFetchingProfile)
            VnCard(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              child: Column(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: p.brand),
                  ),
                  const SizedBox(height: 16),
                  Text('Loading your health records…',
                      style: VnText.body(14, weight: FontWeight.w600, color: p.ink)),
                ],
              ),
            )
          else ...[
            // Email Input
            VnTextField(
              label: 'Email address',
              controller: _emailCtrl,
              hint: 'you@example.com',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Enter your email';
                if (!s.contains('@') || !s.contains('.')) return 'Enter a valid email address';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password Input
            VnTextField(
              label: 'Password',
              controller: _passwordCtrl,
              hint: _createMode ? 'At least 6 characters' : 'Enter your password',
              prefixIcon: Icons.lock_outline_rounded,
              obscure: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitEmail(),
              validator: (v) {
                if ((v ?? '').isEmpty) return 'Enter your password';
                if (_createMode && v!.length < 6) {
                  return 'Use at least 6 characters';
                }
                return null;
              },
              suffix: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: p.muted,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),

            if (!_createMode) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: VnLink(
                  label: 'Forgot password?',
                  fontSize: 13,
                  weight: FontWeight.w500,
                  onTap: isLoading ? null : _forgotPassword,
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              const SizedBox(height: 24),
            ],

            // Submit Button
            VnButton(
              label: _createMode ? 'Create Personal Account' : 'Sign In',
              loading: isLoading,
              onPressed: isLoading ? null : _submitEmail,
            ),
            const SizedBox(height: 20),

            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: p.line, height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text('or continue with',
                      style: VnText.body(12, color: p.faint, weight: FontWeight.w500)),
                ),
                Expanded(child: Divider(color: p.line, height: 1)),
              ],
            ),
            const SizedBox(height: 16),

            // Google Sign-In Button
            VnOutlineButton(
              label: 'Continue with Google',
              background: p.surface,
              borderColor: p.line,
              leading: Image.asset(
                'assets/images/google_logo.png',
                width: 18,
                height: 18,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.g_mobiledata_rounded,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              onPressed: isLoading
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      ref.read(authProvider.notifier).linkGoogleAccount();
                    },
            ),
            const SizedBox(height: 12),

            // Anonymous / Guest Triage
            VnOutlineButton(
              label: 'Continue as Guest',
              icon: Icons.person_outline_rounded,
              background: p.surfaceAlt.withValues(alpha: 0.6),
              borderColor: Colors.transparent,
              onPressed: isLoading
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      ref.read(authProvider.notifier).signInAnonymously();
                    },
            ),
            const SizedBox(height: 6),
            Text(
              'Guest mode: perform instant triage without cloud sync.',
              textAlign: TextAlign.center,
              style: VnText.body(11, color: p.faint),
            ),
          ],

          const SizedBox(height: 24),
          Divider(color: p.line, height: 1),
          const SizedBox(height: 16),

          // Switch to Hospital Staff
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Healthcare professional? ',
                    style: VnText.body(13, color: p.muted)),
                VnLink(
                  label: 'Access Hospital Staff Portal →',
                  fontSize: 13,
                  weight: FontWeight.w600,
                  onTap: () => context.push('/login/hospital_personnel'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Left hero showcase panel on desktop.
class _PatientHeroPanel extends StatelessWidget {
  const _PatientHeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.staffNavy,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo & Brand
            Row(
              children: [
                const VitaNetLogo(size: 34),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VitaNet',
                      style: VnText.heading(20, weight: FontWeight.w800, color: Colors.white),
                    ),
                    Text(
                      'Personal Health Network',
                      style: VnText.body(12, weight: FontWeight.w500, color: AppColors.mint),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 36),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Text(
                'PATIENT & CAREGIVER PORTAL',
                style: VnText.heading(10, weight: FontWeight.w700, color: AppColors.mint),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Your Connected Health & Hospital Gateway.',
              style: VnText.heading(28, weight: FontWeight.w800, color: Colors.white, height: 1.25),
            ),
            const SizedBox(height: 16),
            Text(
              'Check symptoms in seconds, dispatch live ER pre-arrivals to regional hospitals, and access verified inpatient discharge records.',
              style: VnText.body(14, color: const Color(0xFF94A3B8), height: 1.6),
            ),
            const SizedBox(height: 28),

            // Features
            _PatientHeroBullet(
              icon: Icons.bolt_rounded,
              title: '1-Tap ER Pre-Arrival Dispatch',
              desc: 'Transmit symptoms and triage vitals directly to hospital emergency departments before arriving.',
            ),
            const SizedBox(height: 16),
            _PatientHeroBullet(
              icon: Icons.assignment_outlined,
              title: 'Inpatient Hospital Stay Summaries',
              desc: 'Review attending doctor notes, bed assignments, and official discharge medication plans.',
            ),
            const SizedBox(height: 16),
            _PatientHeroBullet(
              icon: Icons.favorite_outline_rounded,
              title: 'Continuous Vital Signs Tracking',
              desc: 'Monitor blood pressure, oxygen saturation, heart rate, and temperature over time.',
            ),

            const SizedBox(height: 36),

            // Security footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.mint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'End-to-End Encrypted • HIPAA Compliant • Protected Health Information (PHI)',
                      style: VnText.body(11, color: const Color(0xFF94A3B8)),
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
}

class _PatientHeroBullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _PatientHeroBullet({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Icon(icon, size: 16, color: AppColors.mint),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: VnText.heading(13, weight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: VnText.body(12, color: const Color(0xFF94A3B8), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeSwitchButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeSwitchButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Material(
      color: active ? p.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      elevation: active ? 1 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          child: Text(
            label,
            style: VnText.heading(
              13,
              weight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? p.ink : p.muted,
            ),
          ),
        ),
      ),
    );
  }
}
