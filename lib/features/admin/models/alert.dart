class ClinicalAlert {
  final String id;
  final String title;
  final String description;
  final bool isCritical;
  final DateTime timestamp;

  ClinicalAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.isCritical,
    required this.timestamp,
  });

  factory ClinicalAlert.fromJson(Map<String, dynamic> json) {
    return ClinicalAlert(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      isCritical: json['isCritical'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
