import 'package:health/health.dart';
import 'package:flutter/foundation.dart';

class HealthService {
  late final Health _health;

  HealthService() {
    _health = Health();
  }

  Future<bool> requestPermissions() async {
    final types = [
      HealthDataType.HEART_RATE,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.BODY_TEMPERATURE,
      HealthDataType.RESPIRATORY_RATE,
      HealthDataType.STEPS,
      HealthDataType.SLEEP_SESSION,
    ];
    
    final permissions = types.map((e) => HealthDataAccess.READ).toList();

    try {
      bool? hasPermissions = await _health.hasPermissions(types, permissions: permissions);
      if (hasPermissions != true) {
        bool requested = await _health.requestAuthorization(types, permissions: permissions);
        return requested;
      }
      return true;
    } catch (e) {
      debugPrint("Error requesting health permissions: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchBiometrics() async {
    Map<String, dynamic> biometrics = {};
    
    final hasPerms = await requestPermissions();
    if (!hasPerms) return biometrics;

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 2));

    try {
      final types = [
        HealthDataType.HEART_RATE,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      ];
      
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: yesterday,
        endTime: now,
        types: types,
      );

      if (healthData.isNotEmpty) {
        healthData.sort((a, b) => b.dateTo.compareTo(a.dateTo));
        
        for (var point in healthData) {
          final val = point.value;
          if (point.type == HealthDataType.HEART_RATE && !biometrics.containsKey('heart_rate')) {
            biometrics['heart_rate'] = val.toString();
          } else if (point.type == HealthDataType.BLOOD_PRESSURE_SYSTOLIC && !biometrics.containsKey('systolic_bp')) {
            biometrics['systolic_bp'] = val.toString();
          } else if (point.type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC && !biometrics.containsKey('diastolic_bp')) {
            biometrics['diastolic_bp'] = val.toString();
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching biometrics: $e");
    }

    return biometrics;
  }

  Future<List<HealthDataPoint>> fetchMetric(String metricId, int daysBack) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: daysBack));

    HealthDataType type;
    switch (metricId) {
      case 'heart_rate':
        type = HealthDataType.HEART_RATE;
        break;
      case 'blood_oxygen':
        type = HealthDataType.BLOOD_OXYGEN;
        break;
      case 'temperature':
        type = HealthDataType.BODY_TEMPERATURE;
        break;
      case 'respiratory_rate':
        type = HealthDataType.RESPIRATORY_RATE;
        break;
      default:
        type = HealthDataType.HEART_RATE;
    }

    try {
      List<HealthDataPoint> data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [type],
      );
      data = Health().removeDuplicates(data);
      data.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
      return data;
    } catch (e) {
      debugPrint("Error fetching metric $metricId: $e");
      return [];
    }
  }
}

