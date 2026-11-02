import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import '../services/hospital_api_service.dart';
import '../widgets/patient_sheets.dart';
import '../widgets/staff_demo_data.dart';
import '../widgets/staff_ui.dart';

/// Patients (Patients.dc.html) with the Add patient and Patient record sheets.
class AdminPatientDataPage extends StatefulWidget {
  const AdminPatientDataPage({super.key});

  @override
  State<AdminPatientDataPage> createState() => _AdminPatientDataPageState();
}

class _AdminPatientDataPageState extends State<AdminPatientDataPage> {
  final ApiService _apiService = ApiService();
  List<StaffPatientRecord>? _allPatients;
  bool _fromApi = false;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static const _avatarTones = [StaffTone.indigo, StaffTone.pink, StaffTone.brand, StaffTone.amber];

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    try {
      final patients = await _apiService.getPatients();
      if (!mounted) return;
      setState(() {
        if (patients.isNotEmpty) {
          _fromApi = true;
          _allPatients = patients.map(StaffPatientRecord.fromApi).toList();
        } else {
          _allPatients ??= [
            for (final id in demoPatientOrder)
              if (demoRecords[id] != null) demoRecords[id]!,
          ];
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<StaffPatientRecord> get _filtered {
    final all = _allPatients ?? const <StaffPatientRecord>[];
    final q = _query.toLowerCase();
    if (q.isEmpty) return all;
    return all.where((p) => p.name.toLowerCase().contains(q) || p.id.toLowerCase().contains(q)).toList();
  }

  Future<void> _addPatient() async {
    final count = _allPatients?.length ?? 0;
    final record = await showAddPatientSheet(context, nextId: 'P-${10245 + count}');
    if (record == null || !mounted) return;
    demoRecords[record.id] = record;
    setState(() => _allPatients = [record, ...?_allPatients]);
    _apiService.createPatient(record);
    showStaffSnack(context, 'Patient record created for ${record.name}');
  }

  Future<void> _showPatientDetails(StaffPatientRecord patient) async {
    final detailed = await _apiService.getPatientDetail(patient.id);
    final recordToShow = detailed ?? demoRecords[patient.id] ?? patient;
    if (!mounted) return;
    showPatientRecordSheet(
      context,
      recordToShow,
      onUpdated: (r) {
        demoRecords[r.id] = r;
        setState(() {
          final i = _allPatients?.indexWhere((x) => x.id == r.id) ?? -1;
          if (i >= 0) _allPatients![i] = r;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final all = _allPatients ?? const <StaffPatientRecord>[];
    final list = _filtered;

    // Hospital-wide census when running on ward data; computed when live.
    final admitted = _fromApi ? all.length : 68 + (all.length - demoPatientOrder.length).clamp(0, 999);
    final critical = _fromApi ? all.where((x) => x.status == PatientStatus.critical).length : 5;
    final discharge = _fromApi ? all.where((x) => x.status == PatientStatus.recovering).length : 9;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadPatients,
          color: AppColors.brand,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              StaffContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StaffPageHeader(
                      title: 'Patients',
                      trailing: StaffButton(
                        'Add patient',
                        icon: Icons.add_rounded,
                        expand: false,
                        height: 44,
                        fontSize: 14,
                        onPressed: _addPatient,
                      ),
                    ),
                    const SizedBox(height: 14),
                    StaffSearchField(
                      controller: _searchController,
                      hint: 'Search by name or patient ID',
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _StatTile('$admitted', 'Admitted', p.ink)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile('$critical', 'Critical', p.dark ? const Color(0xFFFCA5A5) : kStaffDanger),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile('$discharge', 'Discharge today', p.dark ? const Color(0xFF6EE7B7) : kStaffGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
                      )
                    else if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(
                          children: [
                            Icon(Icons.person_search_outlined, size: 44, color: p.faint),
                            const SizedBox(height: 12),
                            Text(
                              _query.isEmpty ? 'No patients admitted' : 'No patients match "$_query"',
                              style: staffHeading(16, weight: FontWeight.w700, color: p.ink),
                            ),
                          ],
                        ),
                      )
                    else
                      StaffGroup(
                        children: [
                          for (var i = 0; i < list.length; i++)
                            _PatientRow(
                              record: list[i],
                              tone: _avatarTones[i % _avatarTones.length],
                              onTap: () => _showPatientDetails(list[i]),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatTile(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: staffBody(20, weight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: staffBody(11, weight: FontWeight.w600, color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientRow extends StatelessWidget {
  final StaffPatientRecord record;
  final StaffTone tone;
  final VoidCallback onTap;
  const _PatientRow({required this.record, required this.tone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Semantics(
      button: true,
      label: '${record.nameAge}, ${record.id}, ${record.location}, ${record.status.label}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              StaffInitialsAvatar(record.initials, tone: tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.nameAge, style: staffBody(14, weight: FontWeight.w700, color: p.ink)),
                    const SizedBox(height: 2),
                    Text(
                      '${record.id} · ${record.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: staffBody(12, color: p.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StaffTag(record.status.label, tone: record.status.tone),
            ],
          ),
        ),
      ),
    );
  }
}
