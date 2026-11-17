import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitanet/data/models/health_alert.dart';
import 'package:vitanet/data/providers/referral_providers.dart';
import 'package:vitanet/features/portal/data/portal_models.dart';
import 'package:vitanet/features/assessment/screens/assessment_wizard_screen.dart';
import 'package:vitanet/features/history/screens/patient_visits_screen.dart';
import 'package:vitanet/features/home/screens/hospital_directory_screen.dart';
import 'package:vitanet/features/settings/screens/disclaimer_screen.dart';
import 'package:vitanet/features/settings/screens/privacy_screen.dart';
import 'package:vitanet/features/settings/screens/settings_screen.dart';
import 'package:vitanet/shared/widgets/health_alert_banner.dart';

/// UI/UX audit UX-14 / T13: key screens on a small phone (360 x 740) with system text at 1.5x and 2.0x must
/// lay out without overflow errors (Flutter reports clipped / overflowing layouts as errors in tests).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final screens = <String, Widget>{
    'Symptom assessment': const AssessmentWizardScreen(),
    'Settings': const SettingsScreen(),
    'Hospital directory': ProviderScope(
      overrides: [
        nearbyFacilitiesProvider.overrideWith((ref) async => const [
              Facility(name: 'Korle Bu Teaching Hospital', address: 'Guggisberg Ave, Accra', latitude: 5.536,
                  longitude: -0.226, phoneNumber: '0302 674 000', hasAmbulance: true, distanceKm: 2.4,
                  bedsTotal: 40, bedsFree: 6, etaMinutes: 9),
            ]),
      ],
      child: const HospitalDirectoryScreen(),
    ),
    'Hospital visits': const PatientVisitsScreen(),
    'Privacy': const PrivacyScreen(),
    'Disclaimer': const DisclaimerScreen(),
    'Health alert card': Scaffold(
      body: HealthAlertCard(
        alert: HealthAlertItem(
          id: 'a', vitalType: 'blood_oxygen', severity: 'urgent', status: 'pending', createdAt: DateTime.now(),
          message: 'Your blood oxygen reading is 88%. Your usual is about 97%. This can be dangerous. If you feel '
              'unwell, short of breath, confused or have chest pain, go to the nearest hospital now or call 112 / 193.',
        ),
      ),
    ),
  };

  for (final scale in [1.5, 2.0]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} fits a 360 px phone at ${scale}x text', (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: entry.value,
          ),
        ));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
