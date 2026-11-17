import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/platform/local_reminders.dart';

void main() {
  group('ReminderDestination', () {
    test('parses the event identity and occurrence date from a reminder', () {
      final destination = ReminderDestination.parse(
        'shift-study-reminder:${Uri.encodeComponent('class-42|2026-11-16|1794852000000|15')}',
      );

      expect(destination?.itemId, 'class-42');
      expect(destination?.occurrenceDate, const CivilDate(2026, 11, 16));
    });

    test('ignores malformed or unrelated payloads', () {
      expect(ReminderDestination.parse(null), isNull);
      expect(ReminderDestination.parse('other-app:event'), isNull);
      expect(
        ReminderDestination.parse('shift-study-reminder:garbage'),
        isNull,
      );
      expect(
        ReminderDestination.parse(
          'shift-study-reminder:${Uri.encodeComponent('event|2026-02-30|1|5')}',
        ),
        isNull,
      );
    });

    test('resolves only a saved event occurrence and ignores deleted events', () {
      final item = _classItem();
      final destination = ReminderDestination(
        itemId: item.id,
        occurrenceDate: const CivilDate(2026, 11, 16),
      );

      expect(destination.resolve([item])?.item, same(item));
      expect(destination.resolve(const []), isNull);
    });

    test('does not resolve a recurrence on a skipped or non-class day', () {
      final item = _classItem(
        recurrence: WeeklyRecurrence(
          weekdays: const {DateTime.monday},
          until: const CivilDate(2026, 12, 31),
          exceptionDates: {const CivilDate(2026, 11, 16)},
        ),
      );

      expect(
        ReminderDestination(
          itemId: item.id,
          occurrenceDate: const CivilDate(2026, 11, 16),
        ).resolve([item]),
        isNull,
      );
      expect(
        ReminderDestination(
          itemId: item.id,
          occurrenceDate: const CivilDate(2026, 11, 17),
        ).resolve([item]),
        isNull,
      );
    });
  });
}

ScheduleItem _classItem({WeeklyRecurrence? recurrence}) => ScheduleItem(
  id: 'class-42',
  kind: ScheduleKind.classSession,
  title: 'Computing',
  startDate: const CivilDate(2026, 11, 16),
  intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
  timeZoneId: 'America/Barbados',
  reminderMinutesBefore: 15,
  recurrence: recurrence,
);
