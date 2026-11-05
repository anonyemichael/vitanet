import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

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
              // Staff access is decided by the backend (/staff/me); the
              // router sends approved staff to the portal.
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
    final isLoading =
        authState.status == AuthStatus.loading || _isFetchingProfile;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: p.page,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 230 + topInset,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Semantics(
                        image: true,
                        label: 'Doctor chatting with a smiling patient',
                        child: Image.asset(
                          'assets/images/photos/doctor_with_patient.jpg',
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.4),
                        ),
                      ),
                      Positioned(
                        top: 16 + topInset,
                        left: 16,
                        child: VnIconButton(
                          icon: Icons.chevron_left_rounded,
                          tooltip: 'Back',
                          iconSize: 26,
                          background: p.surface,
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/login');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.page,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: SafeArea(
                      top: false,
                      child: _buildForm(p, isLoading),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(VnPalette p, bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(_createMode ? 'Create your account' : 'Welcome back',
                style: VnText.heading(26, color: p.ink)),
          ),
          const SizedBox(height: 6),
          Text(
            _createMode
                ? 'Sign up to save your checks, vitals and care circle.'
                : 'Sign in to see your checks, vitals and care circle.',
            style: VnText.body(15, color: p.muted),
          ),
          const SizedBox(height: 18),
          if (_isFetchingProfile)
            VnCard(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Column(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: p.brand),
                  ),
                  const SizedBox(height: 16),
                  Text('Preparing your health dashboard…',
                      style: VnText.body(14, weight: FontWeight.w600, color: p.ink)),
                ],
              ),
            )
          else ...[
            VnTextField(
              label: 'Email',
              controller: _emailCtrl,
              hint: 'you@example.com',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Enter your email';
                if (!s.contains('@') || !s.contains('.')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 18),
            VnTextField(
              label: 'Password',
              controller: _passwordCtrl,
              hint: 'Your password',
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
            if (!_createMode)
              Align(
                alignment: Alignment.centerRight,
                child: VnLink(
                  label: 'Forgot password?',
                  fontSize: 13,
                  onTap: isLoading ? null : _forgotPassword,
                ),
              )
            else
              const SizedBox(height: 18),
            VnButton(
              label: _createMode ? 'Create account' : 'Sign in',
              loading: isLoading,
              onPressed: isLoading ? null : _submitEmail,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Divider(color: p.line, height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or', style: VnText.body(12, color: p.muted)),
                ),
                Expanded(child: Divider(color: p.line, height: 1)),
              ],
            ),
            const SizedBox(height: 18),
            VnOutlineButton(
              label: 'Continue with Google',
              background: p.surface,
              leading: Image.asset(
                'assets/images/google_logo.png',
                width: 20,
                height: 20,
                errorBuilder: (c, e, s) => const Icon(
                    Icons.g_mobiledata_rounded,
                    color: Colors.blue,
                    size: 24),
              ),
              onPressed: isLoading
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      ref.read(authProvider.notifier).linkGoogleAccount();
                    },
            ),
            const SizedBox(height: 18),
            VnOutlineButton(
              label: 'Try anonymously',
              icon: Icons.person_outline_rounded,
              background: p.surfaceAlt,
              borderColor: Colors.transparent,
              onPressed: isLoading
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      ref.read(authProvider.notifier).signInAnonymously();
                    },
            ),

            const SizedBox(height: 8),
            Text(
              'Guest mode: no history sync across devices.',
              textAlign: TextAlign.center,
              style: VnText.body(12, color: p.muted),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_createMode ? 'Already have an account? ' : 'New to VitaNet? ',
                  style: VnText.body(14, color: p.muted)),
              VnLink(
                label: _createMode ? 'Sign in' : 'Create an account',
                weight: FontWeight.w700,
                onTap: () => setState(() => _createMode = !_createMode),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Healthcare worker? ', style: VnText.body(13, color: p.muted)),
              VnLink(
                label: 'Clinical staff sign-in',
                fontSize: 13,
                weight: FontWeight.w600,
                onTap: () => context.push('/login/hospital_personnel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
