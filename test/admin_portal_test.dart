import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/screens/alerts_screen.dart';
import 'package:vitanet/features/admin/screens/portal_gate_screen.dart';
import 'package:vitanet/features/admin/screens/referrals_screen.dart';
import 'package:vitanet/features/admin/services/hospital_api_service.dart';
import 'package:vitanet/features/admin/widgets/portal_common.dart';

StaffMe _me({
  StaffStatus status = StaffStatus.approved,
  StaffRole role = StaffRole.doctor,
  String? hospitalId = 'h1',
}) =>
    StaffMe(
      firebaseUid: 'u1',
      email: 'ama@ridge.org',
      fullName: 'Dr. Ama Mensah',
      role: role,
      status: status,
      hospitalId: hospitalId,
    );

final _referral = Referral.fromJson({
  'id': 'r1',
  'hospital_id': 'h1',
  'status': 'new',
  'triage_level': 'urgent',
  'summary': {
    'patient_name': 'Kofi Boateng',
    'age': 54,
    'sex': 'male',
    'complaint': 'Crushing chest pain',
    'triage_summary': 'Possible ACS',
    'allergies': ['Penicillin'],
    'medications': ['Aspirin'],
    'conditions': ['Hypertension'],
    'vitals': {'heart_rate': 112},
  },
  'eta_minutes': 14,
  'created_at': DateTime.now().toUtc().subtract(const Duration(minutes: 12)).toIso8601String(),
  'updated_at': DateTime.now().toUtc().toIso8601String(),
});

/// Fake API: only what each test needs; anything else throws.
class FakeApi extends Fake implements HospitalApiService {
  List<Referral> referrals = [];
  List<PortalAlert> alerts = [];
  Capacity capacity = const Capacity();
  Map<String, Object?>? lastAccept;

  @override
  Future<List<Facility>> listFacilities({double? lat, double? lng, String? query, int limit = 200}) async =>
      [const Facility(id: 'h1', name: 'Ridge Hospital', latitude: 5.56, longitude: -0.2)];

  @override
  Future<Dashboard> getDashboard() async => const Dashboard(counts: DashboardCounts(), myName: 'Dr. Ama Mensah');

  @override
  Future<List<PortalAlert>> listAlerts() async => alerts;

  @override
  Future<List<Referral>> listReferrals({String? status}) async =>
      referrals.where((r) => status == null || r.status == status).toList();

  @override
  Future<Referral> getReferral(String id) async => referrals.firstWhere((r) => r.id == id);

  @override
  Future<Capacity> getCapacity() async => capacity;

  @override
  Future<PortalCase> getCase(String id) async => PortalCase(
        id: id,
        patientName: 'Kofi Boateng',
        complaint: 'Crushing chest pain',
        level: 'urgent',
        status: 'waiting',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );

  @override
  Future<AcceptResult> acceptReferral(String id, {String? assigneeUid, int? wardId, String? bed}) async {
    lastAccept = {'id': id, 'assignee': assigneeUid, 'ward': wardId, 'bed': bed};
    final c = await getCase('c1');
    return AcceptResult(_referral, c);
  }
}

Widget _app(Widget child, {required List<Override> overrides}) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: child),
    );

void main() {
  group('staffRouteRedirect', () {
    final none = StaffAccess.none;
    final pending = StaffAccess.fromMe(_me(status: StaffStatus.pending));
    final approved = StaffAccess.fromMe(_me());
    final noHospital = StaffAccess.fromMe(_me(role: StaffRole.admin, hospitalId: null));
    final suspended = StaffAccess.fromMe(_me(status: StaffStatus.suspended));

    test('patients are sent from /admin to /home', () {
      expect(staffRouteRedirect('/admin', none), '/home');
      expect(staffRouteRedirect('/home', none), isNull);
      expect(staffRouteRedirect('/chat', none), isNull);
    });

    test('approved, pending and no-hospital staff go to the portal', () {
      for (final a in [approved, pending, noHospital]) {
        expect(staffRouteRedirect('/admin', a), isNull);
        expect(staffRouteRedirect('/home', a), '/admin');
        expect(staffRouteRedirect('/', a), '/admin');
      }
      expect(noHospital.kind, StaffAccessKind.needsHospital);
    });

    test('suspended staff may still use the patient app; unknown access never redirects', () {
      expect(staffRouteRedirect('/home', suspended), isNull);
      expect(staffRouteRedirect('/admin', suspended), isNull);
      expect(staffRouteRedirect('/admin', null), isNull);
      expect(staffRouteRedirect('/home', null), isNull);
    });
  });

  test('relativeTime formats ISO timestamps', () {
    final now = DateTime.utc(2026, 11, 2, 12);
    expect(relativeTime('2026-11-02T11:48:00Z', now: now), '12 min ago');
    expect(relativeTime('2026-11-02T11:59:40Z', now: now), 'just now');
    expect(relativeTime('2026-11-02T09:00:00Z', now: now), '3 h ago');
    expect(relativeTime('2026-10-31T12:00:00Z', now: now), '2 d ago');
  });

  group('PortalGate access states', () {
    testWidgets('pending shows waiting screen with the chosen hospital', (tester) async {
      final api = FakeApi();
      await tester.pumpWidget(_app(const PortalGate(), overrides: [
        hospitalApiProvider.overrideWithValue(api),
        staffAccessProvider.overrideWith((ref) async => StaffAccess.fromMe(_me(status: StaffStatus.pending))),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Waiting for approval'), findsOneWidget);
      expect(find.text('Ridge Hospital'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('approved admin without a hospital sees Create your hospital', (tester) async {
      await tester.pumpWidget(_app(const PortalGate(), overrides: [
        hospitalApiProvider.overrideWithValue(FakeApi()),
        staffAccessProvider.overrideWith(
            (ref) async => StaffAccess.fromMe(_me(role: StaffRole.admin, hospitalId: null))),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Create your hospital'), findsOneWidget);
      expect(find.text('Use my current location'), findsOneWidget);
    });

    testWidgets('approved staff with a hospital get the portal', (tester) async {
      await tester.pumpWidget(_app(const PortalGate(), overrides: [
        hospitalApiProvider.overrideWithValue(FakeApi()),
        staffAccessProvider.overrideWith((ref) async => StaffAccess.fromMe(_me())),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Incoming referrals'), findsOneWidget);
      expect(find.text('No incoming referrals yet'), findsOneWidget);
      expect(find.text('No open cases assigned to you'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('suspended staff see an explanation', (tester) async {
      await tester.pumpWidget(_app(const PortalGate(), overrides: [
        hospitalApiProvider.overrideWithValue(FakeApi()),
        staffAccessProvider.overrideWith((ref) async => StaffAccess.fromMe(_me(status: StaffStatus.suspended))),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Account suspended'), findsOneWidget);
    });
  });

  group('empty states', () {
    testWidgets('referrals inbox', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: ReferralsScreen()), overrides: [
        hospitalApiProvider.overrideWithValue(FakeApi()),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('No incoming referrals yet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('alerts', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: AlertsScreen()), overrides: [
        hospitalApiProvider.overrideWithValue(FakeApi()),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('No alerts right now'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('referral accept flow sends assignee, ward and bed', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = FakeApi()
      ..referrals = [_referral]
      ..capacity = const Capacity(
        wards: [
          Ward(id: 7, name: 'Emergency', bedsTotal: 10, bedsOccupied: 4),
          Ward(id: 8, name: 'ICU', bedsTotal: 4, bedsOccupied: 4),
        ],
        team: [
          TeamMember(firebaseUid: 'd2', fullName: 'Dr. Yaw Addo', role: StaffRole.doctor, status: StaffStatus.approved, onDuty: true),
        ],
      );

    await tester.pumpWidget(_app(const ReferralDetailScreen(referralId: 'r1'), overrides: [
      hospitalApiProvider.overrideWithValue(api),
      staffAccessProvider.overrideWith((ref) async => StaffAccess.fromMe(_me())),
    ]));
    await tester.pumpAndSettle();

    // Consented summary is shown.
    expect(find.text('Crushing chest pain'), findsOneWidget);
    expect(find.text('Penicillin'), findsOneWidget);
    expect(find.text('ETA 14 min'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(find.text('Accept referral'), findsWidgets);

    // Full ward (ICU) isn't offered.
    await tester.tap(find.text('No ward yet'));
    await tester.pumpAndSettle();
    expect(find.text('ICU · 0 free'), findsNothing);
    await tester.tap(find.text('Emergency · 6 free').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unassigned'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dr. Yaw Addo · Doctor · on duty').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'e.g. B4'), 'B4');
    await tester.tap(find.widgetWithText(InkWell, 'Accept referral'));
    await tester.pumpAndSettle();

    expect(api.lastAccept, {'id': 'r1', 'assignee': 'd2', 'ward': 7, 'bed': 'B4'});
    // Navigated to the new case record.
    expect(find.text('Start treatment'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
