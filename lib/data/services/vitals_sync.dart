import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/data/providers/providers.dart';

/// When readings were last pulled successfully from a real source (device /
/// health platform, or the user's backend record). `null` means no source has
/// delivered data this session.
final vitalsLastSyncProvider = StateProvider<DateTime?>((ref) => null);

/// One place that keeps the watch readings, the app and the backend in step.
///
/// Watch -> Health Connect / Apple Health -> [syncNow] -> the vitals card
/// ([liveVitalsProvider]) and the backend (`POST /vitals/{id}/batch`), where
/// the assistant's `get_health_metrics` tool and the health alerts read them.
///
/// It runs every 2 minutes while the app is open on ANY screen, again when the
/// app comes back to the front, and right before each chat message, so the
/// assistant always sees the newest reading. Guests are included: their
/// readings go to their own (anonymous) account. Each reading carries the time
/// the watch took it, so the backend stores it once.
///
/// Not covered yet: syncing while the app is closed (needs a background task
/// and the "read health data in the background" permission).
class VitalsSync with WidgetsBindingObserver {
  VitalsSync(this._ref);

  static const interval = Duration(minutes: 2);

  final Ref _ref;
  Timer? _timer;
  Future<Map<String, double>>? _running;

  void start() {
    if (_timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    syncNow();
    _timer = Timer.periodic(interval, (_) => syncNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) syncNow();
  }

  /// Reads the watch now and sends what it found. Returns the readings taken
  /// from the watch (empty when there is no watch data). Calls made while a
  /// sync is running share that sync.
  Future<Map<String, double>> syncNow() =>
      _running ??= _sync().whenComplete(() => _running = null);

  Future<Map<String, double>> _sync() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return const {};          // not signed in yet (not even as a guest)
    final api = _ref.read(apiServiceProvider);
    final live = _ref.read(liveVitalsProvider.notifier);
    try {
      if (!kIsWeb) {
        final readings = await _ref.read(healthServiceProvider).fetchLatestReadings();
        if (readings.isNotEmpty) {
          final values = {for (final e in readings.entries) e.key: e.value.value};
          values.forEach(live.setVital);
          _ref.read(vitalsLastSyncProvider.notifier).state = DateTime.now();
          await api.postDeviceVitals(user.uid, values,
              measuredAt: {for (final e in readings.entries) e.key: e.value.at});
          return values;
        }
      }
      // No watch data on this phone: show the latest readings already on the
      // user's own backend record (e.g. from another phone or a hospital).
      final saved = await api.getLatestVitals(user.uid);
      if (saved.isNotEmpty) {
        saved.forEach(live.setVital);
        _ref.read(vitalsLastSyncProvider.notifier).state = DateTime.now();
      }
    } catch (e) {
      debugPrint('VitalsSync: $e');
    }
    return const {};
  }
}

final vitalsSyncProvider = Provider<VitalsSync>((ref) {
  final sync = VitalsSync(ref);
  ref.onDispose(sync.stop);
  return sync;
});
