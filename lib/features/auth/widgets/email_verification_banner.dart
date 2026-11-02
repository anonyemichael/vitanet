import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

/// Shown to email/password users whose address isn't verified yet. Hospital
/// administrators must verify before the backend recognises them.
class EmailVerificationBanner extends ConsumerStatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  ConsumerState<EmailVerificationBanner> createState() => _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends ConsumerState<EmailVerificationBanner> {
  bool _busy = false;
  String? _message;

  User? get _user => Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;

  bool get _needsVerification {
    final u = _user;
    if (u == null || u.isAnonymous || u.emailVerified) return false;
    return u.providerData.any((p) => p.providerId == 'password');
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      await _user?.sendEmailVerification();
      _message = 'Verification email sent to ${_user?.email}.';
    } on FirebaseAuthException catch (e) {
      _message = e.code == 'too-many-requests'
          ? 'Please wait a minute before requesting another email.'
          : 'Could not send the email (${e.code}).';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkVerified() async {
    setState(() => _busy = true);
    try {
      await _user?.reload();
      final refreshed = Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;
      if (refreshed?.emailVerified ?? false) {
        // Force a new ID token so the backend sees email_verified = true.
        await refreshed!.getIdToken(true);
        ref.invalidate(staffAccessProvider);
        _message = null;
      } else {
        _message = "Not verified yet. Open the link in the email, then tap \"I've verified\".";
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_needsVerification) return const SizedBox.shrink();
    final p = StaffPalette.of(context);
    final tone = p.tone(StaffTone.amber);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: StaffCard(
        color: tone.bg,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verify your email', style: staffBody(14, weight: FontWeight.w700, color: tone.fg)),
            const SizedBox(height: 4),
            Text(
              'We sent a link to ${_user?.email}. Hospital administrators must verify '
              'their email before they can set up a hospital.',
              style: staffBody(13, color: tone.fg),
            ),
            if (_message != null) ...[
              const SizedBox(height: 6),
              Text(_message!, style: staffBody(12, weight: FontWeight.w600, color: tone.fg)),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              StaffButton("I've verified", onPressed: _busy ? null : _checkVerified),
              StaffButton('Resend email', kind: StaffButtonKind.secondary, onPressed: _busy ? null : _resend),
            ]),
          ],
        ),
      ),
    );
  }
}
