import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
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

      // Redesign copy, plus the desktop hero panel
      expect(find.text('How will you use VitaNet?'), findsOneWidget);
      expect(find.text('Personal user'), findsOneWidget);
      expect(find.text('Hospital personnel'), findsOneWidget);
      expect(find.text('One Unified Platform for Patients & Clinical Teams.'), findsOneWidget);

      // Tapping the personal card opens patient login
      await tester.tap(find.text('Personal user'));
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

      expect(find.text('How will you use VitaNet?'), findsOneWidget);
      expect(find.text('Pick one. You can switch later from Settings.'), findsOneWidget);
      expect(find.text('Personal user'), findsOneWidget);
      expect(find.text('Hospital personnel'), findsOneWidget);
      // The old badge is gone
      expect(find.text('HEALTHCARE'), findsNothing);
    });

    testWidgets('PatientLoginScreen renders the redesign form and toggles create-account mode',
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

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Try anonymously'), findsOneWidget);

      // Footer link switches to create-account mode
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);

      // And back to sign in
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('ActiveWorkspaceNotifier persists and isolates personal and hospital modes',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Default is personal
      expect(container.read(activeWorkspaceProvider), AppWorkspace.personal);

      // Switch to hospital
      await container.read(activeWorkspaceProvider.notifier).setWorkspace(AppWorkspace.hospital);
      expect(container.read(activeWorkspaceProvider), AppWorkspace.hospital);

      // Switch to personal
      await container.read(activeWorkspaceProvider.notifier).setWorkspace(AppWorkspace.personal);
      expect(container.read(activeWorkspaceProvider), AppWorkspace.personal);
    });
  });
}
