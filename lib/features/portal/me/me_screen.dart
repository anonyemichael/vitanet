import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/portal/data/portal_live.dart';
import 'package:vitanet/features/portal/data/portal_models.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
import 'package:vitanet/features/portal/ui/clinical_ui.dart';

/// Profile, shift, this device's settings, switching to the personal app and
/// signing out with a handover.
class MeScreen extends ConsumerWidget {
  /// Opens another destination (1 = Patients).
  final ValueChanged<int> onOpenTab;
  const MeScreen({super.key, required this.onOpenTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ClinicalPalette.of(context);
    final me = ref.watch(staffAccessProvider).valueOrNull?.me;
    final dash = ref.watch(dashboardProvider).valueOrNull;
    final announce = ref.watch(announceNewPatientsProvider);
    final theme = ref.watch(themeModeProvider);
    if (me == null) return const CLoading();
    final verified = me.status == StaffStatus.approved && (me.licenseNumber ?? '').isNotEmpty;
    final onDuty = dash?.onDuty ?? me.onDuty;
    final myPatients = dash?.myCases.where((c) => c.isActive).length ?? 0;

    Widget rowLink(String title, VoidCallback onTap, {Widget? trailing, Color? color, bool last = false}) => Column(
          children: [
            InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(children: [
                    Expanded(child: Text(title, style: cText(15, weight: FontWeight.w500, color: color ?? p.ink))),
                    trailing ?? Icon(Icons.chevron_right_rounded, color: p.faint),
                  ]),
                ),
              ),
            ),
            if (!last) Divider(height: 1, color: p.divider),
          ],
        );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text('Me', style: cText(26, weight: FontWeight.w700, color: p.ink, letterSpacing: -0.2)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: p.navy, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: p.navyRaised, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(initialsOf(me.fullName), style: cText(18, weight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(me.fullName, style: cText(18, weight: FontWeight.w700, color: Colors.white)),
                    Text([me.role.label, if ((me.department ?? '').isNotEmpty) me.department!].join(' · '),
                        style: cText(13, color: p.navyMuted)),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Licence '),
                        TextSpan(
                          text: (me.licenseNumber ?? '').isEmpty ? 'not added' : me.licenseNumber,
                          style: cMono(12, color: Colors.white),
                        ),
                        if (verified) const TextSpan(text: ' · Approved', style: TextStyle(color: Color(0xFF86EFAC))),
                      ]),
                      style: cText(12, color: p.navyMuted),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            CCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                rowLink(onDuty ? "You're on shift" : "You're off shift", () => _setDuty(context, ref, !onDuty),
                    trailing: IgnorePointer(child: CSwitch(value: onDuty, onChanged: (_) {}))),
                rowLink('My patients', () => onOpenTab(1),
                    last: true,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('$myPatients', style: cMono(14, color: p.ink)),
                      Icon(Icons.chevron_right_rounded, color: p.faint),
                    ])),
              ]),
            ),
            const SizedBox(height: 12),
            CCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Announce new patients aloud', style: cText(15, weight: FontWeight.w500, color: p.ink)),
                        Text('Speaks urgent arrivals on this device while the portal is open',
                            style: cText(12, color: p.muted)),
                      ]),
                    ),
                    CSwitch(
                      value: announce,
                      activeColor: p.primary,
                      onChanged: (v) {
                        ref.read(announceNewPatientsProvider.notifier).set(v);
                        if (v) ref.read(announcerProvider).say('New patient announcements are on.');
                      },
                    ),
                  ]),
                ),
                Divider(height: 1, color: p.divider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: Row(children: [
                    Expanded(child: Text('Appearance', style: cText(15, weight: FontWeight.w500, color: p.ink))),
                    SizedBox(
                      width: 210,
                      child: CSegmented(
                        height: 32,
                        labels: const ['System', 'Light', 'Dark'],
                        selected: switch (theme) {
                          ThemeMode.light => 1,
                          ThemeMode.dark => 2,
                          _ => 0,
                        },
                        onChanged: (i) => ref
                            .read(themeModeProvider.notifier)
                            .setTheme(const [ThemeMode.system, ThemeMode.light, ThemeMode.dark][i]),
                      ),
                    ),
                  ]),
                ),
                Divider(height: 1, color: p.divider),
                rowLink('Edit profile & licence', () => showCSheet<void>(context, builder: (_) => ProfileSheet(me: me))),
                rowLink('Change password', () => _resetPassword(context), last: true),
              ]),
            ),
            const SizedBox(height: 12),
            CCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                rowLink('Open my personal VitaNet', () {
                  ref.read(activeWorkspaceProvider.notifier).setWorkspace(AppWorkspace.personal);
                  context.go('/home');
                }, trailing: Icon(Icons.north_east_rounded, size: 18, color: p.faint)),
                rowLink('End shift & sign out', () => endShiftAndSignOut(context, ref),
                    color: p.tone(Tone.red).fg, last: true, trailing: const SizedBox.shrink()),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _setDuty(BuildContext context, WidgetRef ref, bool on) async {
    final res = await runCAction(context, () => ref.read(hospitalApiProvider).setDuty(on),
        success: on ? "You're on shift." : "You're off shift.");
    if (res != null) {
      ref.invalidate(dashboardProvider);
      ref.invalidate(capacityProvider);
    }
  }

  static Future<void> _resetPassword(BuildContext context) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      showCSnack(context, 'This account signs in without a password.');
      return;
    }
    final ok = await confirmC(context,
        title: 'Change password?',
        message: "We'll email a secure link to $email. Open it on any device to choose a new password.",
        confirm: 'Send link');
    if (!ok || !context.mounted) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) showCSnack(context, 'Link sent to $email.');
    } catch (_) {
      if (context.mounted) showCSnack(context, "Couldn't send the link. Try again in a moment.");
    }
  }
}

class ProfileSheet extends ConsumerStatefulWidget {
  final StaffMe me;
  const ProfileSheet({super.key, required this.me});

  @override
  ConsumerState<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<ProfileSheet> {
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
      showCSnack(context, 'Add your name.');
      return;
    }
    setState(() => _saving = true);
    final ok = await runCAction(context, () async {
      await ref.read(hospitalApiProvider).updateMyProfile(
            fullName: _name.text.trim(),
            department: _dept.text.trim().isEmpty ? null : _dept.text.trim(),
            licenseNumber: _licence.text.trim().isEmpty ? null : _licence.text.trim(),
          );
      return true;
    }, success: 'Profile saved.');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == true) {
      ref.invalidate(staffAccessProvider);
      ref.invalidate(dashboardProvider);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => CSheet(
        title: 'Your profile',
        subtitle: 'Your role is set by your hospital admin.',
        gap: 14,
        actions: [CButton('Save', loading: _saving, onPressed: _save)],
        children: [
          CTextField(controller: _name, label: 'Full name', capitalization: TextCapitalization.words),
          CTextField(controller: _dept, label: 'Department', hint: 'e.g. Emergency'),
          CTextField(controller: _licence, label: 'Licence number', hint: 'e.g. MDC-10932', capitalization: TextCapitalization.characters),
        ],
      );
}

/// Ends the shift: offers to hand active patients to someone on shift first,
/// then signs out.
Future<void> endShiftAndSignOut(BuildContext context, WidgetRef ref) async {
  final signOut = await showDialog<bool>(context: context, builder: (_) => const _EndShiftDialog()) ?? false;
  if (!signOut || !context.mounted) return;
  await ref.read(authProvider.notifier).signOut();
  if (context.mounted) context.go('/login');
}

class _EndShiftDialog extends ConsumerStatefulWidget {
  const _EndShiftDialog();

  @override
  ConsumerState<_EndShiftDialog> createState() => _EndShiftDialogState();
}

class _EndShiftDialogState extends ConsumerState<_EndShiftDialog> {
  String? _to;
  bool _saving = false;

  Future<void> _handOver() async {
    if (_to == null) {
      showCSnack(context, 'Choose who takes your patients.');
      return;
    }
    setState(() => _saving = true);
    final n = await runCAction(context, () => ref.read(hospitalApiProvider).handover(_to!));
    if (!mounted) return;
    setState(() => _saving = false);
    if (n != null) {
      invalidatePortalData(ref);
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _offShiftOnly() async {
    await runCAction(context, () => ref.read(hospitalApiProvider).setDuty(false));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final me = ref.watch(staffAccessProvider).valueOrNull?.me;
    final mine = (ref.watch(dashboardProvider).valueOrNull?.myCases ?? const <PortalCase>[]).where((c) => c.isActive).toList();
    final colleagues = (ref.watch(capacityProvider).valueOrNull?.team ?? const <TeamMember>[])
        .where((m) => m.onDuty && m.firebaseUid != me?.firebaseUid)
        .toList()
      ..sort((a, b) => a.activeCases.compareTo(b.activeCases));
    _to ??= colleagues.firstOrNull?.firebaseUid;

    return Dialog(
      backgroundColor: p.card,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('End your shift?', style: cText(20, weight: FontWeight.w700, color: p.ink)),
              const SizedBox(height: 4),
              Text(
                mine.isEmpty
                    ? "You have no patients assigned. You'll be marked off shift and signed out."
                    : 'You still have ${mine.length} patient${mine.length == 1 ? '' : 's'}. Hand them to someone on shift '
                        'so nobody is left without a named clinician.',
                style: cText(14, color: p.body, height: 1.45),
              ),
              if (mine.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    for (final c in mine.take(6))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          CDot(p.tone(levelTone(c.level)).dot, size: 8),
                          const SizedBox(width: 8),
                          Expanded(child: Text(c.patientName, style: cText(14, color: p.ink))),
                          Text(c.wardName ?? caseStatusLabel(c.status), style: cText(12, color: p.muted)),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
                if (colleagues.isEmpty)
                  Text('Nobody else is on shift right now.', style: cText(13, color: p.tone(Tone.orange).fg))
                else ...[
                  const CSectionLabel('Hand over to'),
                  const SizedBox(height: 8),
                  for (final m in colleagues.take(5)) ...[
                    COption(
                      leading: CAvatar(m.fullName),
                      title: m.fullName,
                      subtitle: '${m.role.label} · ${m.activeCases} patient${m.activeCases == 1 ? '' : 's'}',
                      selected: _to == m.firebaseUid,
                      onTap: () => setState(() => _to = m.firebaseUid),
                    ),
                    const SizedBox(height: 6),
                  ],
                ],
                const SizedBox(height: 8),
                CButton('Hand over & sign out', loading: _saving, onPressed: colleagues.isEmpty ? null : _handOver),
                const SizedBox(height: 8),
                CButton('Sign out, keep them assigned', kind: CButtonKind.secondary, onPressed: _offShiftOnly),
              ] else ...[
                const SizedBox(height: 16),
                CButton('Sign out', onPressed: _offShiftOnly),
              ],
              const SizedBox(height: 4),
              CButton('Cancel', kind: CButtonKind.ghost, height: 40, onPressed: () => Navigator.of(context).pop(false)),
            ],
          ),
        ),
      ),
    );
  }
}
