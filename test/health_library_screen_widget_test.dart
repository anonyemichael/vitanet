import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitanet/features/resources/screens/general_health_library_screen.dart';

void main() {
  testWidgets('HealthLibraryScreen renders with top bar, search toggle, and unclipped topic chips', (tester) async {
    // Provide a standard desktop/tablet resolution
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HealthLibraryScreen(),
        ),
      ),
    );

    // Initial pump to mount widgets
    await tester.pump();

    // Verify title and the search toggle
    expect(find.text('Health library'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    // Opening search reveals the search field
    await tester.tap(find.byTooltip('Search'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search studies and topics'), findsOneWidget);

    // Verify topic chips
    expect(find.text('For you'), findsWidgets);
    expect(find.text('Heart'), findsWidgets);
    expect(find.text('Breathing'), findsWidgets);
    expect(find.text('Mental health'), findsWidgets);
    expect(find.text('Nutrition'), findsWidgets);
    expect(find.text('Sleep'), findsWidgets);

    // Verify the chip row scrolls horizontally without clipping the chips
    final singleChildScrollViews = tester.widgetList<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    final horizontalScrollView = singleChildScrollViews.firstWhere(
      (sv) => sv.scrollDirection == Axis.horizontal,
    );
    expect(horizontalScrollView.clipBehavior, Clip.none);
    expect(horizontalScrollView.padding, const EdgeInsets.symmetric(horizontal: 20));
  });
}
