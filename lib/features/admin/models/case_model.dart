import 'package:vitanet/features/admin/widgets/staff_ui.dart';

/// Case queue status, matching the three segmented tabs.
enum CaseStatus {
  waiting('Waiting'),
  treatment('In treatment'),
  discharged('Discharged');

  final String label;
  const CaseStatus(this.label);

  static CaseStatus parse(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('treat')) return CaseStatus.treatment;
    if (s.contains('discharg')) return CaseStatus.discharged;
    return CaseStatus.waiting;
  }
}

/// Triage level of a case.
enum CaseLevel {
  urgent('Urgent', StaffTone.danger),
  doctor('Doctor', StaffTone.orange),
  routine('Routine', StaffTone.amber);

  final String label;
  final StaffTone tone;
  const CaseLevel(this.label, this.tone);

  static CaseLevel parse(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('urg')) return CaseLevel.urgent;
    if (s.contains('doc')) return CaseLevel.doctor;
    return CaseLevel.routine;
  }
}

class StaffCase {
  final String id;
  final String nameAge;
  final String complaint;
  final CaseLevel level;
  final String time;
  final String where;
  final String initials;
  final String assignee;
  final CaseStatus status;
  final String? recordId;

  const StaffCase({
    required this.id,
    required this.nameAge,
    required this.complaint,
    required this.level,
    required this.time,
    required this.where,
    required this.initials,
    required this.assignee,
    required this.status,
    this.recordId,
  });

  StaffCase withStatus(CaseStatus s) => StaffCase(
        id: id,
        nameAge: nameAge,
        complaint: complaint,
        level: level,
        time: time,
        where: where,
        initials: initials,
        assignee: assignee,
        status: s,
        recordId: recordId,
      );

  factory StaffCase.fromJson(Map<String, dynamic> json) => StaffCase(
        id: json['id'] ?? '',
        nameAge: json['nameAge'] ?? '',
        complaint: json['complaint'] ?? '',
        level: CaseLevel.parse(json['level'] ?? 'routine'),
        time: json['time'] ?? 'Just now',
        where: json['where'] ?? 'Ward',
        initials: json['initials'] ?? '—',
        assignee: json['assignee'] ?? 'Unassigned',
        status: CaseStatus.parse(json['status'] ?? 'waiting'),
        recordId: json['recordId'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameAge': nameAge,
        'complaint': complaint,
        'level': level.name,
        'time': time,
        'where': where,
        'initials': initials,
        'assignee': assignee,
        'status': status.name,
        'recordId': recordId,
      };
}

