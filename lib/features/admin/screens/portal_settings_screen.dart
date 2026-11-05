import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/screens/hospital_form_screen.dart';
import 'package:vitanet/features/admin/screens/portal_gate_screen.dart';
import 'package:vitanet/features/admin/screens/portal_shell.dart';
import 'package:vitanet/features/admin/widgets/portal_common.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

/// Settings: profile, facility profile (admin edit), audit log (admin),
/// notification preferences, password, sign out.
class PortalSettingsScreen extends ConsumerWidget {
  final VoidCallback? onBack;
  const PortalSettingsScreen({super.key, this.onBack});

  Future<void> _toggleAccepting(BuildContext context, WidgetRef ref, Facility f, bool v) async {
    final r = await runPortalAction(
      context,
      () => ref.read(hospitalApiProvider).updateHospital(Facility(
            name: f.name,
            address: f.address,
            latitude: f.latitude,
            longitude: f.longitude,
            phoneNumber: f.phoneNumber,
            hasEmergencyRoom: f.hasEmergencyRoom,
            hasAmbulance: f.hasAmbulance,
            ambulanceAvailable: f.ambulanceAvailable,
            acceptingReferrals: v,
          )),
      success: v ? 'Now accepting VitaNet referrals.' : 'Referrals paused.',
    );
    if (r != null) ref.invalidate(myHospitalProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = StaffPalette.of(context);
    final me = ref.watch(portalMeProvider);
    final hospital = ref.watch(myHospitalProvider);
    final isAdmin = me?.isAdmin ?? false;

    return Column(
      children: [
        PortalHeader(title: 'Settings', onBack: onBack),
        Expanded(
          child: RefreshIndicator(
            color: p.accent,
            onRefresh: () => ref.refresh(myHospitalProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                StaffContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PortalSectionTitle('Profile'),
                      if (me != null)
                        StaffCard(
                          child: Column(children: [
                            Row(children: [
                              StaffInitialsAvatar(initialsOf(me.fullName), tone: StaffTone.brand, size: 48, fontSize: 16),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(me.fullName, style: staffHeading(17, weight: FontWeight.w700, color: p.ink)),
                                  Text(me.email ?? '', style: staffBody(13, color: p.muted)),
                                ]),
                              ),
                              IconButton(
                                tooltip: 'Edit profile',
                                icon: Icon(Icons.edit_outlined, color: p.accent),
                                onPressed: () => showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => _EditProfileSheet(me: me),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            InfoRow('Role', me.role.label),
                            InfoRow('Department', me.department ?? ''),
                            InfoRow('License no.', me.licenseNumber ?? ''),
                          ]),
                        ),
                      const PortalSectionTitle('Facility'),
                      hospital.when(
                        loading: () => const StaffCard(child: PortalLoading()),
                        error: (e, _) =>
                            StaffCard(child: PortalError(error: e, onRetry: () => ref.invalidate(myHospitalProvider))),
                        data: (f) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            StaffCard(
                              child: Column(children: [
                                InfoRow('Name', f.name),
                                InfoRow('Address', f.address ?? ''),
                                InfoRow('Phone', f.phoneNumber ?? ''),
                                InfoRow('Location',
                                    '${f.latitude.toStringAsFixed(5)}, ${f.longitude.toStringAsFixed(5)}'),
                                InfoRow('Emergency room', f.hasEmergencyRoom ? 'Yes' : 'No'),
                                InfoRow('Ambulance',
                                    f.hasAmbulance ? (f.ambulanceAvailable ? 'Available now' : 'Not available now') : 'No'),
                              ]),
                            ),
                            const SizedBox(height: 10),
                            if (isAdmin)
                              StaffGroup(children: [
                                StaffSwitchRow(
                                  title: 'Accepting VitaNet referrals',
                                  subtitle: 'Patients can send their summary to this hospital',
                                  icon: Icons.move_to_inbox_outlined,
                                  value: f.acceptingReferrals,
                                  onChanged: (v) => _toggleAccepting(context, ref, f, v),
                                ),
                                StaffNavRow(
                                  title: 'Edit facility profile',
                                  subtitle: 'Name, address, map location, ER and ambulance',
                                  icon: Icons.edit_location_alt_outlined,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => HospitalFormScreen(initial: f)),
                                  ),
                                ),
                                StaffNavRow(
                                  title: 'Audit log',
                                  subtitle: 'Who did what, and when',
                                  icon: Icons.history_rounded,
                                  iconTone: StaffTone.indigo,
                                  onTap: () => Navigator.of(context)
                                      .push(MaterialPageRoute(builder: (_) => const AuditLogScreen())),
                                ),
                              ])
                            else
                              Text(
                                f.acceptingReferrals
                                    ? 'This hospital is accepting VitaNet referrals.'
                                    : 'This hospital is not accepting VitaNet referrals right now.',
                                style: staffBody(13, color: p.muted),
                              ),
                          ],
                        ),
                      ),
                      const PortalSectionTitle('Notifications'),
                      const _NotificationPrefs(),
                      const PortalSectionTitle('Account'),
                      StaffGroup(children: [
                        StaffNavRow(
                          title: 'Change password',
                          icon: Icons.lock_outline_rounded,
                          iconTone: StaffTone.amber,
                          onTap: () => showStaffSheet<void>(context, builder: (_) => const ChangePasswordSheet()),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      StaffButton('Sign out',
                          kind: StaffButtonKind.dangerOutline,
                          icon: Icons.logout_rounded,
                          onPressed: () => confirmAndSignOut(context, ref)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  final StaffMe me;
  const _EditProfileSheet({required this.me});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final _name = TextEditingController(text: widget.me.fullName);
  late final _dept = TextEditingController(text: widget.me.department ?? '');
  late final _licence = TextEditingController(text: widget.me.licenseNumber ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _dept.dispose();
    _licence.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      showStaffSnack(context, 'Enter your full name.');
      return;
    }
    setState(() => _saving = true);
    final ok = await runPortalAction<bool>(context, () async {
      await ref.read(hospitalApiProvider).updateMyProfile(
            fullName: _name.text.trim(),
            department: _dept.text.trim().isEmpty ? null : _dept.text.trim(),
            licenseNumber: _licence.text.trim().isEmpty ? null : _licence.text.trim(),
          );
      return true;
    }, success: 'Profile updated.');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == true) {
      ref.invalidate(staffAccessProvider);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: p.card,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: PortalSheet(
        title: 'Edit profile',
        subtitle: 'Your role and approval can only be changed by an administrator.',
        actions: [
          StaffButton('Save', onPressed: _saving ? null : _save),
        ],
        children: [
          StaffField(label: 'Full name', child: TextField(controller: _name, decoration: deco('Dr. Ama Mensah'))),
          const SizedBox(height: 12),
          StaffField(label: 'Department', child: TextField(controller: _dept, decoration: deco('Emergency'))),
          const SizedBox(height: 12),
          StaffField(label: 'License no.', child: TextField(controller: _licence, decoration: deco('MDC/RN/04712'))),
        ],
      ),
    );
  }
}

class _NotificationPrefs extends StatefulWidget {
  const _NotificationPrefs();

  @override
  State<_NotificationPrefs> createState() => _NotificationPrefsState();
}

class _NotificationPrefsState extends State<_NotificationPrefs> {
  static const _keys = {
    'portal_notify_urgent': ('Urgent referrals', 'Alert me when an urgent referral arrives'),
    'portal_notify_cases': ('My cases', 'Changes to cases assigned to me'),
    'portal_notify_staff': ('Staff requests', 'New sign-up requests (admins)'),
  };
  final Map<String, bool> _values = {for (final k in _keys.keys) k: true};
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        for (final k in _keys.keys) {
          _values[k] = prefs.getBool(k) ?? true;
        }
      });
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StaffGroup(children: [
          for (final e in _keys.entries)
            StaffSwitchRow(
              title: e.value.$1,
              subtitle: e.value.$2,
              value: _values[e.key] ?? true,
              onChanged: (v) {
                setState(() => _values[e.key] = v);
                _prefs?.setBool(e.key, v);
              },
            ),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 6),
          child: Text('Saved on this device.', style: staffBody(12, color: StaffPalette.of(context).muted)),
        ),
      ],
    );
  }
}

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  User? get _user => Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;

  bool get _hasPassword => _user?.providerData.any((p) => p.providerId == 'password') ?? false;

  Future<void> _save() async {
    final user = _user;
    if (user == null || user.email == null) return;
    if (_next.text.length < 8) {
      showStaffSnack(context, 'Use at least 8 characters for the new password.');
      return;
    }
    setState(() => _saving = true);
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: _current.text),
      );
      await user.updatePassword(_next.text);
      if (mounted) {
        Navigator.of(context).pop();
        showStaffSnack(context, 'Password changed.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showStaffSnack(
          context,
          e.code == 'wrong-password' || e.code == 'invalid-credential'
              ? 'Your current password is incorrect.'
              : (e.message ?? 'Could not change password.'),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label) => StaffField(
        label: label,
        child: TextField(
          controller: c,
          obscureText: true,
          style: staffBody(15, color: StaffPalette.of(context).ink),
          decoration: staffInputDecoration(context),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!_hasPassword) {
      return PortalSheet(
        title: 'Change password',
        actions: [StaffButton('Close', kind: StaffButtonKind.secondary, onPressed: () => Navigator.of(context).pop())],
        children: [
          Text('You sign in with Google, so your password is managed by your Google account.',
              style: staffBody(14, color: StaffPalette.of(context).inkSoft, height: 1.5)),
        ],
      );
    }
    return PortalSheet(
      title: 'Change password',
      actions: [
        StaffButton('Cancel', kind: StaffButtonKind.secondary, onPressed: () => Navigator.of(context).pop()),
        StaffButton('Change', loading: _saving, onPressed: _save),
      ],
      children: [
        _field(_current, 'Current password'),
        const SizedBox(height: 14),
        _field(_next, 'New password'),
      ],
    );
  }
}

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = StaffPalette.of(context);
    final value = ref.watch(auditProvider);
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          PortalHeader(title: 'Audit log', subtitle: 'Most recent first', onBack: () => Navigator.of(context).pop()),
          Expanded(
            child: PortalAsyncList<List<AuditEntry>>(
              value: value,
              onRefresh: () => ref.refresh(auditProvider.future),
              builder: (list) => list.isEmpty
                  ? const [PortalEmpty(icon: Icons.history_rounded, title: 'No activity recorded yet')]
                  : [
                      StaffGroup(children: [
                        for (final a in list)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(a.action,
                                        style: staffBody(14, weight: FontWeight.w700, color: p.ink)),
                                  ),
                                  Text(relativeTime(a.at), style: staffBody(12, color: p.muted)),
                                ]),
                                const SizedBox(height: 2),
                                Text(
                                  [a.actor ?? 'Unknown', if ((a.detail ?? '').isNotEmpty) a.detail!]
                                      .join(' · '),
                                  style: staffBody(13, color: p.body),
                                ),
                              ],
                            ),
                          ),
                      ]),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}
