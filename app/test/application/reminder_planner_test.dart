import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/schedule_engine.dart';
import 'package:shift_study/platform/local_reminders.dart';

void main() {
  const planner = ReminderPlanner(ScheduleEngine());

  test('plans a one-time reminder at the requested absolute offset', () {
    final item = ScheduleItem(
      id: 'qa-shift',
      kind: ScheduleKind.work,
      title: 'QA shift',
      startDate: CivilDate(2026, 11, 10),
      timeZoneId: 'America/Barbados',
      intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 720)],
      reminderMinutesBefore: 15,
    );

    final reminders = planner.plan([item], DateTime.utc(2026, 11, 10, 12));

    expect(reminders, hasLength(1));
    expect(
      reminders.single.triggerAt.toUtc(),
      DateTime.utc(2026, 11, 10, 13, 45),
    );
    expect(reminders.single.eventStart.toUtc(), DateTime.utc(2026, 11, 10, 14));
  });

  test('changing a reminder time creates a new notification identity', () {
    final original = ScheduleItem(
      id: 'qa-shift',
      kind: ScheduleKind.work,
      title: 'QA shift',
      startDate: CivilDate(2026, 11, 10),
      timeZoneId: 'America/Barbados',
      intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 720)],
      reminderMinutesBefore: 15,
    );
    final changed = ScheduleItem(
      id: original.id,
      kind: original.kind,
      title: original.title,
      startDate: original.startDate,
      timeZoneId: original.timeZoneId,
      intervals: [EventInterval.sameDay(startMinute: 630, endMinute: 750)],
      reminderMinutesBefore: original.reminderMinutesBefore,
    );

    final originalKey = planner
        .plan([original], DateTime.utc(2026, 11, 10, 12))
        .single
        .key;
    final changedKey = planner
        .plan([changed], DateTime.utc(2026, 11, 10, 12))
        .single
        .key;

    expect(originalKey, isNot(changedKey));
  });

  test('expands weekly recurrences and respects cancelled dates', () {
    final item = ScheduleItem(
      id: 'qa-class',
      kind: ScheduleKind.classSession,
      title: 'QA class',
      startDate: CivilDate(2026, 11, 6),
      timeZoneId: 'America/Barbados',
      intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
      recurrence: WeeklyRecurrence(
        weekdays: {DateTime.friday},
        until: CivilDate(2026, 11, 20),
        exceptionDates: {CivilDate(2026, 11, 13)},
      ),
      reminderMinutesBefore: 5,
    );

    final reminders = planner.plan([item], DateTime.utc(2026, 11, 6));

    expect(reminders.map((entry) => entry.occurrenceDate).toList(), [
      CivilDate(2026, 11, 6),
      CivilDate(2026, 11, 20),
    ]);
  });

  test(
    'does not guess missing zones or issue reminders for all-day records',
    () {
      final items = [
        ScheduleItem(
          id: 'qa-unknown-zone',
          kind: ScheduleKind.personal,
          title: 'Unknown zone',
          startDate: CivilDate(2026, 11, 10),
          intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
          reminderMinutesBefore: 5,
        ),
        ScheduleItem(
          id: 'qa-day-off',
          kind: ScheduleKind.work,
          title: 'Rest day',
          startDate: CivilDate(2026, 11, 10),
          intervals: const [],
          workCategory: WorkCategory.restDay,
        ),
      ];

      expect(planner.plan(items, DateTime.utc(2026, 11, 9)), isEmpty);
    },
  );
}
