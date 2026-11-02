import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';
import '../models/hospital_data.dart';
import '../services/hospital_api_service.dart';
import '../widgets/staff_demo_data.dart';
import '../widgets/staff_ui.dart';
import 'case_management_screen.dart';

class _StaffMember {
  final String name;
  final String role;
  final String status;
  final String? department;
  final String? patients;
  final String? shift;
  final String? phone;
  final String? license;
  final String? email;
  final String? photo;

  const _StaffMember(
    this.name,
    this.role,
    this.status, {
    this.department,
    this.patients,
    this.shift,
    this.phone,
    this.license,
    this.email,
    this.photo,
  });

  factory _StaffMember.fromApi(StaffInfo s) => _StaffMember(s.name, s.role, s.status);

  String get initials => name
      .replaceFirst(RegExp(r'^(Dr\.|Nurse)\s+'), '')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();

  StaffTone get tone {
    final s = status.toLowerCase();
    if (s.contains('available') || s.contains('on duty') || s == 'active') return StaffTone.green;
    if (s.contains('theatre') || s.contains('surgery')) return StaffTone.danger;
    return StaffTone.amber;
  }
}

const _demoStaff = [
  _StaffMember('Dr. Kwame Mensah', 'Emergency physician', 'With patient',
      department: 'Emergency', patients: '2', shift: '07–19', phone: 'Ext 201',
      license: 'MDC/RN/04712 · valid to Mar 2028', email: 'k.mensah@korlebu.gov.gh'),
  _StaffMember('Dr. Akosua Addo', 'Obstetrics registrar', 'Available',
      department: 'Maternity', patients: '4', shift: '07–19', phone: 'Ext 214',
      license: 'MDC/RN/03318 · valid to Jun 2027', email: 'a.addo@korlebu.gov.gh', photo: kAddoPhoto),
  _StaffMember('Nurse Esi Badu', 'Charge nurse, ED', 'With patient',
      department: 'Emergency', patients: '6', shift: '07–19', phone: 'Ext 230',
      license: 'NMC/RGN/22871 · valid to Jan 2027', email: 'e.badu@korlebu.gov.gh'),
  _StaffMember('Dr. Kojo Asare', 'Cardiology consultant', 'In theatre',
      department: 'Cardiology', patients: '3', shift: '08–17', phone: 'Ext 340',
      license: 'MDC/RN/01954 · valid to Sep 2027', email: 'k.asare@korlebu.gov.gh'),
  _StaffMember('Nurse Yaa Amponsah', 'Staff nurse, ICU', 'Available',
      department: 'ICU', patients: '2', shift: '07–19', phone: 'Ext 410',
      license: 'NMC/RGN/30442 · valid to Nov 2027', email: 'y.amponsah@korlebu.gov.gh'),
  _StaffMember('Dr. Selorm Dzidzienyo', 'Paediatric resident', 'With patient',
      department: 'Paediatrics', patients: '5', shift: '07–19', phone: 'Ext 512',
      license: 'MDC/RN/05207 · valid to Feb 2028', email: 's.dzidzienyo@korlebu.gov.gh'),
];

/// Hospital infrastructure (Hospital.dc.html).
class AdminInfrastructurePage extends StatefulWidget {
  const AdminInfrastructurePage({super.key});

  @override
  State<AdminInfrastructurePage> createState() => _AdminInfrastructurePageState();
}

class _AdminInfrastructurePageState extends State<AdminInfrastructurePage> {
  final ApiService _apiService = ApiService();
  late Future<List<WardInfo>> _wardsFuture;
  late Future<List<StaffInfo>> _staffFuture;
  late Future<List<EquipmentInfo>> _equipFuture;
  DateTime _loadedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _wardsFuture = _apiService.getWards();
    _staffFuture = _apiService.getStaff();
    _equipFuture = _apiService.getEquipment();
    _loadedAt = DateTime.now();
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_wardsFuture, _staffFuture, _equipFuture]);
  }

  void _contactStaff(_StaffMember staff) {
    showStaffSheet<void>(context, builder: (_) => _StaffSheet(staff: staff));
  }

  void _openRoster(List<_StaffMember> staff) {
    final p = StaffPalette.of(context);
    showStaffSheet<void>(
      context,
      tall: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Roster · on duty now', style: staffHeading(20, color: p.ink)),
            const SizedBox(height: 4),
            Text('$kDemoFacility · ${staff.length} clinicians', style: staffBody(13, color: p.muted)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in staff)
                    _StaffRow(
                      staff: s,
                      onTap: () {
                        Navigator.pop(ctx);
                        _contactStaff(s);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.brand,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              StaffContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(header: true, child: Text('Hospital', style: staffHeading(24, color: p.ink))),
                          const SizedBox(height: 2),
                          Text(
                            '$kDemoFacility · live at ${DateFormat('HH:mm').format(_loadedAt)}',
                            style: staffBody(13, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _section(
                      context,
                      title: 'Bed occupancy',
                      child: FutureBuilder<List<WardInfo>>(
                        future: _wardsFuture,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) return const _Loading();
                          final api = snap.data ?? const <WardInfo>[];
                          final wards = api.isNotEmpty
                              ? [for (final w in api) DemoWard(w.name, w.occupied, w.total)]
                              : demoWards;
                          return Column(
                            children: [
                              for (var i = 0; i < wards.length; i++) ...[
                                if (i > 0) const SizedBox(height: 12),
                                _WardBar(ward: wards[i]),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    _section(context, title: 'Equipment', child: _EquipmentGrid(future: _equipFuture)),
                    const SizedBox(height: 14),
                    FutureBuilder<List<StaffInfo>>(
                      future: _staffFuture,
                      builder: (context, snap) {
                        final loading = snap.connectionState == ConnectionState.waiting;
                        final api = snap.data ?? const <StaffInfo>[];
                        final staff = api.isNotEmpty ? api.map(_StaffMember.fromApi).toList() : _demoStaff;
                        return StaffCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      loading ? 'On duty now' : 'On duty now · ${staff.length}',
                                      style: staffHeading(16, weight: FontWeight.w700, color: p.ink),
                                    ),
                                  ),
                                  if (!loading)
                                    TextButton(
                                      onPressed: () => _openRoster(staff),
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(44, 44),
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                      ),
                                      child: Text('Roster', style: staffBody(13, weight: FontWeight.w700, color: p.accent)),
                                    ),
                                ],
                              ),
                              if (loading)
                                const _Loading()
                              else
                                for (final s in staff.take(4)) _StaffRow(staff: s, onTap: () => _contactStaff(s)),
                            ],
                          ),
                        );
                      },
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

  Widget _section(BuildContext context, {required String title, required Widget child}) {
    final p = StaffPalette.of(context);
    return StaffCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: staffHeading(16, weight: FontWeight.w700, color: p.ink)),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
      );
}

class _WardBar extends StatelessWidget {
  final DemoWard ward;
  const _WardBar({required this.ward});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final rate = ward.total == 0 ? 0.0 : (ward.used / ward.total).clamp(0.0, 1.0);
    final color = rate >= 0.9
        ? const Color(0xFFDC2626)
        : rate >= 0.75
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);
    return Semantics(
      label: '${ward.name}: ${ward.used} of ${ward.total} beds used, ${ward.free} free',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(ward.name, style: staffBody(13, weight: FontWeight.w600, color: p.ink))),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${ward.used}', style: TextStyle(fontWeight: FontWeight.w700, color: p.ink)),
                    TextSpan(text: ' / ${ward.total} · ${ward.free} free'),
                  ],
                ),
                style: staffBody(13, color: p.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(value: rate, backgroundColor: p.divider, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentGrid extends StatelessWidget {
  final Future<List<EquipmentInfo>> future;
  const _EquipmentGrid({required this.future});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final amber = p.tone(StaffTone.amber);
    final danger = p.tone(StaffTone.danger);
    final green = p.dark ? const Color(0xFF6EE7B7) : kStaffGreen;

    return FutureBuilder<List<EquipmentInfo>>(
      future: future,
      builder: (context, snap) {
        final list = snap.data ?? const <EquipmentInfo>[];
        final List<_EquipTile> tiles;
        if (list.isNotEmpty) {
          tiles = list.map((e) {
            final t = e.tone.toLowerCase();
            final bg = t == 'danger'
                ? (p.dark ? danger.bg : const Color(0xFFFEF2F2))
                : (t == 'amber' ? (p.dark ? amber.bg : const Color(0xFFFFFBEB)) : p.fill);
            final fg = t == 'danger'
                ? (p.dark ? danger.fg : kStaffDanger)
                : (t == 'amber' ? (p.dark ? amber.fg : kStaffAmber) : green);
            return _EquipTile(
              e.name,
              e.status,
              null,
              bg,
              p.muted,
              fg,
              valueColor: fg,
            );
          }).toList();
        } else {
          tiles = [
            _EquipTile('Ventilators', '6', ' of 9 free', p.fill, p.muted, green),
            _EquipTile('Oxygen supply', '72%', ' OK', p.fill, p.muted, green),
            _EquipTile('CT scanner', '2', ' in queue', p.dark ? amber.bg : const Color(0xFFFFFBEB), amber.fg,
                p.dark ? amber.fg : kStaffAmber),
            _EquipTile('Defibrillator B', 'Service due', null, p.dark ? danger.bg : const Color(0xFFFEF2F2), danger.fg,
                p.dark ? danger.fg : kStaffDanger,
                valueColor: p.dark ? danger.fg : kStaffDanger),
          ];
        }

        return LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 560 ? 4 : 2;
            final w = (c.maxWidth - 8 * (cols - 1)) / cols;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final t in tiles) SizedBox(width: w, child: t)],
            );
          },
        );
      },
    );
  }
}

class _EquipTile extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final Color bg;
  final Color labelColor;
  final Color suffixColor;
  final Color? valueColor;

  const _EquipTile(this.label, this.value, this.suffix, this.bg, this.labelColor, this.suffixColor, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: staffBody(12, weight: FontWeight.w600, color: labelColor)),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: value,
              children: [
                if (suffix != null)
                  TextSpan(
                    text: suffix,
                    style: staffBody(12, weight: FontWeight.w700, color: suffixColor),
                  ),
              ],
            ),
            style: staffBody(suffix == null ? 15 : 18, weight: FontWeight.w800, color: valueColor ?? p.ink, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  final _StaffMember staff;
  final VoidCallback onTap;
  const _StaffRow({required this.staff, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Semantics(
      button: true,
      label: '${staff.name}, ${staff.role}, ${staff.status}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              StaffInitialsAvatar(staff.initials, size: 38, fontSize: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(staff.name, style: staffBody(14, weight: FontWeight.w600, color: p.ink)),
                    const SizedBox(height: 1),
                    Text(staff.role, style: staffBody(12, color: p.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StaffTag(staff.status, tone: staff.tone, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Staff member sheet (StaffSheet.dc.html) ───

class _StaffSheet extends StatelessWidget {
  final _StaffMember staff;
  const _StaffSheet({required this.staff});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final s = staff;
    final tiles = [
      if (s.patients != null) ('Patients', s.patients!),
      if (s.shift != null) ('Shift', s.shift!),
      if (s.phone != null) ('Phone', s.phone!),
    ];
    final subtitle = s.department != null ? '${s.role} · ${s.department}' : s.role;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: s.photo != null
                  ? StaffPhoto(s.photo!, size: 72, alignment: const Alignment(0, -0.5), semanticLabel: s.name)
                  : StaffInitialsAvatar(s.initials, size: 72, fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(s.name, textAlign: TextAlign.center, style: staffHeading(20, color: p.ink)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: staffBody(14, color: p.muted)),
            const SizedBox(height: 8),
            Center(
              child: StaffTag(s.status,
                  tone: s.tone,
                  fontSize: 12,
                  radius: 999,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
            ),
            if (tiles.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(tiles[i].$2, style: staffBody(17, weight: FontWeight.w800, color: p.ink)),
                            ),
                            const SizedBox(height: 2),
                            Text(tiles[i].$1, style: staffBody(11, weight: FontWeight.w600, color: p.muted)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (s.license != null || s.email != null) ...[
              const SizedBox(height: 16),
              if (s.license != null) _kv(p, 'License', s.license!),
              if (s.email != null) ...[const SizedBox(height: 4), _kv(p, 'Email', s.email!)],
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StaffButton(
                    'Call',
                    icon: Icons.call_outlined,
                    kind: StaffButtonKind.secondary,
                    fontSize: 14,
                    onPressed: s.phone == null
                        ? null
                        : () => LaunchHelpers.dialOrSnack(context, s.phone!.replaceAll(RegExp(r'[^\d]'), '')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StaffButton(
                    'Assign a case',
                    fontSize: 14,
                    onPressed: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(MaterialPageRoute(builder: (_) => const CaseManagementScreen()));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(StaffPalette p, String k, String v) => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: k, style: TextStyle(fontWeight: FontWeight.w700, color: p.ink)),
            TextSpan(text: ' $v'),
          ],
        ),
        style: staffBody(13, color: p.inkSoft),
      );
}
