import 'schedule.dart';

/// Extra time worked for one occurrence of a scheduled shift.
///
/// This is deliberately separate from the shift's planned intervals: overtime
/// can happen during a split-shift gap or after the final scheduled interval.
class WorkOvertimeAdjustment {
  WorkOvertimeAdjustment({
    required this.shiftItemId,
    required this.occurrenceDate,
    required this.minutes,
    this.isCompleted = false,
  }) {
    if (shiftItemId.trim().isEmpty) {
      throw ArgumentError.value(shiftItemId, 'shiftItemId');
    }
    if (!occurrenceDate.isValid) {
      throw ArgumentError.value(occurrenceDate, 'occurrenceDate');
    }
    if (minutes < 0 || minutes > 24 * 60 || (minutes == 0 && !isCompleted)) {
      throw ArgumentError.value(
        minutes,
        'minutes',
        'Overtime must be between 1 minute and 24 hours; a zero-minute record must mark a completed occurrence.',
      );
    }
  }

  final String shiftItemId;
  final CivilDate occurrenceDate;
  final int minutes;
  final bool isCompleted;

  @override
  bool operator ==(Object other) =>
      other is WorkOvertimeAdjustment &&
      other.shiftItemId == shiftItemId &&
      other.occurrenceDate == occurrenceDate &&
      other.minutes == minutes &&
      other.isCompleted == isCompleted;

  @override
  int get hashCode =>
      Object.hash(shiftItemId, occurrenceDate, minutes, isCompleted);
}

/// Worked-time totals for a single shift occurrence.
class WorkHoursSummary {
  const WorkHoursSummary({
    required this.scheduledMinutes,
    required this.overtimeMinutes,
    required this.regularMinutes,
    required this.premiumEligibleMinutes,
  });

  static const standardShiftMinutes = 8 * 60;

  factory WorkHoursSummary.fromMinutes({
    required int scheduledMinutes,
    required int overtimeMinutes,
  }) {
    if (scheduledMinutes < 0 || overtimeMinutes < 0) {
      throw ArgumentError('Worked-time durations cannot be negative.');
    }
    final total = scheduledMinutes + overtimeMinutes;
    final regular = total < standardShiftMinutes ? total : standardShiftMinutes;
    return WorkHoursSummary(
      scheduledMinutes: scheduledMinutes,
      overtimeMinutes: overtimeMinutes,
      regularMinutes: regular,
      premiumEligibleMinutes: total - regular,
    );
  }

  factory WorkHoursSummary.forIntervals({
    required List<EventInterval> intervals,
    int overtimeMinutes = 0,
  }) => WorkHoursSummary.fromMinutes(
    scheduledMinutes: sumIntervalMinutes(intervals),
    overtimeMinutes: overtimeMinutes,
  );

  final int scheduledMinutes;
  final int overtimeMinutes;
  final int regularMinutes;
  final int premiumEligibleMinutes;

  int get totalMinutes => scheduledMinutes + overtimeMinutes;

  static int sumIntervalMinutes(List<EventInterval> intervals) =>
      intervals.fold(
        0,
        (total, interval) =>
            total +
            (interval.endDayOffset - interval.startDayOffset) * 1440 +
            interval.endMinute -
            interval.startMinute,
      );
}
