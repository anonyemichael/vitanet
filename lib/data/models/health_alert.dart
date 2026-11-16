/// A health alert made by the backend from a watch or manual reading
/// (vitanet-backend/app/services/health_alert_service.py).
class HealthAlertItem {
  final String id;
  final String vitalType;
  final String severity; // "urgent" | "watch"
  final String status; // "pending" | "acknowledged" | "escalated"
  final String message;
  final DateTime createdAt;

  const HealthAlertItem({
    required this.id,
    required this.vitalType,
    required this.severity,
    required this.status,
    required this.message,
    required this.createdAt,
  });

  bool get isUrgent => severity == 'urgent';

  /// Still waiting for the person to answer ("I'm OK"). An escalated alert has
  /// also not been answered: the care circle was told, but it still shows.
  bool get isOpen => status == 'pending' || status == 'escalated';

  static DateTime _utc(String raw) =>
      DateTime.parse(RegExp(r'(Z|[+-]\d\d:?\d\d)$').hasMatch(raw) ? raw : '${raw}Z').toLocal();

  factory HealthAlertItem.fromJson(Map<String, dynamic> j) => HealthAlertItem(
        id: '${j['id']}',
        vitalType: '${j['vital_type'] ?? ''}',
        severity: '${j['severity'] ?? 'watch'}'.toLowerCase(),
        status: '${j['status'] ?? 'pending'}'.toLowerCase(),
        message: '${j['message'] ?? ''}',
        createdAt: _utc('${j['created_at']}'),
      );

  HealthAlertItem copyWith({String? status}) => HealthAlertItem(
        id: id,
        vitalType: vitalType,
        severity: severity,
        status: status ?? this.status,
        message: message,
        createdAt: createdAt,
      );
}
