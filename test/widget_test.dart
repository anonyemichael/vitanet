import 'package:flutter_test/flutter_test.dart';
import 'package:untitled1/main.dart';

void main() {
  testWidgets('Medical System App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MedicalSystemApp());

    // Verify that the dashboard title is present
    expect(find.text('Medical System Dashboard'), findsOneWidget);
  });
}
