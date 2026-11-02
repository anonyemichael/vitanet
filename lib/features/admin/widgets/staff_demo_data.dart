import 'package:vitanet/features/admin/models/patient.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

/// Clinical content used by the hospital portal when the backend has no data
/// for a section (offline / hackathon mode). Real API data always wins.

const String kStaffPhoto = 'assets/images/photos/physician_male.jpg';
const String kAddoPhoto = 'assets/images/photos/clinician_female.jpg';
const String kDemoStaffName = 'Dr. Kwame Mensah';
const String kDemoFacility = 'Korle Bu Teaching Hospital';

// ─── Patient records ───

class VitalReading {
  final String label;
  final String value;
  final bool alert;
  const VitalReading(this.label, this.value, {this.alert = false});
}

enum TimelineTone { critical, action, neutral }

class TimelineEntry {
  final String time;
  final String text;
  final TimelineTone tone;
  const TimelineEntry(this.time, this.text, [this.tone = TimelineTone.action]);
}

/// Patient status as shown in the list tags.
enum PatientStatus {
  critical('Critical', StaffTone.danger),
  observation('Observation', StaffTone.amber),
  stable('Stable', StaffTone.green),
  recovering('Recovering', StaffTone.sky);

  final String label;
  final StaffTone tone;
  const PatientStatus(this.label, this.tone);

  static PatientStatus parse(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('crit')) return PatientStatus.critical;
    if (s.contains('obs') || s.contains('monitor') || s.contains('watch')) {
      return PatientStatus.observation;
    }
    if (s.contains('recover')) return PatientStatus.recovering;
    return PatientStatus.stable;
  }
}

class StaffPatientRecord {
  final String id;
  final String name;
  final int age;
  final String sex; // 'F' / 'M'
  final String location;
  final PatientStatus status;
  final String? diagnosis;
  final String? allergy;
  final List<VitalReading> vitals;
  final List<TimelineEntry> timeline;
  final String? note;
  final String? noteAuthor;

  const StaffPatientRecord({
    required this.id,
    required this.name,
    required this.age,
    required this.sex,
    required this.location,
    required this.status,
    this.diagnosis,
    this.allergy,
    this.vitals = const [],
    this.timeline = const [],
    this.note,
    this.noteAuthor,
  });

  String get initials => name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();

  String get nameAge => '$name, $age $sex';

  StaffPatientRecord copyWith({
    String? location,
    PatientStatus? status,
    List<TimelineEntry>? timeline,
  }) =>
      StaffPatientRecord(
        id: id,
        name: name,
        age: age,
        sex: sex,
        location: location ?? this.location,
        status: status ?? this.status,
        diagnosis: diagnosis,
        allergy: allergy,
        vitals: vitals,
        timeline: timeline ?? this.timeline,
        note: note,
        noteAuthor: noteAuthor,
      );

  /// Builds a record from the backend [Patient] model.
  factory StaffPatientRecord.fromApi(Patient p) {
    final g = p.gender.toLowerCase();
    final h = p.lastUpdated.hour.toString().padLeft(2, '0');
    final m = p.lastUpdated.minute.toString().padLeft(2, '0');
    return StaffPatientRecord(
      id: p.id,
      name: p.name,
      age: p.age,
      sex: g.startsWith('f') ? 'F' : (g.startsWith('m') ? 'M' : p.gender),
      location: 'Ward not assigned',
      status: PatientStatus.parse(p.status),
      timeline: [TimelineEntry('$h:$m', 'Record updated · status ${p.status}.', TimelineTone.neutral)],
    );
  }
}

final Map<String, StaffPatientRecord> demoRecords = {
  for (final r in _records) r.id: r,
};

final List<StaffPatientRecord> _records = [
  const StaffPatientRecord(
    id: 'P-10233',
    name: 'Ama Kuffour',
    age: 54,
    sex: 'F',
    location: 'Emergency · Bed 7',
    status: PatientStatus.critical,
    diagnosis: 'Community-acquired pneumonia',
    allergy: 'Allergy: sulfonamides',
    vitals: [
      VitalReading('HR', '118', alert: true),
      VitalReading('BP', '104/66'),
      VitalReading('SpO2', '88%', alert: true),
      VitalReading('RR', '28', alert: true),
    ],
    timeline: [
      TimelineEntry('10:40', 'SpO2 88% for 3 min on 2 L oxygen. Alert raised.', TimelineTone.critical),
      TimelineEntry('09:20', 'IV co-amoxiclav started. Blood cultures sent.'),
      TimelineEntry('08:55', 'Chest X-ray: right lower lobe consolidation.'),
      TimelineEntry('08:10', 'Arrived by ambulance. Productive cough 4 days.', TimelineTone.neutral),
    ],
    note: 'Type 2 diabetic. Titrate oxygen to SpO2 94–98%. Consider HDU review if no improvement within the hour.',
    noteAuthor: 'Dr. Mensah',
  ),
  const StaffPatientRecord(
    id: 'P-10241',
    name: 'Yaw Boateng',
    age: 62,
    sex: 'M',
    location: 'Resus bay 2',
    status: PatientStatus.critical,
    diagnosis: 'Suspected NSTEMI',
    allergy: 'Allergy: none known',
    vitals: [
      VitalReading('HR', '108', alert: true),
      VitalReading('BP', '162/98', alert: true),
      VitalReading('SpO2', '95%'),
      VitalReading('Temp', '36.9'),
    ],
    timeline: [
      TimelineEntry('10:12', 'hs-Troponin T 112 ng/L. Cardiology paged.', TimelineTone.critical),
      TimelineEntry('09:58', 'Aspirin 300 mg given. GTN spray ×1, pain 7 → 4.'),
      TimelineEntry('09:44', 'ECG: ST depression V4–V6.'),
      TimelineEntry('09:31', 'Arrived. Alerted by daughter via VitaNet care circle.', TimelineTone.neutral),
    ],
    note: 'Known hypertensive on amlodipine. Pain eased after GTN. Awaiting cardiology review for angiography. Keep nil by mouth.',
    noteAuthor: 'Dr. Mensah',
  ),
  const StaffPatientRecord(
    id: 'P-10198',
    name: 'Kwesi Nyarko',
    age: 47,
    sex: 'M',
    location: 'Ward B · Bed 3',
    status: PatientStatus.observation,
    diagnosis: 'Cellulitis, left leg',
    allergy: 'Allergy: none known',
    vitals: [
      VitalReading('HR', '92'),
      VitalReading('BP', '128/82'),
      VitalReading('SpO2', '98%'),
      VitalReading('Temp', '38.1', alert: true),
    ],
    timeline: [
      TimelineEntry('09:30', 'IV ceftriaxone 2 g due. Not yet charted.', TimelineTone.critical),
      TimelineEntry('06:00', 'Erythema margin marked. Spreading 2 cm overnight.'),
      TimelineEntry('Yesterday', 'Admitted from ED.', TimelineTone.neutral),
    ],
    note: 'Elevate limb. Repeat CRP in the morning. Switch to oral antibiotics once afebrile for 24 h.',
    noteAuthor: 'Dr. Addo',
  ),
  const StaffPatientRecord(
    id: 'P-10238',
    name: 'Kofi Owusu',
    age: 9,
    sex: 'M',
    location: 'Minors 4',
    status: PatientStatus.stable,
    diagnosis: 'Distal radius fracture',
    allergy: 'Allergy: none known',
    vitals: [
      VitalReading('HR', '96'),
      VitalReading('BP', '108/68'),
      VitalReading('SpO2', '99%'),
      VitalReading('Pain', '3/10'),
    ],
    timeline: [
      TimelineEntry('10:05', 'Back slab applied. Neurovascularly intact.'),
      TimelineEntry('09:40', 'X-ray: undisplaced distal radius fracture.'),
      TimelineEntry('09:15', 'Fell from bicycle. Arrived with mother.', TimelineTone.neutral),
    ],
    note: 'Fracture clinic in 7 days. Paracetamol and ibuprofen as needed. Safeguarding screen completed.',
    noteAuthor: 'Nurse Badu',
  ),
  const StaffPatientRecord(
    id: 'P-10235',
    name: 'Abena Darko',
    age: 71,
    sex: 'F',
    location: 'Waiting area',
    status: PatientStatus.observation,
    diagnosis: 'Fall, query postural hypotension',
    allergy: 'Allergy: penicillin',
    vitals: [
      VitalReading('HR', '64'),
      VitalReading('BP', '98/60', alert: true),
      VitalReading('SpO2', '97%'),
      VitalReading('Temp', '36.6'),
    ],
    timeline: [
      TimelineEntry('09:50', 'Lying and standing BP requested.'),
      TimelineEntry('09:30', 'Triaged: dizziness on standing, fall at home.', TimelineTone.neutral),
    ],
    note: 'On bendroflumethiazide and ramipril. Check sodium and potassium. Falls risk: assist when mobilising.',
    noteAuthor: 'Nurse Badu',
  ),
  const StaffPatientRecord(
    id: 'P-10177',
    name: 'Esi Mensah',
    age: 33,
    sex: 'F',
    location: 'Ward A · Bed 12',
    status: PatientStatus.recovering,
    diagnosis: 'Post laparoscopic appendicectomy',
    allergy: 'Allergy: none known',
    vitals: [
      VitalReading('HR', '78'),
      VitalReading('BP', '118/74'),
      VitalReading('SpO2', '99%'),
      VitalReading('Temp', '36.8'),
    ],
    timeline: [
      TimelineEntry('08:30', 'Tolerating diet. Mobilising independently.'),
      TimelineEntry('Yesterday', 'Theatre: uncomplicated laparoscopic appendicectomy.', TimelineTone.neutral),
    ],
    note: 'Likely discharge this afternoon with oral analgesia. Wound check at clinic in 10 days.',
    noteAuthor: 'Dr. Asare',
  ),
  const StaffPatientRecord(
    id: 'P-10164',
    name: 'Nana Agyei',
    age: 58,
    sex: 'M',
    location: 'Ward C · Bed 5',
    status: PatientStatus.stable,
    diagnosis: 'Hyperglycaemia, type 2 diabetes',
    allergy: 'Allergy: none known',
    vitals: [
      VitalReading('HR', '82'),
      VitalReading('BP', '136/84'),
      VitalReading('SpO2', '98%'),
      VitalReading('BG', '11.2'),
    ],
    timeline: [
      TimelineEntry('07:00', 'Fasting glucose 11.2 mmol/L. Insulin regimen adjusted.'),
      TimelineEntry('2 days ago', 'Admitted with glucose 24 mmol/L, no ketones.', TimelineTone.neutral),
    ],
    note: 'Diabetes nurse education today. Plan discharge tomorrow if glucose stays under 12.',
    noteAuthor: 'Dr. Addo',
  ),
  const StaffPatientRecord(
    id: 'P-10243',
    name: 'Amara Okafor',
    age: 35,
    sex: 'F',
    location: 'Arriving · ETA 9 min',
    status: PatientStatus.critical,
    diagnosis: 'Query meningitis',
    allergy: 'Allergy: penicillin',
    vitals: [
      VitalReading('HR', '94'),
      VitalReading('SpO2', '97%'),
      VitalReading('Temp', '38.4', alert: true),
      VitalReading('RR', '20'),
    ],
    timeline: [
      TimelineEntry('10:24', 'VitaNet triage: URGENT. Self-referred, en route.', TimelineTone.critical),
      TimelineEntry('10:20', 'Reported fever, severe neck stiffness, photophobia.', TimelineTone.neutral),
    ],
    note: 'Prepare side room and blood cultures. Penicillin allergy: use alternative empirical cover per protocol.',
    noteAuthor: 'Dr. Mensah',
  ),
  const StaffPatientRecord(
    id: 'P-10244',
    name: 'Efua Asante',
    age: 28,
    sex: 'F',
    location: 'Arriving · ETA 22 min',
    status: PatientStatus.observation,
    diagnosis: 'Abdominal pain in pregnancy, 14 weeks',
    allergy: 'Allergy: none known',
    vitals: [
      VitalReading('HR', '88'),
      VitalReading('SpO2', '99%'),
      VitalReading('Temp', '37.6'),
      VitalReading('Pain', '6/10'),
    ],
    timeline: [
      TimelineEntry('10:38', 'VitaNet triage: DOCTOR. Self-referred.', TimelineTone.action),
      TimelineEntry('10:35', 'Lower right abdominal pain 6 h, nausea, no vomiting.', TimelineTone.neutral),
    ],
    note: 'Obstetrics registrar informed. Ultrasound slot requested on arrival.',
    noteAuthor: 'Dr. Addo',
  ),
];

/// Order of the Patients list in the design.
const List<String> demoPatientOrder = [
  'P-10233',
  'P-10241',
  'P-10198',
  'P-10238',
  'P-10235',
  'P-10177',
  'P-10164',
];

// ─── Referrals (home) ───

class StaffReferral {
  final String recordId;
  final String nameAge;
  final String meta;
  final String level;
  final StaffTone tone;
  final String summary;
  final List<String> vitals;
  final String eta;

  const StaffReferral({
    required this.recordId,
    required this.nameAge,
    required this.meta,
    required this.level,
    required this.tone,
    required this.summary,
    required this.vitals,
    required this.eta,
  });
}

const List<StaffReferral> demoReferrals = [
  StaffReferral(
    recordId: 'P-10243',
    nameAge: 'Amara Okafor, 35 F',
    meta: 'Self-referred via VitaNet · 10:24',
    level: 'URGENT',
    tone: StaffTone.danger,
    summary: 'Fever 38.4 °C, severe neck stiffness, photophobia. Query meningitis. Allergic to penicillin.',
    vitals: ['HR 94', 'SpO2 97%', 'T 38.4'],
    eta: '9 min',
  ),
  StaffReferral(
    recordId: 'P-10241',
    nameAge: 'Yaw Boateng, 62 M',
    meta: 'Care circle alert · 10:31',
    level: 'URGENT',
    tone: StaffTone.danger,
    summary: 'Central chest pain 40 min, radiating to left arm, sweating. History of hypertension.',
    vitals: ['HR 108', 'SpO2 95%', 'BP 162/98'],
    eta: '14 min',
  ),
  StaffReferral(
    recordId: 'P-10244',
    nameAge: 'Efua Asante, 28 F',
    meta: 'Self-referred via VitaNet · 10:38',
    level: 'DOCTOR',
    tone: StaffTone.orange,
    summary: 'Lower right abdominal pain 6 h, nausea, no vomiting. 14 weeks pregnant.',
    vitals: ['HR 88', 'SpO2 99%', 'T 37.6'],
    eta: '22 min',
  ),
];

// ─── Wards & beds ───

class DemoWard {
  final String name;
  final int used;
  final int total;
  const DemoWard(this.name, this.used, this.total);
  int get free => total - used;
}

const List<DemoWard> demoWards = [
  DemoWard('Emergency', 68, 80),
  DemoWard('ICU', 11, 12),
  DemoWard('Maternity', 30, 44),
  DemoWard('Paediatrics', 22, 36),
  DemoWard('General medicine', 51, 60),
];

const List<String> demoFreeBeds = [
  'Emergency · Bed 9 (free)',
  'Emergency · Bed 14 (free)',
  'ICU · Bed 4 (free)',
  'Maternity · Bed 21 (free)',
  'Paediatrics · Bed 6 (free)',
  'General medicine · Bed 18 (free)',
];
