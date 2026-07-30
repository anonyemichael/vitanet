import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vitanet/shared/widgets/gradient_background.dart';

class RegistrationFormScreen extends ConsumerStatefulWidget {
  const RegistrationFormScreen({super.key});

  @override
  ConsumerState<RegistrationFormScreen> createState() => _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends ConsumerState<RegistrationFormScreen> {
  bool _isSignIn = true;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 800;

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 54,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isSignIn = true),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isSignIn ? context.colorScheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl - 4),
                      boxShadow: _isSignIn ? [
                        BoxShadow(
                          color: context.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ] : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: _isSignIn ? context.colorScheme.onPrimary : context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isSignIn = false),
                  child: Container(
                    decoration: BoxDecoration(
                      color: !_isSignIn ? context.colorScheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl - 4),
                      boxShadow: !_isSignIn ? [
                        BoxShadow(
                          color: context.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ] : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: !_isSignIn ? context.colorScheme.onPrimary : context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideY(begin: 0.2, curve: Curves.easeOut),
        const SizedBox(height: AppSpacing.xxl),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _isSignIn 
              ? const _SignInTab(key: ValueKey('signin')) 
              : const _SignUpTab(key: ValueKey('signup')),
        ),
      ],
    );

    if (isWide) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: GradientBackground(
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ShaderMask(
                      shaderCallback: (rect) {
                        return LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black,
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.7, 1.0],
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.dstIn,
                      child: Image.asset(
                        'assets/images/staff_login.jpg',
                        fit: BoxFit.cover,
                        height: double.infinity,
                        alignment: Alignment.centerLeft,
                        errorBuilder: (c, e, s) => Container(color: context.colorScheme.primaryContainer),
                      ),
                    ),
                    Positioned(
                      left: AppSpacing.xxl * 2,
                      bottom: AppSpacing.xxl * 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: context.colorScheme.primaryContainer.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.health_and_safety_rounded, color: context.colorScheme.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'FOR PROVIDERS',
                                  style: context.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: context.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideX(begin: -0.1),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Empowering\nHealthcare.',
                            style: context.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            ),
                          ).animate().fadeIn(duration: 600.ms, delay: 300.ms).slideX(begin: -0.1),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Manage triage, view patient history, and\nprovide better care with AI-driven insights.',
                            style: context.textTheme.titleLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w400,
                            ),
                          ).animate().fadeIn(duration: 600.ms, delay: 400.ms).slideX(begin: -0.1),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480, maxHeight: 800),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                      child: content,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.sizeOf(context).height * 0.45,
            child: ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black,
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: Image.asset(
                'assets/images/staff_login.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (c, e, s) => Container(color: context.colorScheme.primaryContainer),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.sizeOf(context).height * 0.12,
            left: AppSpacing.xxl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'FOR PROVIDERS',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2),
              ],
            ),
          ),
          Positioned.fill(
            top: MediaQuery.sizeOf(context).height * 0.28,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? const Color(0xFF061017).withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: content,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 500.ms, curve: Curves.easeOut).slideY(begin: 0.1, curve: Curves.easeOut),
          ),
        ],
      ),
    );
  }
}

// ─── Sign In Tab ───

class _SignInTab extends ConsumerStatefulWidget {
  const _SignInTab({super.key});

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
      context.showSnack('Please enter both email and password.');
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

      if (authState.user != null) {
        final backendUser = await ref.read(apiServiceProvider).getUserByFirebaseUid(authState.user!.uid);
        if (backendUser != null) {
          // The backend returns user details under 'full_name' and 'account_type'.
          final accountType = backendUser['account_type'];
          final role = (accountType == 'healthcare_professional' || accountType == 'admin') ? 'admin' : 'user';
          ref.read(userProfileProvider.notifier).updateProfile(
            UserProfile(name: backendUser['full_name'] ?? 'Provider', role: role),
          );
        } else {
          // Fallback if backend fetch fails or no user found
          ref.read(userProfileProvider.notifier).updateProfile(
            UserProfile(name: 'Provider', role: 'admin'),
          );
        }
      }

      if (mounted) context.go('/admin');
    } catch (e) {
      if (mounted) context.showSnack('Sign In failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          _buildTextField(
            context: context,
            controller: _emailCtrl,
            label: 'Hospital Email',
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
          const SizedBox(height: AppSpacing.lg),
          _buildTextField(
            context: context,
            controller: _passCtrl,
            label: 'Password',
            icon: Icons.lock_rounded,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: context.colorScheme.onSurfaceVariant),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                context.showSnack('Password reset not implemented yet.');
              },
              child: const Text('Forgot Password?', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: AppSpacing.xl),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            FilledButton(
              onPressed: _signIn,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 4,
                shadowColor: context.colorScheme.primary.withValues(alpha: 0.4),
              ),
              child: const Text('Sign In Securely', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.95, 0.95)),
        ],
      ),
    );
  }
}

// ─── Sign Up Tab ───

class _SignUpTab extends ConsumerStatefulWidget {
  const _SignUpTab({super.key});

  @override
  ConsumerState<_SignUpTab> createState() => _SignUpTabState();
}

class _SignUpTabState extends ConsumerState<_SignUpTab> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      context.showSnack('Please fill in all fields.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).signUpWithEmail(email, password);
      
      final authState = ref.read(authProvider);
      if (authState.status == AuthStatus.error) {
        throw Exception(authState.errorMessage);
      }
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Firebase failed to return user.');

      ref.read(userProfileProvider.notifier).updateProfile(
        UserProfile(name: name, role: 'health_worker'),
      );

      final payload = {
        "user": {
          "account_type": "healthcare_professional",
          "full_name": name,
          "email": email,
          "phone_number": phone,
          "firebase_uid": currentUser.uid,
        },
        "care_circle": [],
      };

      await ref.read(apiServiceProvider).registerUser(payload);

      if (mounted) context.go('/admin');
    } catch (e) {
      if (mounted) context.showSnack('Registration failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          _buildTextField(
            context: context,
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person_rounded,
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
          const SizedBox(height: AppSpacing.md),
          _buildTextField(
            context: context,
            controller: _emailController,
            label: 'Hospital Email',
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
          const SizedBox(height: AppSpacing.md),
          _buildTextField(
            context: context,
            controller: _phoneController,
            label: 'Phone Number',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
          const SizedBox(height: AppSpacing.md),
          _buildTextField(
            context: context,
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_rounded,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: context.colorScheme.onSurfaceVariant),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),
          const SizedBox(height: AppSpacing.xl),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            FilledButton(
              onPressed: _register,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 4,
                shadowColor: context.colorScheme.primary.withValues(alpha: 0.4),
              ),
              child: const Text('Create Provider Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ).animate().fadeIn(delay: 350.ms).scale(begin: const Offset(0.95, 0.95)),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

// ─── Helpers ───

Widget _buildTextField({
  required BuildContext context,
  required TextEditingController controller,
  required String label,
  required IconData icon,
  bool obscureText = false,
  TextInputType? keyboardType,
  Widget? suffixIcon,
}) {
  return TextField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    style: const TextStyle(fontWeight: FontWeight.w600),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: context.colorScheme.primary),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
  );
}
