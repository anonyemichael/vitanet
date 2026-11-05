/// Typed models for the hospital portal API (vitanet-backend
/// app/routes/portal.py and app/routes/staff.py). Parsing is defensive:
/// missing optional fields become null / empty, never sample values.
library;

String? _str(dynamic v) => v?.toString();
int? _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));
double? _double(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
bool _bool(dynamic v) => v == true;
List<String> _strList(dynamic v) =>
    v is List ? v.where((e) => e != null).map((e) => e.toString()).toList() : const [];
Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const {};

enum StaffRole {
  doctor('doctor', 'Doctor'),
  nurse('nurse', 'Nurse'),
  admin('admin', 'Admin');

  final String api;
  final String label;
  const StaffRole(this.api, this.label);

  static StaffRole parse(dynamic v) =>
      StaffRole.values.firstWhere((r) => r.api == v, orElse: () => StaffRole.doctor);
}

enum StaffStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  suspended('suspended');

  final String api;
  const StaffStatus(this.api);

  static StaffStatus parse(dynamic v) =>
      StaffStatus.values.firstWhere((s) => s.api == v, orElse: () => StaffStatus.pending);
}

/// GET /staff/me, POST /staff/register.
class StaffMe {
  final String firebaseUid;
  final String? email;
  final String fullName;
  final StaffRole role;
  final StaffStatus status;
  final String? hospitalId;
  final bool onDuty;
  final String? department;
  final String? licenseNumber;
  final String? reviewNote;

  const StaffMe({
    required this.firebaseUid,
    this.email,
    required this.fullName,
    required this.role,
    required this.status,
    this.hospitalId,
    this.onDuty = false,
    this.department,
    this.licenseNumber,
    this.reviewNote,
  });

  bool get isAdmin => role == StaffRole.admin;

  factory StaffMe.fromJson(Map<String, dynamic> j) => StaffMe(
        firebaseUid: _str(j['firebase_uid']) ?? '',
        email: _str(j['email']),
        fullName: _str(j['full_name']) ?? '',
        role: StaffRole.parse(j['role']),
        status: StaffStatus.parse(j['status']),
        hospitalId: _str(j['hospital_id']),
        onDuty: _bool(j['on_duty']),
        department: _str(j['department']),
        licenseNumber: _str(j['license_number']),
        reviewNote: _str(j['review_note']),
      );
}

/// A registered facility (`_hospital_out`). Also used as the request body
/// for POST /portal/hospitals and PUT /portal/hospital.
class Facility {
  final String? id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final String? phoneNumber;
  final bool hasEmergencyRoom;
  final bool hasAmbulance;
  final bool ambulanceAvailable;
  final bool acceptingReferrals;
  final double? distanceKm;
  final int bedsTotal;
  final int bedsFree;
  final int? etaMinutes;

  const Facility({
    this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.phoneNumber,
    this.hasEmergencyRoom = true,
    this.hasAmbulance = false,
    this.ambulanceAvailable = false,
    this.acceptingReferrals = true,
    this.distanceKm,
    this.bedsTotal = 0,
    this.bedsFree = 0,
    this.etaMinutes,
  });

  factory Facility.fromJson(Map<String, dynamic> j) => Facility(
        id: _str(j['id']),
        name: _str(j['name']) ?? '',
        address: _str(j['address']),
        latitude: _double(j['latitude']) ?? 0,
        longitude: _double(j['longitude']) ?? 0,
        phoneNumber: _str(j['phone_number']),
        hasEmergencyRoom: _bool(j['has_emergency_room']),
        hasAmbulance: _bool(j['has_ambulance']),
        ambulanceAvailable: _bool(j['ambulance_available']),
        acceptingReferrals: _bool(j['accepting_referrals']),
        distanceKm: _double(j['distance_km']),
        bedsTotal: _int(j['beds_total']) ?? 0,
        bedsFree: _int(j['beds_free']) ?? 0,
        etaMinutes: _int(j['eta_minutes']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': (address ?? '').isEmpty ? null : address,
        'latitude': latitude,
        'longitude': longitude,
        'phone_number': (phoneNumber ?? '').isEmpty ? null : phoneNumber,
        'has_emergency_room': hasEmergencyRoom,
        'has_ambulance': hasAmbulance,
        'ambulance_available': hasAmbulance && ambulanceAvailable,
        'accepting_referrals': acceptingReferrals,
      };
}

/// The consented patient summary attached to a referral.
class ReferralSummary {
  final String? patientName;
  final int? age;
  final String? sex;
  final String? complaint;
  final String? triageSummary;
  final List<String> allergies;
  final List<String> medications;
  final List<String> conditions;
  final Map<String, dynamic> vitals;

  const ReferralSummary({
    this.patientName,
    this.age,
    this.sex,
    this.complaint,
    this.triageSummary,
    this.allergies = const [],
    this.medications = const [],
    this.conditions = const [],
    this.vitals = const {},
  });

  factory ReferralSummary.fromJson(Map<String, dynamic> j) => ReferralSummary(
        patientName: _str(j['patient_name']),
        age: _int(j['age']),
        sex: _str(j['sex']),
        complaint: _str(j['complaint']),
        triageSummary: _str(j['triage_summary']),
        allergies: _strList(j['allergies']),
        medications: _strList(j['medications']),
        conditions: _strList(j['conditions']),
        vitals: _map(j['vitals']),
      );
}

class Referral {
  final String id;
  final String hospitalId;
  final String? hospitalName;
  final String status; // new | accepted | declined | cancelled | arrived
  final String triageLevel;
  final ReferralSummary summary;
  final int? etaMinutes;
  final String? declineReason;
  final String? caseId;
  final String createdAt;
  final String updatedAt;

  const Referral({
    required this.id,
    required this.hospitalId,
    this.hospitalName,
    required this.status,
    required this.triageLevel,
    required this.summary,
    this.etaMinutes,
    this.declineReason,
    this.caseId,
    required this.createdAt,
    required this.updatedAt,
  });

  String get patientName => summary.patientName ?? 'VitaNet patient';

  factory Referral.fromJson(Map<String, dynamic> j) => Referral(
        id: _str(j['id']) ?? '',
        hospitalId: _str(j['hospital_id']) ?? '',
        hospitalName: _str(j['hospital_name']),
        status: _str(j['status']) ?? 'new',
        triageLevel: _str(j['triage_level']) ?? 'routine',
        summary: ReferralSummary.fromJson(_map(j['summary'])),
        etaMinutes: _int(j['eta_minutes']),
        declineReason: _str(j['decline_reason']),
        caseId: _str(j['case_id']),
        createdAt: _str(j['created_at']) ?? '',
        updatedAt: _str(j['updated_at']) ?? '',
      );
}

class TimelineEvent {
  final String at;
  final String by;
  final String kind;
  final String text;

  const TimelineEvent({required this.at, required this.by, required this.kind, required this.text});

  factory TimelineEvent.fromJson(Map<String, dynamic> j) => TimelineEvent(
        at: _str(j['at']) ?? '',
        by: _str(j['by']) ?? '',
        kind: _str(j['kind']) ?? 'note',
        text: _str(j['text']) ?? '',
      );
}

class PortalCase {
  final String id;
  final String? referralId;
  final String patientName;
  final int? age;
  final String? sex;
  final String complaint;
  final String level; // urgent | doctor | routine
  final String status; // waiting | treatment | discharged
  final int? wardId;
  final String? wardName;
  final String? bed;
  final String? assigneeUid;
  final String? assigneeName;
  final String? allergies;
  final List<TimelineEvent> timeline;
  final String? dischargeSummary;
  final String createdAt;
  final String updatedAt;
  final Referral? referral;

  const PortalCase({
    required this.id,
    this.referralId,
    required this.patientName,
    this.age,
    this.sex,
    required this.complaint,
    required this.level,
    required this.status,
    this.wardId,
    this.wardName,
    this.bed,
    this.assigneeUid,
    this.assigneeName,
    this.allergies,
    this.timeline = const [],
    this.dischargeSummary,
    required this.createdAt,
    required this.updatedAt,
    this.referral,
  });

  bool get isDischarged => status == 'discharged';

  factory PortalCase.fromJson(Map<String, dynamic> j) => PortalCase(
        id: _str(j['id']) ?? '',
        referralId: _str(j['referral_id']),
        patientName: _str(j['patient_name']) ?? '',
        age: _int(j['age']),
        sex: _str(j['sex']),
        complaint: _str(j['complaint']) ?? '',
        level: _str(j['level']) ?? 'routine',
        status: _str(j['status']) ?? 'waiting',
        wardId: _int(j['ward_id']),
        wardName: _str(j['ward_name']),
        bed: _str(j['bed']),
        assigneeUid: _str(j['assignee_uid']),
        assigneeName: _str(j['assignee_name']),
        allergies: _str(j['allergies']),
        timeline: (j['timeline'] is List)
            ? (j['timeline'] as List).whereType<Map>().map((e) => TimelineEvent.fromJson(Map<String, dynamic>.from(e))).toList()
            : const [],
        dischargeSummary: _str(j['discharge_summary']),
        createdAt: _str(j['created_at']) ?? '',
        updatedAt: _str(j['updated_at']) ?? '',
        referral: j['referral'] is Map ? Referral.fromJson(Map<String, dynamic>.from(j['referral'])) : null,
      );
}

class DashboardCounts {
  final int incoming;
  final int incomingUrgent;
  final int waiting;
  final int inTreatment;
  final int bedsFree;
  final int bedsTotal;
  final int staffOnDuty;
  final int pendingStaff;

  const DashboardCounts({
    this.incoming = 0,
    this.incomingUrgent = 0,
    this.waiting = 0,
    this.inTreatment = 0,
    this.bedsFree = 0,
    this.bedsTotal = 0,
    this.staffOnDuty = 0,
    this.pendingStaff = 0,
  });

  factory DashboardCounts.fromJson(Map<String, dynamic> j) => DashboardCounts(
        incoming: _int(j['incoming']) ?? 0,
        incomingUrgent: _int(j['incoming_urgent']) ?? 0,
        waiting: _int(j['waiting']) ?? 0,
        inTreatment: _int(j['in_treatment']) ?? 0,
        bedsFree: _int(j['beds_free']) ?? 0,
        bedsTotal: _int(j['beds_total']) ?? 0,
        staffOnDuty: _int(j['staff_on_duty']) ?? 0,
        pendingStaff: _int(j['pending_staff']) ?? 0,
      );
}

class Dashboard {
  final DashboardCounts counts;
  final List<Referral> incoming;
  final List<PortalCase> myCases;
  final String myName;
  final StaffRole myRole;
  final bool onDuty;

  const Dashboard({
    required this.counts,
    this.incoming = const [],
    this.myCases = const [],
    this.myName = '',
    this.myRole = StaffRole.doctor,
    this.onDuty = false,
  });

  factory Dashboard.fromJson(Map<String, dynamic> j) {
    final me = _map(j['me']);
    return Dashboard(
      counts: DashboardCounts.fromJson(_map(j['counts'])),
      incoming: _list(j['incoming'], Referral.fromJson),
      myCases: _list(j['my_cases'], PortalCase.fromJson),
      myName: _str(me['name']) ?? '',
      myRole: StaffRole.parse(me['role']),
      onDuty: _bool(me['on_duty']),
    );
  }
}

List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) parse) =>
    v is List ? v.whereType<Map>().map((e) => parse(Map<String, dynamic>.from(e))).toList() : <T>[];

/// Public helper so the API layer can parse list responses the same way.
List<T> parseList<T>(dynamic v, T Function(Map<String, dynamic>) parse) => _list(v, parse);

class Ward {
  final int id;
  final String name;
  final int bedsTotal;
  final int bedsOccupied;
  final bool critical;

  const Ward({
    required this.id,
    required this.name,
    required this.bedsTotal,
    required this.bedsOccupied,
    this.critical = false,
  });

  int get bedsFree => (bedsTotal - bedsOccupied).clamp(0, bedsTotal);

  factory Ward.fromJson(Map<String, dynamic> j) => Ward(
        id: _int(j['id']) ?? 0,
        name: _str(j['name']) ?? '',
        bedsTotal: _int(j['beds_total']) ?? 0,
        bedsOccupied: _int(j['beds_occupied']) ?? 0,
        critical: _bool(j['critical']),
      );
}

class WardInput {
  final String name;
  final int bedsTotal;
  final int bedsOccupied;
  final bool critical;

  const WardInput({required this.name, required this.bedsTotal, required this.bedsOccupied, this.critical = false});

  Map<String, dynamic> toJson() =>
      {'name': name, 'beds_total': bedsTotal, 'beds_occupied': bedsOccupied, 'critical': critical};
}

class Equipment {
  final int id;
  final String name;
  final int available;
  final int total;
  final String? note;

  const Equipment({required this.id, required this.name, required this.available, required this.total, this.note});

  factory Equipment.fromJson(Map<String, dynamic> j) => Equipment(
        id: _int(j['id']) ?? 0,
        name: _str(j['name']) ?? '',
        available: _int(j['available']) ?? 0,
        total: _int(j['total']) ?? 0,
        note: _str(j['note']),
      );
}

class EquipmentInput {
  final String name;
  final int available;
  final int total;
  final String? note;

  const EquipmentInput({required this.name, required this.available, required this.total, this.note});

  Map<String, dynamic> toJson() => {
        'name': name,
        'available': available,
        'total': total,
        'note': (note ?? '').isEmpty ? null : note,
      };
}

/// `_staff_out` — team members (capacity.team, /portal/team, duty).
class TeamMember {
  final String firebaseUid;
  final String fullName;
  final String? email;
  final StaffRole role;
  final StaffStatus status;
  final bool onDuty;
  final String? department;
  final String? licenseNumber;

  const TeamMember({
    required this.firebaseUid,
    required this.fullName,
    this.email,
    required this.role,
    required this.status,
    this.onDuty = false,
    this.department,
    this.licenseNumber,
  });

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
        firebaseUid: _str(j['firebase_uid']) ?? '',
        fullName: _str(j['full_name']) ?? '',
        email: _str(j['email']),
        role: StaffRole.parse(j['role']),
        status: StaffStatus.parse(j['status']),
        onDuty: _bool(j['on_duty']),
        department: _str(j['department']),
        licenseNumber: _str(j['license_number']),
      );
}

class Capacity {
  final List<Ward> wards;
  final List<Equipment> equipment;
  final List<TeamMember> team;

  const Capacity({this.wards = const [], this.equipment = const [], this.team = const []});

  factory Capacity.fromJson(Map<String, dynamic> j) => Capacity(
        wards: _list(j['wards'], Ward.fromJson),
        equipment: _list(j['equipment'], Equipment.fromJson),
        team: _list(j['team'], TeamMember.fromJson),
      );
}

class PortalAlert {
  final String id;
  final String kind; // referral | vitals | broadcast
  final String severity; // critical | warning
  final String title;
  final String? body;
  final String? department;
  final String? authorName;
  final String? referralId;
  final String? patientUserId;
  final String at;

  const PortalAlert({
    required this.id,
    required this.kind,
    required this.severity,
    required this.title,
    this.body,
    this.department,
    this.authorName,
    this.referralId,
    this.patientUserId,
    required this.at,
  });

  factory PortalAlert.fromJson(Map<String, dynamic> j) => PortalAlert(
        id: _str(j['id']) ?? '',
        kind: _str(j['kind']) ?? '',
        severity: _str(j['severity']) ?? 'warning',
        title: _str(j['title']) ?? '',
        body: _str(j['body']),
        department: _str(j['department']),
        authorName: _str(j['author_name']),
        referralId: _str(j['referral_id']),
        patientUserId: _str(j['patient_user_id']),
        at: _str(j['at']) ?? '',
      );
}

class AuditEntry {
  final String at;
  final String? actor;
  final String action;
  final String? target;
  final String? detail;

  const AuditEntry({required this.at, this.actor, required this.action, this.target, this.detail});

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        at: _str(j['at']) ?? '',
        actor: _str(j['actor']),
        action: _str(j['action']) ?? '',
        target: _str(j['target']),
        detail: _str(j['detail']),
      );
}

class AcceptResult {
  final Referral referral;
  final PortalCase portalCase;
  const AcceptResult(this.referral, this.portalCase);
}

class NewCaseInput {
  final String patientName;
  final int? age;
  final String? sex;
  final String complaint;
  final String level;
  final int? wardId;
  final String? bed;
  final String? assigneeUid;
  final String? allergies;

  const NewCaseInput({
    required this.patientName,
    this.age,
    this.sex,
    required this.complaint,
    this.level = 'routine',
    this.wardId,
    this.bed,
    this.assigneeUid,
    this.allergies,
  });

  Map<String, dynamic> toJson() => {
        'patient_name': patientName,
        'age': age,
        'sex': (sex ?? '').isEmpty ? null : sex,
        'complaint': complaint,
        'level': level,
        'ward_id': wardId,
        'bed': (bed ?? '').isEmpty ? null : bed,
        'assignee_uid': (assigneeUid ?? '').isEmpty ? null : assigneeUid,
        'allergies': (allergies ?? '').isEmpty ? null : allergies,
      };
}

/// A prescription ordered for a hospital case.
class PrescriptionOrder {
  final String medication;
  final String dosage;
  final String frequency;
  final String duration;
  final String? instructions;
  final String? orderedBy;
  final String? orderedAt;

  const PrescriptionOrder({
    required this.medication,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.instructions,
    this.orderedBy,
    this.orderedAt,
  });

  factory PrescriptionOrder.fromJson(Map<String, dynamic> j) => PrescriptionOrder(
        medication: _str(j['medication']) ?? '',
        dosage: _str(j['dosage']) ?? '',
        frequency: _str(j['frequency']) ?? '',
        duration: _str(j['duration']) ?? '',
        instructions: _str(j['instructions']),
        orderedBy: _str(j['ordered_by']),
        orderedAt: _str(j['ordered_at']),
      );

  Map<String, dynamic> toJson() => {
        'medication': medication,
        'dosage': dosage,
        'frequency': frequency,
        'duration': duration,
        if (instructions != null && instructions!.isNotEmpty) 'instructions': instructions,
      };
}

/// Inpatient vitals recorded during clinical observation rounds.
class InpatientVitals {
  final int? heartRate;
  final double? bloodOxygen;
  final String? bloodPressure;
  final double? temperature;
  final int? respiratoryRate;
  final String? recordedBy;
  final String? recordedAt;

  const InpatientVitals({
    this.heartRate,
    this.bloodOxygen,
    this.bloodPressure,
    this.temperature,
    this.respiratoryRate,
    this.recordedBy,
    this.recordedAt,
  });

  factory InpatientVitals.fromJson(Map<String, dynamic> j) => InpatientVitals(
        heartRate: _int(j['heart_rate']),
        bloodOxygen: _double(j['blood_oxygen']),
        bloodPressure: _str(j['blood_pressure']),
        temperature: _double(j['temperature']),
        respiratoryRate: _int(j['respiratory_rate']),
        recordedBy: _str(j['recorded_by']),
        recordedAt: _str(j['recorded_at']),
      );

  Map<String, dynamic> toJson() => {
        if (heartRate != null) 'heart_rate': heartRate,
        if (bloodOxygen != null) 'blood_oxygen': bloodOxygen,
        if (bloodPressure != null) 'blood_pressure': bloodPressure,
        if (temperature != null) 'temperature': temperature,
        if (respiratoryRate != null) 'respiratory_rate': respiratoryRate,
      };
}

/// Patient-facing view of a hospital admission / visit.
class PatientHospitalCase {
  final String id;
  final String hospitalId;
  final String hospitalName;
  final String? hospitalPhone;
  final String? ward;
  final String? bed;
  final String? attendingDoctor;
  final String status;
  final String level;
  final String complaint;
  final String? dischargeSummary;
  final List<TimelineEvent> timeline;
  final String createdAt;
  final String updatedAt;

  const PatientHospitalCase({
    required this.id,
    required this.hospitalId,
    required this.hospitalName,
    this.hospitalPhone,
    this.ward,
    this.bed,
    this.attendingDoctor,
    required this.status,
    required this.level,
    required this.complaint,
    this.dischargeSummary,
    this.timeline = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDischarged => status == 'discharged';
  bool get isInTreatment => status == 'treatment';
  bool get isWaiting => status == 'waiting';

  factory PatientHospitalCase.fromJson(Map<String, dynamic> j) => PatientHospitalCase(
        id: _str(j['id']) ?? '',
        hospitalId: _str(j['hospital_id']) ?? '',
        hospitalName: _str(j['hospital_name']) ?? 'VitaNet Hospital',
        hospitalPhone: _str(j['hospital_phone']),
        ward: _str(j['ward']),
        bed: _str(j['bed']),
        attendingDoctor: _str(j['attending_doctor']),
        status: _str(j['status']) ?? 'waiting',
        level: _str(j['level']) ?? 'routine',
        complaint: _str(j['complaint']) ?? '',
        dischargeSummary: _str(j['discharge_summary']),
        timeline: (j['timeline'] is List)
            ? (j['timeline'] as List)
                .whereType<Map>()
                .map((e) => TimelineEvent.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
        createdAt: _str(j['created_at']) ?? '',
        updatedAt: _str(j['updated_at']) ?? '',
      );
}

/// Result returned from pre-arrival emergency check-in.
class EmergencyCheckinResult {
  final String referralId;
  final String caseId;
  final String hospitalId;
  final String status;
  final int etaMinutes;
  final String message;

  const EmergencyCheckinResult({
    required this.referralId,
    required this.caseId,
    required this.hospitalId,
    required this.status,
    required this.etaMinutes,
    required this.message,
  });

  factory EmergencyCheckinResult.fromJson(Map<String, dynamic> j) => EmergencyCheckinResult(
        referralId: _str(j['referral_id']) ?? '',
        caseId: _str(j['case_id']) ?? '',
        hospitalId: _str(j['hospital_id']) ?? '',
        status: _str(j['status']) ?? 'arriving',
        etaMinutes: _int(j['eta_minutes']) ?? 15,
        message: _str(j['message']) ?? 'Emergency check-in confirmed.',
      );
}
