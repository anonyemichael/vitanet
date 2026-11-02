import 'package:dio/dio.dart';
import 'package:vitanet/core/network/backend.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';

/// An error from the portal API, carrying the server's `detail` message
/// when there is one.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Human-readable message for any error thrown by [HospitalApiService].
String apiErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  return 'Something went wrong. Please try again.';
}

/// Typed client for the hospital portal backend. Every call is authenticated
/// with the signed-in user's Firebase ID token (see [createBackendDio]).
/// There are no sample-data fallbacks: failures throw [ApiException].
class HospitalApiService {
  HospitalApiService([Dio? dio]) : _dio = dio ?? createBackendDio();

  final Dio _dio;

  static ApiException _toApiException(DioException e) {
    final res = e.response;
    if (res == null) {
      return const ApiException("Can't reach the VitaNet server. Check your connection and try again.");
    }
    final data = res.data;
    String? detail;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) {
        detail = d;
      } else if (d is List) {
        // FastAPI validation errors: [{loc, msg, type}, ...]
        detail = d
            .whereType<Map>()
            .map((m) {
              final loc = m['loc'] is List ? (m['loc'] as List).last.toString().replaceAll('_', ' ') : null;
              final msg = m['msg']?.toString() ?? '';
              return loc == null ? msg : '$loc: $msg';
            })
            .where((s) => s.isNotEmpty)
            .join('\n');
      }
    }
    final code = res.statusCode;
    detail ??= switch (code) {
      401 => 'Your sign-in has expired. Please sign in again.',
      403 => "You don't have permission to do that.",
      404 => 'Not found.',
      _ => 'The server returned an error ($code). Please try again.',
    };
    return ApiException(detail, statusCode: code);
  }

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final res = await request();
      return res.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Map<String, dynamic> _obj(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : throw const ApiException('Unexpected response from the server.');

  // ─── Staff account ───

  /// The caller's staff account, or null when they have none (404).
  Future<StaffMe?> getStaffMe() async {
    try {
      return StaffMe.fromJson(_obj(await _send(() => _dio.get('staff/me'))));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<StaffMe> registerStaff({
    required String fullName,
    required StaffRole role,
    String? hospitalId,
    String? department,
    String? licenseNumber,
  }) async =>
      StaffMe.fromJson(_obj(await _send(() => _dio.post('staff/register', data: {
            'full_name': fullName,
            'role': role.api,
            'hospital_id': hospitalId,
            'department': (department ?? '').isEmpty ? null : department,
            'license_number': (licenseNumber ?? '').isEmpty ? null : licenseNumber,
          }))));

  /// approve | reject | suspend.
  Future<StaffMe> reviewStaff(String uid, String action, {String? note, StaffRole? role}) async =>
      StaffMe.fromJson(_obj(await _send(() => _dio.post('admin/staff-requests/${Uri.encodeComponent(uid)}/$action', data: {
            'note': (note ?? '').isEmpty ? null : note,
            'role': ?role?.api,
          }))));

  // ─── Facility ───

  Future<List<Facility>> listFacilities({double? lat, double? lng, int limit = 50}) async =>
      parseList(
          await _send(() => _dio.get('facilities', queryParameters: {
                'limit': limit,
                'lat': ?lat,
                'lng': ?lng,
              })),
          Facility.fromJson);

  Future<Facility> createHospital(Facility input) async =>
      Facility.fromJson(_obj(await _send(() => _dio.post('portal/hospitals', data: input.toJson()))));

  Future<Facility> getMyHospital() async =>
      Facility.fromJson(_obj(await _send(() => _dio.get('portal/hospital'))));

  Future<Facility> updateHospital(Facility input) async =>
      Facility.fromJson(_obj(await _send(() => _dio.put('portal/hospital', data: input.toJson()))));

  // ─── Dashboard & referrals ───

  Future<Dashboard> getDashboard() async =>
      Dashboard.fromJson(_obj(await _send(() => _dio.get('portal/dashboard'))));

  Future<List<Referral>> listReferrals({String? status}) async => parseList(
      await _send(() => _dio.get('portal/referrals', queryParameters: {'status': ?status})),
      Referral.fromJson);

  Future<Referral> getReferral(String id) async =>
      Referral.fromJson(_obj(await _send(() => _dio.get('portal/referrals/$id'))));

  Future<AcceptResult> acceptReferral(String id, {String? assigneeUid, int? wardId, String? bed}) async {
    final j = _obj(await _send(() => _dio.post('portal/referrals/$id/accept', data: {
          'assignee_uid': (assigneeUid ?? '').isEmpty ? null : assigneeUid,
          'ward_id': wardId,
          'bed': (bed ?? '').isEmpty ? null : bed,
        })));
    return AcceptResult(Referral.fromJson(_obj(j['referral'])), PortalCase.fromJson(_obj(j['case'])));
  }

  Future<Referral> declineReferral(String id, String reason) async =>
      Referral.fromJson(_obj(await _send(() => _dio.post('portal/referrals/$id/decline', data: {'reason': reason}))));

  // ─── Cases ───

  Future<List<PortalCase>> listCases({String? status, bool mine = false}) async => parseList(
      await _send(() => _dio.get('portal/cases', queryParameters: {
            'status': ?status,
            if (mine) 'mine': true,
          })),
      PortalCase.fromJson);

  Future<PortalCase> createCase(NewCaseInput input) async =>
      PortalCase.fromJson(_obj(await _send(() => _dio.post('portal/cases', data: input.toJson()))));

  Future<PortalCase> getCase(String id) async =>
      PortalCase.fromJson(_obj(await _send(() => _dio.get('portal/cases/$id'))));

  /// PATCH /portal/cases/{id}. Pass `assigneeUid: ''` to unassign and
  /// `bed: ''` to clear the bed.
  Future<PortalCase> updateCase(
    String id, {
    String? status,
    int? wardId,
    bool clearWard = false,
    String? bed,
    String? assigneeUid,
    String? level,
  }) async =>
      PortalCase.fromJson(_obj(await _send(() => _dio.patch('portal/cases/$id', data: {
            'status': ?status,
            'ward_id': ?wardId,
            if (clearWard) 'clear_ward': true,
            'bed': ?bed,
            'assignee_uid': ?assigneeUid,
            'level': ?level,
          }))));

  Future<PortalCase> addNote(String id, String text) async =>
      PortalCase.fromJson(_obj(await _send(() => _dio.post('portal/cases/$id/notes', data: {'text': text}))));

  Future<PortalCase> dischargeCase(String id, String summary) async =>
      PortalCase.fromJson(_obj(await _send(() => _dio.post('portal/cases/$id/discharge', data: {'summary': summary}))));

  // ─── Alerts, capacity, team, audit ───

  Future<List<PortalAlert>> listAlerts() async =>
      parseList(await _send(() => _dio.get('portal/alerts')), PortalAlert.fromJson);

  Future<Capacity> getCapacity() async =>
      Capacity.fromJson(_obj(await _send(() => _dio.get('portal/capacity'))));

  Future<void> addWard(WardInput input) async => _send(() => _dio.post('portal/wards', data: input.toJson()));

  Future<void> updateWard(int id, WardInput input) async =>
      _send(() => _dio.put('portal/wards/$id', data: input.toJson()));

  Future<void> deleteWard(int id) async => _send(() => _dio.delete('portal/wards/$id'));

  Future<void> addEquipment(EquipmentInput input) async =>
      _send(() => _dio.post('portal/equipment', data: input.toJson()));

  Future<void> updateEquipment(int id, EquipmentInput input) async =>
      _send(() => _dio.put('portal/equipment/$id', data: input.toJson()));

  Future<void> deleteEquipment(int id) async => _send(() => _dio.delete('portal/equipment/$id'));

  Future<TeamMember> setDuty(bool onDuty) async =>
      TeamMember.fromJson(_obj(await _send(() => _dio.put('portal/me/duty', data: {'on_duty': onDuty}))));

  Future<List<TeamMember>> listTeam() async =>
      parseList(await _send(() => _dio.get('portal/team')), TeamMember.fromJson);

  Future<List<AuditEntry>> listAudit({int limit = 200}) async => parseList(
      await _send(() => _dio.get('portal/audit', queryParameters: {'limit': limit})), AuditEntry.fromJson);
}
