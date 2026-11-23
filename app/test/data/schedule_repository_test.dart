import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/data/schedule_import_history_repository.dart';
import 'package:shift_study/domain/schedule.dart';

void main() {
  test(
    'import provenance persists and matching event replacement is explicit',
    () async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = ScheduleRepository(database);
      final existing = ScheduleItem(
        id: 'ics-stable-event',
        kind: ScheduleKind.personal,
        title: 'Existing calendar entry',
        startDate: CivilDate(2026, 11, 6),
        intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 600)],
      );
      await repository.save(existing);

      final imported = ScheduleItem(
        id: existing.id,
        kind: ScheduleKind.personal,
        title: 'Reviewed calendar entry',
        startDate: CivilDate(2026, 11, 7),
        intervals: const [],
        allDay: true,
        importProvenance: ScheduleImportProvenance(
          format: 'iCalendar 2.0',
          uid: 'event@example.test',
          sourceName: 'reviewed.ics',
          sourceText:
              'BEGIN:VEVENT\\r\\nUID:event@example.test\\r\\nEND:VEVENT',
          importedAt: DateTime.utc(2026, 11, 6),
        ),
      );

      final skipped = await repository.importItems([
        imported,
      ], replaceExisting: false);
      expect(skipped.skipped, 1);
      expect(
        (await repository.getItems()).single.title,
        'Existing calendar entry',
      );

      final replaced = await repository.importItems([
        imported,
      ], replaceExisting: true);
      expect(replaced.replaced, 1);
      final saved = (await repository.getItems()).single;
      expect(saved.title, 'Reviewed calendar entry');
      expect(saved.allDay, isTrue);
      expect(saved.importProvenance!.uid, 'event@example.test');
      expect(saved.importProvenance!.sourceName, 'reviewed.ics');
      expect(
        saved.importProvenance!.sourceText,
        imported.importProvenance!.sourceText,
      );

      await expectLater(
        repository.importItems([existing], replaceExisting: true),
        throwsA(isA<FormatException>()),
      );
    },
  );

  late ScheduleDatabase db;
  late ScheduleRepository repository;

  setUp(() {
    db = ScheduleDatabase.forTesting(NativeDatabase.memory());
    repository = ScheduleRepository(db);
  });

  tearDown(() async => db.close());

  test(
    'bulk interval lookup returns each event intervals in stable order',
    () async {
      await db.saveItem(
        ScheduleRowsCompanion.insert(
          id: 'bulk-a',
          kind: ScheduleKind.work.index,
          title: 'Synthetic shift A',
          startDate: '2026-11-13',
        ),
        [
          IntervalRowsCompanion.insert(
            itemId: 'bulk-a',
            startDayOffset: 0,
            startMinute: 780,
            endDayOffset: 0,
            endMinute: 960,
          ),
          IntervalRowsCompanion.insert(
            itemId: 'bulk-a',
            startDayOffset: 0,
            startMinute: 360,
            endDayOffset: 0,
            endMinute: 540,
          ),
        ],
      );
      await db.saveItem(
        ScheduleRowsCompanion.insert(
          id: 'bulk-b',
          kind: ScheduleKind.classSession.index,
          title: 'Synthetic class B',
          startDate: '2026-11-14',
        ),
        [
          IntervalRowsCompanion.insert(
            itemId: 'bulk-b',
            startDayOffset: 0,
            startMinute: 600,
            endDayOffset: 0,
            endMinute: 660,
          ),
        ],
      );

      final intervals = await db.getIntervalsForItems(['bulk-b', 'bulk-a']);

      expect(intervals.keys, containsAll(['bulk-a', 'bulk-b']));
      expect(intervals['bulk-a']!.map((interval) => interval.startMinute), [
        360,
        780,
      ]);
      expect(intervals['bulk-b']!.single.startMinute, 600);
      expect(await db.getIntervalsForItems([]), isEmpty);
    },
  );

  test(
    'shift wrap-up stores actual intervals while preserving roster times',
    () async {
      final planned = ScheduleItem(
        id: 'synthetic-overtime-wrap-up',
        kind: ScheduleKind.work,
        workCategory: WorkCategory.overtime,
        title: 'Synthetic overtime duty',
        startDate: CivilDate(2026, 11, 13),
        intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 1020)],
        isCompleted: true,
        actualIntervals: [
          EventInterval.sameDay(startMinute: 540, endMinute: 1140),
        ],
      );
      await repository.save(planned);

      final restored = (await repository.getItems()).single;
      expect(restored.intervals.single.endMinute, 1020);
      expect(restored.actualIntervals?.single.endMinute, 1140);
      expect(restored.isCompleted, isTrue);
    },
  );

  test('reminder choice persists across repository reload', () async {
    final item = ScheduleItem(
      id: 'qa-reminder',
      kind: ScheduleKind.classSession,
      title: 'QA reminder class',
      startDate: CivilDate(2026, 11, 9),
      timeZoneId: 'America/Barbados',
      intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
      reminderMinutesBefore: 15,
    );

    await repository.save(item);

    expect((await repository.getItems()).single.reminderMinutesBefore, 15);
  });

  test('failed import rolls back both event and history writes', () async {
    final item = ScheduleItem(
      id: 'synthetic-invalid-term-import',
      kind: ScheduleKind.classSession,
      title: 'Synthetic class outside missing term',
      startDate: CivilDate(2026, 11, 9),
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 600)],
      academicTermId: 'missing-term',
      importProvenance: ScheduleImportProvenance(
        format: 'CSV',
        uid: 'synthetic-row-1',
        sourceName: 'synthetic.csv',
        sourceText: 'synthetic test input',
        importedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    final history = ScheduleImportHistoryDraft(
      sourceType: ScheduleImportSourceType.csv,
      parserVersion: '1',
      proposedCount: 1,
      rejectedCount: 0,
      skippedCount: 0,
      warningsCount: 0,
      importedAt: DateTime.utc(2026, 11, 1),
    );

    await expectLater(
      repository.importItems(
        [item],
        replaceExisting: false,
        historyDraft: history,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(await repository.getItems(), isEmpty);
    expect(await ScheduleImportHistoryRepository(db).getEntries(), isEmpty);
  });

  test('overtime category and timed interval persist locally', () async {
    final item = ScheduleItem(
      id: 'overtime-duty',
      kind: ScheduleKind.work,
      title: 'Synthetic overtime cover',
      startDate: CivilDate(2026, 11, 9),
      timeZoneId: 'America/Barbados',
      intervals: [EventInterval.sameDay(startMinute: 1080, endMinute: 1260)],
      workCategory: WorkCategory.overtime,
      code: 'OT',
    );

    await repository.save(item);

    final saved = (await repository.getItems()).single;
    expect(saved.workCategory, WorkCategory.overtime);
    expect(saved.intervals, item.intervals);
    expect(saved.code, 'OT');
  });

  test(
    'create, edit and delete preserve complete split/recurrence data',
    () async {
      final original = ScheduleItem(
        id: 'course-1',
        kind: ScheduleKind.classSession,
        title: 'COMP 1010',
        startDate: CivilDate(2026, 11, 2),
        intervals: [
          EventInterval.sameDay(startMinute: 10 * 60, endMinute: 11 * 60),
        ],
        location: 'Lecture Room A',
        recurrence: WeeklyRecurrence(
          weekdays: {DateTime.monday, DateTime.wednesday},
          until: CivilDate(2026, 12, 10),
          exceptionDates: {CivilDate(2026, 11, 4)},
        ),
      );
      await repository.save(original);
      expect((await repository.getItems()).single, isA<ScheduleItem>());
      final saved = (await repository.getItems()).single;
      expect(saved.title, 'COMP 1010');
      expect(saved.recurrence!.weekdays, {DateTime.monday, DateTime.wednesday});
      expect(saved.recurrence!.until, CivilDate(2026, 12, 10));
      expect(saved.recurrence!.exceptionDates, {CivilDate(2026, 11, 4)});

      await repository.save(
        ScheduleItem(
          id: original.id,
          kind: original.kind,
          title: 'COMP 1010 tutorial',
          startDate: original.startDate,
          intervals: [
            EventInterval.sameDay(startMinute: 12 * 60, endMinute: 13 * 60),
          ],
          location: 'Lab 2',
        ),
      );
      final updated = (await repository.getItems()).single;
      expect(updated.title, 'COMP 1010 tutorial');
      expect(updated.intervals.single.startMinute, 12 * 60);
      expect(updated.recurrence, isNull);

      await repository.delete(original.id);
      expect(await repository.getItems(), isEmpty);
    },
  );

  test('work shift with separate intervals round trips unchanged', () async {
    final shift = ScheduleItem(
      id: 'shift-1',
      kind: ScheduleKind.work,
      title: 'Split duty',
      startDate: CivilDate(2026, 11, 2),
      intervals: [
        EventInterval.sameDay(startMinute: 7 * 60, endMinute: 11 * 60),
        EventInterval.sameDay(startMinute: 15 * 60, endMinute: 19 * 60),
      ],
      code: 'RMP',
      codeMeaning: 'Synthetic ramp duty',
      coworkers: const ['Synthetic teammate A', 'Synthetic teammate B'],
      notes: 'Synthetic example',
      reportingInstruction: 'Synthetic reporting point: north gate',
    );
    await repository.save(shift);
    final result = (await repository.getItems()).single;
    expect(result.intervals, shift.intervals);
    expect(result.code, 'RMP');
    expect(result.codeMeaning, 'Synthetic ramp duty');
    expect(result.coworkers, ['Synthetic teammate A', 'Synthetic teammate B']);
    expect(result.notes, 'Synthetic example');
    expect(
      result.reportingInstruction,
      'Synthetic reporting point: north gate',
    );
    await repository.save(
      result.copyWith(coworkers: const ['Synthetic teammate C']),
    );
    expect((await repository.getItems()).single.coworkers, [
      'Synthetic teammate C',
    ]);
  });

  test(
    'work contacts persist locally and survive ordinary event edits',
    () async {
      final item = ScheduleItem(
        id: 'contacted-shift',
        kind: ScheduleKind.work,
        title: 'Synthetic covered shift',
        startDate: CivilDate(2026, 11, 14),
        intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 1020)],
        employerName: 'Synthetic Airport Services',
        departmentName: 'Synthetic ramp operations',
        jobRole: 'Ramp agent',
        supervisorName: 'Synthetic supervisor',
        supervisorPhone: '+1 246 555 0100',
        contactName: 'Synthetic operations desk',
        contactPhone: '+1 246 555 0101',
      );
      await repository.save(item);

      final loaded = (await repository.getItems()).single;
      expect(loaded.supervisorName, 'Synthetic supervisor');
      expect(loaded.employerName, 'Synthetic Airport Services');
      expect(loaded.departmentName, 'Synthetic ramp operations');
      expect(loaded.jobRole, 'Ramp agent');
      expect(loaded.supervisorPhone, '+1 246 555 0100');
      expect(loaded.contactName, 'Synthetic operations desk');
      expect(loaded.contactPhone, '+1 246 555 0101');

      await repository.save(loaded.copyWith(title: 'Edited synthetic shift'));
      final edited = (await repository.getItems()).single;
      expect(edited.title, 'Edited synthetic shift');
      expect(edited.supervisorName, 'Synthetic supervisor');
      expect(edited.employerName, 'Synthetic Airport Services');
      expect(edited.departmentName, 'Synthetic ramp operations');
      expect(edited.jobRole, 'Ramp agent');
      expect(edited.supervisorPhone, '+1 246 555 0100');
      expect(edited.contactName, 'Synthetic operations desk');
      expect(edited.contactPhone, '+1 246 555 0101');
    },
  );

  test(
    'training and leave categories persist with the right time model',
    () async {
      final training = ScheduleItem(
        id: 'training-category',
        kind: ScheduleKind.work,
        workCategory: WorkCategory.training,
        title: 'Safety training',
        startDate: CivilDate(2026, 11, 3),
        timeZoneId: 'America/Barbados',
        intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 720)],
      );
      final leave = ScheduleItem(
        id: 'leave-category',
        kind: ScheduleKind.work,
        workCategory: WorkCategory.leave,
        title: 'Annual leave',
        startDate: CivilDate(2026, 11, 4),
        timeZoneId: 'America/Barbados',
        intervals: const [],
      );
      await repository.save(training);
      await repository.save(leave);

      final restored = {
        for (final item in await repository.getItems()) item.id: item,
      };
      expect(restored[training.id]!.workCategory, WorkCategory.training);
      expect(restored[training.id]!.hasNoTime, isFalse);
      expect(restored[training.id]!.intervals, training.intervals);
      expect(restored[leave.id]!.workCategory, WorkCategory.leave);
      expect(restored[leave.id]!.hasNoTime, isTrue);
      expect(restored[leave.id]!.intervals, isEmpty);
    },
  );

  test(
    'assignments and examinations persist with their intended time models',
    () async {
      final assignment = ScheduleItem(
        id: 'school-assignment',
        kind: ScheduleKind.deadline,
        deadlineType: DeadlineType.assignment,
        title: 'Synthetic chemistry assignment',
        startDate: CivilDate(2026, 11, 13),
        timeZoneId: 'America/Barbados',
        intervals: const [],
        code: 'CHEM1100',
        isCompleted: true,
      );
      final examination = ScheduleItem(
        id: 'school-exam',
        kind: ScheduleKind.deadline,
        deadlineType: DeadlineType.examination,
        title: 'Synthetic chemistry exam',
        startDate: CivilDate(2026, 11, 20),
        timeZoneId: 'America/Barbados',
        intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 720)],
        code: 'CHEM1100',
      );
      await repository.save(assignment);
      await repository.save(examination);

      final restored = {
        for (final item in await repository.getItems()) item.id: item,
      };
      expect(restored[assignment.id]!.deadlineType, DeadlineType.assignment);
      expect(restored[assignment.id]!.hasNoTime, isTrue);
      expect(restored[assignment.id]!.isCompleted, isTrue);
      expect(restored[assignment.id]!.intervals, isEmpty);
      expect(restored[examination.id]!.deadlineType, DeadlineType.examination);
      expect(restored[examination.id]!.hasNoTime, isFalse);
      expect(restored[examination.id]!.intervals, examination.intervals);
      expect(restored[examination.id]!.code, 'CHEM1100');
      expect(restored[examination.id]!.isCompleted, isFalse);
    },
  );

  test(
    'file-backed SQLite data survives closing and reopening the database',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'shift-study-reopen-',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final file = File(
        '${directory.path}${Platform.pathSeparator}schedule.sqlite',
      );
      final firstDatabase = ScheduleDatabase.forTesting(NativeDatabase(file));
      final item = ScheduleItem(
        id: 'reopen-shift',
        kind: ScheduleKind.work,
        title: 'Synthetic overnight split shift',
        startDate: CivilDate(2026, 11, 2),
        timeZoneId: 'America/Barbados',
        intervals: [
          EventInterval.sameDay(startMinute: 8 * 60, endMinute: 12 * 60),
          EventInterval(
            startDayOffset: 0,
            startMinute: 22 * 60,
            endDayOffset: 1,
            endMinute: 1 * 60,
            startFoldChoice: CivilTimeFoldChoice.earlier,
          ),
        ],
        notes: 'Synthetic persistence check',
      );
      try {
        await ScheduleRepository(firstDatabase).save(item);
      } finally {
        await firstDatabase.close();
      }

      final reopenedDatabase = ScheduleDatabase.forTesting(
        NativeDatabase(file),
      );
      try {
        final restored = (await ScheduleRepository(
          reopenedDatabase,
        ).getItems()).single;
        expect(restored.id, item.id);
        expect(restored.title, item.title);
        expect(restored.startDate, item.startDate);
        expect(restored.timeZoneId, item.timeZoneId);
        expect(restored.intervals, item.intervals);
        expect(restored.notes, item.notes);
      } finally {
        await reopenedDatabase.close();
      }
    },
  );

  test(
    'an explicitly selected IANA time zone survives edits and reloads',
    () async {
      final item = ScheduleItem(
        id: 'barbados-class',
        kind: ScheduleKind.classSession,
        title: 'Synthetic lecture',
        startDate: CivilDate(2026, 11, 2),
        timeZoneId: 'America/Barbados',
        intervals: [
          EventInterval(
            startDayOffset: 0,
            startMinute: 90,
            endDayOffset: 0,
            endMinute: 150,
            startFoldChoice: CivilTimeFoldChoice.later,
          ),
        ],
      );

      await repository.save(item);
      final edited = item.copyWith(title: 'Synthetic edited lecture');
      await repository.save(edited);

      final restored = (await repository.getItems()).single;
      expect(restored.title, 'Synthetic edited lecture');
      expect(restored.timeZoneId, 'America/Barbados');
      expect(
        restored.intervals.single.startFoldChoice,
        CivilTimeFoldChoice.later,
      );
    },
  );
}
