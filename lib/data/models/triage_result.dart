/// The three triage levels VitaNet can recommend.
enum TriageLevel { selfCare, pharmacist, doctor, emergency }

/// Holds the result of a triage session.
class TriageResult {
  final String id;
  final TriageLevel level;
  final String summary;
  final List<String> recommendations;
  final List<String> monitorSymptoms;
  final String primarySymptom;
  final DateTime timestamp;

  const TriageResult({
    required this.id,
    required this.level,
    required this.summary,
    required this.recommendations,
    required this.monitorSymptoms,
    required this.primarySymptom,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'level': level.name,
        'summary': summary,
        'recommendations': recommendations,
        'monitorSymptoms': monitorSymptoms,
        'primarySymptom': primarySymptom,
        'timestamp': timestamp.toIso8601String(),
      };

  factory TriageResult.fromMap(Map<String, dynamic> map) => TriageResult(
        id: map['id'] as String,
        level: TriageLevel.values.byName(map['level'] as String),
        summary: map['summary'] as String,
        recommendations: List<String>.from(map['recommendations'] as List),
        monitorSymptoms: List<String>.from(map['monitorSymptoms'] as List),
        primarySymptom: map['primarySymptom'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}
