import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitanet/features/resources/screens/emergency_protocols_screen.dart';
import 'package:vitanet/features/first_aid/screens/first_aid_screen.dart';
import 'package:vitanet/data/services/media_library_service.dart';

void main() {
  group('Emergency Protocols Data & Imagery Integrity Tests', () {
    test('Verified burns imagery points to burn care and NOT loose pills', () {
      final burnImage = MediaLibraryService.getProtocolImage('Burns (minor)');
      expect(burnImage.contains('photo-1512069772995-ec65ed45afd6'), isFalse,
          reason: 'Burns must never display loose pill capsules');
      expect(burnImage.isNotEmpty, isTrue);

      final quickBurnImage = MediaLibraryService.getQuickScenarioImage('burns');
      expect(quickBurnImage.contains('photo-1512069772995-ec65ed45afd6'), isFalse,
          reason: 'Quick jump burns must never display loose pill capsules');
    });

    test('Verified protocols have dynamic and diverse step counts', () {
      final tips = FirstAidScreen.tips;
      expect(tips.isNotEmpty, isTrue);

      // Verify not every card has exactly 4 steps
      final stepCounts = tips.map((t) => t.steps.length).toSet();
      expect(stepCounts.length, greaterThan(1),
          reason: 'Protocols must have dynamic realistic step counts, not static mock counts');

      // Check specific clinical step counts
      final cpr = tips.firstWhere((t) => t.title.toLowerCase().contains('cpr'));
      expect(cpr.steps.length, equals(5));

      final burns = tips.firstWhere((t) => t.title.toLowerCase().contains('burn'));
      expect(burns.steps.length, equals(6));

      final bleeding = tips.firstWhere((t) => t.title.toLowerCase().contains('bleeding'));
      expect(bleeding.steps.length, equals(5));
    });
  });

  group('EmergencyProtocolsScreen Widget Tests', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: EmergencyProtocolsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('Renders call-first header, search and both protocol groups', (tester) async {
      await pumpScreen(tester);

      // Header elements
      expect(find.text('Emergency protocols'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('Call 112'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);

      // Verify no fake foreign placeholder text
      expect(find.textContaining('Zhongfang'), findsNothing);

      // Severity groups
      expect(find.text('LIFE-THREATENING'), findsOneWidget);
      expect(find.text('URGENT BUT MANAGEABLE'), findsOneWidget);

      // Life-threatening protocols with their real step counts
      expect(find.text('CPR (adult, hands-only)'), findsOneWidget);
      expect(find.textContaining('5 steps'), findsWidgets);
      expect(find.text('Choking (adult)'), findsOneWidget);
      expect(find.text('Severe Bleeding (Hemorrhage)'), findsOneWidget);

      // Urgent but manageable guides
      expect(find.text('Burns (minor)'), findsOneWidget);
      expect(find.text('Cool water 20 min'), findsOneWidget);
    });

    testWidgets('Real-time search filters protocols instantly', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'burn');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Burns (minor)'), findsOneWidget);
      expect(find.text('CPR (adult, hands-only)'), findsNothing);
      expect(find.text('Choking (adult)'), findsNothing);

      // Clear search button
      final clearButton = find.byIcon(Icons.close_rounded);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('CPR (adult, hands-only)'), findsOneWidget);
      expect(find.text('Burns (minor)'), findsOneWidget);
    });

    testWidgets('Tapping a protocol opens the step-by-step guide with tickable steps', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('CPR (adult, hands-only)'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // Guide opened
      expect(find.text('CPR: hands-only'), findsOneWidget);
      expect(find.text('100–120'), findsOneWidget);
      expect(find.text('Compression rhythm'), findsOneWidget);
      expect(find.textContaining('Call 112'), findsOneWidget);

      // Steps are tickable
      final firstStep = find.text('Check for danger and a response');
      expect(firstStep, findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      await tester.tap(firstStep);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });
}