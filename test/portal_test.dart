import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitanet/features/auth/widgets/staff_common.dart';
import 'package:vitanet/features/portal/board/referral_view.dart';
import 'package:vitanet/features/portal/data/hospital_api_service.dart';
import 'package:vitanet/features/portal/data/portal_live.dart';
import 'package:vitanet/features/portal/data/portal_models.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
import 'package:vitanet/features/portal/gate/portal_gate.dart';
import 'package:vitanet/features/portal/record/case_record_view.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

StaffMe _me({
  StaffStatus status = StaffStatus.approved,
  StaffRole role = StaffRole.nurse,
  String? hospitalId = 'h1',
}) =>
    StaffMe(
      firebaseUid: 'u1',
      email: 'ama@ridge.org',
      fullName: 'Ama Mensah',
      role: role,
      status: status,
      hospitalId: hospitalId,
      onDuty: true,
      licenseNumber: 'NMC-30417',
    );

String _iso(Duration fromNow) => DateTime.now().toUtc().add(fromNow).toIso8601String();

Referral _referral({String status = 'new'}) => Referral.fromJson({
      'id': 'r1',
      'hospital_id': 'h1',
      'status': status,
      'triage_level': 'urgent',
      'summary': {
        'patient_name': 'Yaw Boateng',
        'age': 62,
        'sex': 'male',
        'complaint': 'Crushing chest pain',
        'triage_summary': 'Possible heart attack',
        'allergies': ['Penicillin'],
        'medications': ['Amlodipine'],
        'vitals': {'heart_rate': 112},
      },
      'eta_minutes': 14,
      'eta_at': _iso(const Duration(minutes: 14)),
      'created_at': _iso(const Duration(minutes: -2)),
      'updated_at': _iso(Duration.zero),
      'suggestion': {'ward_id': 7, 'ward_name': 'Resus', 'assignee_uid': 'd2', 'assignee_name': 'Dr. Yaw Addo'},
    });

PortalCase _case({String status = 'expected', CaseVitals? vitals}) => PortalCase(
      id: 'c1a2b3c4-0000-0000-0000-000000000000',
      referralId: 'r1',
      patientName: 'Yaw Boateng',
      age: 62,
      sex: 'male',
      complaint: 'Crushing chest pain',
      level: 'urgent',
      status: status,
      wardId: 7,
      wardName: 'Resus',
      bed: 'Bay 2',
      assigneeUid: 'd2',
      assigneeName: 'Dr. Yaw Addo',
      allergies: 'Penicillin',
      latestVitals: vitals,
      createdAt: _iso(const Duration(minutes: -5)),
      updatedAt: _iso(Duration.zero),
    );

/// Only what each test needs; anything else throws.
class FakeApi extends Fake implements HospitalApiService {
  List<Referral> incoming = [];
  List<PortalCase> active = [];
  PortalCase current = _case();
  Map<String, Object?>? lastAccept;
  String? lastDecline;
  int arrivedCalls = 0;
  int referralListCalls = 0;

  static const capacity = Capacity(
    wards: [
      Ward(id: 7, name: 'Resus', bedsTotal: 3, bedsOccupied: 1),
      Ward(id: 8, name: 'ICU', bedsTotal: 4, bedsOccupied: 4),
    ],
    team: [
      TeamMember(firebaseUid: 'd2', fullName: 'Dr. Yaw Addo', role: StaffRole.doctor, status: StaffStatus.approved,
          onDuty: true, activeCases: 1),
    ],
  );

  @override
  Future<List<Facility>> listFacilities({double? lat, double? lng, String? query, int limit = 200}) async =>
      [const Facility(id: 'h1', name: 'Ridge Hospital', latitude: 5.56, longitude: -0.2)];

  @override
  Future<Facility> getMyHospital() async => const Facility(id: 'h1', name: 'Ridge Hospital', latitude: 5.56, longitude: -0.2);

  @override
  Future<Dashboard> getDashboard() async => const Dashboard(counts: DashboardCounts(), myName: 'Ama Mensah', onDuty: true);

  @override
  Future<List<PortalAlert>> listAlerts() async => const [];

  @override
  Future<List<Referral>> listReferrals({String? status}) async {
    referralListCalls++;
    return status == 'new' ? incoming : const [];
  }

  @override
  Future<Referral> getReferral(String id) async => incoming.firstWhere((r) => r.id == id, orElse: () => _referral());

  @override
  Future<Capacity> getCapacity() async => capacity;

  @override
  Future<List<PortalCase>> listCases({String? status, bool mine = false, String? query}) async =>
      status == activeCaseStatuses ? active : const [];

  @override
  Future<PortalCase> getCase(String id) async => current;

  @override
  Future<AcceptResult> acceptReferral(String id, {String? assigneeUid, int? wardId, String? bed}) async {
    lastAccept = {'id': id, 'assignee': assigneeUid, 'ward': wardId, 'bed': bed};
    incoming = [];
    return AcceptResult(_referral(status: 'accepted'), current);
  }

  @override
  Future<Referral> declineReferral(String id, String reason) async {
    lastDecline = reason;
    incoming = [];
    return _referral(status: 'declined');
  }

  @override
  Future<PortalCase> markArrived(String id) async {
    arrivedCalls++;
    current = _case(status: 'waiting');
    return current;
  }
}

/// The live socket is replaced so tests never open a real connection.
final _quietLive = portalLiveProvider.overrideWith((ref) => PortalLive(ref));

Widget _app(Widget child, {required List<Override> overrides}) => ProviderScope(
      overrides: [_quietLive, ...overrides],
      child: MaterialApp(home: child),
    );

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('staffRouteRedirect (the router uses this)', () {
    final none = StaffAccess.none;
    final pending = StaffAccess.fromMe(_me(status: StaffStatus.pending));
    final approved = StaffAccess.fromMe(_me());
    final suspended = StaffAccess.fromMe(_me(status: StaffStatus.suspended));

    test('patients never get into /admin', () {
      expect(staffRouteRedirect('/admin', none), '/home');
      expect(staffRouteRedirect('/', none), '/home');
      expect(staffRouteRedirect('/home', none), isNull);
    });

    test('staff in the hospital workspace land in the portal', () {
      for (final a in [approved, pending]) {
        expect(staffRouteRedirect('/', a), '/admin');
        expect(staffRouteRedirect('/home', a), '/admin');
        expect(staffRouteRedirect('/admin', a), isNull);
      }
    });

    test('staff who chose their personal workspace stay in the patient app', () {
      expect(staffRouteRedirect('/home', approved, workspace: AppWorkspace.personal), isNull);
      expect(staffRouteRedirect('/', approved, workspace: AppWorkspace.personal), '/home');
      expect(staffRouteRedirect('/admin', approved, workspace: AppWorkspace.personal), isNull);
    });

    test('suspended staff keep the patient app; unknown access forces nothing', () {
      expect(staffRouteRedirect('/home', suspended), isNull);
      expect(staffRouteRedirect('/admin', null), isNull);
      expect(staffRouteRedirect('/home', null), isNull);
    });
  });

  test('relativeTime formats ISO timestamps', () {
    final now = DateTime.utc(2026, 11, 2, 12);
    expect(relativeTime('2026-11-02T11:48:00Z', now: now), '12 min ago');
    expect(relativeTime('2026-11-02T11:59:40Z', now: now), 'just now');
    expect(relativeTime('2026-11-02T09:00:00Z', now: now), '3 h ago');
  });

  group('PortalGate access states', () {
    testWidgets('pending shows the hospital and opens itself once approved', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(_app(const PortalGate(), overrides: [
        hospitalApiProvider.overrideWithValue(FakeApi()),
        staffAccessProvider.overrideWith((ref) async => StaffAccess.fromMe(_me(status: StaffStatus.pending))),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Waiting for approval'), findsOneWidget);
      expect(find.text('Ridge Hospital'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an admin without a hospital sets one up', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(_app(const PortalGate(), overrides: [
        hospitalApiProvider.overrideWithValue(FakeApi()),
        staffAccessProvider.overrideWith((ref) async => StaffAccess.fromMe(_me(role: StaffRole.admin, hospitalId: null))),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Set up your hospital'), findsOneWidget);
      expect(find.text('Use my location'), findsOneWidget);
      expect(find.text('Create hospital', skipOffstage: false), findsOneWidget);
    });

    testWidgets('suspended staff see why', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(_app(const PortalGate(), overrides: [
        hospitalApiProvider.overrideWithValue(FakeApi()),
        staffAccessProvider.overrideWith((ref) async => StaffAccess.fromMe(_me(status: StaffStatus.suspended))),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Account suspended'), findsOneWidget);
      expect(find.text('Open my personal VitaNet'), findsOneWidget);
    });
  });

  group('Board', () {
    testWidgets('approved staff get the Board with four destinations', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(_app(const PortalGate(), overrides: [
        hospitalApiProvider.overrideWithValue(FakeApi()),
        staffAccessProvider.overrideWith((ref) async => StaffAccess.fromMe(_me())),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Board'), findsWidgets);
      for (final tab in ['Patients', 'Hospital', 'Me']) {
        expect(find.text(tab), findsWidgets);
      }
      expect(find.text('Nobody on the way'), findsOneWidget);
      expect(find.text('RIDGE HOSPITAL'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('accept from the card: suggested ward and clinician, then the record', (tester) async {
      await _phone(tester);
      tester.view.physicalSize = const Size(400, 1400);
      final api = FakeApi()..incoming = [_referral()];
      await tester.pumpWidget(_app(const PortalGate(), overrides: [
        hospitalApiProvider.overrideWithValue(api),
        staffAccessProvider.overrideWith((ref) async => StaffAccess.fromMe(_me())),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Yaw Boateng · 62 M'), findsOneWidget);
      expect(find.text('Allergy · Penicillin'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^1[34] min$')), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(find.text('Accept Yaw Boateng'), findsOneWidget);
      expect(find.text('Suggested: Resus'), findsOneWidget);
      // The full ward can't be chosen.
      expect(find.text('Full'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Bay 2');
      await tester.pumpAndSettle();
      expect(find.textContaining('Accepted · Resus, Bay 2 · Dr. Yaw Addo'), findsOneWidget);

      await tester.tap(find.text('Accept & prepare bed'));
      await tester.pumpAndSettle();
      expect(api.lastAccept, {'id': 'r1', 'assignee': 'd2', 'ward': 7, 'bed': 'Bay 2'});
      expect(find.text('Mark arrived'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('decline asks for a reason', (tester) async {
      await _phone(tester);
      tester.view.physicalSize = const Size(400, 1400);
      final api = FakeApi()..incoming = [_referral()];
      await tester.pumpWidget(_app(const ReferralPage(referralId: 'r1'), overrides: [
        hospitalApiProvider.overrideWithValue(api),
        staffAccessProvider.overrideWith((ref) async => StaffAccess.fromMe(_me())),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Allergic to Penicillin'), findsOneWidget);
      expect(find.text('VitaNet triage: Possible heart attack'), findsOneWidget);

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Decline referral'));
      await tester.pump();
      expect(api.lastDecline, isNull); // no reason yet
      await tester.tap(find.text('Specialist not available'));
      await tester.tap(find.text('Decline referral'));
      await tester.pumpAndSettle();
      expect(api.lastDecline, 'Specialist not available');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Case record', () {
    testWidgets('mark arrived moves the patient on', (tester) async {
      await _phone(tester);
      final api = FakeApi();
      await tester.pumpWidget(_app(const CaseRecordPage(caseId: 'c1'), overrides: [
        hospitalApiProvider.overrideWithValue(api),
        staffAccessProvider.overrideWith((ref) async => StaffAccess.fromMe(_me())),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Allergy · Penicillin'), findsOneWidget);
      await tester.tap(find.text('Mark arrived'));
      await tester.pumpAndSettle();
      expect(api.arrivedCalls, 1);
      expect(find.text('Start treatment'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('vitals tiles show the latest readings and the early warning', (tester) async {
      await _phone(tester);
      tester.view.physicalSize = const Size(400, 1400);
      final api = FakeApi()
        ..current = _case(
          status: 'treatment',
          vitals: CaseVitals(heartRate: 124, bpSystolic: 98, bpDiastolic: 60, spo2: 91, respiratoryRate: 26,
              earlyWarning: 8, recordedBy: 'Nurse Badu', at: _iso(const Duration(minutes: -1))),
        );
      await tester.pumpWidget(_app(const CaseRecordPage(caseId: 'c1'), overrides: [
        hospitalApiProvider.overrideWithValue(api),
        staffAccessProvider.overrideWith((ref) async => StaffAccess.fromMe(_me())),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('124'), findsOneWidget);
      expect(find.text('98/60'), findsOneWidget);
      expect(find.text('91%'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.textContaining('Early warning score 8'), findsOneWidget);
      expect(find.text('Discharge'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('desk: rail and a detail pane next to the board', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeApi()..incoming = [_referral()];
    await tester.pumpWidget(_app(const PortalGate(), overrides: [
      hospitalApiProvider.overrideWithValue(api),
      staffAccessProvider.overrideWith((ref) async => StaffAccess.fromMe(_me())),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Select a patient'), findsOneWidget);
    expect(find.text('IN HOSPITAL'), findsOneWidget);
    await tester.tap(find.text('Crushing chest pain').first);
    await tester.pumpAndSettle();
    expect(find.text('Incoming patient'), findsOneWidget);
    expect(find.text('Select a patient'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('live events refetch what changed', () async {
    final api = FakeApi();
    final socket = _FakeSocket();
    final container = ProviderContainer(overrides: [
      hospitalApiProvider.overrideWithValue(api),
      portalLiveProvider.overrideWith((ref) {
        final live = PortalLive(ref, connect: (_) => socket, token: () async => 'token-1')..start();
        ref.onDispose(live.dispose);
        return live;
      }),
    ]);
    addTearDown(container.dispose);
    container.listen(referralsProvider('new'), (_, _) {});
    container.listen(portalLiveProvider, (_, _) {});
    await container.read(referralsProvider('new').future);
    await Future<void>.delayed(Duration.zero);
    expect(jsonDecode(socket.sent.single as String), {'token': 'token-1'});

    socket.incoming.add(jsonEncode({'type': 'ready'}));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(portalLiveConnectedProvider), isTrue);

    final before = api.referralListCalls;
    socket.incoming.add(jsonEncode({'type': 'referral', 'id': 'r9'}));
    await Future<void>.delayed(Duration.zero);
    await container.read(referralsProvider('new').future);
    expect(api.referralListCalls, greaterThan(before));

    await socket.incoming.close();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(portalLiveConnectedProvider), isFalse);
  });
}

class _FakeSink extends Fake implements WebSocketSink {
  final List<Object?> sent;
  _FakeSink(this.sent);

  @override
  void add(Object? data) => sent.add(data);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}
}

class _FakeSocket extends Fake implements WebSocketChannel {
  final incoming = StreamController<dynamic>();
  final sent = <Object?>[];

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  WebSocketSink get sink => _FakeSink(sent);
}
