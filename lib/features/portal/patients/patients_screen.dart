import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/portal/board/board_screen.dart';
import 'package:vitanet/features/portal/data/portal_models.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
import 'package:vitanet/features/portal/record/case_record_view.dart';
import 'package:vitanet/features/portal/shell/portal_nav.dart';
import 'package:vitanet/features/portal/ui/clinical_ui.dart';

const _filters = <(String, CaseQuery)>[
  ('Mine', (status: activeCaseStatuses, mine: true)),
  ('All', (status: activeCaseStatuses, mine: false)),
  ('Waiting', (status: 'waiting', mine: false)),
  ('In treatment', (status: 'treatment', mine: false)),
  ('Discharged', (status: 'discharged', mine: false)),
];

/// Everyone in the hospital (and recently discharged), searchable. On desk
/// the record opens beside the list.
class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  final _search = TextEditingController();
  int _filter = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(PortalCase c) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return c.patientName.toLowerCase().contains(q) ||
        c.complaint.toLowerCase().contains(q) ||
        caseRef(c.id).toLowerCase().contains(q.replaceAll(' ', ''));
  }

  Future<void> _walkIn() async {
    final created = await showCSheet<PortalCase>(context, builder: (_) => const WalkInSheet());
    if (created != null && mounted) openCase(context, ref, created.id);
  }

  Widget _list() {
    final p = ClinicalPalette.of(context);
    final query = _filters[_filter].$2;
    final value = ref.watch(casesProvider(query));
    final selected = ref.watch(deskSelectionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Expanded(child: Text('Patients', style: cText(26, weight: FontWeight.w700, color: p.ink, letterSpacing: -0.2))),
              CButton('Walk-in', kind: CButtonKind.dark, icon: Icons.add_rounded, expand: false, height: 44, onPressed: _walkIn),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: cText(15, color: p.ink),
            decoration: cInputDecoration(context,
                hint: 'Name, case number or complaint', prefixIcon: Icon(Icons.search_rounded, color: p.muted)),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            itemCount: _filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) => CPill(label: _filters[i].$1, selected: _filter == i, onTap: () => setState(() => _filter = i)),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: p.primary,
            onRefresh: () => ref.refresh(casesProvider(query).future),
            child: value.when(
              loading: () => ListView(children: const [CLoading()]),
              error: (e, _) => ListView(children: [CError(error: e, onRetry: () => ref.invalidate(casesProvider(query)))]),
              data: (all) {
                final list = all.where(_matches).toList();
                if (list.isEmpty) {
                  return ListView(children: [
                    CEmpty(
                      icon: Icons.people_outline_rounded,
                      title: _search.text.isNotEmpty
                          ? 'No one matches "${_search.text.trim()}"'
                          : _filter == 0
                              ? 'No patients assigned to you'
                              : 'No patients here',
                      message: _filter == 0 ? 'Patients you accept or are given at handover show up here.' : null,
                    ),
                  ]);
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    CCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < list.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: p.divider),
                            CaseRow(
                              portalCase: list[i],
                              discharged: list[i].isDischarged,
                              selected: selected?.id == list[i].id,
                              showRef: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesk(context)) return _list();
    final p = ClinicalPalette.of(context);
    final selection = ref.watch(deskSelectionProvider);
    return DetailPaneScope(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 400,
            decoration: BoxDecoration(color: p.card, border: Border(right: BorderSide(color: p.line))),
            child: _list(),
          ),
          Expanded(
            child: selection?.kind == 'case'
                ? CaseRecordView(key: ValueKey(selection!.id), caseId: selection.id)
                : const CEmpty(icon: Icons.assignment_ind_outlined, title: 'Select a patient', message: 'Their record opens here.'),
          ),
        ],
      ),
    );
  }
}

/// Register someone who walked in (already here, so they start as waiting).
class WalkInSheet extends ConsumerStatefulWidget {
  const WalkInSheet({super.key});

  @override
  ConsumerState<WalkInSheet> createState() => _WalkInSheetState();
}

class _WalkInSheetState extends ConsumerState<WalkInSheet> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _complaint = TextEditingController();
  final _allergies = TextEditingController();
  int _sex = 2; // female, male, not said
  String _level = 'doctor';
  int? _ward;
  bool _mine = true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _age, _complaint, _allergies]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2 || _complaint.text.trim().length < 2) {
      showCSnack(context, "Add the patient's name and what's wrong.");
      return;
    }
    final me = ref.read(staffAccessProvider).valueOrNull?.me;
    setState(() => _saving = true);
    final res = await runCAction(
      context,
      () => ref.read(hospitalApiProvider).createCase(NewCaseInput(
            patientName: _name.text.trim(),
            age: int.tryParse(_age.text.trim()),
            sex: const ['female', 'male', null][_sex],
            complaint: _complaint.text.trim(),
            level: _level,
            wardId: _ward,
            allergies: _allergies.text.trim(),
            assigneeUid: _mine ? me?.firebaseUid : null,
          )),
      success: '${_name.text.trim()} registered.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) {
      invalidatePortalData(ref);
      Navigator.of(context).pop(res);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final wards = ref.watch(capacityProvider).valueOrNull?.wards ?? const <Ward>[];
    return CSheet(
      title: 'New walk-in',
      subtitle: 'For someone already here. VitaNet referrals arrive on the Board by themselves.',
      gap: 14,
      actions: [CButton('Register patient', loading: _saving, onPressed: _save)],
      children: [
        CTextField(controller: _name, label: 'Full name', capitalization: TextCapitalization.words),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(width: 96, child: CTextField(controller: _age, label: 'Age', keyboardType: TextInputType.number, mono: true)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Sex', style: cText(13, weight: FontWeight.w600, color: p.body)),
                  const SizedBox(height: 6),
                  CSegmented(labels: const ['Female', 'Male', 'Not said'], selected: _sex, height: 40,
                      onChanged: (i) => setState(() => _sex = i)),
                ],
              ),
            ),
          ],
        ),
        CTextField(controller: _complaint, label: "What's wrong", hint: 'e.g. Fell, forearm swollen'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CSectionLabel('Triage level'),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final l in const ['urgent', 'doctor', 'routine']) ...[
                  if (l != 'urgent') const SizedBox(width: 8),
                  Expanded(
                    child: COption(
                      leading: CDot(p.tone(levelTone(l)).dot, size: 10),
                      title: levelLabel(l),
                      selected: _level == l,
                      onTap: () => setState(() => _level = l),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        CTextField(controller: _allergies, label: 'Allergies (optional)', hint: 'e.g. Penicillin'),
        if (wards.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CSectionLabel('Ward (optional)'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final w in wards)
                    CPill(
                      label: '${w.name} · ${w.bedsFree == 0 ? 'full' : '${w.bedsFree} free'}',
                      selected: _ward == w.id,
                      round: false,
                      onTap: w.bedsFree == 0 ? () => showCSnack(context, '${w.name} is full.') : () => setState(() => _ward = _ward == w.id ? null : w.id),
                    ),
                ],
              ),
            ],
          ),
        Row(
          children: [
            Expanded(child: Text("I'm looking after them", style: cText(15, weight: FontWeight.w600, color: p.ink))),
            CSwitch(value: _mine, onChanged: (v) => setState(() => _mine = v)),
          ],
        ),
      ],
    );
  }
}
