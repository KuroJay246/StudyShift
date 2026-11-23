import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/data/work_overtime_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/work_overtime.dart';

void main() {
  late ScheduleDatabase database;
  late ScheduleRepository scheduleRepository;
  late WorkOvertimeRepository overtimeRepository;

  setUp(() {
    database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    scheduleRepository = ScheduleRepository(database);
    overtimeRepository = WorkOvertimeRepository(database);
  });

  tearDown(() async => database.close());

  test('stores one overtime total for a specific shift occurrence', () async {
    final shift = ScheduleItem(
      id: 'shift-overtime-test',
      kind: ScheduleKind.work,
      title: 'Synthetic shift',
      startDate: CivilDate(2026, 11, 22),
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 900)],
      recurrence: WeeklyRecurrence(
        weekdays: {DateTime.sunday},
        until: CivilDate(2026, 12, 6),
      ),
    );
    await scheduleRepository.save(shift);

    await overtimeRepository.setForOccurrence(
      shift,
      CivilDate(2026, 11, 29),
      90,
    );

    expect(
      await overtimeRepository.getForOccurrence(
        shift.id,
        CivilDate(2026, 11, 29),
      ),
      WorkOvertimeAdjustment(
        shiftItemId: shift.id,
        occurrenceDate: CivilDate(2026, 11, 29),
        minutes: 90,
      ),
    );
    expect(
      await overtimeRepository.getForOccurrence(
        shift.id,
        CivilDate(2026, 12, 6),
      ),
      isNull,
    );
  });

  test('completes only the selected recurring shift occurrence', () async {
    final shift = ScheduleItem(
      id: 'shift-overtime-occurrence-completion-test',
      kind: ScheduleKind.work,
      title: 'Synthetic recurring shift',
      startDate: CivilDate(2026, 11, 22),
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 900)],
      recurrence: WeeklyRecurrence(
        weekdays: {DateTime.sunday},
        until: CivilDate(2026, 12, 6),
      ),
    );
    await scheduleRepository.save(shift);

    await overtimeRepository.completeOccurrence(
      shift,
      CivilDate(2026, 11, 29),
      overtimeMinutes: 0,
    );

    final savedSeries = (await scheduleRepository.getItems()).single;
    expect(savedSeries.isCompleted, isFalse);
    final completedOccurrence = await overtimeRepository.getForOccurrence(
      shift.id,
      CivilDate(2026, 11, 29),
    );
    expect(completedOccurrence?.minutes, 0);
    expect(completedOccurrence?.isCompleted, isTrue);
    expect(
      await overtimeRepository.getForOccurrence(
        shift.id,
        CivilDate(2026, 12, 6),
      ),
      isNull,
    );
  });

  test('clearing overtime on a completed occurrence keeps its completion', () async {
    final shift = ScheduleItem(
      id: 'shift-overtime-clear-completion-test',
      kind: ScheduleKind.work,
      title: 'Synthetic recurring shift',
      startDate: CivilDate(2026, 11, 22),
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 900)],
      recurrence: WeeklyRecurrence(
        weekdays: {DateTime.sunday},
        until: CivilDate(2026, 12, 6),
      ),
    );
    await scheduleRepository.save(shift);
    await overtimeRepository.completeOccurrence(
      shift,
      CivilDate(2026, 11, 29),
      overtimeMinutes: 90,
    );

    await overtimeRepository.clearForOccurrence(
      shift.id,
      CivilDate(2026, 11, 29),
    );

    final record = await overtimeRepository.getForOccurrence(
      shift.id,
      CivilDate(2026, 11, 29),
    );
    expect(record?.minutes, 0);
    expect(record?.isCompleted, isTrue);
  });

  test(
    'rejects dates that are not occurrences of the selected shift',
    () async {
      final shift = ScheduleItem(
        id: 'shift-overtime-date-test',
        kind: ScheduleKind.work,
        title: 'Synthetic shift',
        startDate: CivilDate(2026, 11, 22),
        intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 900)],
      );
      await scheduleRepository.save(shift);

      await expectLater(
        overtimeRepository.setForOccurrence(shift, CivilDate(2026, 11, 23), 60),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('deleting a shift cascades its overtime record', () async {
    final shift = ScheduleItem(
      id: 'shift-overtime-cascade-test',
      kind: ScheduleKind.work,
      title: 'Synthetic shift',
      startDate: CivilDate(2026, 11, 22),
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 900)],
    );
    await scheduleRepository.save(shift);
    await overtimeRepository.setForOccurrence(shift, shift.startDate, 60);

    await scheduleRepository.delete(shift.id);

    expect(await overtimeRepository.getAll(), isEmpty);
  });

  test(
    'restore merges without overwriting and replace installs the backup',
    () async {
      final shift = ScheduleItem(
        id: 'shift-overtime-restore-test',
        kind: ScheduleKind.work,
        title: 'Synthetic shift',
        startDate: CivilDate(2026, 11, 22),
        intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 900)],
      );
      await scheduleRepository.save(shift);
      final backupEntry = WorkOvertimeAdjustment(
        shiftItemId: shift.id,
        occurrenceDate: shift.startDate,
        minutes: 90,
      );
      await overtimeRepository.setForOccurrence(shift, shift.startDate, 30);

      await overtimeRepository.restoreItems([
        backupEntry,
      ], replaceExisting: false);
      expect((await overtimeRepository.getAll()).single.minutes, 30);

      await overtimeRepository.restoreItems([
        backupEntry,
      ], replaceExisting: true);
      expect((await overtimeRepository.getAll()).single.minutes, 90);
    },
  );
}
