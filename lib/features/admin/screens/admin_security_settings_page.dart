import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/staff_ui.dart';

/// Security & access key, in the staff portal visual language.
class AdminSecuritySettingsPage extends StatefulWidget {
  const AdminSecuritySettingsPage({super.key});

  @override
  State<AdminSecuritySettingsPage> createState() => _SecurityAdminSettingsPageState();
}

class _SecurityAdminSettingsPageState extends State<AdminSecuritySettingsPage> {
  bool _biometricAuth = true;
  bool _twoFactorAuth = false;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isUpdatingPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearFields() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  /// Re-authenticates and updates the Firebase password. Returns true on
  /// success.
  Future<bool> _updatePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      showStaffSnack(context, 'New keys do not match.');
      return false;
    }
    if (_newPasswordController.text.length < 8) {
      showStaffSnack(context, 'Use at least 8 characters for your new key.');
      return false;
    }

    try {
      final user = Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null;
      if (user != null && user.email != null) {
        // Re-authenticate user
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );
        await user.reauthenticateWithCredential(cred);

        // Update password
        await user.updatePassword(_newPasswordController.text);

        if (mounted) showStaffSnack(context, 'Access key updated successfully.');
        _clearFields();
        return true;
      }
      if (mounted) showStaffSnack(context, 'Sign in again to change your access key.');
      return false;
    } on FirebaseAuthException catch (e) {
      if (mounted) showStaffSnack(context, e.message ?? 'Authentication failed.');
      return false;
    } catch (e) {
      if (mounted) showStaffSnack(context, 'Error: $e');
      return false;
    }
  }

  void _showSessions() {
    final p = StaffPalette.of(context);
    showStaffSheet<void>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Active sessions', style: staffHeading(20, color: p.ink)),
            const SizedBox(height: 4),
            Text('Devices signed in to the clinical system with your account.',
                style: staffBody(13, color: p.muted)),
            const SizedBox(height: 14),
            const _SessionTile(Icons.smartphone_rounded, 'This device', 'Active now', current: true),
            const SizedBox(height: 8),
            const _SessionTile(Icons.tablet_android_rounded, 'Emergency ward shared tablet', 'Last active 2 h ago'),
            const SizedBox(height: 8),
            const _SessionTile(Icons.desktop_windows_outlined, 'Nurses\' station workstation', 'Last active yesterday'),
            const SizedBox(height: 16),
            StaffButton(
              'Sign out other devices',
              kind: StaffButtonKind.dangerOutline,
              onPressed: () {
                Navigator.pop(ctx);
                showStaffSnack(context, 'Other devices will be signed out within a minute.');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmPurge() {
    final p = StaffPalette.of(context);
    showStaffDialog<void>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Request record purge?', style: staffHeading(20, color: p.ink)),
            const SizedBox(height: 8),
            Text(
              'The records office reviews requests to delete your personal activity logs. Clinical records are kept as required by law.',
              style: staffBody(13, color: p.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: StaffButton('Cancel', kind: StaffButtonKind.secondary, onPressed: () => Navigator.pop(ctx)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StaffButton(
                    'Send request',
                    kind: StaffButtonKind.dangerOutline,
                    onPressed: () {
                      Navigator.pop(ctx);
                      showStaffSnack(context, 'Purge request sent to the records office.');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            StaffContent(
              maxWidth: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StaffPageHeader(
                    title: 'Security & access key',
                    fontSize: 21,
                    onBack: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 16),
                  const StaffSectionLabel('Credential protection'),
                  const SizedBox(height: 8),
                  StaffGroup(
                    children: [
                      StaffNavRow(
                        title: 'Update access key',
                        subtitle: 'Last changed 42 days ago',
                        icon: Icons.key_outlined,
                        iconTone: StaffTone.amber,
                        onTap: () => _showChangePasswordDialog(context),
                      ),
                      StaffSwitchRow(
                        title: 'Biometric verification',
                        subtitle: 'Unlock with fingerprint or face',
                        icon: Icons.fingerprint_rounded,
                        iconTone: StaffTone.brand,
                        value: _biometricAuth,
                        onChanged: (val) => setState(() => _biometricAuth = val),
                      ),
                      StaffSwitchRow(
                        title: 'Multi-factor authentication',
                        subtitle: 'Code by SMS on new devices',
                        icon: Icons.verified_user_outlined,
                        iconTone: StaffTone.indigo,
                        value: _twoFactorAuth,
                        onChanged: (val) => setState(() => _twoFactorAuth = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const StaffSectionLabel('Data privacy'),
                  const SizedBox(height: 8),
                  StaffGroup(
                    children: [
                      StaffNavRow(
                        title: 'Active sessions',
                        subtitle: 'Devices and recent sign-ins',
                        icon: Icons.devices_outlined,
                        iconTone: StaffTone.sky,
                        onTap: _showSessions,
                      ),
                      StaffNavRow(
                        title: 'Purge activity records',
                        subtitle: 'Request deletion of your access logs',
                        icon: Icons.delete_outline_rounded,
                        iconTone: StaffTone.danger,
                        onTap: _confirmPurge,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Access key dialog (AccessKey.dc.html) ───

  void _showChangePasswordDialog(BuildContext context) {
    showStaffDialog<void>(
      context,
      barrierDismissible: !_isUpdatingPassword,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          final p = StaffPalette.of(dialogContext);
          final amber = p.tone(StaffTone.amber);
          final newKey = _newPasswordController.text;
          final longEnough = newKey.length >= 8;
          final confirm = _confirmPasswordController.text;
          final mismatch = confirm.isNotEmpty && confirm != newKey;

          Widget keyField(TextEditingController c, IconData icon, {bool autofocus = false}) => TextField(
                controller: c,
                autofocus: autofocus,
                obscureText: true,
                enabled: !_isUpdatingPassword,
                onChanged: (_) => setStateDialog(() {}),
                style: staffBody(15, color: p.ink, letterSpacing: 4),
                decoration: staffInputDecoration(dialogContext, prefixIcon: Icon(icon, size: 20)),
              );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: amber.bg, borderRadius: BorderRadius.circular(16)),
                    child: Icon(Icons.vpn_key_outlined, size: 26, color: p.dark ? amber.fg : kStaffAmber),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Update access key', style: staffHeading(20, color: p.ink)),
                const SizedBox(height: 14),
                Text(
                  'Your key unlocks patient records on shared ward devices. You\'ll be signed out of other devices.',
                  style: staffBody(13, color: p.inkSoft, height: 1.5),
                ),
                const SizedBox(height: 14),
                StaffField(
                  label: 'Current key',
                  child: keyField(_currentPasswordController, Icons.lock_outline_rounded, autofocus: true),
                ),
                const SizedBox(height: 14),
                StaffField(
                  label: 'New key',
                  helper: Row(
                    children: [
                      Icon(
                        longEnough ? Icons.check_rounded : Icons.info_outline_rounded,
                        size: 14,
                        color: longEnough ? (p.dark ? const Color(0xFF6EE7B7) : kStaffGreen) : p.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'At least 8 characters',
                        style: staffBody(12,
                            weight: FontWeight.w500,
                            color: longEnough ? (p.dark ? const Color(0xFF6EE7B7) : kStaffGreen) : p.muted),
                      ),
                    ],
                  ),
                  child: keyField(_newPasswordController, Icons.vpn_key_outlined),
                ),
                const SizedBox(height: 14),
                StaffField(
                  label: 'Confirm new key',
                  helper: mismatch
                      ? Text('Keys do not match',
                          style: staffBody(12, weight: FontWeight.w500, color: p.tone(StaffTone.danger).fg))
                      : null,
                  child: keyField(_confirmPasswordController, Icons.check_rounded),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: StaffButton(
                        'Cancel',
                        kind: StaffButtonKind.secondary,
                        onPressed: _isUpdatingPassword
                            ? null
                            : () {
                                _clearFields();
                                Navigator.pop(dialogContext);
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StaffButton(
                        'Update key',
                        loading: _isUpdatingPassword,
                        onPressed: () async {
                          setStateDialog(() => _isUpdatingPassword = true);
                          final ok = await _updatePassword();
                          if (!mounted) return;
                          setState(() => _isUpdatingPassword = false);
                          if (ok && dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          } else if (dialogContext.mounted) {
                            setStateDialog(() {});
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final bool current;
  const _SessionTile(this.icon, this.title, this.sub, {this.current = false});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, size: 22, color: p.inkSoft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: staffBody(14, weight: FontWeight.w600, color: p.ink)),
                Text(sub, style: staffBody(12, color: p.muted)),
              ],
            ),
          ),
          if (current) const StaffTag('This device', tone: StaffTone.green),
        ],
      ),
    );
  }
}
