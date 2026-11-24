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
    required this.standardDayMinutes,
  });

  factory WorkHoursSummary.fromMinutes({
    required int scheduledMinutes,
    required int overtimeMinutes,
    int? standardDayMinutes,
  }) {
    if (scheduledMinutes < 0 ||
        overtimeMinutes < 0 ||
        (standardDayMinutes != null &&
            (standardDayMinutes <= 0 || standardDayMinutes > 24 * 60))) {
      throw ArgumentError('Work durations and daily thresholds are invalid.');
    }
    final total = scheduledMinutes + overtimeMinutes;
    final regular = standardDayMinutes == null
        ? total
        : total < standardDayMinutes
        ? total
        : standardDayMinutes;
    return WorkHoursSummary(
      scheduledMinutes: scheduledMinutes,
      overtimeMinutes: overtimeMinutes,
      regularMinutes: regular,
      premiumEligibleMinutes: total - regular,
      standardDayMinutes: standardDayMinutes,
    );
  }

  factory WorkHoursSummary.forIntervals({
    required List<EventInterval> intervals,
    int overtimeMinutes = 0,
    int? standardDayMinutes,
  }) => WorkHoursSummary.fromMinutes(
    scheduledMinutes: sumIntervalMinutes(intervals),
    overtimeMinutes: overtimeMinutes,
    standardDayMinutes: standardDayMinutes,
  );

  final int scheduledMinutes;
  final int overtimeMinutes;
  final int regularMinutes;
  final int premiumEligibleMinutes;
  final int? standardDayMinutes;

  int get standardRateTopUpMinutes {
    final threshold = standardDayMinutes;
    if (threshold == null || scheduledMinutes >= threshold) return 0;
    final remaining = threshold - scheduledMinutes;
    return overtimeMinutes < remaining ? overtimeMinutes : remaining;
  }

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
