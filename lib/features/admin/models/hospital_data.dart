class HospitalStats {
  final int activePatients;
  final int availableWards;
  final String systemHealth;
  final int staffOnDuty;

  HospitalStats({
    required this.activePatients,
    required this.availableWards,
    required this.systemHealth,
    required this.staffOnDuty,
  });

  factory HospitalStats.fromJson(Map<String, dynamic> json) {
    return HospitalStats(
      activePatients: json['activePatients'] ?? 0,
      availableWards: json['availableWards'] ?? 0,
      systemHealth: json['systemHealth'] ?? '98%',
      staffOnDuty: json['staffOnDuty'] ?? 0,
    );
  }
}

class WardInfo {
  final String name;
  final int occupied;
  final int total;
  final String type;

  WardInfo({
    required this.name,
    required this.occupied,
    required this.total,
    required this.type,
  });

  double get occupancyRate => total > 0 ? (occupied / total).clamp(0.0, 1.0) : 0.0;
}

class StaffInfo {
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

  StaffInfo({
    required this.name,
    required this.role,
    required this.status,
    this.department,
    this.patients,
    this.shift,
    this.phone,
    this.license,
    this.email,
    this.photo,
  });
}

class EquipmentInfo {
  final String name;
  final String status;
  final String tone;
  final String? detail;

  EquipmentInfo({
    required this.name,
    required this.status,
    required this.tone,
    this.detail,
  });

  factory EquipmentInfo.fromJson(Map<String, dynamic> json) => EquipmentInfo(
    name: json['name'] ?? '',
    status: json['status'] ?? '',
    tone: json['tone'] ?? 'green',
    detail: json['detail'],
  );
}
