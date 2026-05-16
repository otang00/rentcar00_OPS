import 'package:flutter_test/flutter_test.dart';
import 'package:rentcar00_ops/shared/input/ops_input_formatters.dart';

void main() {
  test('formats phone numbers for display while keeping storage digits', () {
    expect(opsFormatPhoneInput('01012345678'), '010-1234-5678');
    expect(opsFormatPhoneInput('0212345678'), '02-1234-5678');
    expect(opsFormatPhoneInput('15881234'), '1588-1234');
    expect(opsNormalizePhoneForStorage('010-1234-5678'), '01012345678');
  });

  test('formats and validates only complete birth dates', () {
    expect(opsFormatBirthDateInput('19841115'), '1984-11-15');
    expect(opsFormatBirthDateInput('198411'), '1984-11');
    expect(opsIsCompleteBirthDate('1984'), isFalse);
    expect(opsIsCompleteBirthDate('1984-11'), isFalse);
    expect(opsIsCompleteBirthDate('1984-11-15'), isTrue);
  });

  test('formats date time input with a fixed year prefix', () {
    expect(
      opsFormatDateTimeInput('2026-05171030', defaultYear: 2026),
      '2026-05-17 10:30',
    );
    expect(opsFormatDateTimeInput('0517', defaultYear: 2026), '2026-05-17');
  });

  test('parses date-only values using default or fallback time', () {
    final defaulted = opsTryParseEditorDateTime('2026-05-17');
    expect(defaulted, DateTime(2026, 5, 17, 10));

    final preserved = opsTryParseEditorDateTime(
      '2026-05-17',
      fallback: DateTime(2026, 5, 16, 14, 30),
    );
    expect(preserved, DateTime(2026, 5, 17, 14, 30));
  });
}
