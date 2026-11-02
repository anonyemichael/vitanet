import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/features/splash/screens/splash_screen.dart';
import 'package:vitanet/shared/widgets/vitanet_logo.dart';

void main() {
  testWidgets('Minimal splash shows brand and auto-continues to onboarding',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const Scaffold(body: Text('ONBOARDING')),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('LOGIN')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('HOME')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );

    // Minimal splash content.
    expect(find.byType(VitaNetLogo), findsOneWidget);
    expect(find.text('VitaNet'), findsOneWidget);
    expect(find.text('Your health, guided'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // No buttons on the splash any more.
    expect(find.text('Get started'), findsNothing);
    expect(find.text('I already have an account'), findsNothing);

    // After the minimum display time (bootstrap times out in tests),
    // a first-time user is taken to onboarding automatically.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('ONBOARDING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
