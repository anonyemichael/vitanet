import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/admin/widgets/patient_sheets.dart';
import 'package:vitanet/features/admin/widgets/staff_demo_data.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

export 'package:vitanet/features/admin/models/case_model.dart';
import 'package:vitanet/features/admin/models/case_model.dart';
import 'package:vitanet/features/admin/services/hospital_api_service.dart';

final adminCasesProvider = Provider<List<StaffCase>>((ref) {
  return const [
    StaffCase(id: 'C-2041', nameAge: 'Yaw Boateng, 62 M', complaint: 'Chest pain', level: CaseLevel.urgent, time: '31 min', where: 'Resus bay 2', initials: 'KM', assignee: 'Dr. Mensah', status: CaseStatus.waiting, recordId: 'P-10241'),
    StaffCase(id: 'C-2043', nameAge: 'Amara Okafor, 35 F', complaint: 'Fever, neck stiffness', level: CaseLevel.urgent, time: 'ETA 9 min', where: 'Arriving', initials: '—', assignee: 'Unassigned', status: CaseStatus.waiting, recordId: 'P-10243'),
    StaffCase(id: 'C-2044', nameAge: 'Efua Asante, 28 F', complaint: 'Abdominal pain, pregnant', level: CaseLevel.doctor, time: 'ETA 22 min', where: 'Arriving', initials: 'AA', assignee: 'Dr. Addo', status: CaseStatus.waiting, recordId: 'P-10244'),
    StaffCase(id: 'C-2038', nameAge: 'Kofi Owusu, 9 M', complaint: 'Forearm injury', level: CaseLevel.doctor, time: '48 min', where: 'Minors 4', initials: 'EB', assignee: 'Nurse Badu', status: CaseStatus.waiting, recordId: 'P-10238'),
    StaffCase(id: 'C-2035', nameAge: 'Abena Darko, 71 F', complaint: 'Dizziness, fall', level: CaseLevel.routine, time: '1 h 12 m', where: 'Waiting area', initials: 'EB', assignee: 'Nurse Badu', status: CaseStatus.waiting, recordId: 'P-10235'),
    StaffCase(id: 'C-2029', nameAge: 'Ama Kuffour, 54 F', complaint: 'Pneumonia, low SpO2', level: CaseLevel.urgent, time: '2 h 32 m', where: 'Emergency · Bed 7', initials: 'KM', assignee: 'Dr. Mensah', status: CaseStatus.treatment, recordId: 'P-10233'),
    StaffCase(id: 'C-2017', nameAge: 'Kwesi Nyarko, 47 M', complaint: 'Cellulitis, left leg', level: CaseLevel.doctor, time: '1 d 4 h', where: 'Ward B · Bed 3', initials: 'AA', assignee: 'Dr. Addo', status: CaseStatus.treatment, recordId: 'P-10198'),
    StaffCase(id: 'C-2009', nameAge: 'Nana Agyei, 58 M', complaint: 'High blood glucose', level: CaseLevel.routine, time: '2 d 3 h', where: 'Ward C · Bed 5', initials: 'AA', assignee: 'Dr. Addo', status: CaseStatus.treatment, recordId: 'P-10164'),
    StaffCase(id: 'C-2011', nameAge: 'Esi Mensah, 33 F', complaint: 'Appendicitis, post-op', level: CaseLevel.doctor, time: '1 d 22 h', where: 'Ward A · Bed 12', initials: 'KA', assignee: 'Dr. Asare', status: CaseStatus.treatment, recordId: 'P-10177'),
    StaffCase(id: 'C-2032', nameAge: 'Kojo Antwi, 24 M', complaint: 'Ankle sprain', level: CaseLevel.routine, time: '09:52', where: 'Home, follow-up GP', initials: 'EB', assignee: 'Nurse Badu', status: CaseStatus.discharged),
    StaffCase(id: 'C-2027', nameAge: 'Akua Sarpong, 41 F', complaint: 'Migraine', level: CaseLevel.routine, time: '08:40', where: 'Home', initials: 'KM', assignee: 'Dr. Mensah', status: CaseStatus.discharged),
    StaffCase(id: 'C-2020', nameAge: 'Fiifi Quaye, 66 M', complaint: 'Asthma exacerbation', level: CaseLevel.doctor, time: '07:15', where: 'Home, inhaler plan', initials: 'AA', assignee: 'Dr. Addo', status: CaseStatus.discharged),
  ];
});

/// Case management (Cases.dc.html).
class CaseManagementScreen extends ConsumerStatefulWidget {
  const CaseManagementScreen({super.key});

  @override
  ConsumerState<CaseManagementScreen> createState() => _CaseManagementScreenState();
}

class _CaseManagementScreenState extends ConsumerState<CaseManagementScreen> {
  final ApiService _apiService = ApiService();
  late List<StaffCase> _cases;
  CaseStatus _tab = CaseStatus.waiting;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _cases = List.of(ref.read(adminCasesProvider));
    _loadCases();
  }

  Future<void> _loadCases() async {
    final live = await _apiService.getCases();
    if (live.isNotEmpty && mounted) {
      setState(() => _cases = live);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _updateStatus(String id, CaseStatus newStatus) {
    setState(() {
      final index = _cases.indexWhere((c) => c.id == id);
      if (index != -1) _cases[index] = _cases[index].withStatus(newStatus);
    });
    _apiService.updateCase(id, status: newStatus.name);
  }

  Future<void> _newCase() async {
    final record = await showAddPatientSheet(context, nextId: 'P-${10245 + _cases.length}');
    if (record == null || !mounted) return;
    final level = switch (record.status) {
      PatientStatus.critical => CaseLevel.urgent,
      PatientStatus.observation => CaseLevel.doctor,
      _ => CaseLevel.routine,
    };
    final newId = 'C-${2045 + _cases.length}';
    demoRecords[record.id] = record;
    final newCase = StaffCase(
      id: newId,
      nameAge: record.nameAge,
      complaint: record.diagnosis ?? 'New presentation',
      level: level,
      time: 'Just now',
      where: record.location,
      initials: '—',
      assignee: 'Unassigned',
      status: CaseStatus.waiting,
      recordId: record.id,
    );
    setState(() {
      _cases.insert(0, newCase);
      _tab = CaseStatus.waiting;
    });
    // Persist to backend database
    _apiService.createPatient(record);
    _apiService.createCase(newCase);
    showStaffSnack(context, 'Case $newId opened for ${record.name}');
  }

  Future<void> _moveCase(StaffCase c) async {
    final p = StaffPalette.of(context);
    final s = await showStaffSheet<CaseStatus>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Move ${c.id}', style: staffHeading(20, color: p.ink)),
            const SizedBox(height: 4),
            Text(c.nameAge, style: staffBody(13, color: p.muted)),
            const SizedBox(height: 14),
            for (final st in CaseStatus.values) ...[
              StaffButton(
                st == c.status ? '${st.label} (current)' : st.label,
                kind: st == c.status ? StaffButtonKind.secondary : StaffButtonKind.primary,
                onPressed: st == c.status ? null : () => Navigator.pop(ctx, st),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
    if (s == null || !mounted) return;
    _updateStatus(c.id, s);
    showStaffSnack(context, '${c.id} moved to ${s.label.toLowerCase()}');
  }

  void _openCase(StaffCase c) {
    final rec = c.recordId != null ? demoRecords[c.recordId] : null;
    if (rec == null) {
      _moveCase(c);
      return;
    }
    showPatientRecordSheet(context, rec, onUpdated: (r) => demoRecords[r.id] = r);
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final q = _query.toLowerCase();
    final visible = _cases.where((c) {
      if (c.status != _tab) return false;
      if (q.isEmpty) return true;
      return c.nameAge.toLowerCase().contains(q) ||
          c.id.toLowerCase().contains(q) ||
          c.complaint.toLowerCase().contains(q);
    }).toList();
    int count(CaseStatus s) => _cases.where((c) => c.status == s).length;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            StaffContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StaffPageHeader(
                    title: 'Case management',
                    fontSize: 21,
                    onBack: Navigator.of(context).canPop() ? () => Navigator.of(context).pop() : null,
                    trailing: StaffIconButton(
                      icon: Icons.add_rounded,
                      tooltip: 'New case',
                      background: p.primaryBtn,
                      foreground: Colors.white,
                      onPressed: _newCase,
                    ),
                  ),
                  const SizedBox(height: 14),
                  StaffSearchField(
                    controller: _search,
                    hint: 'Search name, case ID or complaint',
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                  const SizedBox(height: 14),
                  StaffSegmented(
                    labels: [for (final s in CaseStatus.values) '${s.label} · ${count(s)}'],
                    selected: _tab.index,
                    onChanged: (i) => setState(() => _tab = CaseStatus.values[i]),
                  ),
                  const SizedBox(height: 14),
                  if (visible.isEmpty)
                    _EmptyQueue(searching: q.isNotEmpty)
                  else
                    for (final c in visible) ...[
                      _CaseCard(
                        data: c,
                        onTap: () => _openCase(c),
                        onLongPress: () => _moveCase(c),
                      ),
                      const SizedBox(height: 10),
                    ],
                  if (visible.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Long-press a case to move it between queues.',
                        textAlign: TextAlign.center,
                        style: staffBody(12, color: p.muted),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final StaffCase data;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CaseCard({required this.data, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final tone = p.tone(data.level.tone);
    final c = data;
    return Semantics(
      button: true,
      label: '${c.level.label} case ${c.id}, ${c.nameAge}, ${c.complaint}, ${c.assignee}',
      excludeSemantics: true,
      child: StaffTap(
        color: p.card,
        radius: 16,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  StaffDot(tone.strong, size: 10),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.nameAge, style: staffBody(15, weight: FontWeight.w700, color: p.ink)),
                        const SizedBox(height: 1),
                        Text(
                          '${c.id} · ${c.complaint}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: staffBody(12, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(c.time, style: staffBody(12, weight: FontWeight.w700, color: p.inkSoft)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  StaffTag(c.level.label,
                      tone: c.level.tone,
                      fontSize: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.where,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: staffBody(12, color: p.muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StaffInitialsAvatar(c.initials, size: 22, fontSize: 9),
                  const SizedBox(width: 6),
                  Text(c.assignee, style: staffBody(12, weight: FontWeight.w600, color: p.body)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  final bool searching;
  const _EmptyQueue({required this.searching});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 44, color: p.faint),
          const SizedBox(height: 12),
          Text(
            searching ? 'No matching cases' : 'This queue is empty',
            style: staffHeading(16, weight: FontWeight.w700, color: p.ink),
          ),
        ],
      ),
    );
  }
}
