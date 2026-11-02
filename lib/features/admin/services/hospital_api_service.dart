import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vitanet/core/network/backend.dart';
import '../models/patient.dart';
import '../models/alert.dart';
import '../models/hospital_data.dart';
import '../models/case_model.dart';
import '../widgets/staff_demo_data.dart';

class ApiService {
  final Dio _dio;

  /// Remotely configured backend URL + Firebase ID token on every request.
  ApiService({String? baseUrl}) : _dio = createBackendDio() {
    if (baseUrl != null) {
      _dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
        o.baseUrl = baseUrl;
        h.next(o);
      }));
    }
  }

  Future<HospitalStats> getDashboardStats() async {
    try {
      final response = await _dio.get('admin/stats');
      final data = response.data;
      return HospitalStats(
        activePatients: data['activePatients'] ?? 0,
        availableWards: data['availableWards'] ?? 0,
        systemHealth: data['systemHealth'] ?? '98%',
        staffOnDuty: data['staffOnDuty'] ?? 0,
      );
    } catch (e) {
      debugPrint('HospitalApiService: fallback stats used ($e)');
      return HospitalStats(activePatients: 24, availableWards: 5, systemHealth: '98%', staffOnDuty: 6);
    }
  }

  Future<List<Patient>> getPatients({String? query}) async {
    try {
      final response = await _dio.get(
        'admin/patients',
        queryParameters: query != null && query.isNotEmpty ? {'query': query} : null,
      );
      return (response.data as List).map((p) => Patient(
        id: p['id'] ?? '',
        name: p['name'] ?? 'Unknown',
        age: p['age'] ?? 0,
        gender: p['gender'] ?? 'Unknown',
        status: p['status'] ?? 'Unknown',
        lastUpdated: p['lastUpdated'] != null ? DateTime.parse(p['lastUpdated']) : DateTime.now(),
      )).toList();
    } catch (e) {
      debugPrint('HospitalApiService: fallback patients used ($e)');
      return [];
    }
  }

  Future<StaffPatientRecord?> getPatientDetail(String id) async {
    try {
      final response = await _dio.get('admin/patients/$id');
      final d = response.data;
      return StaffPatientRecord(
        id: d['id'] ?? id,
        name: d['name'] ?? '',
        age: d['age'] ?? 0,
        sex: d['sex'] ?? 'F',
        location: d['location'] ?? '',
        status: PatientStatus.parse(d['status'] ?? 'stable'),
        diagnosis: d['diagnosis'],
        allergy: d['allergy'],
        vitals: (d['vitals'] as List? ?? []).map((v) => VitalReading(
          v['label'] ?? '',
          v['value'] ?? '',
          alert: v['alert'] ?? false,
        )).toList(),
        timeline: (d['timeline'] as List? ?? []).map((t) => TimelineEntry(
          t['time'] ?? '',
          t['text'] ?? '',
          t['tone'] == 'critical'
              ? TimelineTone.critical
              : (t['tone'] == 'neutral' ? TimelineTone.neutral : TimelineTone.action),
        )).toList(),
        note: d['note'],
        noteAuthor: d['noteAuthor'],
      );
    } catch (e) {
      debugPrint('HospitalApiService: getPatientDetail failed ($e)');
      return null;
    }
  }

  Future<bool> createPatient(StaffPatientRecord r) async {
    try {
      await _dio.post('admin/patients', data: {
        'id': r.id,
        'name': r.name,
        'age': r.age,
        'sex': r.sex,
        'location': r.location,
        'status': r.status.name,
        'diagnosis': r.diagnosis,
        'allergy': r.allergy,
        'vitals': r.vitals.map((v) => {'label': v.label, 'value': v.value, 'alert': v.alert}).toList(),
        'note': r.note,
        'noteAuthor': r.noteAuthor ?? 'Dr. Kwame Mensah',
      });
      return true;
    } catch (e) {
      debugPrint('HospitalApiService: createPatient failed ($e)');
      return false;
    }
  }

  Future<bool> addPatientNote(String id, String note, {String author = 'Dr. Kwame Mensah'}) async {
    try {
      await _dio.post('admin/patients/$id/notes', data: {
        'note': note,
        'author': author,
      });
      return true;
    } catch (e) {
      debugPrint('HospitalApiService: addPatientNote failed ($e)');
      return false;
    }
  }

  Future<bool> transferPatient(String id, String newLocation, {String author = 'Dr. Kwame Mensah'}) async {
    try {
      await _dio.patch('admin/patients/$id/transfer', data: {
        'newLocation': newLocation,
        'author': author,
      });
      return true;
    } catch (e) {
      debugPrint('HospitalApiService: transferPatient failed ($e)');
      return false;
    }
  }

  Future<bool> updatePatientStatus(String id, String status) async {
    try {
      await _dio.patch('admin/patients/$id/status', queryParameters: {'status': status});
      return true;
    } catch (e) {
      debugPrint('HospitalApiService: updatePatientStatus failed ($e)');
      return false;
    }
  }

  Future<List<StaffCase>> getCases({String? status}) async {
    try {
      final response = await _dio.get(
        'admin/cases',
        queryParameters: status != null ? {'status': status} : null,
      );
      return (response.data as List).map((c) => StaffCase.fromJson(c)).toList();
    } catch (e) {
      debugPrint('HospitalApiService: getCases fallback used ($e)');
      return [];
    }
  }

  Future<bool> createCase(StaffCase c) async {
    try {
      await _dio.post('admin/cases', data: c.toJson());
      return true;
    } catch (e) {
      debugPrint('HospitalApiService: createCase failed ($e)');
      return false;
    }
  }

  Future<bool> updateCase(String id, {String? status, String? assignee}) async {
    try {
      await _dio.patch('admin/cases/$id', data: {
        'status': ?status,
        'assignee': ?assignee,
      });
      return true;
    } catch (e) {
      debugPrint('HospitalApiService: updateCase failed ($e)');
      return false;
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
      debugPrint('HospitalApiService: fallback alerts used ($e)');
      return [];
    }
  }

  Future<bool> attendAlert(String alertId, {String? note, String staffName = 'Dr. Kwame Mensah'}) async {
    try {
      await _dio.post('admin/alerts/$alertId/attend', data: {
        'note': note,
        'staffName': staffName,
      });
      return true;
    } catch (e) {
      debugPrint('HospitalApiService: attendAlert failed ($e)');
      return false;
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
      debugPrint('HospitalApiService: fallback wards used ($e)');
      return [];
    }
  }

  Future<List<EquipmentInfo>> getEquipment() async {
    try {
      final response = await _dio.get('admin/equipment');
      return (response.data as List).map((e) => EquipmentInfo.fromJson(e)).toList();
    } catch (e) {
      debugPrint('HospitalApiService: fallback equipment used ($e)');
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
        department: s['department'],
        patients: s['patients'],
        shift: s['shift'],
        phone: s['phone'],
        license: s['license'],
        email: s['email'],
        photo: s['photo'],
      )).toList();
    } catch (e) {
      debugPrint('HospitalApiService: fallback staff used ($e)');
      return [];
    }
  }
}
