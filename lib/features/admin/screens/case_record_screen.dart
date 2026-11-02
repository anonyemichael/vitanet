import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/screens/referrals_screen.dart';
import 'package:vitanet/features/admin/widgets/portal_common.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

void openCase(BuildContext context, String id) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => CaseRecordScreen(caseId: id)));
}

/// Case record: details, timeline, notes, status, ward/bed, assignee,
/// discharge.
class CaseRecordScreen extends ConsumerStatefulWidget {
  final String caseId;
  const CaseRecordScreen({super.key, required this.caseId});

  @override
  ConsumerState<CaseRecordScreen> createState() => _CaseRecordScreenState();
}

class _CaseRecordScreenState extends ConsumerState<CaseRecordScreen> {
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<bool> _apply(Future<PortalCase> Function() call, {String? success}) async {
    setState(() => _busy = true);
    final r = await runPortalAction(context, call, success: success);
    if (!mounted) return false;
    setState(() => _busy = false);
    if (r != null) invalidatePortalData(ref);
    return r != null;
  }

  Future<void> _addNote() async {
    final text = _note.text.trim();
    if (text.isEmpty) return;
    final ok = await _apply(() => ref.read(hospitalApiProvider).addNote(widget.caseId, text), success: 'Note added.');
    if (ok) _note.clear();
  }

  Future<void> _sheet(Widget sheet) async {
    final changed = await showStaffSheet<bool>(context, tall: true, builder: (_) => sheet);
    if (changed == true && mounted) invalidatePortalData(ref);
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final value = ref.watch(caseProvider(widget.caseId));
    final c = value.valueOrNull;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          PortalHeader(
            title: c?.patientName ?? 'Case',
            subtitle: c == null ? null : '${caseStatusLabel(c.status)} · opened ${relativeTime(c.createdAt)}',
            onBack: () => Navigator.of(context).pop(),
          ),
          if (_busy) LinearProgressIndicator(minHeight: 2, color: p.accent, backgroundColor: Colors.transparent),
          Expanded(
            child: PortalAsyncList<PortalCase>(
              value: value,
              onRefresh: () => ref.refresh(caseProvider(widget.caseId).future),
              builder: (c) => _body(context, c),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, PortalCase c) {
    final p = StaffPalette.of(context);
    final api = ref.read(hospitalApiProvider);
    return [
      StaffCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              StaffTag(levelLabel(c.level), tone: levelTone(c.level)),
              StaffTag(caseStatusLabel(c.status),
                  tone: switch (c.status) {
                    'waiting' => StaffTone.amber,
                    'treatment' => StaffTone.indigo,
                    _ => StaffTone.green,
                  }),
              if (c.referralId != null) const StaffTag('VitaNet referral', tone: StaffTone.brand),
            ]),
            const SizedBox(height: 12),
            Text(c.complaint, style: staffHeading(18, weight: FontWeight.w700, color: p.ink)),
            const SizedBox(height: 8),
            InfoRow('Age / sex', ageSex(c.age, c.sex)),
            InfoRow('Ward', c.wardName ?? 'Not in a ward'),
            InfoRow('Bed', c.bed ?? ''),
            InfoRow('Assigned to', c.assigneeName ?? 'Unassigned'),
            InfoRow('Allergies', c.allergies ?? 'None recorded', tone: c.allergies == null ? null : StaffTone.danger),
            InfoRow('Updated', relativeTime(c.updatedAt)),
          ],
        ),
      ),
      if (c.referral != null) ...[
        const SizedBox(height: 10),
        StaffButton('View referral summary',
            kind: StaffButtonKind.secondary,
            icon: Icons.description_outlined,
            onPressed: () => openReferral(context, c.referral!.id)),
      ],
      if (c.isDischarged) ...[
        const PortalSectionTitle('Discharge summary'),
        StaffCard(child: Text(c.dischargeSummary ?? '', style: staffBody(14, color: p.body, height: 1.55))),
      ] else ...[
        const PortalSectionTitle('Actions'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ActionChip(
              icon: c.status == 'waiting' ? Icons.play_arrow_rounded : Icons.undo_rounded,
              label: c.status == 'waiting' ? 'Start treatment' : 'Back to waiting',
              onTap: _busy
                  ? null
                  : () => _apply(
                      () => api.updateCase(c.id, status: c.status == 'waiting' ? 'treatment' : 'waiting'),
                      success: 'Status updated.'),
            ),
            _ActionChip(
                icon: Icons.bed_outlined,
                label: 'Move ward / bed',
                onTap: _busy ? null : () => _sheet(MoveCaseSheet(portalCase: c))),
            _ActionChip(
                icon: Icons.person_outline_rounded,
                label: 'Reassign',
                onTap: _busy ? null : () => _sheet(ReassignCaseSheet(portalCase: c))),
            _ActionChip(
                icon: Icons.logout_rounded,
                label: 'Discharge',
                danger: true,
                onTap: _busy ? null : () => _sheet(DischargeCaseSheet(portalCase: c))),
          ],
        ),
      ],
      const PortalSectionTitle('Add note'),
      StaffCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              style: staffBody(15, color: p.ink),
              decoration: staffInputDecoration(context, hint: 'Observation, vitals, plan…', fill: p.fill),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: StaffButton('Add note',
                  expand: false, height: 44, icon: Icons.note_add_outlined, onPressed: _busy ? null : _addNote),
            ),
          ],
        ),
      ),
      const PortalSectionTitle('Timeline'),
      if (c.timeline.isEmpty)
        const StaffCard(child: PortalEmpty(icon: Icons.timeline_rounded, title: 'Nothing on the timeline yet'))
      else
        StaffCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            for (final e in c.timeline.reversed) _TimelineRow(event: e),
          ]),
        ),
    ];
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  const _ActionChip({required this.icon, required this.label, this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final fg = danger ? p.tone(StaffTone.danger).fg : p.ink;
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SizedBox(
            height: 46,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 19, color: fg),
              const SizedBox(width: 8),
              Text(label, style: staffBody(14, weight: FontWeight.w600, color: fg)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TimelineEvent event;
  const _TimelineRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final (icon, tone) = switch (event.kind) {
      'note' => (Icons.sticky_note_2_outlined, StaffTone.sky),
      'status' => (Icons.swap_horiz_rounded, StaffTone.indigo),
      'move' => (Icons.bed_outlined, StaffTone.violet),
      'assign' => (Icons.person_outline_rounded, StaffTone.brand),
      'discharge' => (Icons.logout_rounded, StaffTone.green),
      'referral' => (Icons.move_to_inbox_outlined, StaffTone.brand),
      _ => (Icons.circle_outlined, StaffTone.neutral),
    };
    final t = p.tone(tone);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: p.dark ? t.fg : t.strong),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.text, style: staffBody(14, color: p.ink, height: 1.45)),
                const SizedBox(height: 2),
                Text([event.by, relativeTime(event.at)].where((s) => s.isNotEmpty).join(' · '),
                    style: staffBody(12, color: p.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Move to another ward (or out of a ward) and/or change bed.
class MoveCaseSheet extends ConsumerStatefulWidget {
  final PortalCase portalCase;
  const MoveCaseSheet({super.key, required this.portalCase});

  @override
  ConsumerState<MoveCaseSheet> createState() => _MoveCaseSheetState();
}

class _MoveCaseSheetState extends ConsumerState<MoveCaseSheet> {
  late int _ward = widget.portalCase.wardId ?? -1;
  late final _bed = TextEditingController(text: widget.portalCase.bed);
  bool _saving = false;

  @override
  void dispose() {
    _bed.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final c = widget.portalCase;
    final clear = _ward < 0 && c.wardId != null;
    setState(() => _saving = true);
    final r = await runPortalAction(
      context,
      () => ref.read(hospitalApiProvider).updateCase(
            c.id,
            wardId: _ward >= 0 && _ward != c.wardId ? _ward : null,
            clearWard: clear,
            bed: _bed.text.trim(),
          ),
      success: 'Location updated.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (r != null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cap = ref.watch(capacityProvider);
    final current = widget.portalCase.wardId;
    return PortalSheet(
      title: 'Move ward / bed',
      actions: [
        StaffButton('Cancel', kind: StaffButtonKind.secondary, onPressed: () => Navigator.of(context).pop()),
        StaffButton('Save', loading: _saving, onPressed: cap.hasValue ? _submit : null),
      ],
      children: cap.when(
        loading: () => const [PortalLoading()],
        error: (e, _) => [PortalError(error: e, onRetry: () => ref.invalidate(capacityProvider))],
        data: (cap) {
          final options = cap.wards.where((w) => w.id == current || w.bedsFree > 0).toList();
          return [
            StaffField(
              label: 'Ward',
              child: StaffSelect<int>(
                value: options.any((w) => w.id == _ward) ? _ward : -1,
                items: [-1, ...options.map((w) => w.id)],
                labelOf: (id) {
                  if (id < 0) return 'Not in a ward';
                  final w = options.firstWhere((w) => w.id == id);
                  return w.id == current ? '${w.name} (current)' : '${w.name} · ${w.bedsFree} free';
                },
                icon: Icons.bed_outlined,
                onChanged: (v) => setState(() => _ward = v),
              ),
            ),
            const SizedBox(height: 14),
            PortalTextField(controller: _bed, label: 'Bed', hint: 'Leave empty to clear'),
          ];
        },
      ),
    );
  }
}

class ReassignCaseSheet extends ConsumerStatefulWidget {
  final PortalCase portalCase;
  const ReassignCaseSheet({super.key, required this.portalCase});

  @override
  ConsumerState<ReassignCaseSheet> createState() => _ReassignCaseSheetState();
}

class _ReassignCaseSheetState extends ConsumerState<ReassignCaseSheet> {
  late String _uid = widget.portalCase.assigneeUid ?? '';
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    final r = await runPortalAction(
      context,
      () => ref.read(hospitalApiProvider).updateCase(widget.portalCase.id, assigneeUid: _uid),
      success: _uid.isEmpty ? 'Case unassigned.' : 'Case reassigned.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (r != null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cap = ref.watch(capacityProvider);
    return PortalSheet(
      title: 'Reassign case',
      actions: [
        StaffButton('Cancel', kind: StaffButtonKind.secondary, onPressed: () => Navigator.of(context).pop()),
        StaffButton('Save', loading: _saving, onPressed: cap.hasValue ? _submit : null),
      ],
      children: cap.when(
        loading: () => const [PortalLoading()],
        error: (e, _) => [PortalError(error: e, onRetry: () => ref.invalidate(capacityProvider))],
        data: (cap) => [
          StaffGroup(children: [
            for (final uid in ['', ...cap.team.map((m) => m.firebaseUid)])
              _RadioRow(
                selected: _uid == uid,
                onTap: () => setState(() => _uid = uid),
                child: uid.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        child: Text('Unassigned',
                            style: staffBody(15, weight: FontWeight.w600, color: StaffPalette.of(context).ink)),
                      )
                    : TeamMemberTile(member: cap.team.firstWhere((m) => m.firebaseUid == uid)),
              ),
          ]),
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  const _RadioRow({required this.selected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Row(children: [
          Expanded(child: IgnorePointer(child: child)),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? p.accent : p.faint),
          ),
        ]),
      ),
    );
  }
}

class DischargeCaseSheet extends ConsumerStatefulWidget {
  final PortalCase portalCase;
  const DischargeCaseSheet({super.key, required this.portalCase});

  @override
  ConsumerState<DischargeCaseSheet> createState() => _DischargeCaseSheetState();
}

class _DischargeCaseSheetState extends ConsumerState<DischargeCaseSheet> {
  final _summary = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = _summary.text.trim();
    if (s.length < 3) {
      showStaffSnack(context, 'Write a short discharge summary.');
      return;
    }
    setState(() => _saving = true);
    final r = await runPortalAction(
      context,
      () => ref.read(hospitalApiProvider).dischargeCase(widget.portalCase.id, s),
      success: '${widget.portalCase.patientName} discharged.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (r != null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return PortalSheet(
      title: 'Discharge patient',
      subtitle: 'Frees their bed and closes the case. This can’t be undone.',
      actions: [
        StaffButton('Cancel', kind: StaffButtonKind.secondary, onPressed: () => Navigator.of(context).pop()),
        StaffButton('Discharge', kind: StaffButtonKind.dangerOutline, loading: _saving, onPressed: _submit),
      ],
      children: [
        PortalTextField(
          controller: _summary,
          label: 'Discharge summary',
          hint: 'Diagnosis, treatment given, follow-up advice…',
          maxLines: 6,
        ),
      ],
    );
  }
}
