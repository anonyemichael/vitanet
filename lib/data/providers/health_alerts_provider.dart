import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/data/models/health_alert.dart';
import 'package:vitanet/data/providers/providers.dart';

/// The person's health alerts from the backend, newest first. Refreshed after
/// every vitals sync (lib/data/services/vitals_sync.dart), because a new
/// reading is what makes an alert.
class HealthAlertsNotifier extends StateNotifier<List<HealthAlertItem>> {
  HealthAlertsNotifier(this._ref) : super(const []);

  final Ref _ref;

  Future<void> refresh() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;
    final alerts = await _ref.read(apiServiceProvider).getAlerts(user.uid);
    if (mounted) state = alerts;
  }

  /// "I'm OK". Shown as answered at once; the server is told in the background.
  Future<void> acknowledge(String id) async {
    state = [for (final a in state) a.id == id ? a.copyWith(status: 'acknowledged') : a];
    await _ref.read(apiServiceProvider).acknowledgeAlert(id);
  }
}

final healthAlertsProvider =
    StateNotifierProvider<HealthAlertsNotifier, List<HealthAlertItem>>((ref) => HealthAlertsNotifier(ref));

/// The alert to show in the banner: the newest unanswered one from the last
/// 24 hours (urgent first), or null.
final activeHealthAlertProvider = Provider<HealthAlertItem?>((ref) {
  final cutoff = DateTime.now().subtract(const Duration(hours: 24));
  final open = ref.watch(healthAlertsProvider).where((a) => a.isOpen && a.createdAt.isAfter(cutoff)).toList();
  if (open.isEmpty) return null;
  return open.firstWhere((a) => a.isUrgent, orElse: () => open.first);
});
