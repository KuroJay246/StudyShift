import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/domain/schedule.dart';

void main() {
  test('overtime extends only the final interval of a split shift', () {
    final planned = [
      EventInterval.sameDay(startMinute: 360, endMinute: 720),
      EventInterval.sameDay(startMinute: 900, endMinute: 1020),
    ];

    final actual = intervalsWithOvertimeEnd(planned, 1140);

    expect(actual, hasLength(2));
    expect(actual.first, planned.first);
    expect(actual.last.startMinute, 900);
    expect(actual.last.endMinute, 1140);
    expect(planned.last.endMinute, 1020);
  });

  test('a finish time before the planned clock time rolls into the next day', () {
    final actual = intervalsWithOvertimeEnd([
      EventInterval.overnight(startMinute: 1320, endMinute: 360),
    ], 300);

    expect(actual.single.endDayOffset, 2);
    expect(actual.single.endMinute, 300);
  });
}
