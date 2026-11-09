import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/portal/data/hospital_api_service.dart';
import 'package:vitanet/features/portal/data/portal_models.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
import 'package:vitanet/features/portal/hospital/admin_pages.dart';
import 'package:vitanet/features/portal/shell/portal_shell.dart';
import 'package:vitanet/features/portal/ui/clinical_ui.dart';

/// Entry point for /admin: shows the right screen for the person's staff
/// access (GET /staff/me), and the portal once they're approved.
class PortalGate extends ConsumerWidget {
  const PortalGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(staffAccessProvider);
    return access.when(
      skipLoadingOnRefresh: true,
      loading: () => const _GateFrame(child: CLoading()),
      error: (e, _) => _AccessState(
        icon: Icons.cloud_off_rounded,
        tone: Tone.red,
        title: "Couldn't check your access",
        message: apiErrorMessage(e),
        primary: ('Try again', () => ref.invalidate(staffAccessProvider)),
      ),
      data: (a) => switch (a.kind) {
        StaffAccessKind.approved => PortalShell(me: a.me!),
        StaffAccessKind.needsHospital => a.me!.isAdmin
            ? const _CreateHospital()
            : _AccessState(
                icon: Icons.local_hospital_outlined,
                tone: Tone.amber,
                title: 'No hospital linked',
                message: "You're approved but not linked to a hospital yet. Ask your hospital's admin to add you.",
                primary: ('Check again', () => ref.invalidate(staffAccessProvider)),
              ),
        StaffAccessKind.pending => _Pending(me: a.me!),
        StaffAccessKind.rejected => _AccessState(
            icon: Icons.block_rounded,
            tone: Tone.red,
            title: 'Access request declined',
            message: "Your hospital's admin didn't approve this account. If that's a mistake, contact them and ask again.",
            note: a.me?.reviewNote,
            primary: ('Ask again', () => context.go('/login/hospital_personnel')),
          ),
        StaffAccessKind.suspended => _AccessState(
            icon: Icons.lock_outline_rounded,
            tone: Tone.red,
            title: 'Account suspended',
            message: "An admin at your hospital paused your portal access. Ask them to reinstate you. "
                'Your personal VitaNet still works.',
            note: a.me?.reviewNote,
          ),
        StaffAccessKind.none => _AccessState(
            icon: Icons.badge_outlined,
            tone: Tone.blue,
            title: 'No staff account',
            message: 'This sign-in has no hospital staff account. Ask to join your hospital.',
            primary: ('Ask to join', () => context.go('/login/hospital_personnel')),
          ),
      },
    );
  }
}

Future<void> _signOut(BuildContext context, WidgetRef ref) async {
  await ref.read(authProvider.notifier).signOut();
  if (context.mounted) context.go('/login');
}

void _openPersonal(BuildContext context, WidgetRef ref) {
  ref.read(activeWorkspaceProvider.notifier).setWorkspace(AppWorkspace.personal);
  context.go('/home');
}

class _GateFrame extends StatelessWidget {
  final Widget child;
  const _GateFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: p.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Row(children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(color: p.navy, borderRadius: BorderRadius.circular(8)),
                        alignment: Alignment.center,
                        child: Text('V', style: cText(13, weight: FontWeight.w700, color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      Text('VitaNet for hospitals', style: cText(14, weight: FontWeight.w700, color: p.ink)),
                    ]),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessState extends ConsumerWidget {
  final IconData icon;
  final Tone tone;
  final String title;
  final String message;
  final String? note;
  final (String, VoidCallback)? primary;
  final List<Widget> details;

  const _AccessState({
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
    this.note,
    this.primary,
    this.details = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ClinicalPalette.of(context);
    final t = p.tone(tone);
    return _GateFrame(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: t.fg, size: 26),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(header: true, child: Text(title, style: cText(24, weight: FontWeight.w700, color: p.ink))),
          const SizedBox(height: 6),
          Text(message, style: cText(15, color: p.body, height: 1.5)),
          if ((note ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            CCard(child: Text('Note from your admin: $note', style: cText(14, color: p.body))),
          ],
          ...details,
          const SizedBox(height: 28),
          if (primary != null) ...[CButton(primary!.$1, onPressed: primary!.$2), const SizedBox(height: 8)],
          CButton('Open my personal VitaNet', kind: CButtonKind.secondary, onPressed: () => _openPersonal(context, ref)),
          const SizedBox(height: 4),
          CButton('Sign out', kind: CButtonKind.ghost, height: 40, onPressed: () => _signOut(context, ref)),
        ],
      ),
    );
  }
}

/// Waiting for an admin. Checks again every 30 s, so the portal opens by
/// itself once approved.
class _Pending extends ConsumerStatefulWidget {
  final StaffMe me;
  const _Pending({required this.me});

  @override
  ConsumerState<_Pending> createState() => _PendingState();
}

class _PendingState extends ConsumerState<_Pending> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => ref.invalidate(staffAccessProvider));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final hospitals = ref.watch(facilitiesProvider).valueOrNull ?? const <Facility>[];
    final hospital = hospitals.where((h) => h.id == widget.me.hospitalId).firstOrNull;
    Widget line(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 110, child: Text(k, style: cText(14, color: p.muted))),
            Expanded(child: Text(v, style: cText(14, weight: FontWeight.w600, color: p.ink))),
          ]),
        );
    return _AccessState(
      icon: Icons.schedule_rounded,
      tone: Tone.blue,
      title: 'Waiting for approval',
      message: 'An admin at ${hospital?.name ?? 'your hospital'} checks your licence and lets you in. '
          'This page opens the portal by itself once they approve.',
      primary: ('Check again', () => ref.invalidate(staffAccessProvider)),
      details: [
        const SizedBox(height: 16),
        CCard(
          child: Column(children: [
            if (hospital != null) line('Hospital', hospital.name),
            line('Role asked', widget.me.role.label),
            if ((widget.me.licenseNumber ?? '').isNotEmpty) line('Licence', widget.me.licenseNumber!),
          ]),
        ),
      ],
    );
  }
}

/// An approved admin with no hospital yet creates it.
class _CreateHospital extends ConsumerWidget {
  const _CreateHospital();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ClinicalPalette.of(context);
    return _GateFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text('Set up your hospital', style: cText(24, weight: FontWeight.w700, color: p.ink))),
              const SizedBox(height: 6),
              Text("You're approved as an admin. Add your hospital so staff can join and VitaNet patients nearby can find you.",
                  style: cText(15, color: p.body, height: 1.5)),
            ]),
          ),
          const Expanded(child: FacilityForm()),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CButton('Sign out', kind: CButtonKind.ghost, height: 40, onPressed: () => _signOut(context, ref)),
          ),
        ],
      ),
    );
  }
}
