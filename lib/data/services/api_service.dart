import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:vitanet/data/models/user_profile.dart';

class ApiService {
  final Dio _dio;

  // Placeholder base URL for the custom backend. The backend team will update this.
  static const String _baseUrl = 'https://api.vitanet-dev.com/v1/';

  ApiService() : _dio = Dio(BaseOptions(baseUrl: _baseUrl)) {
    // Interceptor to automatically attach the Firebase ID token to all outgoing requests
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            // Get the ID token, forcing a refresh if necessary
            final idToken = await currentUser.getIdToken();
            if (idToken != null) {
              options.headers['Authorization'] = 'Bearer $idToken';
            }
          }
          return handler.next(options);
        },
      ),
    );
  }

  /// Registers a new user with the backend using the exact fields requested.
  Future<void> registerUser(Map<String, dynamic> payload) async {
    try {
      if (kDebugMode) {
        print('--- API REQUEST: Register User ---');
        print('URL: ${_baseUrl}users/register');
        print('Payload: $payload');
      }

      // Uncomment below when backend is ready
      // await _dio.post('users/register', data: payload);
      
    } catch (e) {
      debugPrint('Error registering user to backend: $e');
    }
  }

  /// Adds an emergency contact for the user.
  Future<void> addEmergencyContact(Map<String, dynamic> payload) async {
    try {
      if (kDebugMode) {
        print('--- API REQUEST: Add Emergency Contact ---');
        print('URL: ${_baseUrl}users/emergency-contact');
        print('Payload: $payload');
      }

      // Uncomment below when backend is ready
      // await _dio.post('users/emergency-contact', data: payload);
      
    } catch (e) {
      debugPrint('Error adding emergency contact to backend: $e');
    }
  }

  /// Sends the fully filled out UserProfile to the custom backend in JSON format.
  Future<void> syncUserProfile(UserProfile profile) async {
    try {
      final payload = profile.toMap();

      if (kDebugMode) {
        print('--- API REQUEST: Syncing User Profile ---');
        print('URL: ${_baseUrl}users/profile');
        print('Payload: $payload');
      }

      // Uncomment below when backend is ready
      // await _dio.put('users/profile', data: payload);
      
    } catch (e) {
      debugPrint('Error syncing user profile to backend: $e');
    }
  }

  /// Fetches the connection status of various health monitoring devices.
  Future<Map<String, bool>> getDeviceConnections() async {
    try {
      if (kDebugMode) {
        print('--- API REQUEST: Get Device Connections ---');
        print('URL: ${_baseUrl}devices/connections');
      }

      // Mock response for now. Backend team should implement this endpoint.
      return {
        'heart_rate': true,
        'blood_oxygen': false,
        'temperature': false,
        'respiratory_rate': false,
      };

      // Uncomment below when backend is ready
      // final response = await _dio.get('devices/connections');
      // return Map<String, bool>.from(response.data);
      
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
}
