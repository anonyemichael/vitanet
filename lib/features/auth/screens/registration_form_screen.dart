import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/services/hospital_api_service.dart';
import 'package:vitanet/features/admin/widgets/portal_common.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';
import 'package:vitanet/features/auth/widgets/email_verification_banner.dart';

/// Hospital staff sign-in / sign-up (StaffRegister.dc.html).
///
/// Step 1 is a Firebase account (email + password or Google). Step 2 is the
/// staff request (POST /staff/register): name, role, hospital, department,
/// license. Portal access comes only from GET /staff/me — the Firestore
/// profile role is never set to a staff role here.
class RegistrationFormScreen extends ConsumerStatefulWidget {
  const RegistrationFormScreen({super.key});

  @override
  ConsumerState<RegistrationFormScreen> createState() => _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends ConsumerState<RegistrationFormScreen> {
  bool _isSignIn = true;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final signedIn = ref.watch(authProvider.select((s) => s.status == AuthStatus.authenticated && s.user != null));
    final access = signedIn ? ref.watch(staffAccessProvider) : null;
    // Someone who signs in here and already has a staff account goes
    // straight to the portal (which shows pending / approved etc.).
    ref.listen<AsyncValue<StaffAccess>>(staffAccessProvider, (prev, next) {
      final a = next.valueOrNull;
      if (next.isLoading || a == null || !mounted) return;
      if (a.kind != StaffAccessKind.none && a.kind != StaffAccessKind.rejected) {
        ref.read(preferredWorkspaceProvider.notifier).state = AppWorkspace.hospital;
        context.go('/admin');
      }
    });

    final String title;
    final String subtitle;
    if (!signedIn) {
      title = _isSignIn ? 'Clinical staff sign-in' : 'Clinical staff sign-up';
      subtitle = _isSignIn
          ? 'Use the account your hospital administrator approved.'
          : 'Create your account, then tell us where you work. Your hospital administrator approves new staff.';
    } else {
      title = 'Request staff access';
      subtitle = 'Your hospital administrator reviews requests, usually within one working day.';
    }

    Widget body;
    if (!signedIn) {
      body = _CredentialsStep(
        key: ValueKey(_isSignIn),
        isSignIn: _isSignIn,
        onSwitch: () => setState(() => _isSignIn = !_isSignIn),
      );
    } else {
      body = access!.when(
        loading: () => const PortalLoading(),
        error: (e, _) => PortalError(error: e, onRetry: () => ref.invalidate(staffAccessProvider)),
        data: (a) => a.kind == StaffAccessKind.none || a.kind == StaffAccessKind.rejected
            ? _StaffDetailsStep(
                notice: a.kind == StaffAccessKind.rejected
                    ? 'Your last request was declined. You can send a new one.'
                    : (_isSignIn ? 'This account has no staff access yet. Complete the form to request it.' : null),
              )
            : _AlreadyRegistered(access: a),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: p.dark ? p.bg : AppColors.pageBg,
        body: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: AppColors.staffNavy,
              padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 28),
              child: StaffContent(
                maxWidth: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        StaffIconButton(
                          icon: Icons.chevron_left_rounded,
                          iconSize: 26,
                          tooltip: 'Back',
                          background: const Color(0x14FFFFFF),
                          foreground: const Color(0xFFF1F5F9),
                          onPressed: _back,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0x1F2DD4BF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield_outlined, size: 14, color: AppColors.mintLight),
                              const SizedBox(width: 6),
                              Text('Verified access',
                                  style: staffBody(12, weight: FontWeight.w600, color: AppColors.mintLight)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Semantics(
                      header: true,
                      child: Text(title, style: staffHeading(26, color: const Color(0xFFF1F5F9))),
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle, style: staffBody(14, color: const Color(0xFF94A3B8), height: 1.5)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: StaffContent(
                maxWidth: 480,
                child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: body),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared pieces ───

InputDecoration _fieldDecoration(BuildContext context, {String? hint, Widget? suffix}) => staffInputDecoration(
      context,
      hint: hint,
      radius: 16,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );

Widget _footerLink(BuildContext context, String lead, String action, VoidCallback onTap) {
  final p = StaffPalette.of(context);
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Flexible(child: Text(lead, style: staffBody(14, color: p.muted))),
      TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 6)),
        child: Text(action, style: staffBody(14, weight: FontWeight.w700, color: p.accent)),
      ),
    ],
  );
}

// ─── Step 1: Firebase account ───

class _CredentialsStep extends ConsumerStatefulWidget {
  final bool isSignIn;
  final VoidCallback onSwitch;
  const _CredentialsStep({super.key, required this.isSignIn, required this.onSwitch});

  @override
  ConsumerState<_CredentialsStep> createState() => _CredentialsStepState();
}

class _CredentialsStepState extends ConsumerState<_CredentialsStep> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// Surfaces Firebase errors. On success the parent swaps to step 2 and
  /// routes staff with an existing account to the portal.
  void _afterSignIn() {
    final authState = ref.read(authProvider);
    if (authState.status == AuthStatus.error) throw authState.errorMessage ?? 'Sign in failed.';
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      showStaffSnack(context, 'Enter your email and password.');
      return;
    }
    if (!widget.isSignIn && pass.length < 8) {
      showStaffSnack(context, 'Use at least 8 characters for your password.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final notifier = ref.read(authProvider.notifier);
      if (widget.isSignIn) {
        await notifier.signInWithEmail(email, pass);
      } else {
        await notifier.signUpWithEmail(email, pass);
      }
      _afterSignIn();
    } catch (e) {
      if (mounted) showStaffSnack(context, e is String ? e : apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).linkGoogleAccount();
      _afterSignIn();
    } catch (e) {
      if (mounted) showStaffSnack(context, e is String ? e : apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      showStaffSnack(context, 'Enter your work email first, then tap "Forgot password?".');
      return;
    }
    if (Firebase.apps.isEmpty) {
      showStaffSnack(context, 'Password reset is unavailable right now.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) showStaffSnack(context, 'Reset link sent to $email.');
    } on FirebaseAuthException catch (e) {
      if (mounted) showStaffSnack(context, e.message ?? 'Could not send reset link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StaffField(
          label: 'Work email',
          child: TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            style: staffBody(15, color: p.ink),
            decoration: _fieldDecoration(context, hint: 'name@hospital.org'),
          ),
        ),
        const SizedBox(height: 16),
        StaffField(
          label: widget.isSignIn ? 'Password' : 'Create password',
          helper: widget.isSignIn
              ? null
              : ListenableBuilder(
                  listenable: _passCtrl,
                  builder: (context, _) => _StrengthMeter(password: _passCtrl.text),
                ),
          child: TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            autofillHints: [widget.isSignIn ? AutofillHints.password : AutofillHints.newPassword],
            onSubmitted: (_) => _submit(),
            style: staffBody(15, color: p.ink),
            decoration: _fieldDecoration(
              context,
              suffix: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: p.muted, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ),
        if (widget.isSignIn)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _resetPassword,
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: Text('Forgot password?', style: staffBody(13, weight: FontWeight.w600, color: p.accent)),
            ),
          )
        else
          const SizedBox(height: 20),
        const SizedBox(height: 8),
        StaffButton(widget.isSignIn ? 'Sign in' : 'Create account',
            height: 56, radius: 16, fontSize: 16, loading: _isLoading, onPressed: _submit),
        const SizedBox(height: 12),
        StaffButton('Continue with Google',
            kind: StaffButtonKind.secondary,
            icon: Icons.account_circle_outlined,
            height: 52,
            radius: 16,
            onPressed: _isLoading ? null : _google),
        const SizedBox(height: 12),
        widget.isSignIn
            ? _footerLink(context, 'New to VitaNet?', 'Request access', widget.onSwitch)
            : _footerLink(context, 'Already have an account?', 'Sign in', widget.onSwitch),
        const SizedBox(height: 8),
        _footerLink(context, 'Personal user?', 'Go to Patient login', () => context.go('/login/patient')),
      ],
    );
  }
}

// ─── Step 2: staff request ───

class _StaffDetailsStep extends ConsumerStatefulWidget {
  final String? notice;
  const _StaffDetailsStep({this.notice});

  @override
  ConsumerState<_StaffDetailsStep> createState() => _StaffDetailsStepState();
}

class _StaffDetailsStepState extends ConsumerState<_StaffDetailsStep> {
  final _nameController = TextEditingController(
    text: Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser?.displayName,
  );
  final _departmentController = TextEditingController();
  final _licenseController = TextEditingController();
  StaffRole _role = StaffRole.doctor;
  Facility? _hospital;
  bool _newHospital = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _departmentController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _pickHospital() async {
    final result = await showStaffSheet<Object>(context, tall: true, builder: (_) => const _HospitalPickerSheet());
    if (!mounted || result == null) return;
    setState(() {
      if (result is Facility) {
        _hospital = result;
        _newHospital = false;
      } else {
        _hospital = null;
        _newHospital = true;
        _role = StaffRole.admin;
      }
    });
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      showStaffSnack(context, 'Enter your full name.');
      return;
    }
    if (_hospital == null && !_newHospital) {
      showStaffSnack(context, 'Choose the hospital you work at.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;
      if (user != null && (user.displayName ?? '').isEmpty) {
        try {
          await user.updateDisplayName(name);
        } catch (_) {}
      }
      await ref.read(hospitalApiProvider).registerStaff(
            fullName: name,
            role: _role,
            hospitalId: _newHospital ? null : _hospital!.id,
            department: _departmentController.text.trim(),
            licenseNumber: _licenseController.text.trim(),
          );
      ref.invalidate(staffAccessProvider);
      await ref.read(staffAccessProvider.future);
      if (mounted) context.go('/admin');
    } catch (e) {
      if (mounted) showStaffSnack(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final email = Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser?.email;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.notice != null) ...[
          StaffCard(
            color: p.tone(StaffTone.amber).bg,
            padding: const EdgeInsets.all(12),
            child: Text(widget.notice!, style: staffBody(13, weight: FontWeight.w600, color: p.tone(StaffTone.amber).fg)),
          ),
          const SizedBox(height: 16),
        ],
        if (email != null) ...[
          Text('Signed in as $email', style: staffBody(13, color: p.muted)),
          const SizedBox(height: 16),
        ],
        const EmailVerificationBanner(),
        StaffField(
          label: 'Full name',
          child: TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            style: staffBody(15, color: p.ink),
            decoration: _fieldDecoration(context, hint: 'Dr. Ama Mensah'),
          ),
        ),
        const SizedBox(height: 16),
        Text('Role', style: staffBody(13, weight: FontWeight.w600, color: p.ink)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < StaffRole.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _roleButton(StaffRole.values[i], p)),
            ],
          ],
        ),
        const SizedBox(height: 16),
        StaffField(
          label: 'Hospital',
          helper: _newHospital
              ? Text(
                  'Only the VitaNet bootstrap administrator can set up a new hospital. '
                  'You will create it on the next screen.',
                  style: staffBody(12, color: p.muted, height: 1.4))
              : null,
          child: Semantics(
            button: true,
            label: 'Choose hospital',
            child: Material(
              color: p.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.line)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _pickHospital,
                child: SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(children: [
                      Icon(Icons.local_hospital_outlined, size: 20, color: p.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _newHospital ? 'Setting up a new hospital' : (_hospital?.name ?? 'Choose your hospital'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: staffBody(15, color: _hospital == null && !_newHospital ? p.faint : p.ink),
                        ),
                      ),
                      Icon(Icons.expand_more_rounded, color: p.muted),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StaffField(
                label: 'Department',
                child: TextField(
                  controller: _departmentController,
                  textCapitalization: TextCapitalization.words,
                  style: staffBody(15, color: p.ink),
                  decoration: _fieldDecoration(context, hint: 'Emergency'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StaffField(
                label: 'License no.',
                child: TextField(
                  controller: _licenseController,
                  textCapitalization: TextCapitalization.characters,
                  style: staffBody(15, color: p.ink),
                  decoration: _fieldDecoration(context, hint: 'MDC/RN/04712'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        StaffButton('Request access', height: 56, radius: 16, fontSize: 16, loading: _isLoading, onPressed: _register),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: Text('Use a different account', style: staffBody(14, weight: FontWeight.w600, color: p.accent)),
          ),
        ),
      ],
    );
  }

  Widget _roleButton(StaffRole role, StaffPalette p) {
    final sel = _role == role;
    final brand = p.tone(StaffTone.brand);
    return Semantics(
      selected: sel,
      button: true,
      child: Material(
        color: sel ? brand.bg : p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: sel ? brand.strong : p.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _role = role),
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                role.label,
                style: staffBody(14, weight: sel ? FontWeight.w700 : FontWeight.w600, color: sel ? brand.fg : p.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marker returned by the picker for "I'm setting up a new hospital".
class _NewHospital {
  const _NewHospital();
}

class _HospitalPickerSheet extends ConsumerStatefulWidget {
  const _HospitalPickerSheet();

  @override
  ConsumerState<_HospitalPickerSheet> createState() => _HospitalPickerSheetState();
}

class _HospitalPickerSheetState extends ConsumerState<_HospitalPickerSheet> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final value = ref.watch(facilitySearchProvider(_q));
    return PortalSheet(
      title: 'Choose your hospital',
      children: [
        StaffSearchField(controller: _search, hint: 'Search hospitals', onChanged: (v) => setState(() => _q = v.trim())),
        const SizedBox(height: 12),
        ...value.when(
          loading: () => const [PortalLoading()],
          error: (e, _) => [PortalError(error: e, onRetry: () => ref.invalidate(facilitySearchProvider(_q)))],
          data: (filtered) {
            return [
              if (filtered.isEmpty)
                PortalEmpty(
                  icon: Icons.search_off_rounded,
                  title: _q.isEmpty ? 'No hospitals registered yet' : 'No hospital matches "$_q"',
                  message: 'Ask your administrator whether your hospital is on VitaNet.',
                )
              else
                StaffGroup(children: [
                  for (final f in filtered)
                    InkWell(
                      onTap: () => Navigator.of(context).pop(f),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.name, style: staffBody(15, weight: FontWeight.w600, color: p.ink)),
                              if ((f.address ?? '').isNotEmpty)
                                Text(f.address!, style: staffBody(12, color: p.muted)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ]),
            ];
          },
        ),
        const SizedBox(height: 12),
        StaffButton("I'm setting up a new hospital",
            kind: StaffButtonKind.secondary,
            icon: Icons.add_business_outlined,
            onPressed: () => Navigator.of(context).pop(const _NewHospital())),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _AlreadyRegistered extends StatelessWidget {
  final StaffAccess access;
  const _AlreadyRegistered({required this.access});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StaffCard(
          child: Text(
            access.kind == StaffAccessKind.pending
                ? 'Your staff request is waiting for approval.'
                : 'You already have a staff account.',
            style: staffBody(15, weight: FontWeight.w600, color: p.ink),
          ),
        ),
        const SizedBox(height: 16),
        StaffButton('Continue to the portal', height: 56, radius: 16, onPressed: () => context.go('/admin')),
      ],
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  final String password;
  const _StrengthMeter({required this.password});

  int get _score {
    if (password.isEmpty) return 0;
    var s = 0;
    if (password.length >= 8) s++;
    if (password.length >= 12) s++;
    if ((RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) ||
        RegExp(r'\d').hasMatch(password)) {
      s++;
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) s++;
    if (s == 0) s = 1;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final score = _score;
    final (label, color, textColor) = switch (score) {
      0 => ('At least 8 characters', p.track, p.muted),
      1 => ('Weak password', const Color(0xFFDC2626), p.tone(StaffTone.danger).fg),
      2 => ('Fair password', const Color(0xFFF59E0B), p.dark ? p.tone(StaffTone.amber).fg : kStaffAmber),
      _ => ('Strong password', const Color(0xFF059669), p.dark ? const Color(0xFF6EE7B7) : kStaffGreen),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < score ? color : p.track,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: staffBody(12, weight: FontWeight.w500, color: textColor)),
        ],
      ),
    );
  }
}
