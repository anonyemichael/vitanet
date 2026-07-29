class Patient {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String status;
  final DateTime lastUpdated;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.status,
    required this.lastUpdated,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'],
      name: json['name'],
      age: json['age'],
      gender: json['gender'],
      status: json['status'],
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}
