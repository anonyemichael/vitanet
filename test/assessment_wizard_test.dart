import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitanet/features/assessment/screens/assessment_wizard_screen.dart';

void main() {
  testWidgets('Assessment: optional questions are marked, pain is not assumed, answers are reviewed (UX-03/06/07)',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: AssessmentWizardScreen())));
    await tester.pumpAndSettle();

    expect(find.text('Optional'), findsNothing);               // where + how long are required
    await tester.tap(find.text('Chest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1–3 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Optional'), findsOneWidget);             // pain is optional and not yet given
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fever'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Review my answers'), findsOneWidget);    // honest label before the review
    await tester.tap(find.text('Review my answers'));
    await tester.pumpAndSettle();

    expect(find.text('Check your answers'), findsWidgets);
    expect(find.text('Chest'), findsOneWidget);
    expect(find.text('1–3 days'), findsOneWidget);
    expect(find.text('Fever'), findsOneWidget);
    expect(find.text('Not given'), findsOneWidget);            // pain: never silently 5/10
    expect(find.text('Get my result'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Change Pain'));    // back to the pain question
    await tester.pumpAndSettle();
    expect(find.text('How bad is the pain or discomfort?'), findsOneWidget);
  });
}
