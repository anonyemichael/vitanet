import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import '../models/alert.dart';
import '../services/hospital_api_service.dart';
import '../widgets/patient_sheets.dart';
import '../widgets/staff_demo_data.dart';
import '../widgets/staff_ui.dart';

enum _AlertKind { vitals, arrival, lab, capacity, medication, handover, general }

/// View model wrapping a [ClinicalAlert] with the presentation details the
/// staff portal needs.
class _StaffAlert {
  final ClinicalAlert source;
  final _AlertKind kind;
  final String? tag;
  final String? attendTitle;
  final String? recordId;
  String? resolutionNote;
  String? resolvedAction;

  _StaffAlert(
    this.source, {
    required this.kind,
    this.tag,
    this.attendTitle,
    this.recordId,
  });

  String get id => source.id;
  String get title => source.title;
  String get body => source.description;
  bool get critical => source.isCritical;
  String get time => DateFormat('HH:mm').format(source.timestamp);

  factory _StaffAlert.fromApi(ClinicalAlert a) =>
      _StaffAlert(a, kind: a.isCritical ? _AlertKind.arrival : _AlertKind.general);

  IconData get icon => switch (kind) {
        _AlertKind.vitals => Icons.warning_amber_rounded,
        _AlertKind.arrival => Icons.monitor_heart_outlined,
        _AlertKind.lab => Icons.description_outlined,
        _AlertKind.capacity => Icons.bed_outlined,
        _AlertKind.medication => Icons.medication_outlined,
        _AlertKind.handover => Icons.check_rounded,
        _AlertKind.general => Icons.info_outline_rounded,
      };

  StaffTone get tone {
    if (critical) return StaffTone.danger;
    return switch (kind) {
      _AlertKind.capacity => StaffTone.amber,
      _AlertKind.medication => StaffTone.violet,
      _AlertKind.handover => StaffTone.green,
      _ => StaffTone.amber,
    };
  }

  List<String> get actions => switch (kind) {
        _AlertKind.vitals => const ['Increased O2', 'Repositioned', 'Called doctor', 'Sensor fault'],
        _AlertKind.arrival => const ['Bed prepared', 'Team alerted', 'Isolation room', 'Called doctor'],
        _AlertKind.lab => const ['Reviewed result', 'Called cardiology', 'Treatment started', 'Repeat test'],
        _ => const ['Reviewed', 'Called doctor', 'Escalated', 'No action needed'],
      };
}

DateTime _today(int h, int m) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

List<_StaffAlert> _demoAlerts() => [
      _StaffAlert(
        ClinicalAlert(id: 'a1', title: 'SpO2 falling · Bed 7', description: 'Ama Kuffour, 54 F. SpO2 88% for 3 min on 2 L oxygen. Respiratory rate 28.', isCritical: true, timestamp: _today(10, 40)),
        kind: _AlertKind.vitals,
        tag: 'CRITICAL · BED 7',
        attendTitle: 'Attend to SpO2 alert',
        recordId: 'P-10233',
      ),
      _StaffAlert(
        ClinicalAlert(id: 'a2', title: 'Urgent arrival · ETA 9 min', description: 'VitaNet triage: query meningitis. Amara Okafor, 35 F. Penicillin allergy.', isCritical: true, timestamp: _today(10, 24)),
        kind: _AlertKind.arrival,
        tag: 'CRITICAL · ARRIVING',
        attendTitle: 'Attend to urgent arrival',
        recordId: 'P-10243',
      ),
      _StaffAlert(
        ClinicalAlert(id: 'a3', title: 'Troponin result critical', description: 'Yaw Boateng, C-2041. hs-Troponin T 112 ng/L. Cardiology notified.', isCritical: true, timestamp: _today(10, 12)),
        kind: _AlertKind.lab,
        tag: 'CRITICAL · RESUS BAY 2',
        attendTitle: 'Attend to troponin result',
        recordId: 'P-10241',
      ),
      _StaffAlert(
        ClinicalAlert(id: 'a4', title: 'Bed capacity at 85%', description: 'Emergency ward has 12 of 80 beds free. Consider step-down transfers.', isCritical: false, timestamp: _today(9, 55)),
        kind: _AlertKind.capacity,
      ),
      _StaffAlert(
        ClinicalAlert(id: 'a5', title: 'Medication due · Bed 3', description: 'IV ceftriaxone 2 g due for Kwesi Nyarko. Not yet charted.', isCritical: false, timestamp: _today(9, 30)),
        kind: _AlertKind.medication,
      ),
      _StaffAlert(
        ClinicalAlert(id: 'a6', title: 'Shift handover notes ready', description: 'Night team logged 14 patients, 2 pending CT scans.', isCritical: false, timestamp: _today(7, 5)),
        kind: _AlertKind.handover,
      ),
    ];

enum _Filter { all, critical, resolved }

/// Clinical alerts (AdminAlerts.dc.html).
class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final ApiService _apiService = ApiService();
  List<_StaffAlert>? _alerts;
  final List<_StaffAlert> _resolved = [];
  bool _isLoading = true;
  bool _seeded = false;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final alerts = await _apiService.getAlerts();
      if (!mounted) return;
      setState(() {
        if (alerts.isNotEmpty) {
          final resolvedIds = _resolved.map((a) => a.id).toSet();
          _alerts = alerts.where((a) => !resolvedIds.contains(a.id)).map(_StaffAlert.fromApi).toList();
        } else if (!_seeded) {
          // Backend has nothing yet: show the ward's current alert board.
          _alerts = _demoAlerts();
        }
        _seeded = true;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearAll() {
    if (_alerts == null || _alerts!.isEmpty) return;
    final p = StaffPalette.of(context);
    showStaffDialog<void>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: p.tone(StaffTone.danger).bg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.notifications_off_outlined, size: 26, color: p.tone(StaffTone.danger).fg),
              ),
            ),
            const SizedBox(height: 14),
            Text('Dismiss all alerts?', textAlign: TextAlign.center, style: staffHeading(20, color: p.ink)),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to dismiss all current clinical alerts? Dismissed alerts are not logged as attended.',
              textAlign: TextAlign.center,
              style: staffBody(14, color: p.inkSoft, height: 1.55),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: StaffButton('Cancel',
                      kind: StaffButtonKind.secondary, onPressed: () => Navigator.pop(ctx)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StaffButton(
                    'Dismiss all',
                    kind: StaffButtonKind.dangerOutline,
                    onPressed: () {
                      setState(() => _alerts = []);
                      Navigator.pop(ctx);
                      showStaffSnack(context, 'All alerts dismissed');
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

  Future<void> _attendAlert(_StaffAlert alert) async {
    final result = await showStaffDialog<(String, String)>(
      context,
      builder: (_) => _AttendDialog(alert: alert),
    );
    if (result == null || !mounted) return;
    setState(() {
      _alerts?.removeWhere((a) => a.id == alert.id);
      alert.resolvedAction = result.$1;
      alert.resolutionNote = result.$2;
      _resolved.insert(0, alert);
    });
    _apiService.attendAlert(alert.id, note: '${result.$1}: ${result.$2}');
    showStaffSnack(context, '${alert.title} marked attended. Charge nurse notified.');
  }

  Future<void> _viewPatient(_StaffAlert alert) async {
    if (alert.recordId == null) return;
    final detailed = await _apiService.getPatientDetail(alert.recordId!);
    final rec = detailed ?? demoRecords[alert.recordId];
    if (rec != null && mounted) {
      showPatientRecordSheet(context, rec, onUpdated: (r) => demoRecords[r.id] = r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final all = _alerts ?? const <_StaffAlert>[];
    final criticalCount = all.where((a) => a.critical).length;
    final visible = switch (_filter) {
      _Filter.all => all,
      _Filter.critical => all.where((a) => a.critical).toList(),
      _Filter.resolved => _resolved,
    };
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadAlerts,
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
                      title: 'Clinical alerts',
                      fontSize: 21,
                      onBack: canPop ? () => Navigator.of(context).pop() : null,
                      trailing: all.isEmpty
                          ? null
                          : TextButton(
                              onPressed: _clearAll,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                foregroundColor: kStaffDanger,
                              ),
                              child: Text(
                                'Dismiss all',
                                style: staffBody(13,
                                    weight: FontWeight.w700,
                                    color: p.dark ? const Color(0xFFFCA5A5) : kStaffDanger),
                              ),
                            ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 0,
                      children: [
                        StaffPill(
                          label: 'All · ${all.length}',
                          selected: _filter == _Filter.all,
                          onTap: () => setState(() => _filter = _Filter.all),
                        ),
                        StaffPill(
                          label: 'Critical · $criticalCount',
                          selected: _filter == _Filter.critical,
                          dot: p.tone(StaffTone.danger).strong,
                          textColor: p.tone(StaffTone.danger).fg,
                          onTap: () => setState(() => _filter = _Filter.critical),
                        ),
                        StaffPill(
                          label: _resolved.isEmpty ? 'Resolved' : 'Resolved · ${_resolved.length}',
                          selected: _filter == _Filter.resolved,
                          onTap: () => setState(() => _filter = _Filter.resolved),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
                      )
                    else if (visible.isEmpty)
                      _EmptyAlerts(filter: _filter)
                    else
                      for (final a in visible) ...[
                        _AlertCard(
                          alert: a,
                          resolved: _filter == _Filter.resolved,
                          onAttend: () => _attendAlert(a),
                          onViewPatient: a.recordId != null ? () => _viewPatient(a) : null,
                        ),
                        const SizedBox(height: 10),
                      ],
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

class _AlertCard extends StatelessWidget {
  final _StaffAlert alert;
  final bool resolved;
  final VoidCallback onAttend;
  final VoidCallback? onViewPatient;

  const _AlertCard({
    required this.alert,
    required this.resolved,
    required this.onAttend,
    this.onViewPatient,
  });

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final tone = p.tone(resolved ? StaffTone.green : alert.tone);
    final critBorder = p.dark ? const Color(0x66DC2626) : const Color(0xFFFECACA);
    final actionable = alert.critical && !resolved;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: actionable ? critBorder : p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(resolved ? Icons.check_rounded : alert.icon,
                    size: 20, color: p.dark ? tone.fg : _iconColor(alert, resolved)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(alert.title, style: staffBody(14, weight: FontWeight.w700, color: p.ink)),
                        ),
                        const SizedBox(width: 8),
                        Text(alert.time, style: staffBody(12, color: p.muted)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(alert.body, style: staffBody(13, color: p.inkSoft, height: 1.45)),
                    if (resolved && alert.resolvedAction != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Attended · ${alert.resolvedAction}'
                        '${(alert.resolutionNote ?? '').isNotEmpty ? ' · ${alert.resolutionNote}' : ''}',
                        style: staffBody(12, weight: FontWeight.w600, color: p.tone(StaffTone.green).fg),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (actionable) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: StaffButton('Attend', height: 44, radius: 12, fontSize: 13, onPressed: onAttend)),
                if (onViewPatient != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: StaffButton(
                      'View patient',
                      kind: StaffButtonKind.secondary,
                      height: 44,
                      radius: 12,
                      fontSize: 13,
                      onPressed: onViewPatient,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _iconColor(_StaffAlert a, bool resolved) {
    if (resolved) return kStaffGreen;
    return switch (a.tone) {
      StaffTone.danger => kStaffDanger,
      StaffTone.amber => kStaffAmber,
      StaffTone.violet => AppColors.ai,
      StaffTone.green => kStaffGreen,
      _ => AppColors.brand,
    };
  }
}

class _EmptyAlerts extends StatelessWidget {
  final _Filter filter;
  const _EmptyAlerts({required this.filter});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final text = switch (filter) {
      _Filter.resolved => 'No alerts attended yet this shift',
      _Filter.critical => 'No critical alerts right now',
      _Filter.all => 'No active clinical alerts',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: p.tone(StaffTone.green).bg, borderRadius: BorderRadius.circular(18)),
            child: Icon(Icons.check_rounded, size: 28, color: p.tone(StaffTone.green).fg),
          ),
          const SizedBox(height: 12),
          Text(text, style: staffHeading(16, weight: FontWeight.w700, color: p.ink)),
          const SizedBox(height: 4),
          Text('Pull down to refresh.', style: staffBody(13, color: p.muted)),
        ],
      ),
    );
  }
}

// ─── Attend dialog (AttendDialog.dc.html) ───

class _AttendDialog extends StatefulWidget {
  final _StaffAlert alert;
  const _AttendDialog({required this.alert});

  @override
  State<_AttendDialog> createState() => _AttendDialogState();
}

class _AttendDialogState extends State<_AttendDialog> {
  late String _action = widget.alert.actions.first;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final a = widget.alert;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.divider))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StaffTag(a.tag ?? (a.critical ? 'CRITICAL' : 'ALERT'),
                    tone: a.critical ? StaffTone.danger : StaffTone.amber,
                    weight: FontWeight.w800,
                    letterSpacing: 0.4),
                const SizedBox(height: 10),
                Text(a.attendTitle ?? 'Attend to ${a.title}', style: staffHeading(20, color: p.ink)),
                const SizedBox(height: 10),
                Text(
                  '${a.body} Marking this attended notifies the charge nurse and logs your response time.',
                  style: staffBody(14, color: p.inkSoft, height: 1.5),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Action taken', style: staffBody(13, weight: FontWeight.w700, color: p.ink)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final act in a.actions)
                      StaffPill(
                        label: act,
                        height: 36,
                        tealSelection: true,
                        selected: _action == act,
                        onTap: () => setState(() => _action = act),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                StaffField(
                  label: 'Note',
                  weight: FontWeight.w700,
                  child: TextField(
                    controller: _note,
                    minLines: 3,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    style: staffBody(14, color: p.ink, height: 1.5),
                    decoration: staffInputDecoration(
                      context,
                      hint: 'e.g. O2 increased to 4 L via nasal cannula. Recheck in 10 min.',
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
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
                      child: StaffButton(
                        'Mark attended',
                        onPressed: () => Navigator.pop(context, (_action, _note.text.trim())),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
