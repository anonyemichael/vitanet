import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide text scale chosen in Settings → Text size.
final textScaleProvider = StateNotifierProvider<TextScaleNotifier, double>((ref) {
  return TextScaleNotifier();
});

class TextScaleNotifier extends StateNotifier<double> {
  static const _key = 'settings_text_scale';
  static const options = <(String, double)>[
    ('Default', 1.0),
    ('Large', 1.15),
    ('Larger', 1.3),
  ];

  TextScaleNotifier() : super(1.0) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getDouble(_key);
      if (v != null && mounted) state = v;
    } catch (_) {}
  }

  Future<void> set(double value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_key, value);
    } catch (_) {}
  }

  static String labelFor(double v) =>
      options.firstWhere((o) => o.$2 == v, orElse: () => options.first).$1;
}

/// Notification preference toggles, persisted locally.
final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, Map<String, bool>>((ref) {
  return NotificationPrefsNotifier();
});

class NotificationPrefsNotifier extends StateNotifier<Map<String, bool>> {
  static const defaults = <String, bool>{
    'urgent_alerts': true,
    'medication_reminders': true,
    'weekly_summary': false,
    'care_circle_activity': true,
  };

  NotificationPrefsNotifier() : super(defaults) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = {
        for (final e in defaults.entries) e.key: prefs.getBool('notif_${e.key}') ?? e.value,
      };
      if (mounted) state = next;
    } catch (_) {}
  }

  Future<void> toggle(String key, bool value) async {
    state = {...state, key: value};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_$key', value);
    } catch (_) {}
  }
}
