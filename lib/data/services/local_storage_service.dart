import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitanet/data/models/triage_result.dart';
import 'package:vitanet/data/models/user_profile.dart';

/// Manages local storage for user profile and triage history.
class LocalStorageService {
  static const _profileKey = 'user_profile';
  static const _historyKey = 'triage_history';
  static const _onboardingKey = 'onboarding_complete';
  static const _themeKey = 'theme_mode';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  // ─── Onboarding ───
  bool get isOnboardingComplete => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> setOnboardingComplete() =>
      _prefs.setBool(_onboardingKey, true);

  // ─── Theme ───
  String get themeMode => _prefs.getString(_themeKey) ?? 'system';

  Future<void> setThemeMode(String mode) =>
      _prefs.setString(_themeKey, mode);

  // ─── User Profile ───
  UserProfile? getProfile() {
    final json = _prefs.getString(_profileKey);
    if (json == null) return null;
    return UserProfile.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> saveProfile(UserProfile profile) =>
      _prefs.setString(_profileKey, jsonEncode(profile.toMap()));

  // ─── Triage History ───
  List<TriageResult> getHistory() {
    final json = _prefs.getString(_historyKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list
        .map((e) => TriageResult.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveHistory(List<TriageResult> history) => _prefs.setString(
        _historyKey,
        jsonEncode(history.map((e) => e.toMap()).toList()),
      );

  Future<void> addTriageResult(TriageResult result) async {
    final history = getHistory();
    history.insert(0, result);
    await saveHistory(history);
  }

  Future<void> deleteTriageResult(String id) async {
    final history = getHistory();
    history.removeWhere((e) => e.id == id);
    await saveHistory(history);
  }

  Future<void> clearHistory() => _prefs.remove(_historyKey);
}
