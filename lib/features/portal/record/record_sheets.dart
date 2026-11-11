import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/portal/data/portal_models.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
import 'package:vitanet/features/portal/ui/clinical_ui.dart';

/// Every sheet here pops `true` once the server accepted the change.

// ─── Vitals ───

class VitalsSheet extends ConsumerStatefulWidget {
  final PortalCase portalCase;
  const VitalsSheet({super.key, required this.portalCase});

  @override
  ConsumerState<VitalsSheet> createState() => _VitalsSheetState();
}

class _VitalsSheetState extends ConsumerState<VitalsSheet> {
  final _hr = TextEditingController();
  final _bp = TextEditingController();
  final _spo2 = TextEditingController();
  final _temp = TextEditingController();
  final _rr = TextEditingController();
  final _pain = TextEditingController();
  bool? _alert = true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_hr, _bp, _spo2, _temp, _rr, _pain]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _int(TextEditingController c) => int.tryParse(c.text.trim());
  double? _dbl(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  (int?, int?) get _bpParts {
    final parts = _bp.text.split(RegExp(r'[/\s]+')).where((s) => s.isNotEmpty).toList();
    return (parts.isNotEmpty ? int.tryParse(parts[0]) : null, parts.length > 1 ? int.tryParse(parts[1]) : null);
  }

  /// A plain-words hint under a field, red when out of the usual range.
  (String, bool)? _hint(String field) {
    switch (field) {
      case 'hr':
        final v = _int(_hr);
        if (v == null) return null;
        return v > 100 ? ('Above 100 — high', true) : v < 50 ? ('Below 50 — low', true) : ('Normal', false);
      case 'bp':
        final (s, d) = _bpParts;
        if (s == null) return null;
        if (s >= 140 || (d ?? 0) >= 90) return ('Above 140/90 — high', true);
        if (s <= 90) return ('90 or below — low', true);
        return ('Normal', false);
      case 'spo2':
        final v = _dbl(_spo2);
        if (v == null) return null;
        return v < 94 ? ('Below 94% — low', true) : ('Normal', false);
      case 'temp':
        final v = _dbl(_temp);
        if (v == null) return null;
        return v >= 38.1 ? ('Fever', true) : v <= 35 ? ('Low', true) : ('Normal', false);
      case 'rr':
        final v = _int(_rr);
        if (v == null) return null;
        return (v >= 21 || v <= 11) ? ('Outside 12–20', true) : ('Normal', false);
    }
    return null;
  }

  Future<void> _save() async {
    final (sys, dia) = _bpParts;
    final vitals = CaseVitals(
      heartRate: _int(_hr),
      bpSystolic: sys,
      bpDiastolic: dia,
      spo2: _dbl(_spo2),
      temperature: _dbl(_temp),
      respiratoryRate: _int(_rr),
      pain: _int(_pain),
      alert: _alert,
    );
    if (vitals.heartRate == null && sys == null && vitals.spo2 == null && vitals.temperature == null &&
        vitals.respiratoryRate == null && vitals.pain == null) {
      showCSnack(context, 'Enter at least one reading.');
      return;
    }
    setState(() => _saving = true);
    final res = await runCAction(
      context,
      () => ref.read(hospitalApiProvider).recordVitals(widget.portalCase.id, vitals),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res == null) return;
    final score = res.latestVitals?.earlyWarning;
    showCSnack(
      context,
      score != null && score >= 5
          ? 'Saved. Early warning score $score — the team has been alerted.'
          : 'Vitals saved.',
    );
    Navigator.of(context).pop(true);
  }

  Widget _field(String key, TextEditingController c, String label, String hint, {TextInputType? type}) {
    final p = ClinicalPalette.of(context);
    final h = _hint(key);
    return CTextField(
      controller: c,
      label: label,
      hint: hint,
      mono: true,
      keyboardType: type ?? const TextInputType.numberWithOptions(decimal: true),
      helper: h?.$1,
      helperColor: h != null && h.$2 ? p.tone(Tone.red).fg : null,
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final c = widget.portalCase;
    Widget pair(Widget a, Widget b) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)],
        );
    return CSheet(
      title: 'Record vitals',
      subtitle: '${c.patientName}${c.wardName == null ? '' : ' · ${c.wardName}'}${c.bed == null ? '' : ', ${c.bed}'}',
      gap: 14,
      actions: [CButton('Save vitals', loading: _saving, onPressed: _save)],
      children: [
        pair(_field('hr', _hr, 'Heart rate (bpm)', 'bpm'), _field('bp', _bp, 'Blood pressure', 'systolic/diastolic', type: TextInputType.text)),
        pair(_field('spo2', _spo2, 'SpO₂ (%)', '%'), _field('temp', _temp, 'Temp (°C)', '°C')),
        pair(_field('rr', _rr, 'Resp. rate (/min)', 'breaths/min'), _field('pain', _pain, 'Pain (0–10)', '0 to 10')),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fully alert', style: cText(15, weight: FontWeight.w600, color: p.ink)),
                  Text('Turn off if confused, drowsy or hard to wake', style: cText(12, color: p.muted)),
                ],
              ),
            ),
            CSwitch(value: _alert ?? true, onChanged: (v) => setState(() => _alert = v)),
          ],
        ),
        Text(
          "Leave a field empty if you didn't measure it. Saved readings update the record's tiles for everyone on shift.",
          style: cText(12, color: p.muted),
        ),
      ],
    );
  }
}

// ─── Order medication ───

class OrderSheet extends ConsumerStatefulWidget {
  final PortalCase portalCase;
  const OrderSheet({super.key, required this.portalCase});

  @override
  ConsumerState<OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends ConsumerState<OrderSheet> {
  final _drug = TextEditingController();
  final _dose = TextEditingController();
  final _freq = TextEditingController();
  final _duration = TextEditingController();
  final _instructions = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_drug, _dose, _freq, _duration, _instructions]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _allergyClash {
    final drug = _drug.text.trim().toLowerCase();
    if (drug.isEmpty) return null;
    for (final a in widget.portalCase.allergyList) {
      final al = a.toLowerCase();
      if (drug.contains(al) || al.contains(drug)) return a;
    }
    return null;
  }

  Future<void> _save() async {
    if ([_drug, _dose, _freq, _duration].any((c) => c.text.trim().isEmpty)) {
      showCSnack(context, 'Fill in the medication, dose, how often and how long.');
      return;
    }
    setState(() => _saving = true);
    final res = await runCAction(
      context,
      () => ref.read(hospitalApiProvider).orderPrescription(
            widget.portalCase.id,
            medication: _drug.text.trim(),
            dosage: _dose.text.trim(),
            frequency: _freq.text.trim(),
            duration: _duration.text.trim(),
            instructions: _instructions.text.trim().isEmpty ? null : _instructions.text.trim(),
          ),
      success: 'Ordered ${_drug.text.trim()}.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final clash = _allergyClash;
    return CSheet(
      title: 'Order medication',
      subtitle: widget.portalCase.allergyList.isEmpty
          ? widget.portalCase.patientName
          : '${widget.portalCase.patientName} · allergic to ${widget.portalCase.allergyList.join(', ')}',
      gap: 14,
      actions: [CButton('Sign & order', loading: _saving, onPressed: clash == null ? _save : null)],
      children: [
        CTextField(controller: _drug, label: 'Medication', hint: 'e.g. Amoxicillin', onChanged: (_) => setState(() {})),
        if (clash != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.tone(Tone.red).bg, borderRadius: BorderRadius.circular(10)),
            child: Text('${widget.portalCase.patientName} is allergic to $clash. Choose another medication.',
                style: cText(13, weight: FontWeight.w600, color: p.tone(Tone.red).fg)),
          ),
        Row(
          children: [
            Expanded(child: CTextField(controller: _dose, label: 'Dose', hint: 'e.g. 500 mg')),
            const SizedBox(width: 12),
            Expanded(child: CTextField(controller: _freq, label: 'How often', hint: 'e.g. Twice daily')),
          ],
        ),
        CTextField(controller: _duration, label: 'For how long', hint: 'e.g. 5 days'),
        CTextField(controller: _instructions, label: 'Instructions (optional)', hint: 'e.g. Take with food'),
      ],
    );
  }
}

// ─── Move ward / bed ───

class MoveSheet extends ConsumerStatefulWidget {
  final PortalCase portalCase;
  const MoveSheet({super.key, required this.portalCase});

  @override
  ConsumerState<MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends ConsumerState<MoveSheet> {
  late final _bed = TextEditingController(text: widget.portalCase.bed ?? '');
  late int? _ward = widget.portalCase.wardId;
  bool _saving = false;

  @override
  void dispose() {
    _bed.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final c = widget.portalCase;
    setState(() => _saving = true);
    final res = await runCAction(
      context,
      () => ref.read(hospitalApiProvider).updateCase(
            c.id,
            wardId: _ward != c.wardId ? _ward : null,
            clearWard: _ward == null && c.wardId != null,
            bed: _bed.text.trim(),
          ),
      success: 'Location updated.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) {
      ref.invalidate(capacityProvider);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final cap = ref.watch(capacityProvider);
    return CSheet(
      title: 'Move ward or bed',
      subtitle: widget.portalCase.patientName,
      actions: [CButton('Save', loading: _saving, onPressed: _save)],
      children: [
        ...cap.when(
          loading: () => const [CLoading()],
          error: (e, _) => [CError(error: e, onRetry: () => ref.invalidate(capacityProvider))],
          data: (c) => [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CSectionLabel('Ward'),
                const SizedBox(height: 8),
                for (final w in c.wards) ...[
                  COption(
                    title: w.name,
                    trailing: w.id == widget.portalCase.wardId
                        ? 'Here now'
                        : (w.bedsFree == 0 ? 'Full' : '${w.bedsFree} free'),
                    trailingColor: w.bedsFree == 0 && w.id != widget.portalCase.wardId ? p.tone(Tone.red).fg : null,
                    enabled: w.bedsFree > 0 || w.id == widget.portalCase.wardId,
                    selected: _ward == w.id,
                    onTap: () => setState(() => _ward = w.id),
                  ),
                  const SizedBox(height: 6),
                ],
                COption(
                  title: 'No ward (waiting area)',
                  selected: _ward == null,
                  onTap: () => setState(() => _ward = null),
                ),
              ],
            ),
          ],
        ),
        CTextField(controller: _bed, label: 'Bed or bay', hint: 'Leave empty to clear'),
      ],
    );
  }
}

// ─── Reassign ───

class ReassignSheet extends ConsumerStatefulWidget {
  final PortalCase portalCase;
  const ReassignSheet({super.key, required this.portalCase});

  @override
  ConsumerState<ReassignSheet> createState() => _ReassignSheetState();
}

class _ReassignSheetState extends ConsumerState<ReassignSheet> {
  late String? _uid = widget.portalCase.assigneeUid;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final res = await runCAction(
      context,
      () => ref.read(hospitalApiProvider).updateCase(widget.portalCase.id, assigneeUid: _uid ?? ''),
      success: 'Reassigned.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cap = ref.watch(capacityProvider);
    return CSheet(
      title: 'Who is responsible?',
      subtitle: widget.portalCase.patientName,
      actions: [CButton('Save', loading: _saving, onPressed: _save)],
      children: cap.when(
        loading: () => const [CLoading()],
        error: (e, _) => [CError(error: e, onRetry: () => ref.invalidate(capacityProvider))],
        data: (c) {
          final team = [...c.team]..sort((a, b) {
              if (a.onDuty != b.onDuty) return a.onDuty ? -1 : 1;
              return a.activeCases.compareTo(b.activeCases);
            });
          return [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final m in team) ...[
                  COption(
                    leading: CAvatar(m.fullName),
                    title: m.fullName,
                    subtitle: '${m.role.label} · ${m.onDuty ? 'on shift' : 'off shift'} · ${m.activeCases} active',
                    selected: _uid == m.firebaseUid,
                    onTap: () => setState(() => _uid = m.firebaseUid),
                  ),
                  const SizedBox(height: 6),
                ],
                COption(
                  leading: const CAvatar('', tone: Tone.neutral),
                  title: 'Unassigned',
                  selected: _uid == null,
                  onTap: () => setState(() => _uid = null),
                ),
              ],
            ),
          ];
        },
      ),
    );
  }
}

// ─── Triage level ───

class LevelSheet extends ConsumerStatefulWidget {
  final PortalCase portalCase;
  const LevelSheet({super.key, required this.portalCase});

  @override
  ConsumerState<LevelSheet> createState() => _LevelSheetState();
}

class _LevelSheetState extends ConsumerState<LevelSheet> {
  late String _level = widget.portalCase.level;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final res = await runCAction(
      context,
      () => ref.read(hospitalApiProvider).updateCase(widget.portalCase.id, level: _level),
      success: 'Triage level updated.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    const levels = {
      'urgent': 'Life-threatening or could become so — treat now',
      'doctor': 'Needs a doctor today',
      'routine': 'Can safely wait',
    };
    return CSheet(
      title: 'Triage level',
      subtitle: widget.portalCase.patientName,
      actions: [CButton('Save', loading: _saving, onPressed: _level == widget.portalCase.level ? null : _save)],
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in levels.entries) ...[
              COption(
                leading: CDot(ClinicalPalette.of(context).tone(levelTone(e.key)).dot, size: 12),
                title: levelLabel(e.key),
                subtitle: e.value,
                selected: _level == e.key,
                onTap: () => setState(() => _level = e.key),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ],
    );
  }
}

// ─── Discharge ───

class DischargeSheet extends ConsumerStatefulWidget {
  final PortalCase portalCase;
  const DischargeSheet({super.key, required this.portalCase});

  @override
  ConsumerState<DischargeSheet> createState() => _DischargeSheetState();
}

class _DischargeSheetState extends ConsumerState<DischargeSheet> {
  final _summary = TextEditingController();
  String _outcome = 'home';
  bool _saving = false;

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_summary.text.trim().length < 3) {
      showCSnack(context, 'Write a short summary for the patient.');
      return;
    }
    setState(() => _saving = true);
    final res = await runCAction(
      context,
      () => ref.read(hospitalApiProvider).dischargeCase(widget.portalCase.id, _summary.text.trim(), outcome: _outcome),
      success: '${widget.portalCase.patientName} discharged.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) {
      ref.invalidate(capacityProvider);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final c = widget.portalCase;
    const outcomes = ['home', 'admitted', 'transferred', 'left'];
    final where = [c.wardName, c.bed].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    return CSheet(
      title: 'Discharge ${c.patientName}',
      subtitle: where.isEmpty ? 'Closes the case.' : 'Closes the case and frees $where.',
      actions: [
        CButton('Cancel', kind: CButtonKind.secondary, onPressed: () => Navigator.of(context).pop()),
        CButton('Discharge', kind: CButtonKind.dark, loading: _saving, onPressed: _save),
      ],
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CSectionLabel('Outcome'),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, box) {
              final w = (box.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in outcomes)
                    SizedBox(
                      width: w,
                      child: COption(
                        title: outcomeLabel(o),
                        selected: _outcome == o,
                        onTap: () => setState(() => _outcome = o),
                      ),
                    ),
                ],
              );
            }),
          ],
        ),
        CTextField(
          controller: _summary,
          label: 'Summary for the patient',
          hint: 'What happened, treatment given, medicines and follow-up — in plain words.',
          maxLines: 5,
          helper: 'The patient reads this in VitaNet under Visits.',
        ),
        if (_outcome == 'left')
          Text('Add when to come back and what to watch for.', style: cText(12, color: p.muted)),
      ],
    );
  }
}
