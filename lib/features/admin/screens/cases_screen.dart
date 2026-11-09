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
  String _query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(PortalCase c) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return c.patientName.toLowerCase().contains(q) ||
        c.complaint.toLowerCase().contains(q) ||
        CaseCard.caseRef(c.id).toLowerCase().contains(q) ||
        c.id.toLowerCase().contains(q);
  }

  Future<void> _newCase() async {
    final created = await showStaffSheet<PortalCase>(
      context,
      tall: true,
      builder: (_) => const NewCaseSheet(),
    );
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
    final counts = ref.watch(dashboardProvider).valueOrNull?.counts;
    String tabLabel(String s) {
      final n = switch (s) {
        'waiting' => counts?.waiting,
        'treatment' => counts?.inTreatment,
        _ => null, // no discharged count in the API
      };
      return n == null ? caseStatusLabel(s) : '${caseStatusLabel(s)} · $n';
    }

    return AutoRefresh(
      active: widget.active,
      onTick: () => ref.invalidate(casesProvider(q)),
      child: Column(
        children: [
          PortalHeader(
            title: 'Case management',
            trailing: HeaderIconButton(
              icon: Icons.add_rounded,
              tooltip: 'New patient entry',
              onPressed: _newCase,
            ),
            bottom: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StaffSearchField(
                  controller: _search,
                  hint: 'Search name, case ID or complaint',
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                StaffSegmented(
                  labels: [for (final s in _statuses) tabLabel(s)],
                  selected: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ],
            ),
          ),
          Expanded(
            child: PortalAsyncList<List<PortalCase>>(
              value: value,
              onRefresh: () => ref.refresh(casesProvider(q).future),
              header: [
                Row(
                  children: [
                    StaffPill(
                      label: 'All cases',
                      selected: !_mine,
                      onTap: () => setState(() => _mine = false),
                    ),
                    const SizedBox(width: 8),
                    StaffPill(
                      label: 'Mine',
                      selected: _mine,
                      onTap: () => setState(() => _mine = true),
                    ),
                    const Spacer(),
                    if (value.valueOrNull != null)
                      Text(
                        '${value.valueOrNull!.length}',
                        style: staffBody(
                          13,
                          weight: FontWeight.w700,
                          color: p.muted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              builder: (all) {
                final list = all.where(_matches).toList();
                return list.isEmpty
                    ? [
                        PortalEmpty(
                          icon: Icons.assignment_ind_outlined,
                          title: _query.trim().isNotEmpty
                              ? 'No cases match "${_query.trim()}"'
                              : switch (q.status) {
                                  'waiting' =>
                                    _mine
                                        ? 'No waiting cases assigned to you'
                                        : 'No patients waiting',
                                  'treatment' =>
                                    _mine
                                        ? 'No cases in treatment assigned to you'
                                        : 'No patients in treatment',
                                  _ => 'No discharged cases yet',
                                },
                          message: q.status == 'waiting'
                              ? 'Accepted referrals and walk-in cases appear here.'
                              : null,
                        ),
                      ]
                    : [
                        for (final c in list) ...[
                          CaseCard(
                            portalCase: c,
                            onTap: () => openCase(context, c.id),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ];
              },
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

  /// Short, readable case reference for the card (ids are UUIDs).
  static String caseRef(String id) =>
      'C-${(id.length > 6 ? id.substring(0, 6) : id).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final c = portalCase;
    final tone = p.tone(levelTone(c.level));
    final place = [
      if (c.wardName != null) c.wardName!,
      if ((c.bed ?? '').isNotEmpty) 'Bed ${c.bed}',
    ].join(' · ');
    final who = [
      c.patientName,
      ageSex(c.age, c.sex),
    ].where((s) => s.isNotEmpty).join(', ');
    return StaffTap(
      onTap: onTap,
      color: p.card,
      radius: 20,
      semanticLabel:
          '$who, ${levelLabel(c.level)}, ${caseStatusLabel(c.status)}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: p.dark ? tone.fg : tone.strong,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        who,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: staffBody(
                          16,
                          weight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${caseRef(c.id)} · ${c.complaint}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: staffBody(13, color: p.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  relativeTime(c.createdAt),
                  style: staffBody(13, weight: FontWeight.w700, color: p.body),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                StaffTag(levelLabel(c.level), tone: levelTone(c.level)),
                if (place.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: staffBody(13, color: p.muted),
                    ),
                  ),
                ],
                const Spacer(),
                if (c.assigneeName != null)
                  StaffInitialsAvatar(
                    initialsOf(c.assigneeName!),
                    tone: StaffTone.indigo,
                    size: 28,
                    fontSize: 11,
                  )
                else
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.tone(StaffTone.indigo).bg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.remove_rounded,
                      size: 16,
                      color: p.tone(StaffTone.indigo).fg,
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  c.assigneeName ?? 'Unassigned',
                  style: staffBody(13, weight: FontWeight.w600, color: p.ink),
                ),
              ],
            ),
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
    final age = _age.text.trim().isEmpty
        ? null
        : int.tryParse(_age.text.trim());
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
      () => ref
          .read(hospitalApiProvider)
          .createCase(
            NewCaseInput(
              patientName: name,
              age: age,
              sex: _sex,
              complaint: complaint,
              level: _level,
              wardId: _ward < 0 ? null : _ward,
              bed: _bed.text.trim(),
              assigneeUid: _assignee,
              allergies: _allergies.text.trim(),
            ),
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (r != null) Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) {
    final cap = ref.watch(capacityProvider).valueOrNull;
    final freeWards =
        cap?.wards.where((w) => w.bedsFree > 0).toList() ?? const <Ward>[];
    final team = cap?.team ?? const <TeamMember>[];
    return PortalSheet(
      title: 'New walk-in case',
      actions: [
        StaffButton(
          'Cancel',
          kind: StaffButtonKind.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        StaffButton('Create case', loading: _saving, onPressed: _submit),
      ],
      children: [
        PortalTextField(
          controller: _name,
          label: 'Patient name',
          capitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PortalTextField(
                controller: _age,
                label: 'Age',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StaffField(
                label: 'Sex',
                child: StaffSelect<String>(
                  value: _sex,
                  items: const ['', 'female', 'male', 'other'],
                  labelOf: (s) => s.isEmpty
                      ? 'Not stated'
                      : s[0].toUpperCase() + s.substring(1),
                  onChanged: (v) => setState(() => _sex = v),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        PortalTextField(
          controller: _complaint,
          label: 'Main complaint',
          hint: 'Chest pain for 2 hours',
        ),
        const SizedBox(height: 14),
        Text(
          'Priority',
          style: staffBody(
            13,
            weight: FontWeight.w600,
            color: StaffPalette.of(context).ink,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final l in const ['urgent', 'doctor', 'routine'])
              StaffPill(
                label: levelLabel(l),
                selected: _level == l,
                tealSelection: true,
                dot: StaffPalette.of(context).tone(levelTone(l)).strong,
                onTap: () => setState(() => _level = l),
              ),
          ],
        ),
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
        PortalTextField(
          controller: _allergies,
          label: 'Allergies (optional)',
          hint: 'Penicillin',
        ),
      ],
    );
  }
}
