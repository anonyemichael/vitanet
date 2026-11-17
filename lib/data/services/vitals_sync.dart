import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitanet/data/providers/health_alerts_provider.dart';
import 'package:vitanet/data/providers/providers.dart';

/// When readings were last pulled successfully from a real source (device /
/// health platform, or the user's backend record). `null` means no source has
/// delivered data this session.
final vitalsLastSyncProvider = StateProvider<DateTime?>((ref) => null);

/// What the last sync really did (audit F-06): permission, readings read, readings saved, and any error.
class SyncOutcome {
  final bool permission;
  final int read;
  final int uploaded;
  final String? error;
  final DateTime at;

  SyncOutcome({required this.permission, required this.read, required this.uploaded, this.error})
      : at = DateTime.now();

  bool get readOk => permission && error == null;
}

final lastSyncOutcomeProvider = StateProvider<SyncOutcome?>((ref) => null);

/// Where the readings on screen came from and when each was measured (UI/UX audit UX-17), so a tile can say
/// "From Health Connect · 10:42" or "Old reading" instead of looking current.
class VitalsProvenance {
  final String source;
  final Map<String, DateTime> measuredAt;
  const VitalsProvenance(this.source, this.measuredAt);

  DateTime? get newest =>
      measuredAt.values.fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
}

final vitalsProvenanceProvider = StateProvider<VitalsProvenance?>((ref) => null);

/// Whether VitaNet may use the phone's watch readings. Turned off by "Disconnect" and remembered across app
/// restarts (audit F-05); turned on again by "Connect / Sync now".
final deviceSharingProvider = StateNotifierProvider<DeviceSharing, bool>((ref) => DeviceSharing());

class DeviceSharing extends StateNotifier<bool> {
  static const _key = 'device_sharing_on';
  DeviceSharing() : super(true) {
    SharedPreferences.getInstance().then((p) {
      if (mounted) state = p.getBool(_key) ?? true;
    }).catchError((Object _) {});
  }

  Future<void> set(bool on) async {
    state = on;
    try {
      (await SharedPreferences.getInstance()).setBool(_key, on);
    } catch (_) {}
  }
}

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
    if (!_ref.read(deviceSharingProvider)) return const {}; // the person disconnected their device
    final api = _ref.read(apiServiceProvider);
    final live = _ref.read(liveVitalsProvider.notifier);
    try {
      if (!kIsWeb) {
        final health = _ref.read(healthServiceProvider);
        final readings = await health.fetchLatestReadings();
        final error = health.lastError;
        if (readings.isEmpty) {
          _ref.read(lastSyncOutcomeProvider.notifier).state = SyncOutcome(
              permission: error != 'permission not granted', read: 0, uploaded: 0, error: error);
        }
        if (readings.isNotEmpty) {
          final values = {for (final e in readings.entries) e.key: e.value.value};
          values.forEach(live.setVital);
          _ref.read(vitalsLastSyncProvider.notifier).state = DateTime.now();
          _ref.read(vitalsProvenanceProvider.notifier).state = VitalsProvenance(
              defaultTargetPlatform == TargetPlatform.iOS ? 'Apple Health' : 'Health Connect',
              {for (final e in readings.entries) e.key: e.value.at});
          final sent = await api.postDeviceVitals(user.uid, values,
              measuredAt: {for (final e in readings.entries) e.key: e.value.at});
          _ref.read(lastSyncOutcomeProvider.notifier).state = SyncOutcome(
              permission: true, read: values.length, uploaded: sent,
              error: sent == 0 ? 'could not save to your VitaNet account' : null);
          await _ref.read(healthAlertsProvider.notifier).refresh();   // a new reading can make an alert
          return values;
        }
      }
      // No watch data on this phone: show the latest readings already on the
      // user's own backend record (e.g. from another phone or a hospital).
      await _ref.read(healthAlertsProvider.notifier).refresh();
      final saved = await api.getLatestVitals(user.uid);
      if (saved.isNotEmpty) {
        saved.forEach(live.setVital);
        _ref.read(vitalsLastSyncProvider.notifier).state = DateTime.now();
        _ref.read(vitalsProvenanceProvider.notifier).state = const VitalsProvenance('your VitaNet account', {});
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
