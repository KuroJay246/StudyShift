import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/data/work_occurrence_coworker_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/work_occurrence_coworkers.dart';

void main() {
  test(
    'saves coworkers for one recurrence without changing the series',
    () async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final schedule = ScheduleRepository(database);
      final coworkers = WorkOccurrenceCoworkerRepository(database);
      final shift = _recurringShift();
      await schedule.save(shift);

      await schedule.updateCoworkersAtomically(
        const [],
        occurrenceUpdates: [
          WorkOccurrenceCoworkers(
            shiftItemId: shift.id,
            occurrenceDate: const CivilDate(2026, 11, 24),
            rosterCode: 'A1',
            employerName: 'Synthetic employer',
            coworkers: const ['Synthetic Sam', 'Synthetic Lee'],
          ),
        ],
      );

      final savedShift = (await schedule.getItems()).single;
      expect(savedShift.coworkers, isEmpty);
      expect(
        (await coworkers.getForOccurrence(
          shift.id,
          const CivilDate(2026, 11, 24),
        ))?.coworkers,
        ['Synthetic Sam', 'Synthetic Lee'],
      );
      expect(
        await coworkers.getForOccurrence(
          shift.id,
          const CivilDate(2026, 12, 1),
        ),
        isNull,
      );
    },
  );

  test('rejects cancelled occurrences and saves nothing', () async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final schedule = ScheduleRepository(database);
    final shift = _recurringShift(
      recurrence: WeeklyRecurrence(
        weekdays: {DateTime.tuesday},
        until: const CivilDate(2026, 12, 31),
        exceptionDates: {const CivilDate(2026, 11, 24)},
      ),
    );
    await schedule.save(shift);

    await expectLater(
      schedule.updateCoworkersAtomically(
        const [],
        occurrenceUpdates: [
          WorkOccurrenceCoworkers(
            shiftItemId: shift.id,
            occurrenceDate: const CivilDate(2026, 11, 24),
            rosterCode: 'A1',
            employerName: 'Synthetic employer',
            coworkers: const ['Synthetic Sam'],
          ),
        ],
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      await WorkOccurrenceCoworkerRepository(database)
          .getForOccurrence(shift.id, const CivilDate(2026, 11, 24)),
      isNull,
    );
  });
}

ScheduleItem _recurringShift({WeeklyRecurrence? recurrence}) => ScheduleItem(
  id: 'synthetic-weekly-shift',
  kind: ScheduleKind.work,
  workCategory: WorkCategory.shift,
  title: 'Synthetic weekly shift',
  startDate: const CivilDate(2026, 11, 17),
  intervals: const [
    EventInterval(
      startDayOffset: 0,
      startMinute: 600,
      endDayOffset: 0,
      endMinute: 1020,
    ),
  ],
  timeZoneId: 'America/Barbados',
  code: 'A1',
  employerName: 'Synthetic employer',
  recurrence:
      recurrence ??
      WeeklyRecurrence(
        weekdays: {DateTime.tuesday},
        until: const CivilDate(2026, 12, 31),
      ),
);
