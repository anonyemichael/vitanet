import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:vitanet/data/services/health_service.dart';

void main() {
  test('a watch reading becomes a plain number (its text is "NumericHealthValue - numericValue: 72")', () {
    final v = NumericHealthValue(numericValue: 72);
    expect(double.tryParse(v.toString()), isNull); // the old bug: parsing the text gives nothing
    expect(HealthService.numberOf(v), 72.0);
  });
}
