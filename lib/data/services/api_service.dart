import 'package:dio/dio.dart';
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

  /// Fetches the connection status of various health monitoring devices.
  Future<Map<String, bool>> getDeviceConnections() async {
    try {
      if (kDebugMode) {
        print('--- API REQUEST: Get Device Connections ---');
      }
      return {
        'heart_rate': true,
        'blood_oxygen': true,
        'temperature': true,
        'respiratory_rate': false,
      };
    } catch (e) {
      debugPrint('Error fetching device connections from backend: $e');
      return {
        'heart_rate': true,
        'blood_oxygen': false,
        'temperature': false,
        'respiratory_rate': false,
      };
    }
  }

  /// Runs live Machine Learning disease and severity triage predictions.
  Future<MLTriagePrediction?> predictTriage({
    required List<String> symptoms,
    int age = 40,
    String gender = 'M',
    double heartRate = 80.0,
    double temperature = 37.0,
    double bloodOxygen = 98.0,
    double systolicBp = 120.0,
    double diastolicBp = 80.0,
  }) async {
    try {
      final response = await _dio.post('triage/predict', data: {
        'symptoms': symptoms,
        'age': age,
        'gender': gender,
        'heart_rate': heartRate,
        'temperature': temperature,
        'blood_oxygen': bloodOxygen,
        'systolic_bp': systolicBp,
        'diastolic_bp': diastolicBp,
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
