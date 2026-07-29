import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import '../services/health_service.dart';

final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService();
});

class HealthMetricRequest {
  final String metricId;
  final int daysBack;

  HealthMetricRequest({required this.metricId, required this.daysBack});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HealthMetricRequest &&
        other.metricId == metricId &&
        other.daysBack == daysBack;
  }

  @override
  int get hashCode => metricId.hashCode ^ daysBack.hashCode;
}

final healthDataProvider = FutureProvider.family<List<HealthDataPoint>, HealthMetricRequest>((ref, request) async {
  final service = ref.watch(healthServiceProvider);
  final hasPerms = await service.requestPermissions();
  if (!hasPerms) {
    return [];
  }
  return service.fetchMetric(request.metricId, request.daysBack);
});
