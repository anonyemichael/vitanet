import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/portal/data/portal_models.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
import 'package:vitanet/features/portal/record/record_sheets.dart';
import 'package:vitanet/features/portal/ui/clinical_ui.dart';

class CaseRecordPage extends StatelessWidget {
  final String caseId;
  const CaseRecordPage({super.key, required this.caseId});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: ClinicalPalette.of(context).bg,
        body: SafeArea(child: CaseRecordView(caseId: caseId, showBack: true)),
      );
}

/// A patient's record: who, where, progress, latest vitals, actions and the
/// timeline. A page on phones; the detail pane on desk.
class CaseRecordView extends ConsumerStatefulWidget {
  final String caseId;
  final bool showBack;
  const CaseRecordView({super.key, required this.caseId, this.showBack = false});

  @override
  ConsumerState<CaseRecordView> createState() => _CaseRecordViewState();
}

class _CaseRecordViewState extends ConsumerState<CaseRecordView> {
  final _note = TextEditingController();
  bool _savingNote = false;
  bool _advancing = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(caseProvider(widget.caseId));
    ref.invalidate(casesProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> _addNote() async {
    final text = _note.text.trim();
    if (text.isEmpty) return;
    setState(() => _savingNote = true);
    final res = await runCAction(context, () => ref.read(hospitalApiProvider).addNote(widget.caseId, text));
    if (!mounted) return;
    setState(() => _savingNote = false);
    if (res != null) {
      _note.clear();
      _refresh();
    }
  }

  Future<void> _advance(PortalCase c) async {
    final api = ref.read(hospitalApiProvider);
    setState(() => _advancing = true);
    final res = await runCAction(
      context,
      () => c.isExpected ? api.markArrived(c.id) : api.updateCase(c.id, status: 'treatment'),
      success: c.isExpected ? '${c.patientName} has arrived.' : 'Treatment started.',
    );
    if (!mounted) return;
    setState(() => _advancing = false);
    if (res != null) _refresh();
  }

  Future<void> _open(Widget sheet) async {
    final changed = await showCSheet<bool>(context, builder: (_) => sheet);
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(caseProvider(widget.caseId));
    return value.when(
      loading: () => const CLoading(),
      error: (e, _) => CError(error: e, onRetry: () => ref.invalidate(caseProvider(widget.caseId))),
      data: _build,
    );
  }

  Widget _build(PortalCase c) {
    final p = ClinicalPalette.of(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(widget.showBack ? 4 : 16, 8, 8, 4),
          child: Row(
            children: [
              if (widget.showBack)
                CIconButton(icon: Icons.chevron_left_rounded, tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop()),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Case '),
                    TextSpan(text: caseRef(c.id), style: cMono(13, color: p.ink)),
                    TextSpan(text: ' · opened ${clockTime(c.createdAt)}'),
                  ]),
                  style: cText(13, color: p.muted),
                ),
              ),
              CIconButton(icon: Icons.refresh_rounded, tooltip: 'Refresh', onPressed: _refresh),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: p.primary,
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _header(c),
                const SizedBox(height: 12),
                if (c.isDischarged) ...[_dischargeCard(c), const SizedBox(height: 12)],
                _vitalsCard(c),
                if (c.isActive) ...[const SizedBox(height: 12), _actions(c)],
                const SizedBox(height: 12),
                _timeline(c),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(PortalCase c) {
    final p = ClinicalPalette.of(context);
    final where = [c.wardName, c.bed].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final line = [
      ageSex(c.age, c.sex),
      if (where.isNotEmpty) where else if (c.isExpected) 'On the way' else 'No bed yet',
      c.assigneeName ?? 'Unassigned',
    ].where((s) => s.isNotEmpty).join(' · ');
    final steps = [c.referralId == null ? 'Registered' : 'Accepted', 'Arrived', 'In treatment', 'Discharged'];
    final reached = switch (c.status) {
      'expected' => 1,
      'waiting' => 2,
      'treatment' => 3,
      _ => 4,
    };
    final treatmentSince = c.timeline.lastWhere(
      (e) => e.kind == 'status' && e.text.startsWith('Treatment'),
      orElse: () => const TimelineEvent(at: '', by: '', kind: '', text: ''),
    );
    return CCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CAvatar(c.patientName, size: 52, tone: levelTone(c.level)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.patientName, style: cText(20, weight: FontWeight.w700, color: p.ink)),
                    Text(line, style: cText(13, color: p.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              LevelChip(c.level),
              for (final a in c.allergyList) CChip('Allergy · $a', tone: Tone.red, bordered: true),
              CChip(c.complaint),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            label: 'Progress: ${caseStatusLabel(c.status)}',
            excludeSemantics: true,
            child: Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: i < reached ? p.primary : p.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(steps[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: cText(11, weight: FontWeight.w600, color: i < reached ? p.ink : p.muted)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (c.status == 'expected' || c.status == 'waiting') ...[
            const SizedBox(height: 12),
            CButton(c.isExpected ? 'Mark arrived' : 'Start treatment', loading: _advancing, onPressed: () => _advance(c)),
          ],
          if (c.status == 'treatment') ...[
            const SizedBox(height: 12),
            Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.tone(Tone.green).bg, borderRadius: BorderRadius.circular(12)),
              child: Text(
                treatmentSince.at.isEmpty ? 'In treatment' : 'In treatment since ${clockTime(treatmentSince.at)}',
                style: cText(14, weight: FontWeight.w600, color: p.tone(Tone.green).fg),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dischargeCard(PortalCase c) {
    final p = ClinicalPalette.of(context);
    return CCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CSectionLabel('Discharged · ${outcomeLabel(c.outcome)}'),
          const SizedBox(height: 8),
          Text(c.dischargeSummary ?? '', style: cText(14, color: p.body, height: 1.5)),
          const SizedBox(height: 6),
          Text('The patient sees this summary in VitaNet.', style: cText(12, color: p.muted)),
        ],
      ),
    );
  }

  Widget _vitalsCard(PortalCase c) {
    final p = ClinicalPalette.of(context);
    final v = c.latestVitals;
    final record = c.isActive
        ? TextButton(
            onPressed: () => _open(VitalsSheet(portalCase: c)),
            style: TextButton.styleFrom(minimumSize: const Size(44, 36)),
            child: Text('Record', style: cText(13, weight: FontWeight.w600, color: p.primary)),
          )
        : null;
    if (v == null) {
      return CCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CSectionLabel('Vitals', trailing: record),
            Text('No observations recorded yet.', style: cText(14, color: p.muted)),
          ],
        ),
      );
    }
    final tiles = vitalTiles(v);
    return CCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CSectionLabel('Latest vitals · ${clockTime(v.at)}${v.recordedBy == null ? '' : ' · ${v.recordedBy}'}',
              trailing: record),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth > 520 ? 6 : 3;
            final w = (box.maxWidth - 6 * (cols - 1)) / cols;
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in tiles) SizedBox(width: w, child: t)],
            );
          }),
          if ((v.earlyWarning ?? 0) >= 5) ...[
            const SizedBox(height: 10),
            Text('Early warning score ${v.earlyWarning} — a clinician should review now.',
                style: cText(13, weight: FontWeight.w600, color: p.tone(earlyWarningTone(v.earlyWarning)).fg)),
          ],
        ],
      ),
    );
  }

  Widget _actions(PortalCase c) {
    final p = ClinicalPalette.of(context);
    Widget action(IconData icon, String label, VoidCallback onTap, {bool danger = false}) => Expanded(
          child: Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            child: Material(
              color: p.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.line)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: SizedBox(
                  height: 64,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 20, color: danger ? p.tone(Tone.red).fg : p.ink),
                      const SizedBox(height: 4),
                      Text(label,
                          style: cText(12, weight: FontWeight.w600, color: danger ? p.tone(Tone.red).fg : p.ink)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
    return Column(
      children: [
        Row(children: [
          action(Icons.monitor_heart_outlined, 'Vitals', () => _open(VitalsSheet(portalCase: c))),
          const SizedBox(width: 8),
          action(Icons.medication_outlined, 'Order', () => _open(OrderSheet(portalCase: c))),
          const SizedBox(width: 8),
          action(Icons.bed_outlined, 'Move bed', () => _open(MoveSheet(portalCase: c))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          action(Icons.person_add_alt_outlined, 'Reassign', () => _open(ReassignSheet(portalCase: c))),
          const SizedBox(width: 8),
          action(Icons.flag_outlined, 'Triage', () => _open(LevelSheet(portalCase: c))),
          const SizedBox(width: 8),
          action(Icons.logout_rounded, 'Discharge', () => _open(DischargeSheet(portalCase: c)), danger: true),
        ]),
      ],
    );
  }

  Widget _timeline(PortalCase c) {
    final p = ClinicalPalette.of(context);
    final events = c.timeline.reversed.toList();
    Color dot(String kind) => switch (kind) {
          'warning' => p.tone(Tone.red).dot,
          'arrived' || 'status' || 'discharge' => p.tone(Tone.green).dot,
          'referral' || 'accepted' || 'created' => p.faint,
          _ => p.primary,
        };
    return CCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CSectionLabel('Timeline'),
          const SizedBox(height: 12),
          if (events.isEmpty) Text('Nothing recorded yet.', style: cText(14, color: p.muted)),
          for (var i = 0; i < events.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 12,
                    child: Column(
                      children: [
                        const SizedBox(height: 5),
                        CDot(dot(events[i].kind)),
                        if (i < events.length - 1)
                          Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: p.line)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(text: '${clockTime(events[i].at)}  ', style: cMono(13, color: p.ink)),
                              TextSpan(text: events[i].text),
                            ]),
                            style: cText(14, color: p.ink, height: 1.45),
                          ),
                          if (events[i].by.isNotEmpty) Text(events[i].by, style: cText(12, color: p.muted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (c.isActive)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _note,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: cText(15, color: p.ink),
                    decoration: cInputDecoration(context, hint: 'Add a note…'),
                    onSubmitted: (_) => _addNote(),
                  ),
                ),
                const SizedBox(width: 8),
                CButton('Add', kind: CButtonKind.dark, expand: false, height: 46, loading: _savingNote, onPressed: _addNote),
              ],
            ),
        ],
      ),
    );
  }
}

/// Reading tiles for a set of vitals, tinted when out of range.
List<Widget> vitalTiles(CaseVitals v) {
  String n(num? x, {int digits = 0}) => x == null ? '—' : x.toStringAsFixed(digits);
  return [
    VitalTile(
      label: 'HR${v.heartRate != null && (v.heartRate! > 100 || v.heartRate! < 50) ? ' · ${v.heartRate! > 100 ? 'high' : 'low'}' : ''}',
      value: n(v.heartRate),
      tone: v.heartRate != null && (v.heartRate! > 110 || v.heartRate! < 50) ? Tone.red : null,
    ),
    VitalTile(
      label: 'BP${v.bpSystolic != null && (v.bpSystolic! >= 140 || v.bpSystolic! <= 90) ? ' · ${v.bpSystolic! >= 140 ? 'high' : 'low'}' : ''}',
      value: v.bpSystolic == null ? '—' : '${v.bpSystolic}/${v.bpDiastolic ?? '—'}',
      tone: v.bpSystolic != null && (v.bpSystolic! >= 160 || v.bpSystolic! <= 90) ? Tone.red : null,
    ),
    VitalTile(
      label: 'SpO₂',
      value: v.spo2 == null ? '—' : '${n(v.spo2)}%',
      tone: v.spo2 != null && v.spo2! < 94 ? Tone.red : null,
    ),
    VitalTile(
      label: 'Temp °C',
      value: n(v.temperature, digits: 1),
      tone: v.temperature != null && (v.temperature! >= 38.1 || v.temperature! <= 35) ? Tone.orange : null,
    ),
    VitalTile(
      label: 'Resp /min',
      value: n(v.respiratoryRate),
      tone: v.respiratoryRate != null && (v.respiratoryRate! >= 21 || v.respiratoryRate! <= 11) ? Tone.orange : null,
    ),
    VitalTile(
      label: 'Early warning',
      value: v.earlyWarning == null ? '—' : '${v.earlyWarning}',
      tone: (v.earlyWarning ?? 0) >= 5 ? earlyWarningTone(v.earlyWarning) : null,
    ),
  ];
}
