import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/screens/case_record_screen.dart';
import 'package:vitanet/features/admin/widgets/portal_common.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

/// Cases board: Waiting / In treatment / Discharged, "Mine" filter,
/// walk-in "New case".
class CasesScreen extends ConsumerStatefulWidget {
  final bool active;
  const CasesScreen({super.key, this.active = true});

  @override
  ConsumerState<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends ConsumerState<CasesScreen> {
  static const _statuses = ['waiting', 'treatment', 'discharged'];
  int _tab = 0;
  bool _mine = false;

  Future<void> _newCase() async {
    final created = await showStaffSheet<PortalCase>(context, tall: true, builder: (_) => const NewCaseSheet());
    if (created == null || !mounted) return;
    invalidatePortalData(ref);
    showStaffSnack(context, 'Case created for ${created.patientName}.');
    openCase(context, created.id);
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final CaseQuery q = (status: _statuses[_tab], mine: _mine);
    final value = ref.watch(casesProvider(q));
    return AutoRefresh(
      active: widget.active,
      onTick: () => ref.invalidate(casesProvider(q)),
      child: Column(
        children: [
          PortalHeader(
            title: 'Cases',
            trailing: HeaderIconButton(icon: Icons.add_rounded, tooltip: 'New walk-in case', onPressed: _newCase),
            bottom: StaffSegmented(
              labels: [for (final s in _statuses) caseStatusLabel(s)],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: PortalAsyncList<List<PortalCase>>(
              value: value,
              onRefresh: () => ref.refresh(casesProvider(q).future),
              header: [
                Row(
                  children: [
                    StaffPill(label: 'All cases', selected: !_mine, onTap: () => setState(() => _mine = false)),
                    const SizedBox(width: 8),
                    StaffPill(label: 'Mine', selected: _mine, onTap: () => setState(() => _mine = true)),
                    const Spacer(),
                    if (value.valueOrNull != null)
                      Text('${value.valueOrNull!.length}', style: staffBody(13, weight: FontWeight.w700, color: p.muted)),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              builder: (list) => list.isEmpty
                  ? [
                      PortalEmpty(
                        icon: Icons.assignment_ind_outlined,
                        title: switch (q.status) {
                          'waiting' => _mine ? 'No waiting cases assigned to you' : 'No patients waiting',
                          'treatment' => _mine ? 'No cases in treatment assigned to you' : 'No patients in treatment',
                          _ => 'No discharged cases yet',
                        },
                        message: q.status == 'waiting' ? 'Accepted referrals and walk-in cases appear here.' : null,
                      ),
                    ]
                  : [
                      for (final c in list) ...[
                        CaseCard(portalCase: c, onTap: () => openCase(context, c.id)),
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

class CaseCard extends StatelessWidget {
  final PortalCase portalCase;
  final VoidCallback onTap;
  const CaseCard({super.key, required this.portalCase, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final c = portalCase;
    final place = [if (c.wardName != null) c.wardName!, if ((c.bed ?? '').isNotEmpty) 'Bed ${c.bed}'].join(' · ');
    return StaffTap(
      onTap: onTap,
      color: p.card,
      radius: 16,
      semanticLabel: '${c.patientName}, ${levelLabel(c.level)}, ${caseStatusLabel(c.status)}',
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            StaffInitialsAvatar(initialsOf(c.patientName), tone: levelTone(c.level) == StaffTone.neutral ? StaffTone.indigo : levelTone(c.level)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(c.patientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: staffBody(15, weight: FontWeight.w700, color: p.ink)),
                      ),
                      StaffTag(levelLabel(c.level), tone: levelTone(c.level)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(c.complaint, maxLines: 1, overflow: TextOverflow.ellipsis, style: staffBody(13, color: p.body)),
                  const SizedBox(height: 4),
                  Text(
                    [
                      ageSex(c.age, c.sex),
                      if (place.isNotEmpty) place,
                      c.assigneeName ?? 'Unassigned',
                      relativeTime(c.createdAt),
                    ].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: staffBody(12, color: p.muted),
                  ),
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

/// Walk-in case (POST /portal/cases).
class NewCaseSheet extends ConsumerStatefulWidget {
  const NewCaseSheet({super.key});

  @override
  ConsumerState<NewCaseSheet> createState() => _NewCaseSheetState();
}

class _NewCaseSheetState extends ConsumerState<NewCaseSheet> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _complaint = TextEditingController();
  final _bed = TextEditingController();
  final _allergies = TextEditingController();
  String _sex = '';
  String _level = 'routine';
  int _ward = -1;
  String _assignee = '';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _age, _complaint, _bed, _allergies]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final complaint = _complaint.text.trim();
    final age = _age.text.trim().isEmpty ? null : int.tryParse(_age.text.trim());
    if (name.length < 2 || complaint.length < 2) {
      showStaffSnack(context, 'Enter the patient’s name and main complaint.');
      return;
    }
    if (_age.text.trim().isNotEmpty && (age == null || age < 0 || age > 130)) {
      showStaffSnack(context, 'Age must be a number between 0 and 130.');
      return;
    }
    setState(() => _saving = true);
    final r = await runPortalAction(
      context,
      () => ref.read(hospitalApiProvider).createCase(NewCaseInput(
            patientName: name,
            age: age,
            sex: _sex,
            complaint: complaint,
            level: _level,
            wardId: _ward < 0 ? null : _ward,
            bed: _bed.text.trim(),
            assigneeUid: _assignee,
            allergies: _allergies.text.trim(),
          )),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (r != null) Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) {
    final cap = ref.watch(capacityProvider).valueOrNull;
    final freeWards = cap?.wards.where((w) => w.bedsFree > 0).toList() ?? const <Ward>[];
    final team = cap?.team ?? const <TeamMember>[];
    return PortalSheet(
      title: 'New walk-in case',
      actions: [
        StaffButton('Cancel', kind: StaffButtonKind.secondary, onPressed: () => Navigator.of(context).pop()),
        StaffButton('Create case', loading: _saving, onPressed: _submit),
      ],
      children: [
        PortalTextField(controller: _name, label: 'Patient name', capitalization: TextCapitalization.words),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: PortalTextField(controller: _age, label: 'Age', keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(
              child: StaffField(
                label: 'Sex',
                child: StaffSelect<String>(
                  value: _sex,
                  items: const ['', 'female', 'male', 'other'],
                  labelOf: (s) => s.isEmpty ? 'Not stated' : s[0].toUpperCase() + s.substring(1),
                  onChanged: (v) => setState(() => _sex = v),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        PortalTextField(controller: _complaint, label: 'Main complaint', hint: 'Chest pain for 2 hours'),
        const SizedBox(height: 14),
        Text('Priority', style: staffBody(13, weight: FontWeight.w600, color: StaffPalette.of(context).ink)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final l in const ['urgent', 'doctor', 'routine'])
            StaffPill(
              label: levelLabel(l),
              selected: _level == l,
              tealSelection: true,
              dot: StaffPalette.of(context).tone(levelTone(l)).strong,
              onTap: () => setState(() => _level = l),
            ),
        ]),
        const SizedBox(height: 14),
        StaffField(
          label: 'Ward',
          child: StaffSelect<int>(
            value: freeWards.any((w) => w.id == _ward) ? _ward : -1,
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
        PortalTextField(controller: _bed, label: 'Bed (optional)'),
        const SizedBox(height: 14),
        StaffField(
          label: 'Assign to',
          child: StaffSelect<String>(
            value: team.any((m) => m.firebaseUid == _assignee) ? _assignee : '',
            items: ['', ...team.map((m) => m.firebaseUid)],
            labelOf: (uid) {
              if (uid.isEmpty) return 'Unassigned';
              final m = team.firstWhere((m) => m.firebaseUid == uid);
              return '${m.fullName} · ${m.role.label}';
            },
            icon: Icons.person_outline_rounded,
            onChanged: (v) => setState(() => _assignee = v),
          ),
        ),
        const SizedBox(height: 14),
        PortalTextField(controller: _allergies, label: 'Allergies (optional)', hint: 'Penicillin'),
      ],
    );
  }
}
