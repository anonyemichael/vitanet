import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitanet/data/models/health_alert.dart';
import 'package:vitanet/data/providers/health_alerts_provider.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/data/services/api_service.dart';
import 'package:vitanet/shared/widgets/health_alert_banner.dart';

class _FakeApi extends ApiService {
  final acked = <String>[];
  @override
  Future<bool> acknowledgeAlert(String alertId) async {
    acked.add(alertId);
    return true;
  }
}

void main() {
  test('backend times without a zone are read as UTC', () {
    final a = HealthAlertItem.fromJson({
      'id': 'a1', 'vital_type': 'blood_oxygen', 'severity': 'URGENT', 'status': 'pending',
      'message': 'm', 'created_at': '2026-11-16T09:30:00',
    });
    expect(a.createdAt.toUtc(), DateTime.utc(2026, 11, 16, 9, 30));
    expect(a.isUrgent && a.isOpen, isTrue);
  });

  testWidgets('an unanswered alert shows on top of the page and "I\'m OK" answers it', (tester) async {
    final api = _FakeApi();
    final alert = HealthAlertItem(
      id: 'a1', vitalType: 'blood_oxygen', severity: 'urgent', status: 'pending',
      message: 'Your blood oxygen reading is 88%.', createdAt: DateTime.now(),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        // ignore: invalid_use_of_protected_member
        healthAlertsProvider.overrideWith((ref) => HealthAlertsNotifier(ref)..state = [alert]),
      ],
      child: const MaterialApp(home: HealthAlertOverlay(child: Scaffold(body: Text('Home page')))),
    ));
    expect(find.text('Home page'), findsOneWidget);
    expect(find.text('Urgent health alert'), findsOneWidget);
    expect(find.text('Call 112'), findsOneWidget);
    await tester.tap(find.text("I'm OK"));
    await tester.pump();
    expect(find.text('Urgent health alert'), findsNothing);
    expect(api.acked, ['a1']);
  });
}
