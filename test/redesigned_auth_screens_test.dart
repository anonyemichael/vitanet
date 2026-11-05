import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/auth/screens/patient_login_screen.dart';
import 'package:vitanet/features/auth/screens/role_selection_screen.dart';

void main() {
  group('Redesigned Auth Screens Tests', () {
    testWidgets('RoleSelectionScreen renders enterprise workspace cards and hero on desktop',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(path: '/login', builder: (_, _) => const RoleSelectionScreen()),
          GoRoute(path: '/login/patient', builder: (_, _) => const Scaffold(body: Text('PATIENT_LOGIN'))),
          GoRoute(path: '/login/hospital_personnel', builder: (_, _) => const Scaffold(body: Text('STAFF_PORTAL'))),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified enterprise content
      expect(find.text('Select your workspace'), findsOneWidget);
      expect(find.text('Personal Health'), findsOneWidget);
      expect(find.text('Hospital Personnel'), findsOneWidget);
      expect(find.text('One Unified Platform for Patients & Clinical Teams.'), findsOneWidget);
      expect(find.text('Enter Personal Health'), findsOneWidget);
      expect(find.text('Enter Clinical Portal'), findsOneWidget);

      // Tap Personal User card navigates to patient login
      await tester.tap(find.text('Enter Personal Health'));
      await tester.pumpAndSettle();
      expect(find.text('PATIENT_LOGIN'), findsOneWidget);
    });

    testWidgets('RoleSelectionScreen renders cleanly on mobile screen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(path: '/login', builder: (_, _) => const RoleSelectionScreen()),
          GoRoute(path: '/login/patient', builder: (_, _) => const Scaffold(body: Text('PATIENT_LOGIN'))),
          GoRoute(path: '/login/hospital_personnel', builder: (_, _) => const Scaffold(body: Text('STAFF_PORTAL'))),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select your workspace'), findsOneWidget);
      expect(find.text('HEALTHCARE'), findsOneWidget);
      expect(find.text('Personal Health'), findsOneWidget);
      expect(find.text('Hospital Personnel'), findsOneWidget);
    });

    testWidgets('PatientLoginScreen renders segmented mode switcher and form inputs',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/login/patient',
        routes: [
          GoRoute(path: '/login/patient', builder: (_, _) => const PatientLoginScreen()),
          GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('WORKSPACE_SELECTION'))),
          GoRoute(path: '/login/hospital_personnel', builder: (_, _) => const Scaffold(body: Text('STAFF_LOGIN'))),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check segmented buttons
      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);

      // Switch to Create Account mode
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Create your personal account'), findsOneWidget);
      expect(find.text('Create Personal Account'), findsOneWidget);

      // Switch back to Sign In
      await tester.tap(find.text('Sign In').first);
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });
}
