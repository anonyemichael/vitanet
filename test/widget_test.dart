import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vitanet/main.dart';

void main() {
  testWidgets('VitaNetApp smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: VitaNetApp()));
    await tester.pump();

    expect(find.byType(VitaNetApp), findsOneWidget);

    // Let any splash timers finish so fakeAsync has no pending timers
    await tester.pump(const Duration(seconds: 4));
  });
}
