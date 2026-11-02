import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/splash/screens/splash_screen.dart';
import 'package:vitanet/shared/widgets/vitanet_logo.dart';

void main() {
  testWidgets('SplashScreen smoke & narrative test', (WidgetTester tester) async {
    // Set phone viewport (390 x 844 - iPhone 14 / modern Android resolution)
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SplashScreen(),
        ),
      ),
    );

    // Initial frame
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(VitaNetLogo), findsOneWidget);

    // Confirm that old unwanted text elements are NOT present
    expect(find.text('INITIALIZING VITAL ENGINE'), findsNothing);
    expect(find.text('CALIBRATING BIO-METRIC TELEMETRY'), findsNothing);
    expect(find.text('SYNCHRONIZING AI CLINICAL INTELLIGENCE'), findsNothing);

    // Confirm that VitaNet clinical story elements are present per design
    expect(find.text('Clinician-guided'), findsOneWidget);
    expect(find.text('Encrypted'), findsOneWidget);
    expect(find.text('24/7'), findsOneWidget);
    expect(
      find.text('Know when to rest, when to see a pharmacist, and when to go now.'),
      findsOneWidget,
    );
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);

    // Advance 1 second into the animation
    await tester.pump(const Duration(seconds: 1));

    // Advance 3 seconds into the animation so splash timers resolve
    await tester.pump(const Duration(seconds: 3));

    // Verify it pumps cleanly without exceptions
    expect(tester.takeException(), isNull);

    // Unmount widget so active controllers and timers dispose cleanly
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
