import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/screens/case_record_screen.dart';
import 'package:vitanet/features/admin/widgets/portal_common.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

void openReferral(BuildContext context, String id) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReferralDetailScreen(referralId: id)));
}

/// Referrals inbox: New / Accepted / Declined.
class ReferralsScreen extends ConsumerStatefulWidget {
  final bool active;
  const ReferralsScreen({super.key, this.active = true});

  @override
  ConsumerState<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends ConsumerState<ReferralsScreen> {
  static const _statuses = ['new', 'accepted', 'declined'];
  static const _labels = ['New', 'Accepted', 'Declined'];
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final status = _statuses[_tab];
    final value = ref.watch(referralsProvider(status));
    return AutoRefresh(
      active: widget.active,
      onTick: () => ref.invalidate(referralsProvider(status)),
      child: Column(
        children: [
          PortalHeader(
            title: 'Referrals',
            subtitle: 'Patients who chose to send their VitaNet summary here',
            bottom: StaffSegmented(labels: _labels, selected: _tab, onChanged: (i) => setState(() => _tab = i)),
          ),
          Expanded(
            child: PortalAsyncList<List<Referral>>(
              value: value,
              onRefresh: () => ref.refresh(referralsProvider(status).future),
              builder: (list) => list.isEmpty
                  ? [
                      PortalEmpty(
                        icon: Icons.move_to_inbox_outlined,
                        title: switch (status) {
                          'new' => 'No incoming referrals yet',
                          'accepted' => 'No accepted referrals',
                          _ => 'No declined referrals',
                        },
                        message: status == 'new'
                            ? 'New referrals from VitaNet patients appear here. This list refreshes automatically.'
                            : null,
                      ),
                    ]
                  : [
                      for (final r in list) ...[
                        ReferralCard(referral: r, onTap: () => openReferral(context, r.id)),
                        const SizedBox(height: 10),
                      ],
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReferralCard extends StatelessWidget {
  final Referral referral;
  final VoidCallback onTap;
  const ReferralCard({super.key, required this.referral, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final r = referral;
    final meta = [
      ageSex(r.summary.age, r.summary.sex),
      relativeTime(r.createdAt),
      if (r.etaMinutes != null && r.status == 'new') 'ETA ${r.etaMinutes} min',
    ].where((s) => s.isNotEmpty).join(' · ');
    return StaffTap(
      onTap: onTap,
      color: p.card,
      radius: 16,
      semanticLabel: '${levelLabel(r.triageLevel)} referral, ${r.patientName}, ${r.summary.complaint ?? ''}',
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 52,
              decoration: BoxDecoration(
                color: p.tone(levelTone(r.triageLevel)).strong,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(r.patientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: staffBody(15, weight: FontWeight.w700, color: p.ink)),
                      ),
                      StaffTag(levelLabel(r.triageLevel), tone: levelTone(r.triageLevel)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(r.summary.complaint ?? 'No complaint given',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: staffBody(13, color: p.body)),
                  const SizedBox(height: 4),
                  Text(meta, style: staffBody(12, color: p.muted)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: p.faint),
          ],
        ),
      ),
    );
  }
}

/// Referral detail with the consented summary; Accept / Decline when new.
class ReferralDetailScreen extends ConsumerWidget {
  final String referralId;
  const ReferralDetailScreen({super.key, required this.referralId});

  Future<void> _accept(BuildContext context, WidgetRef ref, Referral r) async {
    final result = await showStaffSheet<AcceptResult>(context, tall: true, builder: (_) => AcceptReferralSheet(referral: r));
    if (result == null || !context.mounted) return;
    invalidatePortalData(ref);
    showStaffSnack(context, 'Referral accepted — case created.');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => CaseRecordScreen(caseId: result.portalCase.id)),
    );
  }

  Future<void> _decline(BuildContext context, WidgetRef ref, Referral r) async {
    final done = await showStaffSheet<bool>(context, builder: (_) => DeclineReferralSheet(referral: r));
    if (done != true || !context.mounted) return;
    invalidatePortalData(ref);
    showStaffSnack(context, 'Referral declined. The patient has been told.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = StaffPalette.of(context);
    final value = ref.watch(referralProvider(referralId));
    final r = value.valueOrNull;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          PortalHeader(
            title: r?.patientName ?? 'Referral',
            subtitle: r == null ? null : 'Received ${relativeTime(r.createdAt)}',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: PortalAsyncList<Referral>(
              value: value,
              onRefresh: () => ref.refresh(referralProvider(referralId).future),
              builder: (r) => _details(context, r),
            ),
          ),
          if (r != null && r.status == 'new')
            Container(
              color: p.card,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: StaffContent(
                    maxWidth: 860,
                    child: Row(
                      children: [
                        Expanded(
                          child: StaffButton('Decline',
                              kind: StaffButtonKind.dangerOutline, onPressed: () => _decline(context, ref, r)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: StaffButton('Accept',
                              icon: Icons.check_rounded, onPressed: () => _accept(context, ref, r)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _details(BuildContext context, Referral r) {
    final p = StaffPalette.of(context);
    final s = r.summary;
    final statusTone = switch (r.status) {
      'new' => StaffTone.brand,
      'accepted' => StaffTone.green,
      'declined' => StaffTone.danger,
      _ => StaffTone.neutral,
    };
    return [
      StaffCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              StaffTag(levelLabel(r.triageLevel), tone: levelTone(r.triageLevel)),
              StaffTag(r.status[0].toUpperCase() + r.status.substring(1), tone: statusTone),
              if (r.etaMinutes != null) StaffTag('ETA ${r.etaMinutes} min', tone: StaffTone.sky),
            ]),
            const SizedBox(height: 12),
            Text(s.complaint ?? 'No complaint given', style: staffHeading(18, weight: FontWeight.w700, color: p.ink)),
            const SizedBox(height: 8),
            InfoRow('Patient', s.patientName ?? 'VitaNet patient'),
            InfoRow('Age / sex', ageSex(s.age, s.sex)),
            InfoRow('Triage level', levelLabel(r.triageLevel), tone: levelTone(r.triageLevel)),
            if (r.declineReason != null) InfoRow('Decline reason', r.declineReason!),
          ],
        ),
      ),
      if ((s.triageSummary ?? '').isNotEmpty) ...[
        const PortalSectionTitle('Triage summary'),
        StaffCard(child: Text(s.triageSummary!, style: staffBody(14, color: p.body, height: 1.55))),
      ],
      const PortalSectionTitle('Vitals'),
      StaffCard(
        child: s.vitals.isEmpty
            ? Text('No vitals shared', style: staffBody(13, color: p.muted))
            : Column(children: [
                for (final e in s.vitals.entries)
                  InfoRow(e.key.replaceAll('_', ' '), '${e.value}'),
              ]),
      ),
      const PortalSectionTitle('Allergies'),
      StaffCard(child: SizedBox(width: double.infinity, child: ChipList(s.allergies, tone: StaffTone.danger))),
      const PortalSectionTitle('Medications'),
      StaffCard(child: SizedBox(width: double.infinity, child: ChipList(s.medications, tone: StaffTone.sky))),
      const PortalSectionTitle('Conditions'),
      StaffCard(child: SizedBox(width: double.infinity, child: ChipList(s.conditions, tone: StaffTone.violet))),
      const SizedBox(height: 12),
      Text('Shared by the patient with consent through VitaNet.',
          textAlign: TextAlign.center, style: staffBody(12, color: p.muted)),
      if (r.caseId != null) ...[
        const SizedBox(height: 16),
        Builder(
          builder: (ctx) => StaffButton('Open case',
              kind: StaffButtonKind.secondary,
              icon: Icons.assignment_ind_outlined,
              onPressed: () => openCase(ctx, r.caseId!)),
        ),
      ],
    ];
  }
}

/// Accept: choose assignee (capacity.team), ward with free beds, bed.
class AcceptReferralSheet extends ConsumerStatefulWidget {
  final Referral referral;
  const AcceptReferralSheet({super.key, required this.referral});

  @override
  ConsumerState<AcceptReferralSheet> createState() => _AcceptReferralSheetState();
}

class _AcceptReferralSheetState extends ConsumerState<AcceptReferralSheet> {
  String _assignee = '';
  int _ward = -1;
  final _bed = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _bed.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final r = await runPortalAction(
      context,
      () => ref.read(hospitalApiProvider).acceptReferral(
            widget.referral.id,
            assigneeUid: _assignee.isEmpty ? null : _assignee,
            wardId: _ward < 0 ? null : _ward,
            bed: _bed.text.trim(),
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (r != null) Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) {
    final cap = ref.watch(capacityProvider);
    return PortalSheet(
      title: 'Accept referral',
      subtitle: '${widget.referral.patientName} · ${levelLabel(widget.referral.triageLevel)}',
      actions: [
        StaffButton('Cancel', kind: StaffButtonKind.secondary, onPressed: () => Navigator.of(context).pop()),
        StaffButton('Accept referral', loading: _saving, onPressed: cap.hasValue ? _submit : null),
      ],
      children: cap.when(
        loading: () => const [PortalLoading()],
        error: (e, _) => [PortalError(error: e, onRetry: () => ref.invalidate(capacityProvider))],
        data: (c) {
          final freeWards = c.wards.where((w) => w.bedsFree > 0).toList();
          return [
            StaffField(
              label: 'Assign to',
              child: StaffSelect<String>(
                value: _assignee,
                items: ['', ...c.team.map((m) => m.firebaseUid)],
                labelOf: (uid) {
                  if (uid.isEmpty) return 'Unassigned';
                  final m = c.team.firstWhere((m) => m.firebaseUid == uid);
                  return '${m.fullName} · ${m.role.label}${m.onDuty ? ' · on duty' : ''}';
                },
                icon: Icons.person_outline_rounded,
                onChanged: (v) => setState(() => _assignee = v),
              ),
            ),
            const SizedBox(height: 14),
            StaffField(
              label: 'Ward',
              helper: freeWards.isEmpty
                  ? Text('No ward has a free bed. You can accept now and assign a bed later.',
                      style: staffBody(12, color: StaffPalette.of(context).muted))
                  : null,
              child: StaffSelect<int>(
                value: _ward,
                items: [-1, ...freeWards.map((w) => w.id)],
                labelOf: (id) {
                  if (id < 0) return 'No ward yet';
                  final w = freeWards.firstWhere((w) => w.id == id);
                  return '${w.name} · ${w.bedsFree} free';
                },
                icon: Icons.bed_outlined,
                onChanged: (v) => setState(() => _ward = v),
              ),
            ),
            const SizedBox(height: 14),
            PortalTextField(controller: _bed, label: 'Bed (optional)', hint: 'e.g. B4'),
          ];
        },
      ),
    );
  }
}

/// Decline with a reason (min 3 characters).
class DeclineReferralSheet extends ConsumerStatefulWidget {
  final Referral referral;
  const DeclineReferralSheet({super.key, required this.referral});

  @override
  ConsumerState<DeclineReferralSheet> createState() => _DeclineReferralSheetState();
}

class _DeclineReferralSheetState extends ConsumerState<DeclineReferralSheet> {
  static const _quick = ['No beds available', 'Specialty not available here', 'Closer facility is more suitable'];
  final _reason = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (reason.length < 3) {
      showStaffSnack(context, 'Give the patient a short reason.');
      return;
    }
    setState(() => _saving = true);
    final r = await runPortalAction(
        context, () => ref.read(hospitalApiProvider).declineReferral(widget.referral.id, reason));
    if (!mounted) return;
    setState(() => _saving = false);
    if (r != null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return PortalSheet(
      title: 'Decline referral',
      subtitle: 'The patient sees this reason and is pointed to the next nearest A&E.',
      actions: [
        StaffButton('Cancel', kind: StaffButtonKind.secondary, onPressed: () => Navigator.of(context).pop()),
        StaffButton('Decline', kind: StaffButtonKind.dangerOutline, loading: _saving, onPressed: _submit),
      ],
      children: [
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final q in _quick)
            StaffPill(
              label: q,
              selected: _reason.text == q,
              tealSelection: true,
              onTap: () => setState(() => _reason.text = q),
            ),
        ]),
        const SizedBox(height: 12),
        PortalTextField(controller: _reason, label: 'Reason', hint: 'Why can’t you take this patient?', maxLines: 3),
      ],
    );
  }
}
