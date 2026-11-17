import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/academic_term_repository.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/data/work_code_legend_repository.dart';
import 'package:shift_study/domain/academic_term.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/work_code_legend.dart';

void main() {
  late ScheduleDatabase database;
  late AcademicTermRepository terms;
  late ScheduleRepository schedules;
  late WorkCodeLegendRepository legends;

  setUp(() {
    database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    terms = AcademicTermRepository(database);
    schedules = ScheduleRepository(database);
    legends = WorkCodeLegendRepository(database);
  });

  tearDown(() => database.close());

  test(
    'term records persist, sort, and reject duplicate institution/name pairs',
    () async {
      final later = AcademicTerm(
        id: 'term-later',
        institution: 'Example University',
        name: 'Semester Two',
        startDate: CivilDate(2027, 1, 10),
        endDate: CivilDate(2027, 5, 1),
      );
      final earlier = AcademicTerm(
        id: 'term-earlier',
        institution: 'Example University',
        name: 'Semester One',
        startDate: CivilDate(2026, 9, 1),
        endDate: CivilDate(2026, 12, 15),
      );
      await terms.save(later);
      await terms.save(earlier);

      expect((await terms.getItems()).map((term) => term.id), [
        'term-earlier',
        'term-later',
      ]);
      await expectLater(
        terms.save(
          AcademicTerm(
            id: 'term-duplicate',
            institution: 'example university',
            name: 'semester one',
            startDate: CivilDate(2026, 9, 1),
            endDate: CivilDate(2026, 12, 15),
          ),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'linked study event retains its term, and deleting a term preserves event',
    () async {
      final term = AcademicTerm(
        id: 'term-1',
        institution: 'Example University',
        name: 'Semester One',
        startDate: CivilDate(2026, 9, 1),
        endDate: CivilDate(2026, 12, 15),
      );
      await terms.save(term);
      final item = ScheduleItem(
        id: 'class-1',
        kind: ScheduleKind.classSession,
        title: 'Foundations of Computing',
        academicTermId: term.id,
        startDate: CivilDate(2026, 9, 2),
        intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
        recurrence: WeeklyRecurrence(
          weekdays: {DateTime.wednesday},
          until: term.endDate,
        ),
      );
      await schedules.save(item);
      expect((await schedules.getItems()).single.academicTermId, term.id);

      await terms.delete(term.id);
      final retained = (await schedules.getItems()).single;
      expect(retained.id, item.id);
      expect(retained.academicTermId, isNull);
    },
  );

  test(
    'linked class recurrence cannot continue past its academic term',
    () async {
      final term = AcademicTerm(
        id: 'term-1',
        institution: 'Example University',
        name: 'Semester One',
        startDate: CivilDate(2026, 9, 1),
        endDate: CivilDate(2026, 12, 15),
      );
      await terms.save(term);
      final item = ScheduleItem(
        id: 'class-1',
        kind: ScheduleKind.classSession,
        title: 'Foundations of Computing',
        academicTermId: term.id,
        startDate: CivilDate(2026, 9, 2),
        intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
        recurrence: WeeklyRecurrence(
          weekdays: {DateTime.wednesday},
          until: CivilDate(2026, 12, 20),
        ),
      );

      await expectLater(schedules.save(item), throwsFormatException);
    },
  );

  test(
    'term date edits cannot strand linked classes outside the term',
    () async {
      final term = AcademicTerm(
        id: 'term-1',
        institution: 'Example University',
        name: 'Semester One',
        startDate: CivilDate(2026, 9, 1),
        endDate: CivilDate(2026, 12, 15),
      );
      await terms.save(term);
      await schedules.save(
        ScheduleItem(
          id: 'class-1',
          kind: ScheduleKind.classSession,
          title: 'Synthetic class',
          academicTermId: term.id,
          startDate: CivilDate(2026, 9, 2),
          intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
          recurrence: WeeklyRecurrence(
            weekdays: {DateTime.wednesday},
            until: term.endDate,
          ),
        ),
      );

      await expectLater(
        terms.save(
          AcademicTerm(
            id: term.id,
            institution: term.institution,
            name: term.name,
            startDate: term.startDate,
            endDate: CivilDate(2026, 12, 10),
          ),
        ),
        throwsFormatException,
      );
      expect((await terms.getById(term.id))!.endDate, term.endDate);
    },
  );

  test(
    'merge remaps a colliding term ID instead of linking to the wrong term',
    () async {
      await terms.save(
        AcademicTerm(
          id: 'term-collision',
          institution: 'Local University',
          name: 'Semester One',
          startDate: CivilDate(2026, 9, 1),
          endDate: CivilDate(2026, 12, 15),
        ),
      );
      final incoming = AcademicTerm(
        id: 'term-collision',
        institution: 'Other University',
        name: 'Autumn Term',
        startDate: CivilDate(2026, 9, 1),
        endDate: CivilDate(2026, 12, 20),
      );

      final mapping = await terms.restoreItems([
        incoming,
      ], replaceExisting: false);
      final restoredId = mapping[incoming.id]!;
      expect(restoredId, isNot(incoming.id));
      expect(
        (await terms.getById(incoming.id))!.institution,
        'Local University',
      );
      expect(
        (await terms.getById(restoredId))!.institution,
        'Other University',
      );
    },
  );

  test(
    'outer backup transaction rolls terms back if linked events fail',
    () async {
      final term = AcademicTerm(
        id: 'incoming-term',
        institution: 'Example University',
        name: 'Semester One',
        startDate: CivilDate(2026, 9, 1),
        endDate: CivilDate(2026, 12, 15),
      );
      await expectLater(
        database.transaction(() async {
          await terms.restoreItems([term], replaceExisting: true);
          await schedules.restoreItems([
            ScheduleItem(
              id: 'invalid-class',
              kind: ScheduleKind.classSession,
              title: 'Synthetic invalid class',
              academicTermId: term.id,
              startDate: CivilDate(2027, 1, 3),
              intervals: [
                EventInterval.sameDay(startMinute: 600, endMinute: 660),
              ],
              recurrence: WeeklyRecurrence(
                weekdays: {DateTime.sunday},
                until: CivilDate(2027, 1, 10),
              ),
            ),
          ], replaceExisting: true);
        }),
        throwsFormatException,
      );
      expect(await terms.getItems(), isEmpty);
      expect(await schedules.getItems(), isEmpty);
    },
  );

  test(
    'outer backup transaction restores prior data if roster-code validation fails',
    () async {
      final existingTerm = AcademicTerm(
        id: 'existing-term',
        institution: 'Local University',
        name: 'Current semester',
        startDate: CivilDate(2026, 9, 1),
        endDate: CivilDate(2026, 12, 15),
      );
      await terms.save(existingTerm);
      await schedules.save(
        ScheduleItem(
          id: 'existing-class',
          kind: ScheduleKind.classSession,
          title: 'Keep existing class',
          academicTermId: existingTerm.id,
          startDate: CivilDate(2026, 9, 2),
          intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
        ),
      );
      const existingLegend = WorkCodeLegend(
        id: 'existing-legend',
        employer: 'Local employer',
        code: 'EX',
        assignmentDetails: 'Existing assignment',
      );
      await legends.save(existingLegend);

      final incomingTerm = AcademicTerm(
        id: 'incoming-term',
        institution: 'Other University',
        name: 'Incoming semester',
        startDate: CivilDate(2026, 9, 1),
        endDate: CivilDate(2026, 12, 15),
      );
      await expectLater(
        database.transaction(() async {
          final idMap = await terms.restoreItems(
            [incomingTerm],
            replaceExisting: true,
          );
          await schedules.restoreItems(
            [
              ScheduleItem(
                id: 'incoming-class',
                kind: ScheduleKind.classSession,
                title: 'Incoming class',
                academicTermId: idMap[incomingTerm.id],
                startDate: CivilDate(2026, 9, 2),
                intervals: [
                  EventInterval.sameDay(startMinute: 600, endMinute: 660),
                ],
              ),
            ],
            replaceExisting: true,
          );
          await legends.restoreItems(
            const [
              WorkCodeLegend(
                id: 'duplicate-a',
                employer: 'Incoming employer',
                code: 'QA',
                assignmentDetails: 'Synthetic assignment A',
              ),
              WorkCodeLegend(
                id: 'duplicate-b',
                employer: 'Incoming employer',
                code: 'QA',
                assignmentDetails: 'Synthetic assignment B',
              ),
            ],
            replaceExisting: true,
          );
        }),
        throwsFormatException,
      );

      expect((await terms.getItems()).map((term) => term.id), [existingTerm.id]);
      expect(
        (await schedules.getItems()).map((item) => item.title),
        ['Keep existing class'],
      );
      expect((await legends.getItems()).map((entry) => entry.id), [
        existingLegend.id,
      ]);
    },
  );
}
