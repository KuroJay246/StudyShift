import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/work_overtime.dart';

void main() {
  test(
    'split scheduled intervals sum worked time without counting the gap',
    () {
      final scheduledMinutes = WorkHoursSummary.sumIntervalMinutes([
        EventInterval.sameDay(startMinute: 360, endMinute: 540),
        EventInterval.sameDay(startMinute: 780, endMinute: 960),
      ]);

      final summary = WorkHoursSummary.fromMinutes(
        scheduledMinutes: scheduledMinutes,
        overtimeMinutes: 120,
      );

      expect(scheduledMinutes, 360);
      expect(summary.scheduledMinutes, 360);
      expect(summary.overtimeMinutes, 120);
      expect(summary.totalMinutes, 480);
      expect(summary.regularMinutes, 480);
      expect(summary.premiumEligibleMinutes, 0);
    },
  );

  test('only time over eight hours is marked premium eligible', () {
    final summary = WorkHoursSummary.fromMinutes(
      scheduledMinutes: 420,
      overtimeMinutes: 150,
    );

    expect(summary.totalMinutes, 570);
    expect(summary.regularMinutes, 480);
    expect(summary.premiumEligibleMinutes, 90);
  });

  test('rejects negative work and overtime durations', () {
    expect(
      () => WorkHoursSummary.fromMinutes(
        scheduledMinutes: -1,
        overtimeMinutes: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => WorkHoursSummary.fromMinutes(
        scheduledMinutes: 1,
        overtimeMinutes: -1,
      ),
      throwsArgumentError,
    );
  });
}
