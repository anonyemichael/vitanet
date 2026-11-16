import 'package:dio/dio.dart';
import 'package:vitanet/data/models/health_alert.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:vitanet/core/network/backend.dart';

class MLTriagePrediction {
  final String disease;
  final String confidence;
  final String severity; // "urgent", "doctor", "routine"
  final String severityConfidence;
  final String description;
  final List<String> precautions;
  final String recommendation;

  MLTriagePrediction({
    required this.disease,
    required this.confidence,
    required this.severity,
    required this.severityConfidence,
    required this.description,
    required this.precautions,
    required this.recommendation,
  });

  factory MLTriagePrediction.fromJson(Map<String, dynamic> json) => MLTriagePrediction(
    disease: json['disease'] ?? 'Unknown condition',
    confidence: json['confidence'] ?? '90%',
    severity: json['severity'] ?? 'doctor',
    severityConfidence: json['severity_confidence'] ?? '85%',
    description: json['description'] ?? '',
    precautions: List<String>.from(json['precautions'] ?? []),
    recommendation: json['recommendation'] ?? 'Please consult a clinician.',
  );
}

class ApiService {
  final Dio _dio;

  /// Uses the remotely configured backend URL and sends the user's Firebase
  /// ID token with every request (see [BackendConfig]).
  ApiService({String? baseUrl}) : _dio = createBackendDio() {
    if (baseUrl != null) {
      // Runs after the shared interceptor, so an explicit URL (tests) wins.
      _dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
        o.baseUrl = baseUrl;
        h.next(o);
      }));
    }
  }

  /// Runs live Machine Learning disease and severity triage predictions.
  /// Only vitals that were really measured are sent; nothing is invented.
  Future<MLTriagePrediction?> predictTriage({
    required List<String> symptoms,
    int? age,
    String? gender,
    double? heartRate,
    double? temperature,
    double? bloodOxygen,
    double? systolicBp,
    double? diastolicBp,
  }) async {
    try {
      final response = await _dio.post('triage/predict', data: {
        'symptoms': symptoms,
        'age': ?age,
        'gender': ?gender,
        'heart_rate': ?heartRate,
        'temperature': ?temperature,
        'blood_oxygen': ?bloodOxygen,
        'systolic_bp': ?systolicBp,
        'diastolic_bp': ?diastolicBp,
      });
      return MLTriagePrediction.fromJson(response.data);
    } catch (e) {
      debugPrint('ApiService: predictTriage failed ($e)');
      return null;
    }
  }

  /// Fetches available symptoms recognized by the ML model.
  Future<List<String>> getRecognizedSymptoms() async {
    try {
      final response = await _dio.get('triage/symptoms');
      return List<String>.from(response.data);
    } catch (e) {
      debugPrint('ApiService: getRecognizedSymptoms failed ($e)');
      return [
        'anxiety',
        'chest_pain',
        'cough',
        'dizziness',
        'fatigue',
        'fever',
        'headache',
        'nausea',
        'shortness_of_breath',
        'sore_throat'
      ];
    }
  }

  /// Fetches the latest live vitals for a patient from the backend.
  Future<Map<String, double>> getLatestVitals([
    String userId = '',
  ]) async {
    try {
      final response = await _dio.get('vitals/$userId/latest');
      final data = response.data as Map<String, dynamic>;
      final result = <String, double>{};
      data.forEach((k, v) {
        if (v != null && v['value'] != null) {
          result[k] = (v['value'] as num).toDouble();
        }
      });
      return result;
    } catch (e) {
      debugPrint('ApiService: getLatestVitals failed ($e)');
      return {};
    }
  }

  /// Health Connect / Apple Health keys -> backend vital types.
  static const _vitalTypeFor = {
    'heart_rate': 'heart_rate',
    'blood_oxygen': 'blood_oxygen',
    'temperature': 'temperature',
    'respiratory_rate': 'respiratory_rate',
    'systolic_bp': 'bp_systolic',
    'diastolic_bp': 'bp_diastolic',
  };

  /// Sends readings that came from the user's watch / health platform to
  /// their own backend record, so the assistant, alerts and the hospital see
  /// real data. [measuredAt] (when the watch took each reading) lets the
  /// backend skip a reading it already has. Keys the backend doesn't know are
  /// skipped. Returns how many were sent.
  Future<int> postDeviceVitals(String userId, Map<String, double> readings,
      {Map<String, DateTime> measuredAt = const {}}) async {
    final body = [
      for (final e in readings.entries)
        if (_vitalTypeFor[e.key] != null)
          {
            'vital_type': _vitalTypeFor[e.key],
            'value': e.value,
            'source': 'device',
            if (measuredAt[e.key] != null) 'recorded_at': measuredAt[e.key]!.toUtc().toIso8601String(),
          },
    ];
    if (body.isEmpty) return 0;
    try {
      await _dio.post('vitals/$userId/batch', data: {'readings': body});
      return body.length;
    } catch (e) {
      debugPrint('ApiService: postDeviceVitals failed ($e)');
      return 0;
    }
  }

  /// Copies the profile screen to the backend (PUT /health-profile/{id}/from-app), so the
  /// assistant's get_health_profile tool sees the same age, conditions, medicines and allergies.
  ///
  /// [replaceContacts]: the person edited their contact list, so contacts no
  /// longer in it are removed from the care circle. Otherwise new contacts are
  /// only added (an old copy of the profile can never delete a contact).
  Future<bool> syncProfile(String userId, UserProfile p, {bool replaceContacts = false}) async {
    try {
      await _dio.put('health-profile/$userId/from-app', data: {
        'name': p.name.trim().isEmpty ? null : p.name.trim(),
        'age': p.age,
        'sex': p.sex,
        'dob': p.dob,
        'conditions': p.preExistingConditions,
        'allergies': p.allergies,
        'medications': p.medications,
        'family_history': p.familyMedicalHistory,
        'blood_type': p.bloodType,
        'height_cm': (p.height ?? 0) > 0 ? p.height : null,
        'weight_kg': (p.weight ?? 0) > 0 ? p.weight : null,
        'smoking': p.smoking,
        'alcohol': p.alcohol,
        'exercise_frequency': p.exerciseFrequency,
        'bio': p.bio,
        // the care circle: new contacts are invited to agree to alerts, removed ones stop getting them
        'contacts': [
          for (final c in p.emergencyContacts)
            {'name': c.name, 'phone': c.phone.trim().isEmpty ? null : c.phone, 'email': c.email, 'relation': c.relation},
        ],
        'contacts_replace': replaceContacts,
      });
      return true;
    } catch (e) {
      debugPrint('ApiService: syncProfile failed ($e)');
      return false;
    }
  }

  /// The phone's position, so the assistant can find the nearest hospital and pharmacy.
  Future<bool> putLocation(String userId, double latitude, double longitude) async {
    try {
      await _dio.put('users/$userId/location', data: {'latitude': latitude, 'longitude': longitude});
      return true;
    } catch (e) {
      debugPrint('ApiService: putLocation failed ($e)');
      return false;
    }
  }

  /// The person's health alerts, newest first (GET /alerts/{id}).
  Future<List<HealthAlertItem>> getAlerts(String userId) async {
    try {
      final response = await _dio.get('alerts/$userId');
      return [
        for (final j in (response.data as List? ?? const []))
          if (j is Map) HealthAlertItem.fromJson(Map<String, dynamic>.from(j)),
      ];
    } catch (e) {
      debugPrint('ApiService: getAlerts failed ($e)');
      return const [];
    }
  }

  /// "I'm OK": the alert is answered and the care circle is not told.
  Future<bool> acknowledgeAlert(String alertId) async {
    try {
      await _dio.post('alerts/$alertId/acknowledge');
      return true;
    } catch (e) {
      debugPrint('ApiService: acknowledgeAlert failed ($e)');
      return false;
    }
  }

  /// Persists a new biometric reading to the backend.
  Future<bool> postVitalReading({
    String userId = '',
    required String vitalType,
    required double value,
    String source = 'device',
  }) async {
    try {
      await _dio.post('vitals/$userId', data: {
        'vital_type': vitalType,
        'value': value,
        'source': source,
      });
      return true;
    } catch (e) {
      debugPrint('ApiService: postVitalReading failed ($e)');
      return false;
    }
  }

  /// Fetches active care circle members for a user.
  Future<List<Map<String, dynamic>>> getCareCircleMembers([
    String userId = '',
  ]) async {
    try {
      final response = await _dio.get('care-circles/user/$userId');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('ApiService: getCareCircleMembers failed ($e)');
      return [];
    }
  }

  /// Invites a new emergency contact / care circle member and sends an invite email.
  Future<bool> addCareCircleMember({
    String userId = '',
    required String fullName,
    required String relationship,
    String? contactEmail,
    String? contactPhone,
    bool isPrimary = false,
  }) async {
    try {
      await _dio.post('care-circles/user/$userId', data: {
        'full_name': fullName,
        'relationship': relationship,
        'contact_email': ?contactEmail,
        'contact_phone': ?contactPhone,
        'is_primary': isPrimary,
      });
      return true;
    } catch (e) {
      debugPrint('ApiService: addCareCircleMember failed ($e)');
      return false;
    }
  }
}
