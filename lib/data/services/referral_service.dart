import 'package:dio/dio.dart';

/// A hospital registered with VitaNet (from `GET /facilities`).
class Facility {
  final String id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? phoneNumber;
  final bool hasEmergencyRoom;
  final bool acceptingReferrals;
  final double? distanceKm;
  final int? etaMinutes;
  final int bedsTotal;
  final int bedsFree;

  const Facility({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.phoneNumber,
    this.hasEmergencyRoom = false,
    this.acceptingReferrals = false,
    this.distanceKm,
    this.etaMinutes,
    this.bedsTotal = 0,
    this.bedsFree = 0,
  });

  factory Facility.fromJson(Map<String, dynamic> j) => Facility(
        id: j['id'].toString(),
        name: (j['name'] as String?) ?? 'Hospital',
        address: j['address'] as String?,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        phoneNumber: j['phone_number'] as String?,
        hasEmergencyRoom: j['has_emergency_room'] == true,
        acceptingReferrals: j['accepting_referrals'] == true,
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        etaMinutes: (j['eta_minutes'] as num?)?.toInt(),
        bedsTotal: (j['beds_total'] as num?)?.toInt() ?? 0,
        bedsFree: (j['beds_free'] as num?)?.toInt() ?? 0,
      );
}

/// Case details the hospital attached once it accepted a referral.
class ReferralCase {
  final String? status;
  final String? assigneeName;
  final String? wardName;
  final String? bed;

  const ReferralCase({this.status, this.assigneeName, this.wardName, this.bed});

  factory ReferralCase.fromJson(Map<String, dynamic> j) => ReferralCase(
        status: j['status'] as String?,
        assigneeName: j['assignee_name'] as String?,
        wardName: j['ward_name'] as String?,
        bed: j['bed'] as String?,
      );
}

/// Referral statuses as returned by the backend.
abstract final class ReferralStatus {
  static const newRef = 'new';
  static const accepted = 'accepted';
  static const declined = 'declined';
  static const cancelled = 'cancelled';
  static const arrived = 'arrived';
}

/// A patient's referral to a hospital.
class Referral {
  final String id;
  final String hospitalId;
  final String? hospitalName;
  final String status;
  final String? triageLevel;
  final int? etaMinutes;
  final String? declineReason;
  final String? caseId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ReferralCase? caseInfo;

  const Referral({
    required this.id,
    required this.hospitalId,
    required this.status,
    this.hospitalName,
    this.triageLevel,
    this.etaMinutes,
    this.declineReason,
    this.caseId,
    this.createdAt,
    this.updatedAt,
    this.caseInfo,
  });

  /// Still waiting on, or accepted by, the hospital.
  bool get isOpen => status == ReferralStatus.newRef || status == ReferralStatus.accepted;

  factory Referral.fromJson(Map<String, dynamic> j) => Referral(
        id: j['id'].toString(),
        hospitalId: j['hospital_id'].toString(),
        hospitalName: j['hospital_name'] as String?,
        status: (j['status'] as String?) ?? ReferralStatus.newRef,
        triageLevel: j['triage_level'] as String?,
        etaMinutes: (j['eta_minutes'] as num?)?.toInt(),
        declineReason: j['decline_reason'] as String?,
        caseId: j['case_id']?.toString(),
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? ''),
        caseInfo: j['case'] is Map
            ? ReferralCase.fromJson(Map<String, dynamic>.from(j['case'] as Map))
            : null,
      );
}

/// Body for `POST /referrals`. Only what the patient agreed to share.
class ReferralRequest {
  final String hospitalId;
  final bool consent;
  final String triageLevel; // urgent | doctor | pharmacist | self_care
  final String complaint;
  final String? triageSummary;
  final String? patientName;
  final int? age;
  final String? sex;
  final List<String> allergies;
  final List<String> medications;
  final List<String> conditions;
  final Map<String, dynamic> vitals;
  final double? latitude;
  final double? longitude;

  const ReferralRequest({
    required this.hospitalId,
    required this.consent,
    required this.triageLevel,
    required this.complaint,
    this.triageSummary,
    this.patientName,
    this.age,
    this.sex,
    this.allergies = const [],
    this.medications = const [],
    this.conditions = const [],
    this.vitals = const {},
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'hospital_id': hospitalId,
        'consent': consent,
        'triage_level': triageLevel,
        'complaint': complaint,
        if (triageSummary != null) 'triage_summary': triageSummary,
        if (patientName != null) 'patient_name': patientName,
        if (age != null) 'age': age,
        if (sex != null) 'sex': sex,
        'allergies': allergies,
        'medications': medications,
        'conditions': conditions,
        'vitals': vitals,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

/// A readable error from the referral API (`{"detail": "..."}`).
class ReferralException implements Exception {
  final String message;
  final int? statusCode;
  const ReferralException(this.message, {this.statusCode});

  /// The backend refuses a second referral while one is new/accepted.
  bool get isOpenReferralConflict =>
      statusCode == 409 && message.toLowerCase().contains('open referral');

  @override
  String toString() => message;
}

/// Typed client for the patient side of hospital referrals.
class ReferralService {
  final Dio _dio;
  ReferralService(this._dio);

  Future<List<Facility>> listFacilities({double? lat, double? lng, int limit = 20}) =>
      _guard(() async {
        final res = await _dio.get('facilities', queryParameters: {
          if (lat != null && lng != null) 'lat': lat,
          if (lat != null && lng != null) 'lng': lng,
          'limit': limit,
        });
        return (res.data as List)
            .map((e) => Facility.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });

  Future<Referral> create(ReferralRequest request) => _guard(() async {
        final res = await _dio.post('referrals', data: request.toJson());
        return Referral.fromJson(Map<String, dynamic>.from(res.data as Map));
      });

  Future<List<Referral>> mine() => _guard(() async {
        final res = await _dio.get('referrals/mine');
        return (res.data as List)
            .map((e) => Referral.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });

  Future<Referral> cancel(String id) => _guard(() async {
        final res = await _dio.post('referrals/$id/cancel');
        return Referral.fromJson(Map<String, dynamic>.from(res.data as Map));
      });

  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      final data = e.response?.data;
      String? detail;
      if (data is Map && data['detail'] != null) {
        final d = data['detail'];
        // FastAPI validation errors come back as a list of objects.
        detail = d is List
            ? d.map((x) => x is Map ? (x['msg'] ?? x).toString() : x.toString()).join('; ')
            : d.toString();
      }
      throw ReferralException(
        detail ??
            (e.response == null
                ? 'Could not reach VitaNet. Check your connection and try again.'
                : 'Something went wrong (${e.response?.statusCode}). Please try again.'),
        statusCode: e.response?.statusCode,
      );
    }
  }
}
