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
      activePatients: json['activePatients'],
      availableWards: json['availableWards'],
      systemHealth: json['systemHealth'],
      staffOnDuty: json['staffOnDuty'],
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

  double get occupancyRate => occupied / total;
}

class StaffInfo {
  final String name;
  final String role;
  final String status;

  StaffInfo({
    required this.name,
    required this.role,
    required this.status,
  });
}
