import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

/// Hospital staff sign-up / sign-in (StaffRegister.dc.html).
class RegistrationFormScreen extends ConsumerStatefulWidget {
  const RegistrationFormScreen({super.key});

  @override
  ConsumerState<RegistrationFormScreen> createState() => _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends ConsumerState<RegistrationFormScreen> {
  bool _isSignIn = false;

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: p.dark ? p.bg : AppColors.pageBg,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Navy header ──
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
                      child: Text(
                        _isSignIn ? 'Clinical staff sign-in' : 'Clinical staff sign-up',
                        style: staffHeading(26, color: const Color(0xFFF1F5F9)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isSignIn
                          ? 'Use the work email your facility administrator approved.'
                          : 'Your facility administrator approves new accounts, usually within one working day.',
                      style: staffBody(14, color: const Color(0xFF94A3B8), height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            // ── Form ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: StaffContent(
                maxWidth: 480,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _isSignIn
                      ? _SignInTab(
                          key: const ValueKey('signin'),
                          onSwitch: () => setState(() => _isSignIn = false),
                        )
                      : _SignUpTab(
                          key: const ValueKey('signup'),
                          onSwitch: () => setState(() => _isSignIn = true),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared pieces ───

InputDecoration _fieldDecoration(BuildContext context, {String? hint, Widget? suffix, Widget? prefix}) =>
    staffInputDecoration(
      context,
      hint: hint,
      radius: 16,
      prefixIcon: prefix,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );

Widget _footerLink(BuildContext context, String lead, String action, VoidCallback onTap) {
  final p = StaffPalette.of(context);
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(lead, style: staffBody(14, color: p.muted)),
      TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 6)),
        child: Text(action, style: staffBody(14, weight: FontWeight.w700, color: p.accent)),
      ),
    ],
  );
}

// ─── Sign In Tab ───

class _SignInTab extends ConsumerStatefulWidget {
  final VoidCallback onSwitch;
  const _SignInTab({super.key, required this.onSwitch});

  @override
  ConsumerState<_SignInTab> createState() => _SignInTabState();
}

class _SignInTabState extends ConsumerState<_SignInTab> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      showStaffSnack(context, 'Please enter both email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signInWithEmail(
            _emailCtrl.text.trim(),
            _passCtrl.text,
          );

      final authState = ref.read(authProvider);
      if (authState.status == AuthStatus.error) {
        throw Exception(authState.errorMessage);
      }

      if (authState.status == AuthStatus.authenticated && authState.user != null) {
        final backendUser = await ref.read(firestoreServiceProvider).getUserProfile(authState.user!.uid);
        if (backendUser != null) {
          final accountType = backendUser.role;

          if (accountType == 'personal_user' || accountType == 'patient' || accountType == 'user') {
            await ref.read(authProvider.notifier).signOut();
            if (mounted) {
              showStaffSnack(context, 'This account belongs to a Personal User. Please use the Patient login.');
              setState(() => _isLoading = false);
            }
            return;
          }

          ref.read(userProfileProvider.notifier).updateProfile(backendUser);
        } else {
          // Fallback if backend fetch fails or no user found
          ref.read(userProfileProvider.notifier).updateProfile(
                UserProfile(name: 'Provider', role: 'admin'),
              );
        }
      }

      if (mounted) context.go('/admin');
    } catch (e) {
      if (mounted) showStaffSnack(context, 'Sign in failed: $e');
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
      showStaffSnack(context, 'Password reset is currently unavailable in offline mode.');
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
            decoration: _fieldDecoration(context, hint: 'k.mensah@korlebu.gov.gh'),
          ),
        ),
        const SizedBox(height: 16),
        StaffField(
          label: 'Password',
          child: TextField(
            controller: _passCtrl,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _signIn(),
            style: staffBody(15, color: p.ink),
            decoration: _fieldDecoration(
              context,
              suffix: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: p.muted, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _resetPassword,
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: Text('Forgot password?', style: staffBody(13, weight: FontWeight.w600, color: p.accent)),
          ),
        ),
        const SizedBox(height: 12),
        StaffButton('Sign in', height: 56, radius: 16, fontSize: 16, loading: _isLoading, onPressed: _signIn),

        const SizedBox(height: 12),
        _footerLink(context, 'New to VitaNet?', 'Request access', widget.onSwitch),
      ],
    );
  }
}

// ─── Sign Up Tab ───

class _SignUpTab extends ConsumerStatefulWidget {
  final VoidCallback onSwitch;
  const _SignUpTab({super.key, required this.onSwitch});

  @override
  ConsumerState<_SignUpTab> createState() => _SignUpTabState();
}

class _SignUpTabState extends ConsumerState<_SignUpTab> {
  static const _roles = ['Doctor', 'Nurse', 'Admin'];
  static const _facilities = [
    'Korle Bu Teaching Hospital',
    'Ridge Hospital',
    'Komfo Anokye Teaching Hospital',
    '37 Military Hospital',
    'Tamale Teaching Hospital',
  ];

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _departmentController = TextEditingController();
  final _licenseController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = _roles.first;
  String _facility = _facilities.first;
  PlatformFile? _staffId;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _departmentController.dispose();
    _licenseController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickStaffId() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() => _staffId = result.files.single);
      }
    } catch (e) {
      if (mounted) showStaffSnack(context, 'Could not open files: $e');
    }
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        _departmentController.text.trim().isEmpty ||
        _licenseController.text.trim().isEmpty) {
      showStaffSnack(context, 'Please fill in all fields.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).signUpWithEmail(email, password);

      final authState = ref.read(authProvider);
      if (authState.status == AuthStatus.error) {
        throw Exception(authState.errorMessage);
      }

      final currentUser =
          Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null;
      if (currentUser != null) {
        try {
          await currentUser.updateDisplayName(name);
        } catch (_) {}
      }

      ref.read(userProfileProvider.notifier).updateProfile(
            UserProfile(name: name, role: _role == 'Admin' ? 'admin' : 'health_worker'),
          );

      if (mounted) context.go('/admin');
    } catch (e) {
      if (mounted) showStaffSnack(context, 'Registration failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StaffField(
          label: 'Full name',
          child: TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            style: staffBody(15, color: p.ink),
            decoration: _fieldDecoration(context, hint: 'Dr. Kwame Mensah'),
          ),
        ),
        const SizedBox(height: 16),
        StaffField(
          label: 'Work email',
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            style: staffBody(15, color: p.ink),
            decoration: _fieldDecoration(context, hint: 'k.mensah@korlebu.gov.gh'),
          ),
        ),
        const SizedBox(height: 16),
        Text('Role', style: staffBody(13, weight: FontWeight.w600, color: p.ink)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < _roles.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _roleButton(_roles[i], p)),
            ],
          ],
        ),
        const SizedBox(height: 16),
        StaffField(
          label: 'Facility',
          child: StaffSelect<String>(
            value: _facility,
            items: _facilities,
            labelOf: (f) => f,
            icon: Icons.local_hospital_outlined,
            height: 52,
            radius: 16,
            onChanged: (f) => setState(() => _facility = f),
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
        const SizedBox(height: 16),
        _IdUploadRow(file: _staffId, onTap: _pickStaffId),
        const SizedBox(height: 16),
        StaffField(
          label: 'Create password',
          helper: ListenableBuilder(
            listenable: _passwordController,
            builder: (context, _) => _StrengthMeter(password: _passwordController.text),
          ),
          child: TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.newPassword],
            style: staffBody(15, color: p.ink),
            decoration: _fieldDecoration(
              context,
              suffix: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: p.muted, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        StaffButton('Request access', height: 56, radius: 16, fontSize: 16, loading: _isLoading, onPressed: _register),
        const SizedBox(height: 12),
        _footerLink(context, 'Already approved?', 'Sign in', widget.onSwitch),
      ],
    );
  }

  Widget _roleButton(String role, StaffPalette p) {
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
                role,
                style: staffBody(14, weight: sel ? FontWeight.w700 : FontWeight.w600, color: sel ? brand.fg : p.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IdUploadRow extends StatelessWidget {
  final PlatformFile? file;
  final VoidCallback onTap;
  const _IdUploadRow({required this.file, required this.onTap});

  String _size(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).ceil()} KB';
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final f = file;
    return Semantics(
      button: true,
      label: f == null ? 'Upload staff ID card' : 'Staff ID card uploaded, ${f.name}. Tap to replace',
      excludeSemantics: true,
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: CustomPaint(
            painter: _DashedBorderPainter(color: p.faint, radius: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.file_upload_outlined, size: 20, color: p.accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Staff ID card', style: staffBody(14, weight: FontWeight.w600, color: p.ink)),
                        const SizedBox(height: 2),
                        Text(
                          f == null ? 'Upload the front · JPG, PNG or PDF' : '${f.name} · ${_size(f.size)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: staffBody(12, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  if (f != null)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(color: Color(0xFF059669), shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(0.5);
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color || old.radius != radius;
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
