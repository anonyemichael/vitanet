import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/portal/data/portal_models.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
import 'package:vitanet/features/portal/shell/portal_nav.dart';
import 'package:vitanet/features/portal/ui/clinical_ui.dart';

/// Full-screen incoming patient (phones).
class ReferralPage extends StatelessWidget {
  final String referralId;
  const ReferralPage({super.key, required this.referralId});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(child: ReferralView(referralId: referralId, showBack: true)),
    );
  }
}

/// The consented summary of an incoming patient, with Accept / Decline.
/// Used as a page on phones and in the detail pane on desk.
class ReferralView extends ConsumerWidget {
  final String referralId;
  final bool showBack;
  const ReferralView({super.key, required this.referralId, this.showBack = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ClinicalPalette.of(context);
    final value = ref.watch(referralProvider(referralId));
    return value.when(
      loading: () => const CLoading(),
      error: (e, _) => CError(error: e, onRetry: () => ref.invalidate(referralProvider(referralId))),
      data: (r) {
        final header = Padding(
          padding: EdgeInsets.fromLTRB(showBack ? 4 : 16, 8, 16, 4),
          child: Row(
            children: [
              if (showBack)
                CIconButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.status == 'new' ? 'Incoming patient' : 'Referral',
                        style: cText(17, weight: FontWeight.w700, color: p.ink)),
                    Text(
                      '${_statusLine(r)} · received ${clockTime(r.createdAt)}',
                      style: cText(12, color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        return Column(
          children: [
            header,
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _PatientCard(r),
                  const SizedBox(height: 12),
                  _AllergyBanner(r.summary.allergies),
                  if (r.status != 'new') ...[const SizedBox(height: 12), _StatusBanner(r)],
                  const SizedBox(height: 12),
                  _WhatsWrong(r),
                  if (r.summary.vitals.isNotEmpty) ...[const SizedBox(height: 12), _SharedVitals(r.summary.vitals)],
                  if (r.summary.medications.isNotEmpty || r.summary.conditions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    CCard(
                      child: Column(
                        children: [
                          if (r.summary.medications.isNotEmpty)
                            _InfoLine(label: 'Medications', value: r.summary.medications.join(', ')),
                          if (r.summary.medications.isNotEmpty && r.summary.conditions.isNotEmpty)
                            const SizedBox(height: 10),
                          if (r.summary.conditions.isNotEmpty)
                            _InfoLine(label: 'Conditions', value: r.summary.conditions.join(', ')),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 14, color: p.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Shared with the patient's consent at ${clockTime(r.createdAt)} — only what they chose.",
                          style: cText(12, color: p.muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (r.status == 'new')
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.line))),
                child: Row(
                  children: [
                    Expanded(
                      child: CButton('Decline',
                          kind: CButtonKind.secondary, onPressed: () => showDeclineSheet(context, ref, r)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: CButton('Accept patient', onPressed: () => showAcceptSheet(context, ref, r)),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  static String _statusLine(Referral r) => switch (r.status) {
        'new' => r.source == 'checkin' ? 'Emergency check-in' : 'New referral',
        'accepted' => 'Accepted · on the way',
        'arrived' => 'Arrived',
        'closed' => 'Discharged',
        'declined' => 'Declined',
        'cancelled' => 'Cancelled by the patient',
        _ => r.status,
      };
}

class _PatientCard extends StatelessWidget {
  final Referral r;
  const _PatientCard(this.r);

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final s = r.summary;
    final who = ageSex(s.age, s.sex);
    return CCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LevelChip(r.triageLevel),
              const Spacer(),
              if (r.source == 'checkin') CChip('Check-in', tone: Tone.blue),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.patientName, style: cText(22, weight: FontWeight.w700, color: p.ink)),
                    Text([if (who.isNotEmpty) who, 'from VitaNet'].join(' · '), style: cText(14, color: p.muted)),
                  ],
                ),
              ),
              if (r.status == 'new' || r.status == 'accepted')
                Every(
                  builder: (context) {
                    final mins = r.minutesToArrival();
                    final at = parseTime(r.etaAt);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('ARRIVING IN', style: cText(11, weight: FontWeight.w600, color: p.muted)),
                        Text(etaText(mins), style: cMono(24, color: p.ink)),
                        if (at != null)
                          Text('≈ ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(at), alwaysUse24HourFormat: true)}',
                              style: cMono(12, weight: FontWeight.w500, color: p.muted)),
                      ],
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllergyBanner extends StatelessWidget {
  final List<String> allergies;
  const _AllergyBanner(this.allergies);

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    if (allergies.isEmpty) {
      return Text('No allergies shared', style: cText(13, color: p.muted));
    }
    final t = p.tone(Tone.red);
    return Semantics(
      label: 'Allergic to ${allergies.join(', ')}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: t.bg, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: t.fg, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Allergic to ${allergies.join(', ')}', style: cText(15, weight: FontWeight.w700, color: t.fg)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends ConsumerWidget {
  final Referral r;
  const _StatusBanner(this.r);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ClinicalPalette.of(context);
    final (Tone tone, String text) = switch (r.status) {
      'declined' => (Tone.neutral, 'Declined: ${r.declineReason ?? 'no reason given'}'),
      'cancelled' => (Tone.neutral, 'The patient cancelled before anyone answered.'),
      'accepted' => (Tone.blue, 'Accepted — on the way.'),
      'arrived' => (Tone.green, 'Arrived at the hospital.'),
      _ => (Tone.neutral, 'Discharged.'),
    };
    final t = p.tone(tone);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text(text, style: cText(14, weight: FontWeight.w600, color: t.fg))),
          if (r.caseId != null)
            CButton('Open record',
                expand: false, height: 38, fontSize: 13, onPressed: () => openCase(context, ref, r.caseId!)),
        ],
      ),
    );
  }
}

class _WhatsWrong extends StatelessWidget {
  final Referral r;
  const _WhatsWrong(this.r);

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return CCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CSectionLabel("What's wrong"),
          const SizedBox(height: 8),
          Text(r.summary.complaint ?? 'Not shared', style: cText(15, weight: FontWeight.w600, color: p.ink)),
          if ((r.summary.triageSummary ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('VitaNet triage: ${r.summary.triageSummary}', style: cText(14, color: p.body, height: 1.45)),
          ],
        ],
      ),
    );
  }
}

class _SharedVitals extends StatelessWidget {
  final Map<String, dynamic> vitals;
  const _SharedVitals(this.vitals);

  num? _n(List<String> keys) {
    for (final k in keys) {
      final v = vitals[k];
      if (v is num) return v;
      final parsed = num.tryParse('${v ?? ''}');
      if (parsed != null) return parsed;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hr = _n(['heart_rate', 'hr']);
    final sys = _n(['bp_systolic', 'systolic_bp', 'blood_pressure_systolic']);
    final dia = _n(['bp_diastolic', 'diastolic_bp', 'blood_pressure_diastolic']);
    final spo2 = _n(['spo2', 'blood_oxygen', 'oxygen']);
    final temp = _n(['temperature', 'temp']);
    final rr = _n(['respiratory_rate', 'rr']);
    final tiles = <Widget>[
      if (hr != null) VitalTile(label: 'HR', value: '${hr.round()}', tone: (hr > 100 || hr < 50) ? Tone.red : null),
      if (sys != null)
        VitalTile(
            label: 'BP',
            value: dia == null ? '${sys.round()}' : '${sys.round()}/${dia.round()}',
            tone: (sys >= 140 || sys < 90) ? Tone.red : null),
      if (spo2 != null) VitalTile(label: 'SpO₂', value: '${spo2.round()}%', tone: spo2 < 94 ? Tone.red : null),
      if (temp != null) VitalTile(label: 'Temp', value: temp.toStringAsFixed(1), tone: temp >= 38 ? Tone.orange : null),
      if (rr != null) VitalTile(label: 'Resp', value: '${rr.round()}', tone: (rr > 20 || rr < 10) ? Tone.orange : null),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return CCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CSectionLabel('Vitals shared by the patient'),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 6 * 3) / 4;
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in tiles) SizedBox(width: w.clamp(70, 400).toDouble(), child: t)],
            );
          }),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label, style: cText(13, color: p.muted))),
        Expanded(child: Text(value, style: cText(14, color: p.ink))),
      ],
    );
  }
}

// ─── Accept ───

Future<void> showAcceptSheet(BuildContext context, WidgetRef ref, Referral r) async {
  final caseId = await showCSheet<String>(context, builder: (_) => AcceptSheet(referral: r));
  if (caseId != null && context.mounted) showCaseAfterAccept(context, ref, caseId);
}

class AcceptSheet extends ConsumerStatefulWidget {
  final Referral referral;
  const AcceptSheet({super.key, required this.referral});

  @override
  ConsumerState<AcceptSheet> createState() => _AcceptSheetState();
}

class _AcceptSheetState extends ConsumerState<AcceptSheet> {
  final _bed = TextEditingController();
  int? _wardId;
  String? _assignee;
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _bed.dispose();
    super.dispose();
  }

  void _seed(Capacity cap) {
    if (_seeded) return;
    _seeded = true;
    final s = widget.referral.suggestion;
    final ward = cap.wards.where((w) => w.id == s?.wardId && w.bedsFree > 0).firstOrNull;
    _wardId = ward?.id;
    _assignee = s?.assigneeUid;
  }

  Future<void> _accept() async {
    setState(() => _saving = true);
    final res = await runCAction(
      context,
      () => ref.read(hospitalApiProvider).acceptReferral(
            widget.referral.id,
            wardId: _wardId,
            bed: _bed.text.trim(),
            assigneeUid: _assignee,
          ),
      success: '${widget.referral.patientName} accepted.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) {
      invalidatePortalData(ref);
      Navigator.of(context).pop(res.portalCase.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final r = widget.referral;
    final cap = ref.watch(capacityProvider);
    final mins = r.minutesToArrival();
    return CSheet(
      title: 'Accept ${r.patientName}',
      subtitle: '${levelLabel(r.triageLevel)}${mins == null ? '' : ' · arriving in ${etaText(mins)}'}',
      actions: [CButton('Accept & prepare bed', loading: _saving, onPressed: cap.hasValue ? _accept : null)],
      children: cap.when(
        loading: () => const [CLoading()],
        error: (e, _) => [CError(error: e, onRetry: () => ref.invalidate(capacityProvider))],
        data: (c) {
          _seed(c);
          final ward = c.wards.where((w) => w.id == _wardId).firstOrNull;
          final team = [...c.team]..sort((a, b) {
              if (a.onDuty != b.onDuty) return a.onDuty ? -1 : 1;
              return a.activeCases.compareTo(b.activeCases);
            });
          final assignee = team.where((m) => m.firebaseUid == _assignee).firstOrNull;
          final suggestion = r.suggestion;
          return [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CSectionLabel('Where will they go?',
                    trailing: suggestion?.wardName == null
                        ? null
                        : Text('Suggested: ${suggestion!.wardName}', style: cText(12, color: p.primaryInk))),
                const SizedBox(height: 8),
                if (c.wards.isEmpty)
                  Text('No wards set up yet — an admin can add them under Hospital.', style: cText(13, color: p.muted)),
                for (final w in c.wards) ...[
                  COption(
                    title: w.name,
                    trailing: w.bedsFree == 0 ? 'Full' : '${w.bedsFree} of ${w.bedsTotal} free',
                    trailingColor: w.bedsFree == 0 ? p.tone(Tone.red).fg : null,
                    enabled: w.bedsFree > 0,
                    selected: _wardId == w.id,
                    onTap: () => setState(() => _wardId = _wardId == w.id ? null : w.id),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
            CTextField(controller: _bed, label: 'Bed or bay', hint: 'e.g. Bay 2', onChanged: (_) => setState(() {})),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CSectionLabel("Who's taking them?"),
                const SizedBox(height: 8),
                for (final m in team.take(6)) ...[
                  COption(
                    leading: CAvatar(m.fullName, size: 32),
                    title: m.fullName,
                    subtitle: '${m.role.label} · ${m.onDuty ? 'on shift' : 'off shift'} · '
                        '${m.activeCases} patient${m.activeCases == 1 ? '' : 's'}',
                    selected: _assignee == m.firebaseUid,
                    // "Leave unassigned" below is the explicit way to clear it.
                    onTap: () => setState(() => _assignee = m.firebaseUid),
                  ),
                  const SizedBox(height: 6),
                ],
                COption(
                  leading: const CAvatar('', size: 32, tone: Tone.neutral),
                  title: 'Leave unassigned',
                  subtitle: 'Anyone on shift can pick it up',
                  selected: _assignee == null,
                  onTap: () => setState(() => _assignee = null),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(10)),
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'The patient will see: '),
                  TextSpan(
                    text: 'Accepted${ward == null ? '' : ' · ${ward.name}'}'
                        '${_bed.text.trim().isEmpty ? '' : ', ${_bed.text.trim()}'}'
                        '${assignee == null ? '' : ' · ${assignee.fullName}'}.',
                    style: cText(12, weight: FontWeight.w600, color: p.ink),
                  ),
                ]),
                style: cText(12, color: p.muted),
              ),
            ),
          ];
        },
      ),
    );
  }
}

// ─── Decline ───

Future<void> showDeclineSheet(BuildContext context, WidgetRef ref, Referral r) async {
  final done = await showCSheet<bool>(context, builder: (_) => DeclineSheet(referral: r));
  if (done == true && context.mounted && !DetailPaneScope.hasPane(context)) {
    Navigator.of(context).maybePop();
  }
}

class DeclineSheet extends ConsumerStatefulWidget {
  final Referral referral;
  const DeclineSheet({super.key, required this.referral});

  @override
  ConsumerState<DeclineSheet> createState() => _DeclineSheetState();
}

class _DeclineSheetState extends ConsumerState<DeclineSheet> {
  static const reasons = [
    'No bed in the right ward',
    'Specialist not available',
    'Equipment unavailable',
    'Better served elsewhere',
    'Other',
  ];
  final _note = TextEditingController();
  String? _reason;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _decline() async {
    final note = _note.text.trim();
    final reason = [if (_reason != null && _reason != 'Other') _reason!, if (note.isNotEmpty) note].join('. ');
    if (reason.length < 3) {
      showCSnack(context, 'Choose a reason or write a short note.');
      return;
    }
    setState(() => _saving = true);
    final res = await runCAction(
      context,
      () => ref.read(hospitalApiProvider).declineReferral(widget.referral.id, reason),
      success: 'Declined. The patient has been told.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) {
      invalidatePortalData(ref);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final r = widget.referral;
    return CSheet(
      title: 'Decline ${r.patientName}?',
      subtitle: '${levelLabel(r.triageLevel)} · ${r.summary.complaint ?? ''}. Say why so they know what to do next.',
      actions: [
        CButton('Cancel', kind: CButtonKind.secondary, onPressed: () => Navigator.of(context).pop()),
        CButton('Decline referral', kind: CButtonKind.danger, loading: _saving, onPressed: _decline),
      ],
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CSectionLabel('Reason'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reason in reasons)
                  CPill(label: reason, selected: _reason == reason, onTap: () => setState(() => _reason = reason)),
              ],
            ),
          ],
        ),
        CTextField(controller: _note, label: 'Note for the patient (optional)', maxLines: 3,
            hint: 'e.g. Korle Bu is accepting and 9 min further.'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(10)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: p.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The patient sees your reason and the nearest hospitals that are accepting, '
                  'so they can send their summary there in one tap.',
                  style: cText(13, color: p.body, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
