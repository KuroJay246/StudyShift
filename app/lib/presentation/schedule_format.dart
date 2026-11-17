import 'package:flutter/material.dart';

import '../data/preferences_repository.dart';
import '../domain/schedule.dart';

String formatMinute(int minute, {required bool use24Hour}) {
  final time = TimeOfDay(hour: (minute ~/ 60) % 24, minute: minute % 60);
  final hour = use24Hour
      ? time.hour.toString().padLeft(2, '0')
      : (time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod).toString();
  final minutes = time.minute.toString().padLeft(2, '0');
  return use24Hour
      ? '$hour:$minutes'
      : '$hour:$minutes ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
}

String formatInterval(
  EventInterval interval, {
  required bool use24Hour,
  bool includeEndDay = true,
}) {
  final start = formatMinute(interval.startMinute, use24Hour: use24Hour);
  final end = formatMinute(interval.endMinute, use24Hour: use24Hour);
  final daySuffix =
      includeEndDay && interval.endDayOffset > interval.startDayOffset
      ? ' +${interval.endDayOffset - interval.startDayOffset}d'
      : '';
  return '$start – $end$daySuffix';
}

bool preferenceUses24Hour(AppPreferences? preferences, BuildContext context) =>
    preferences?.use24HourTime ?? MediaQuery.alwaysUse24HourFormatOf(context);

String formatWeekRange(
  MaterialLocalizations localizations,
  CivilDate weekStart,
) {
  final weekEnd = weekStart.addDays(6);
  final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
  final end = DateTime(weekEnd.year, weekEnd.month, weekEnd.day);
  if (weekStart.year == weekEnd.year && weekStart.month == weekEnd.month) {
    return '${localizations.formatShortMonthDay(start)} – ${weekEnd.day}, ${weekEnd.year}';
  }
  if (weekStart.year == weekEnd.year) {
    return '${localizations.formatShortMonthDay(start)} – ${localizations.formatShortMonthDay(end)}, ${weekEnd.year}';
  }
  return '${localizations.formatShortDate(start)} – ${localizations.formatShortDate(end)}';
}

String scheduleKindName(ScheduleKind kind) => switch (kind) {
  ScheduleKind.work => 'Work',
  ScheduleKind.classSession => 'School',
  ScheduleKind.personal => 'Personal',
  ScheduleKind.deadline => 'Deadline',
};

String deadlineTypeName(DeadlineType type) => switch (type) {
  DeadlineType.assignment => 'Assignment',
  DeadlineType.examination => 'Examination',
};

/// Human-readable countdown for deadlines, calculated from local civil dates
/// so daylight-saving transitions cannot add or remove a displayed day.
String? deadlineCountdownLabel(ScheduleItem item, CivilDate today) {
  if (item.kind != ScheduleKind.deadline || item.isCompleted) return null;

  final date = item.startDate;
  final days = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  final isExam = item.deadlineType == DeadlineType.examination;
  final subject = isExam ? 'Exam' : 'Due';

  if (days == 0) return '$subject today';
  if (days == 1) return '$subject tomorrow';
  if (days > 1) return '$subject in $days days';
  if (isExam) {
    return days == -1
        ? 'Exam date passed yesterday'
        : 'Exam date passed ${days.abs()} days ago';
  }
  final overdueDays = days.abs();
  return 'Overdue by $overdueDays ${overdueDays == 1 ? 'day' : 'days'}';
}

String workCategoryName(WorkCategory category) => switch (category) {
  WorkCategory.shift => 'Shift',
  WorkCategory.training => 'Training',
  WorkCategory.restDay => 'Rest day',
  WorkCategory.leave => 'Leave',
  WorkCategory.dayOff => 'Day off',
  WorkCategory.overtime => 'Overtime',
};

String scheduleItemContextLabel(ScheduleItem item) => switch (item.kind) {
  ScheduleKind.work => workCategoryName(item.workCategory!),
  ScheduleKind.classSession => 'Class',
  ScheduleKind.personal => 'Personal',
  ScheduleKind.deadline => deadlineTypeName(item.deadlineType!),
};

IconData scheduleKindIcon(ScheduleKind kind) => switch (kind) {
  ScheduleKind.work => Icons.work_outline_rounded,
  ScheduleKind.classSession => Icons.school_outlined,
  ScheduleKind.personal => Icons.event_outlined,
  ScheduleKind.deadline => Icons.flag_outlined,
};

String scheduleKindIconAsset(ScheduleKind kind) => switch (kind) {
  ScheduleKind.work => 'briefcase-business',
  ScheduleKind.classSession => 'graduation-cap',
  ScheduleKind.personal => 'calendar-plus-2',
  ScheduleKind.deadline => 'calendar-check',
};
