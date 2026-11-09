import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitanet/features/portal/data/portal_models.dart' as portal;
import 'package:vitanet/data/providers/referral_providers.dart';
import 'package:vitanet/data/services/referral_service.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
import 'package:vitanet/features/home/widgets/hospital_care_section.dart';

void main() {
  group('Unified Hospital & Patient Platform Models', () {
    test('Facility parses bed counts, emergency status and ETA accurately', () {
      final fac = portal.Facility.fromJson({
        'id': 'h_ridge',
        'name': 'Greater Accra Regional Hospital',
        'address': 'Castle Road, Ridge, Accra',
        'latitude': 5.556,
        'longitude': -0.198,
        'phone_number': '+233 30 222 8315',
        'has_emergency_room': true,
        'has_ambulance': true,
        'ambulance_available': true,
        'accepting_referrals': true,
        'distance_km': 2.4,
        'beds_total': 180,
        'beds_free': 34,
        'eta_minutes': 11,
      });

      expect(fac.id, 'h_ridge');
      expect(fac.name, 'Greater Accra Regional Hospital');
      expect(fac.bedsTotal, 180);
      expect(fac.bedsFree, 34);
      expect(fac.hasEmergencyRoom, isTrue);
      expect(fac.etaMinutes, 11);
      expect(fac.distanceKm, 2.4);
    });

    test('PrescriptionOrder serializes and deserializes cleanly', () {
      final order = portal.PrescriptionOrder(
        medication: 'Amoxicillin / Clavulanic Acid',
        dosage: '625 mg',
        frequency: 'TID (Every 8 hours)',
        duration: '7 days',
        instructions: 'Take immediately after meals with plenty of water',
        orderedBy: 'Dr. Ama Mensah',
        orderedAt: '2026-11-05T18:00:00Z',
      );

      final json = order.toJson();
      expect(json['medication'], 'Amoxicillin / Clavulanic Acid');
      expect(json['dosage'], '625 mg');
      expect(json['frequency'], 'TID (Every 8 hours)');
      expect(json['duration'], '7 days');
      expect(json['instructions'], 'Take immediately after meals with plenty of water');

      final parsed = portal.PrescriptionOrder.fromJson(json);
      expect(parsed.medication, order.medication);
      expect(parsed.dosage, order.dosage);
    });

    test('CaseVitals sends only what was measured and reads the server shape', () {
      const vitals = portal.CaseVitals(heartRate: 108, bpSystolic: 158, bpDiastolic: 96, spo2: 96, alert: true);
      expect(vitals.toJson(), {
        'heart_rate': 108,
        'bp_systolic': 158,
        'bp_diastolic': 96,
        'blood_oxygen': 96,
        'alert': true,
      });

      final parsed = portal.CaseVitals.fromJson({
        'heart_rate': 124,
        'bp_systolic': 98,
        'bp_diastolic': 60,
        'spo2': 91,
        'respiratory_rate': 26,
        'early_warning': 8,
        'recorded_by': 'Nurse Badu',
        'at': '2026-11-09T10:12:00Z',
      });
      expect(parsed.heartRate, 124);
      expect(parsed.spo2, 91);
      expect(parsed.earlyWarning, 8);
      expect(parsed.temperature, isNull);
      expect(parsed.isEmpty, isFalse);
    });

    test('PatientHospitalCase parses status, ward bed stay, and discharge summary', () {
      final kase = portal.PatientHospitalCase.fromJson({
        'id': 'case_99',
        'hospital_id': 'h_ridge',
        'hospital_name': 'Greater Accra Regional Hospital',
        'hospital_phone': '+233 30 222 8315',
        'ward_name': 'Cardiology Care Unit',
        'bed': 'CCU-04',
        'assignee_name': 'Dr. Mensah',
        'status': 'treatment',
        'level': 'urgent',
        'complaint': 'Acute substernal chest pressure with dyspnea',
        'discharge_summary': null,
        'timeline': [
          {
            'at': '2026-11-05T17:00:00Z',
            'by': 'System',
            'kind': 'emergency_checkin',
            'text': 'Pre-arrival ER check-in dispatched with ETA ~15 min',
          },
          {
            'at': '2026-11-05T17:15:00Z',
            'by': 'Dr. Mensah',
            'kind': 'status',
            'text': 'Admitted to CCU-04. Initiated telemetry & oxygen therapy.',
          },
        ],
        'created_at': '2026-11-05T17:00:00Z',
        'updated_at': '2026-11-05T17:15:00Z',
      });

      expect(kase.id, 'case_99');
      expect(kase.hospitalName, 'Greater Accra Regional Hospital');
      expect(kase.ward, 'Cardiology Care Unit');
      expect(kase.bed, 'CCU-04');
      expect(kase.attendingDoctor, 'Dr. Mensah');
      expect(kase.isInTreatment, isTrue);
      expect(kase.isDischarged, isFalse);
      expect(kase.timeline.length, 2);
      expect(kase.timeline.first.kind, 'emergency_checkin');
    });

    test('EmergencyCheckinResult reads the referral the server creates', () {
      final res = portal.EmergencyCheckinResult.fromJson({
        'id': 'ref_er_123',
        'hospital_id': 'h_ridge',
        'status': 'new',
        'source': 'checkin',
        'eta_minutes': 9,
      });

      expect(res.referralId, 'ref_er_123');
      expect(res.status, 'new');
      expect(res.etaMinutes, 9);
    });

    test('Referral counts down to the absolute ETA', () {
      final r = portal.Referral.fromJson({
        'id': 'r1',
        'hospital_id': 'h1',
        'status': 'new',
        'triage_level': 'urgent',
        'summary': {'complaint': 'Chest pain'},
        'eta_minutes': 10,
        'eta_at': '2026-11-09T10:10:00Z',
        'created_at': '2026-11-09T10:00:00Z',
        'updated_at': '2026-11-09T10:00:00Z',
        'suggestion': {'ward_id': 3, 'ward_name': 'Resus', 'assignee_uid': 'd1', 'assignee_name': 'Dr. Addo'},
      });
      expect(r.minutesToArrival(now: DateTime.utc(2026, 11, 9, 10, 4)), 6);
      expect(r.minutesToArrival(now: DateTime.utc(2026, 11, 9, 10, 15)), -5);
      expect(r.suggestion!.wardName, 'Resus');
    });
  });

  group('HospitalCareSection Widget Tests', () {
    testWidgets('Renders nearest facility with 24/7 ER, beds, and Pre-Arrival Check-In', (tester) async {
      final testFacility = Facility(
        id: 'h_ridge',
        name: 'Greater Accra Regional Hospital',
        address: 'Castle Road, Ridge, Accra',
        latitude: 5.556,
        longitude: -0.198,
        phoneNumber: '+233 30 222 8315',
        hasEmergencyRoom: true,
        acceptingReferrals: true,
        distanceKm: 2.1,
        etaMinutes: 10,
        bedsTotal: 150,
        bedsFree: 28,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyFacilitiesProvider.overrideWith((ref) => Future.value([testFacility])),
            patientCasesProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: HospitalCareSection(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Hospital Care & Emergency'), findsOneWidget);
      expect(find.text('Greater Accra Regional Hospital'), findsOneWidget);
      expect(find.text('24/7 ER Active'), findsOneWidget);
      expect(find.text('28 of 150 beds free'), findsOneWidget);
      expect(find.text('~10 min ETA'), findsOneWidget);
      expect(find.text('ER Pre-Arrival Check-In'), findsOneWidget);
    });

    testWidgets('Renders active inpatient stay banner when patient is admitted', (tester) async {
      final activeCase = portal.PatientHospitalCase(
        id: 'c1',
        hospitalId: 'h1',
        hospitalName: '37 Military Hospital',
        ward: 'Surgical Ward 2',
        bed: 'Bed 14',
        attendingDoctor: 'Dr. K. Mensah',
        status: 'treatment',
        level: 'urgent',
        complaint: 'Post-op appendectomy recovery',
        createdAt: '2026-11-05T10:00:00Z',
        updatedAt: '2026-11-05T14:00:00Z',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyFacilitiesProvider.overrideWith((ref) => Future.value([])),
            patientCasesProvider.overrideWith((ref) => Future.value([activeCase])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: HospitalCareSection(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Active Hospital Stay'), findsOneWidget);
      expect(find.text('37 Military Hospital'), findsOneWidget);
      expect(find.textContaining('Ward: Surgical Ward 2 · Bed: Bed 14'), findsOneWidget);
      expect(find.text('View Inpatient Flow Sheet & Doctor Orders'), findsOneWidget);
    });
  });
}
