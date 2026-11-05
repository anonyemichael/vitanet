import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitanet/features/admin/models/portal_models.dart' as portal;
import 'package:vitanet/data/providers/referral_providers.dart';
import 'package:vitanet/data/services/referral_service.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
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

    test('InpatientVitals serializes vital signs flow sheet', () {
      final vitals = portal.InpatientVitals(
        heartRate: 74,
        bloodOxygen: 98.5,
        bloodPressure: '118/76',
        temperature: 36.7,
        respiratoryRate: 15,
        recordedBy: 'Nurse Serwaa',
        recordedAt: '2026-11-05T18:15:00Z',
      );

      final json = vitals.toJson();
      expect(json['heart_rate'], 74);
      expect(json['blood_oxygen'], 98.5);
      expect(json['blood_pressure'], '118/76');
      expect(json['temperature'], 36.7);
      expect(json['respiratory_rate'], 15);

      final parsed = portal.InpatientVitals.fromJson(json);
      expect(parsed.heartRate, 74);
      expect(parsed.bloodOxygen, 98.5);
      expect(parsed.bloodPressure, '118/76');
    });

    test('PatientHospitalCase parses status, ward bed stay, and discharge summary', () {
      final kase = portal.PatientHospitalCase.fromJson({
        'id': 'case_99',
        'hospital_id': 'h_ridge',
        'hospital_name': 'Greater Accra Regional Hospital',
        'hospital_phone': '+233 30 222 8315',
        'ward': 'Cardiology Care Unit',
        'bed': 'CCU-04',
        'attending_doctor': 'Dr. Mensah',
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
      expect(kase.isInTreatment, isTrue);
      expect(kase.isDischarged, isFalse);
      expect(kase.timeline.length, 2);
      expect(kase.timeline.first.kind, 'emergency_checkin');
    });

    test('EmergencyCheckinResult parses confirmation and triage dispatch', () {
      final res = portal.EmergencyCheckinResult.fromJson({
        'referral_id': 'ref_er_123',
        'case_id': 'case_er_456',
        'hospital_id': 'h_ridge',
        'status': 'arriving',
        'eta_minutes': 15,
        'message': 'Pre-arrival emergency check-in received at Ridge Hospital. ER triage notified.',
      });

      expect(res.referralId, 'ref_er_123');
      expect(res.caseId, 'case_er_456');
      expect(res.status, 'arriving');
      expect(res.etaMinutes, 15);
      expect(res.message, contains('Ridge Hospital'));
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
