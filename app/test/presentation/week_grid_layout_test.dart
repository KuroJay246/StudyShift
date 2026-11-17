import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/presentation/widgets/week_grid.dart';

void main() {
  test(
    'phone columns favor readable two-day browsing over seven tiny days',
    () {
      expect(weekDayColumnWidth(360), 156);
      expect(weekDayColumnWidth(393), closeTo(172.5, 0.1));
      expect(weekDayColumnWidth(412), closeTo(182, 0.1));
    },
  );

  test('expanded calendar fits a full week across available width', () {
    final medium = weekDayColumnWidth(700);
    final landscape = weekDayColumnWidth(834);
    final large = weekDayColumnWidth(900);
    expect(medium, 96);
    expect(landscape, closeTo(112.29, 0.01));
    expect(large, closeTo(121.71, 0.01));
    expect(landscape * 7, closeTo(834 - 48, 0.01));
  });

  test('landscape calendar rows fit more useful hours on screen', () {
    expect(weekGridHourHeight(411), 48);
    expect(weekGridHourHeight(499), 48);
    expect(weekGridHourHeight(500), 64);
    expect(weekGridHourHeight(800), 64);
  });

  test('an empty week opens at the morning hours', () {
    expect(weekGridInitialScrollOffset(firstScheduledMinute: null), 6 * 64);
  });

  test('a scheduled week opens one hour before its first event', () {
    expect(weekGridInitialScrollOffset(firstScheduledMinute: 9 * 60), 8 * 64);
  });
}
