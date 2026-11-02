import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitanet/features/settings/screens/settings_screen.dart';

void main() {
  group('SettingsScreen Widget Tests', () {
    testWidgets('Renders all grouped sections, tiles, and headers', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      // Verify TopBar
      expect(find.text('Settings'), findsOneWidget);

      // Verify Section Headers (VnSectionLabel renders uppercase)
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('NOTIFICATIONS'), findsOneWidget);
      expect(find.text('PRIVACY & DATA'), findsOneWidget);

      // Verify Setting Tiles
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Text size'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Clear triage history'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
    });

    testWidgets('Tapping Theme opens bottom sheet with 3 theme modes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      // Tap Theme tile
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();

      // Verify bottom sheet content
      expect(find.text('Appearance'), findsWidgets);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('Tapping Clear triage history opens confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      // Scroll ListView up to bring Clear triage history to comfortable center
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final clearTile = find.text('Clear triage history');
      expect(clearTile, findsOneWidget);
      await tester.tap(clearTile);
      await tester.pumpAndSettle();

      // Verify Dialog
      expect(find.text('Clear all triage history?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Clear history'), findsOneWidget);
    });
  });
}
