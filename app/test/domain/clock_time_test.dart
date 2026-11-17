import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/domain/clock_time.dart';

void main() {
  test('parses 24-hour and 12-hour inputs to the same canonical minute', () {
    expect(ClockTime.parse('00:00').minuteOfDay, 0);
    expect(ClockTime.parse('23:59').minuteOfDay, 1439);
    expect(ClockTime.parse('12:00 AM').minuteOfDay, 0);
    expect(ClockTime.parse('12:00 PM').minuteOfDay, 720);
    expect(ClockTime.parse('7:05 pm').minuteOfDay, 19 * 60 + 5);
  });

  test('formats both display preferences without changing stored value', () {
    const time = ClockTime(19 * 60 + 5);
    expect(time.format(use24Hour: true), '19:05');
    expect(time.format(use24Hour: false), '7:05 PM');
    expect(time.minuteOfDay, 19 * 60 + 5);
  });

  test('rejects invalid and ambiguous formats rather than guessing', () {
    for (final value in ['24:00', '13:05 PM', '7:5 AM', 'noon', '00:60']) {
      expect(() => ClockTime.parse(value), throwsFormatException, reason: value);
    }
  });
}
