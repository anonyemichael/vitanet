import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/screens/portal_shell.dart';
import 'package:vitanet/features/admin/widgets/portal_common.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

/// Team (admins): staff requests, roles, suspend / reactivate.
class TeamScreen extends ConsumerWidget {
  final VoidCallback? onBack;
  const TeamScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(portalMeProvider);
    final value = ref.watch(teamProvider);

    Future<void> review(TeamMember m) async {
      final changed = await showStaffSheet<bool>(context, tall: true, builder: (_) => ReviewStaffSheet(member: m));
      if (changed == true) {
        ref.invalidate(teamProvider);
        ref.invalidate(capacityProvider);
        ref.invalidate(dashboardProvider);
      }
    }

    Widget section(String title, List<TeamMember> list, {StaffTone tone = StaffTone.neutral}) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PortalSectionTitle('$title (${list.length})'),
            StaffGroup(children: [
              for (final m in list)
                TeamMemberTile(
                  member: m,
                  onTap: m.firebaseUid == me?.firebaseUid ? null : () => review(m),
                  trailing: m.firebaseUid == me?.firebaseUid
                      ? const StaffTag('You', tone: StaffTone.brand)
                      : Icon(Icons.chevron_right_rounded, color: StaffPalette.of(context).faint),
                ),
            ]),
          ],
        );

    return Column(
      children: [
        PortalHeader(title: 'Team', subtitle: 'Everyone linked to your hospital', onBack: onBack),
        Expanded(
          child: PortalAsyncList<List<TeamMember>>(
            value: value,
            onRefresh: () => ref.refresh(teamProvider.future),
            builder: (team) {
              final pending = team.where((m) => m.status == StaffStatus.pending).toList();
              final approved = team.where((m) => m.status == StaffStatus.approved).toList();
              final other = team.where((m) => m.status == StaffStatus.suspended || m.status == StaffStatus.rejected).toList();
              return [
                if (pending.isEmpty) ...[
                  const PortalSectionTitle('Requests'),
                  const StaffCard(
                    child: PortalEmpty(
                      icon: Icons.person_add_alt_outlined,
                      title: 'No pending requests',
                      message: 'Staff who sign up and choose your hospital appear here for approval.',
                    ),
                  ),
                ] else
                  section('Requests', pending),
                if (approved.isNotEmpty) section('Approved', approved),
                if (other.isNotEmpty) section('Suspended / declined', other),
              ];
            },
          ),
        ),
      ],
    );
  }
}

class ReviewStaffSheet extends ConsumerStatefulWidget {
  final TeamMember member;
  const ReviewStaffSheet({super.key, required this.member});

  @override
  ConsumerState<ReviewStaffSheet> createState() => _ReviewStaffSheetState();
}

class _ReviewStaffSheetState extends ConsumerState<ReviewStaffSheet> {
  late StaffRole _role = widget.member.role;
  final _note = TextEditingController();
  String? _busy;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _do(String action) async {
    final m = widget.member;
    if (action != 'approve') {
      final yes = await confirmPortal(
        context,
        title: action == 'reject' ? 'Decline ${m.fullName}?' : 'Suspend ${m.fullName}?',
        message: action == 'reject'
            ? 'They won’t get portal access. They can request again later.'
            : 'They lose portal access immediately until reactivated.',
        confirm: action == 'reject' ? 'Decline' : 'Suspend',
        destructive: true,
      );
      if (!yes || !mounted) return;
    }
    setState(() => _busy = action);
    final r = await runPortalAction(
      context,
      () => ref.read(hospitalApiProvider).reviewStaff(m.firebaseUid, action,
          note: _note.text.trim(), role: action == 'approve' ? _role : null),
      success: switch (action) {
        'approve' => '${m.fullName} approved.',
        'reject' => 'Request declined.',
        _ => '${m.fullName} suspended.',
      },
    );
    if (!mounted) return;
    setState(() => _busy = null);
    if (r != null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final p = StaffPalette.of(context);
    final status = m.status;
    final actions = <Widget>[
      if (status == StaffStatus.pending) ...[
        StaffButton('Decline',
            kind: StaffButtonKind.dangerOutline, loading: _busy == 'reject', onPressed: _busy == null ? () => _do('reject') : null),
        StaffButton('Approve', loading: _busy == 'approve', onPressed: _busy == null ? () => _do('approve') : null),
      ] else if (status == StaffStatus.approved) ...[
        StaffButton('Suspend',
            kind: StaffButtonKind.dangerOutline, loading: _busy == 'suspend', onPressed: _busy == null ? () => _do('suspend') : null),
        StaffButton('Save role', loading: _busy == 'approve', onPressed: _busy == null && _role != m.role ? () => _do('approve') : null),
      ] else
        StaffButton('Reactivate', loading: _busy == 'approve', onPressed: _busy == null ? () => _do('approve') : null),
    ];
    return PortalSheet(
      title: m.fullName,
      subtitle: switch (status) {
        StaffStatus.pending => 'Requesting access',
        StaffStatus.approved => 'Approved',
        StaffStatus.suspended => 'Suspended',
        StaffStatus.rejected => 'Declined',
      },
      actions: actions,
      children: [
        StaffCard(
          color: p.fill,
          child: Column(children: [
            InfoRow('Email', m.email ?? ''),
            InfoRow('Requested role', m.role.label),
            InfoRow('Department', m.department ?? ''),
            InfoRow('License no.', m.licenseNumber ?? ''),
          ]),
        ),
        const SizedBox(height: 14),
        Text(status == StaffStatus.approved ? 'Role' : 'Role when approved',
            style: staffBody(13, weight: FontWeight.w600, color: p.ink)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final r in StaffRole.values)
            StaffPill(label: r.label, selected: _role == r, tealSelection: true, onTap: () => setState(() => _role = r)),
        ]),
        const SizedBox(height: 14),
        PortalTextField(controller: _note, label: 'Note to staff member (optional)', maxLines: 2),
      ],
    );
  }
}
