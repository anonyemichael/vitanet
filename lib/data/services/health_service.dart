import 'package:health/health.dart';
import 'package:flutter/foundation.dart';

class HealthService {
  late final Health _health;

  HealthService() {
    _health = Health();
    if (!kIsWeb) _health.configure().catchError((e) => debugPrint('Health configure failed: $e'));
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    
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

  static const _keyFor = {
    HealthDataType.HEART_RATE: 'heart_rate',
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC: 'systolic_bp',
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC: 'diastolic_bp',
    HealthDataType.BLOOD_OXYGEN: 'blood_oxygen',
    HealthDataType.BODY_TEMPERATURE: 'temperature',
    HealthDataType.RESPIRATORY_RATE: 'respiratory_rate',
  };

  /// The plugin reports values as a [HealthValue] object (its text is "NumericHealthValue - numericValue: 72"),
  /// so the number must be taken out of it, not parsed from the text.
  static double? numberOf(HealthValue value) =>
      value is NumericHealthValue ? value.numericValue.toDouble() : null;

  /// The newest reading of each vital from the last 2 days, with the time it was measured.
  /// Keys: heart_rate, systolic_bp, diastolic_bp, blood_oxygen, temperature, respiratory_rate.
  Future<Map<String, ({double value, DateTime at})>> fetchLatestReadings() async {
    final out = <String, ({double value, DateTime at})>{};
    if (!await requestPermissions()) return out;
    final now = DateTime.now();
    try {
      final points = await _health.getHealthDataFromTypes(
        startTime: now.subtract(const Duration(days: 2)),
        endTime: now,
        types: _keyFor.keys.toList(),
      );
      points.sort((a, b) => b.dateTo.compareTo(a.dateTo));          // newest first
      for (final point in points) {
        final key = _keyFor[point.type];
        final v = numberOf(point.value);
        if (key != null && v != null && !out.containsKey(key)) out[key] = (value: v, at: point.dateTo);
      }
    } catch (e) {
      debugPrint('Error fetching biometrics: $e');
    }
    return out;
  }

  /// Newest reading of each vital as plain numbers (see [fetchLatestReadings]).
  Future<Map<String, double>> fetchBiometrics() async =>
      {for (final e in (await fetchLatestReadings()).entries) e.key: e.value.value};

  Future<List<HealthDataPoint>> fetchMetric(String metricId, int daysBack) async {
    if (kIsWeb) return [];

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

