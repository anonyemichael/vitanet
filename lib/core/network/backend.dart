import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the VitaNet backend lives and how to call it.
///
/// The URL is read at startup from Firestore `app_config/backend` (field
/// `url`), so when the server address changes only that document needs
/// updating — installed apps pick it up on next launch. The last good value
/// is cached locally, and a build-time default is the final fallback.
class BackendConfig {
  BackendConfig._();

  static const String _buildDefault = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://passed-nest-rouge-arrange.trycloudflare.com/',
  );
  static const String _prefsKey = 'backend_base_url';

  static String _baseUrl = _buildDefault;

  static String get baseUrl => _baseUrl;

  static String _normalise(String url) => url.endsWith('/') ? url : '$url/';

  /// Call once after Firebase is initialised. Never throws.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefsKey);
      if (cached != null && cached.startsWith('http')) _baseUrl = cached;

      if (Firebase.apps.isEmpty) return;
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('backend')
          .get()
          .timeout(const Duration(seconds: 4));
      final remote = doc.data()?['url'];
      if (remote is String && remote.startsWith('https://')) {
        _baseUrl = _normalise(remote);
        await prefs.setString(_prefsKey, _baseUrl);
      }
    } catch (e) {
      debugPrint('BackendConfig: using $_baseUrl ($e)');
    }
  }

  /// Firebase ID token for the signed-in user, or null.
  static Future<String?> idToken() async {
    try {
      if (Firebase.apps.isEmpty) return null;
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  /// Headers for raw `http` calls to the backend.
  static Future<Map<String, String>> authHeaders() async {
    final token = await idToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Uri uri(String path) => Uri.parse('$_baseUrl${path.startsWith('/') ? path.substring(1) : path}');
}

/// A Dio client for the backend that always uses the current base URL and
/// attaches the signed-in user's Firebase ID token.
Dio createBackendDio({
  Duration connectTimeout = const Duration(seconds: 8),
  Duration receiveTimeout = const Duration(seconds: 15),
}) {
  final dio = Dio(BaseOptions(
    connectTimeout: connectTimeout,
    receiveTimeout: receiveTimeout,
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      options.baseUrl = BackendConfig.baseUrl;
      final token = await BackendConfig.idToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    },
  ));
  return dio;
}
