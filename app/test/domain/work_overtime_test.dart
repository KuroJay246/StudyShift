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

  test('configured eight-hour daily rule classifies time after threshold', () {
    final summary = WorkHoursSummary.fromMinutes(
      scheduledMinutes: 420,
      overtimeMinutes: 150,
      standardDayMinutes: 8 * 60,
    );

    expect(summary.totalMinutes, 570);
    expect(summary.regularMinutes, 480);
    expect(summary.premiumEligibleMinutes, 90);
    expect(summary.standardRateTopUpMinutes, 60);
  });

  test(
    'does not assume a premium threshold when no employer policy exists',
    () {
      final summary = WorkHoursSummary.fromMinutes(
        scheduledMinutes: 7 * 60,
        overtimeMinutes: 3 * 60,
      );

      expect(summary.totalMinutes, 10 * 60);
      expect(summary.regularMinutes, 10 * 60);
      expect(summary.premiumEligibleMinutes, 0);
    },
  );

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
    expect(
      () => WorkHoursSummary.fromMinutes(
        scheduledMinutes: 1,
        overtimeMinutes: 0,
        standardDayMinutes: 0,
      ),
      throwsArgumentError,
    );
  });
}
