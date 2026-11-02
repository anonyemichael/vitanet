import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/core/providers/shared_state.dart';

void main() {
  group('YouTube Auto-hide Navbar & Header Tests', () {
    testWidgets('handleScrollNotification hides navbar on scroll down and shows on scroll up', (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(navBarVisibleProvider), true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                final isVisible = ref.watch(navBarVisibleProvider);
                return Scaffold(
                  body: Stack(
                    children: [
                      Positioned.fill(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (n) => handleScrollNotification(n, ref),
                          child: ListView.builder(
                            itemCount: 100,
                            itemBuilder: (context, index) => SizedBox(
                              height: 60,
                              child: Text('Item $index'),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: AnimatedSlide(
                          offset: isVisible ? Offset.zero : const Offset(0, 1.6),
                          duration: const Duration(milliseconds: 200),
                          child: const SizedBox(
                            key: Key('liquid-navbar'),
                            height: 64,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('liquid-navbar')), findsOneWidget);

      // Scroll down (drag upwards)
      await tester.drag(find.text('Item 2'), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(container.read(navBarVisibleProvider), false);

      // Scroll up (drag downwards)
      await tester.drag(find.text('Item 10'), const Offset(0, 200));
      await tester.pumpAndSettle();

      expect(container.read(navBarVisibleProvider), true);
    });

    testWidgets('Horizontal scroll does NOT trigger vertical auto-hide', (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(navBarVisibleProvider), true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return Scaffold(
                  body: NotificationListener<ScrollNotification>(
                    onNotification: (n) => handleScrollNotification(n, ref),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 50,
                      itemBuilder: (context, index) => SizedBox(
                        width: 100,
                        child: Text('Card $index'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Scroll horizontally
      await tester.drag(find.text('Card 1'), const Offset(-200, 0));
      await tester.pumpAndSettle();

      // Navbar should remain visible
      expect(container.read(navBarVisibleProvider), true);
    });
  });
}
