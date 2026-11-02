import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vitanet/features/admin/services/hospital_api_service.dart';
import 'package:vitanet/features/admin/widgets/staff_demo_data.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

// ─── Patient record sheet (PatientDetail.dc.html) ───

/// Opens the patient record bottom sheet. [onUpdated] fires when a note is
/// added or the bed is transferred.
Future<void> showPatientRecordSheet(
  BuildContext context,
  StaffPatientRecord record, {
  ValueChanged<StaffPatientRecord>? onUpdated,
}) {
  return showStaffSheet<void>(
    context,
    tall: true,
    builder: (_) => _PatientRecordSheet(record: record, onUpdated: onUpdated),
  );
}

class _PatientRecordSheet extends StatefulWidget {
  final StaffPatientRecord record;
  final ValueChanged<StaffPatientRecord>? onUpdated;
  const _PatientRecordSheet({required this.record, this.onUpdated});

  @override
  State<_PatientRecordSheet> createState() => _PatientRecordSheetState();
}

class _PatientRecordSheetState extends State<_PatientRecordSheet> {
  late StaffPatientRecord _r = widget.record;

  String get _now => DateFormat('HH:mm').format(DateTime.now());

  void _update(StaffPatientRecord r) {
    setState(() => _r = r);
    widget.onUpdated?.call(r);
  }

  Future<void> _addNote() async {
    final note = await showStaffDialog<String>(
      context,
      builder: (_) => const _AddNoteDialog(),
    );
    if (note == null || note.trim().isEmpty || !mounted) return;
    _update(_r.copyWith(timeline: [TimelineEntry(_now, note.trim()), ..._r.timeline]));
    ApiService().addPatientNote(_r.id, note.trim());
    showStaffSnack(context, 'Note added to ${_r.name}\'s record');
  }

  Future<void> _transfer() async {
    final bed = await showStaffSheet<String>(
      context,
      builder: (ctx) => _BedPicker(current: _r.location),
    );
    if (bed == null || !mounted) return;
    _update(_r.copyWith(
      location: bed,
      timeline: [TimelineEntry(_now, 'Transfer to $bed requested.'), ..._r.timeline],
    ));
    ApiService().transferPatient(_r.id, bed);
    showStaffSnack(context, 'Transfer to $bed requested');
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final statusTone = p.tone(_r.status.tone);
    final danger = p.tone(StaffTone.danger);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: statusTone.bg, shape: BoxShape.circle),
                child: Text(
                  _r.initials,
                  style: staffBody(17, weight: FontWeight.w800, color: statusTone.fg),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_r.name, style: staffHeading(19, color: p.ink)),
                    const SizedBox(height: 2),
                    Text(
                      '${_r.age} ${_r.sex} · ${_r.id} · ${_r.location}',
                      style: staffBody(13, color: p.muted),
                    ),
                  ],
                ),
              ),
              StaffIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Close',
                size: 40,
                radius: 12,
                background: p.chip,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StaffTag(_r.status.label.toUpperCase(),
                          tone: _r.status.tone, fontSize: 12, weight: FontWeight.w800),
                      if (_r.diagnosis != null)
                        StaffTag(_r.diagnosis!,
                            tone: StaffTone.neutral, fontSize: 12, weight: FontWeight.w600),
                      if (_r.allergy != null)
                        StaffTag(_r.allergy!,
                            tone: StaffTone.orange, fontSize: 12, weight: FontWeight.w600),
                    ],
                  ),
                  if (_r.vitals.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (var i = 0; i < _r.vitals.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(child: _VitalTile(_r.vitals[i], danger: danger)),
                        ],
                      ],
                    ),
                  ],
                  if (_r.timeline.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'TIMELINE',
                      style: staffBody(12, weight: FontWeight.w700, color: p.muted, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      margin: const EdgeInsets.only(left: 5),
                      padding: const EdgeInsets.only(left: 14),
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: p.track, width: 2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < _r.timeline.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            _TimelineRow(_r.timeline[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (_r.note != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: p.fill,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clinical notes${_r.noteAuthor != null ? ' · ${_r.noteAuthor}' : ''}',
                            style: staffBody(12, weight: FontWeight.w700, color: p.body),
                          ),
                          const SizedBox(height: 6),
                          Text(_r.note!, style: staffBody(13, color: p.body, height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StaffButton(
                  'Transfer bed',
                  kind: StaffButtonKind.secondary,
                  fontSize: 14,
                  onPressed: _transfer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: StaffButton('Add note', fontSize: 14, onPressed: _addNote)),
            ],
          ),
        ],
      ),
    );
  }
}

class _VitalTile extends StatelessWidget {
  final VitalReading v;
  final ToneColors danger;
  const _VitalTile(this.v, {required this.danger});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final alertBg = p.dark ? danger.bg : const Color(0xFFFEF2F2);
    final valueColor = v.alert ? (p.dark ? danger.fg : kStaffDanger) : p.ink;
    return Semantics(
      label: '${v.label} ${v.value}${v.alert ? ', abnormal' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: v.alert ? alertBg : p.fill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              v.label,
              style: staffBody(10, weight: FontWeight.w700, color: v.alert ? danger.fg : p.inkSoft),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                v.value,
                style: staffBody(v.value.length > 5 ? 15 : 17, weight: FontWeight.w800, color: valueColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TimelineEntry e;
  const _TimelineRow(this.e);

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final dot = switch (e.tone) {
      TimelineTone.critical => p.tone(StaffTone.danger).strong,
      TimelineTone.action => p.tone(StaffTone.brand).strong,
      TimelineTone.neutral => p.faint,
    };
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(left: -21, top: 4, child: StaffDot(dot, size: 10)),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: e.time, style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: ' ${e.text}'),
            ],
          ),
          style: staffBody(13, color: p.ink, height: 1.45),
        ),
      ],
    );
  }
}

class _AddNoteDialog extends StatefulWidget {
  const _AddNoteDialog();

  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add clinical note', style: staffHeading(20, color: p.ink)),
          const SizedBox(height: 6),
          Text(
            'The note is time-stamped and added to the patient timeline.',
            style: staffBody(13, color: p.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _c,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            style: staffBody(14, color: p.ink, height: 1.5),
            decoration: staffInputDecoration(context, hint: 'e.g. Pain reassessed, 3/10'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StaffButton('Cancel',
                    kind: StaffButtonKind.secondary, onPressed: () => Navigator.pop(context)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ListenableBuilder(
                  listenable: _c,
                  builder: (context, _) => StaffButton(
                    'Save note',
                    onPressed: _c.text.trim().isEmpty ? null : () => Navigator.pop(context, _c.text),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BedPicker extends StatelessWidget {
  final String current;
  const _BedPicker({required this.current});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Transfer bed', style: staffHeading(20, color: p.ink)),
          const SizedBox(height: 4),
          Text('Currently: $current', style: staffBody(13, color: p.muted)),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: StaffGroup(
                children: [
                  for (final b in demoFreeBeds)
                    Material(
                      color: p.fill,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, b.replaceAll(' (free)', '')),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(Icons.bed_outlined, size: 20, color: p.accent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(b, style: staffBody(14, weight: FontWeight.w600, color: p.ink)),
                              ),
                              Icon(Icons.chevron_right_rounded, color: p.faint),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Add patient sheet (AddPatient.dc.html) ───

enum TriageChoice {
  routine('Routine', Color(0xFF065F46), Color(0xFF047857), Color(0xFFD1FAE5), PatientStatus.stable),
  doctor('Doctor', Color(0xFF9A3412), Color(0xFFC2410C), Color(0xFFFFEDD5), PatientStatus.observation),
  urgent('Urgent', Color(0xFF991B1B), Color(0xFFB91C1C), Color(0xFFFEE2E2), PatientStatus.critical),
  resus('Resus', Color(0xFF7F1D1D), Color(0xFF7F1D1D), Color(0xFFFECACA), PatientStatus.critical);

  final String label;
  final Color text;
  final Color border;
  final Color fill;
  final PatientStatus status;
  const TriageChoice(this.label, this.text, this.border, this.fill, this.status);
}

/// Opens the "New patient entry" sheet. Returns the created record.
Future<StaffPatientRecord?> showAddPatientSheet(BuildContext context, {required String nextId}) {
  return showStaffSheet<StaffPatientRecord>(
    context,
    tall: true,
    builder: (_) => _AddPatientSheet(nextId: nextId),
  );
}

class _AddPatientSheet extends StatefulWidget {
  final String nextId;
  const _AddPatientSheet({required this.nextId});

  @override
  State<_AddPatientSheet> createState() => _AddPatientSheetState();
}

class _AddPatientSheetState extends State<_AddPatientSheet> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _complaint = TextEditingController();
  String _sex = 'Female';
  TriageChoice _triage = TriageChoice.doctor;
  String _ward = demoFreeBeds.first;
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _complaint.dispose();
    super.dispose();
  }

  void _create() {
    setState(() => _submitted = true);
    final age = int.tryParse(_age.text.trim());
    if (_name.text.trim().isEmpty || age == null || _complaint.text.trim().isEmpty) return;
    final location = _ward.replaceAll(' (free)', '');
    final record = StaffPatientRecord(
      id: widget.nextId,
      name: _name.text.trim(),
      age: age,
      sex: _sex == 'Female' ? 'F' : 'M',
      location: location,
      status: _triage.status,
      diagnosis: _complaint.text.trim(),
      timeline: [
        TimelineEntry(
          DateFormat('HH:mm').format(DateTime.now()),
          'Registered. Triage ${_triage.label.toLowerCase()}, assigned to $location.',
          _triage.status == PatientStatus.critical ? TimelineTone.critical : TimelineTone.neutral,
        ),
      ],
    );
    Navigator.pop(context, record);
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    String? err(TextEditingController c, String msg, {bool number = false}) {
      if (!_submitted) return null;
      if (c.text.trim().isEmpty) return msg;
      if (number && int.tryParse(c.text.trim()) == null) return 'Enter a number';
      return null;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('New patient entry', style: staffHeading(20, color: p.ink))),
              StaffIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Close',
                size: 40,
                radius: 12,
                background: p.chip,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StaffField(
                    label: 'Full name',
                    child: TextField(
                      controller: _name,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      style: staffBody(15, color: p.ink),
                      decoration: staffInputDecoration(context, hint: 'Adwoa Frimpong')
                          .copyWith(errorText: err(_name, 'Enter the patient\'s name')),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: StaffField(
                          label: 'Age',
                          child: TextField(
                            controller: _age,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: staffBody(15, color: p.ink),
                            decoration: staffInputDecoration(context, hint: '41')
                                .copyWith(errorText: err(_age, 'Required', number: true)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: StaffField(
                          label: 'Sex',
                          child: StaffSelect<String>(
                            value: _sex,
                            items: const ['Female', 'Male'],
                            labelOf: (s) => s,
                            onChanged: (s) => setState(() => _sex = s),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  StaffField(
                    label: 'Chief complaint',
                    child: TextField(
                      controller: _complaint,
                      textCapitalization: TextCapitalization.sentences,
                      style: staffBody(15, color: p.ink),
                      decoration: staffInputDecoration(context, hint: 'Shortness of breath, 2 days')
                          .copyWith(errorText: err(_complaint, 'Describe the main complaint')),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Triage level', style: staffBody(13, weight: FontWeight.w600, color: p.ink)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final t in TriageChoice.values) ...[
                        if (t != TriageChoice.routine) const SizedBox(width: 6),
                        Expanded(child: _triageButton(t, p)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  StaffField(
                    label: 'Assign to ward',
                    child: StaffSelect<String>(
                      value: _ward,
                      items: demoFreeBeds,
                      labelOf: (s) => s,
                      onChanged: (s) => setState(() => _ward = s),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          StaffButton('Create patient record', height: 54, radius: 16, fontSize: 16, onPressed: _create),
        ],
      ),
    );
  }

  Widget _triageButton(TriageChoice t, StaffPalette p) {
    final sel = _triage == t;
    final textColor = p.dark ? (sel ? Colors.white : p.inkSoft) : t.text;
    return Semantics(
      selected: sel,
      button: true,
      label: 'Triage ${t.label}',
      excludeSemantics: true,
      child: Material(
        color: sel ? (p.dark ? t.border : t.fill) : p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: sel ? t.border : p.line, width: sel ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _triage = t),
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                t.label,
                style: staffBody(12, weight: sel ? FontWeight.w800 : FontWeight.w700, color: textColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
