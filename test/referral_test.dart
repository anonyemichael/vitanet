import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitanet/data/models/triage_result.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/providers/referral_providers.dart';
import 'package:vitanet/data/services/referral_service.dart';
import 'package:vitanet/features/triage_result/widgets/referral_status_card.dart';
import 'package:vitanet/features/triage_result/widgets/send_referral_sheet.dart';

class _FakeService implements ReferralService {
  final List<ReferralRequest> sent = [];
  ReferralException? failWith;
  List<Referral> mineList = const [];

  @override
  Future<Referral> create(ReferralRequest request) async {
    sent.add(request);
    if (failWith != null) throw failWith!;
    return Referral(
        id: 'r1', hospitalId: request.hospitalId, hospitalName: 'General Hospital', status: 'new');
  }

  @override
  Future<List<Referral>> mine() async => mineList;

  @override
  Future<Referral> cancel(String id) async =>
      Referral(id: id, hospitalId: 'h1', status: 'cancelled');

  @override
  Future<List<Facility>> listFacilities({double? lat, double? lng, int limit = 20}) async => const [];
}

const _hospital = Facility(
  id: 'h1',
  name: 'General Hospital',
  latitude: 5.6,
  longitude: -0.2,
  phoneNumber: '+233000000',
  acceptingReferrals: true,
  distanceKm: 2.4,
  etaMinutes: 11,
);

final _result = TriageResult(
  id: 't1',
  level: TriageLevel.emergency,
  summary: 'Chest pain spreading to left arm.',
  recommendations: const [],
  monitorSymptoms: const [],
  primarySymptom: 'Chest pain',
  timestamp: DateTime(2026, 1, 1, 10),
);

void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.5;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openSheet(
  WidgetTester tester, {
  required List<Facility> facilities,
  required _FakeService service,
  UserProfile? profile,
}) async {
  _bigScreen(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      nearbyFacilitiesProvider.overrideWith((ref) async => facilities),
      currentLocationProvider.overrideWith((ref) async => null),
      referralServiceProvider.overrideWithValue(service),
      referralProfileProvider.overrideWithValue(profile),
      referralVitalsProvider.overrideWithValue(const {'heart_rate': 96.0}),
      myReferralsProvider.overrideWith((ref) async => const <Referral>[]),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSendReferralSheet(context, _result),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Widget _card(Referral r) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ReferralStatusCard(referral: r, facility: _hospital, refreshEvery: null),
        ),
      ),
    );

void main() {
  group('Send referral sheet', () {
    testWidgets('consent is required before Send', (tester) async {
      final service = _FakeService();
      await _openSheet(tester,
          facilities: const [_hospital],
          service: service,
          profile: const UserProfile(name: 'Ada', age: 34, allergies: ['Penicillin']));

      // Shows the exact values that will be shared.
      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Penicillin'), findsOneWidget);
      expect(find.text('Heart rate (bpm): 96'), findsOneWidget);

      final send = find.text('Send to General Hospital');
      expect(send, findsOneWidget);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(service.sent, isEmpty);

      await tester.tap(find.byKey(const Key('referral-consent')));
      await tester.pumpAndSettle();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(service.sent, hasLength(1));
      final req = service.sent.single;
      expect(req.consent, isTrue);
      expect(req.triageLevel, 'urgent');
      expect(req.allergies, ['Penicillin']);
      expect(req.vitals, {'heart_rate': 96.0});
      // Sheet closed after a successful send.
      expect(find.text('Send to General Hospital'), findsNothing);
    });

    testWidgets('guest without a profile sees honest placeholders', (tester) async {
      await _openSheet(tester, facilities: const [_hospital], service: _FakeService());
      expect(find.text('Not set'), findsNWidgets(3)); // name, age, sex
      expect(find.text('None recorded'), findsNWidgets(3)); // allergies, meds, conditions
    });

    testWidgets('empty facility state', (tester) async {
      await _openSheet(tester, facilities: const [], service: _FakeService());
      expect(find.text('No hospitals near you use VitaNet yet — call 112 in an emergency'),
          findsOneWidget);
      expect(find.text('Call 112'), findsOneWidget);
      expect(find.text('Find nearest A&E'), findsOneWidget);
      expect(find.byKey(const Key('referral-consent')), findsNothing);
    });

    testWidgets('open-referral conflict shows the existing referral', (tester) async {
      final service = _FakeService()
        ..failWith = const ReferralException('You already have an open referral', statusCode: 409)
        ..mineList = const [
          Referral(id: 'old', hospitalId: 'h1', hospitalName: 'General Hospital', status: 'new'),
        ];
      await _openSheet(tester, facilities: const [_hospital], service: service);
      await tester.tap(find.byKey(const Key('referral-consent')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send to General Hospital'));
      await tester.pumpAndSettle();
      expect(find.text('Send to General Hospital'), findsNothing);
    });
  });

  group('Referral status card', () {
    testWidgets('new', (tester) async {
      await tester.pumpWidget(_card(const Referral(
          id: 'r', hospitalId: 'h1', hospitalName: 'General Hospital', status: 'new', etaMinutes: 11)));
      expect(find.text('Sent — waiting for General Hospital to respond'), findsOneWidget);
      expect(find.text('About 11 min away by road'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Directions'), findsOneWidget);
    });

    testWidgets('accepted', (tester) async {
      await tester.pumpWidget(_card(const Referral(
        id: 'r',
        hospitalId: 'h1',
        hospitalName: 'General Hospital',
        status: 'accepted',
        caseInfo: ReferralCase(assigneeName: 'Dr Mensah', wardName: 'Ward A', bed: '4'),
      )));
      expect(
          find.text('Accepted — go to General Hospital Emergency; ask for Dr Mensah (Ward A, bed 4)'),
          findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('declined', (tester) async {
      var reopened = false;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ReferralStatusCard(
              referral: const Referral(
                  id: 'r',
                  hospitalId: 'h1',
                  hospitalName: 'General Hospital',
                  status: 'declined',
                  declineReason: 'No ICU beds'),
              facility: _hospital,
              refreshEvery: null,
              onFindAnother: () => reopened = true,
            ),
          ),
        ),
      ));
      expect(find.text('General Hospital could not take this referral'), findsOneWidget);
      expect(find.text('Reason: No ICU beds'), findsOneWidget);
      await tester.tap(find.text('Find another hospital'));
      expect(reopened, isTrue);
    });

    testWidgets('arrived', (tester) async {
      await tester.pumpWidget(_card(const Referral(id: 'r', hospitalId: 'h1', status: 'arrived')));
      expect(find.text('Visit completed'), findsOneWidget);
      expect(find.text('Directions'), findsNothing);
    });

    testWidgets('cancelled', (tester) async {
      await tester.pumpWidget(_card(const Referral(id: 'r', hospitalId: 'h1', status: 'cancelled')));
      expect(find.text('Referral cancelled'), findsOneWidget);
    });
  });
}
