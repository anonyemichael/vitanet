import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/patient.dart';
import '../models/alert.dart';
import '../models/hospital_data.dart';

class ApiService {
  final Dio _dio;
  static const String _baseUrl = 'https://vitanet-backend-api.onrender.com/';

  ApiService() : _dio = Dio(BaseOptions(baseUrl: _baseUrl)) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
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

  Future<HospitalStats> getDashboardStats() async {
    try {
      final response = await _dio.get('admin/stats');
      final data = response.data;
      return HospitalStats(
        activePatients: data['activePatients'] ?? 0,
        availableWards: data['availableWards'] ?? 0,
        systemHealth: data['systemHealth'] ?? 'Unknown',
        staffOnDuty: data['staffOnDuty'] ?? 0,
      );
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      return HospitalStats(activePatients: 0, availableWards: 0, systemHealth: 'N/A', staffOnDuty: 0);
    }
  }

  Future<List<Patient>> getPatients() async {
    try {
      final response = await _dio.get('admin/patients');
      return (response.data as List).map((p) => Patient(
        id: p['id'] ?? '',
        name: p['name'] ?? 'Unknown',
        age: p['age'] ?? 0,
        gender: p['gender'] ?? 'Unknown',
        status: p['status'] ?? 'Unknown',
        lastUpdated: p['lastUpdated'] != null ? DateTime.parse(p['lastUpdated']) : DateTime.now(),
      )).toList();
    } catch (e) {
      debugPrint('Error fetching patients: $e');
      return [];
    }
  }

  Future<List<ClinicalAlert>> getAlerts() async {
    try {
      final response = await _dio.get('admin/alerts');
      return (response.data as List).map((a) => ClinicalAlert(
        id: a['id'] ?? '',
        title: a['severity'] == 'urgent' ? 'Urgent Alert' : 'Watch Alert',
        description: a['message'] ?? '',
        isCritical: a['severity'] == 'urgent',
        timestamp: a['created_at'] != null ? DateTime.parse(a['created_at']) : DateTime.now(),
      )).toList();
    } catch (e) {
      debugPrint('Error fetching alerts: $e');
      return [];
    }
  }

  Future<List<WardInfo>> getWards() async {
    try {
      final response = await _dio.get('admin/wards');
      return (response.data as List).map((w) => WardInfo(
        name: w['name'] ?? '',
        occupied: w['occupied'] ?? 0,
        total: w['total'] ?? 0,
        type: w['type'] ?? '',
      )).toList();
    } catch (e) {
      debugPrint('Error fetching wards: $e');
      return [];
    }
  }

  Future<List<StaffInfo>> getStaff() async {
    try {
      final response = await _dio.get('admin/staff');
      return (response.data as List).map((s) => StaffInfo(
        name: s['name'] ?? '',
        role: s['role'] ?? '',
        status: s['status'] ?? '',
      )).toList();
    } catch (e) {
      debugPrint('Error fetching staff: $e');
      return [];
    }
  }
}
