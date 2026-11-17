import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/schedule_engine.dart';

void main() {
  const engine = ScheduleEngine();
  final monday = CivilDate(2026, 11, 2);

  group('schedule invariants', () {
    test(
      'civil date arithmetic advances across daylight saving boundaries',
      () {
        const beforeFallback = CivilDate(2026, 10, 31);
        const fallbackDay = CivilDate(2026, 11, 1);
        const afterFallback = CivilDate(2026, 11, 2);
        expect(beforeFallback.addDays(1), fallbackDay);
        expect(fallbackDay.addDays(1), afterFallback);
        expect(afterFallback.weekday, DateTime.monday);

        final weekly = ScheduleItem(
          id: 'dst-week',
          kind: ScheduleKind.classSession,
          title: 'Synthetic weekly class',
          startDate: beforeFallback,
          intervals: [
            EventInterval.sameDay(startMinute: 9 * 60, endMinute: 10 * 60),
          ],
          recurrence: WeeklyRecurrence(
            weekdays: {DateTime.sunday, DateTime.monday, DateTime.tuesday},
            until: CivilDate(2026, 11, 3),
          ),
        );
        expect(
          engine
              .expand([weekly], beforeFallback, CivilDate(2026, 11, 3))
              .map((occurrence) => occurrence.date),
          [fallbackDay, afterFallback, CivilDate(2026, 11, 3)],
        );
      },
    );

    test('overnight shift keeps the following civil end date', () {
      final overnight = ScheduleItem(
        id: 'night',
        kind: ScheduleKind.work,
        title: 'Ramp duty',
        startDate: monday,
        intervals: [
          EventInterval.overnight(startMinute: 22 * 60 + 30, endMinute: 6 * 60),
        ],
      );
      final occurrence = engine.expand([overnight], monday, monday).single;
      expect(occurrence.intervals.single.start, DateTime(2026, 11, 2, 22, 30));
      expect(occurrence.intervals.single.end, DateTime(2026, 11, 3, 6));
    });

    test('split shift intervals remain distinct and validate separately', () {
      final split = ScheduleItem(
        id: 'split',
        kind: ScheduleKind.work,
        title: 'Split duty',
        startDate: monday,
        intervals: [
          EventInterval.sameDay(startMinute: 8 * 60, endMinute: 12 * 60),
          EventInterval.sameDay(startMinute: 16 * 60, endMinute: 20 * 60),
        ],
      );
      expect(
        engine.expand([split], monday, monday).single.intervals,
        hasLength(2),
      );
      expect(
        () => ScheduleItem(
          id: 'bad',
          kind: ScheduleKind.work,
          title: 'Bad',
          startDate: monday,
          intervals: [
            EventInterval.sameDay(startMinute: 8 * 60, endMinute: 13 * 60),
            EventInterval.sameDay(startMinute: 12 * 60, endMinute: 14 * 60),
          ],
        ),
        throwsArgumentError,
      );
    });

    test(
      'weekly classes appear on selected weekdays through inclusive term end',
      () {
        final classItem = ScheduleItem(
          id: 'math',
          kind: ScheduleKind.classSession,
          title: 'MATH 101',
          startDate: monday,
          intervals: [
            EventInterval.sameDay(startMinute: 9 * 60, endMinute: 10 * 60),
          ],
          recurrence: WeeklyRecurrence(
            weekdays: {DateTime.monday, DateTime.wednesday},
            until: CivilDate(2026, 11, 8),
          ),
        );
        final dates = engine
            .expand([classItem], monday, CivilDate(2026, 11, 8))
            .map((e) => e.date)
            .toList();
        expect(dates, [CivilDate(2026, 11, 2), CivilDate(2026, 11, 4)]);
      },
    );

    test('weekly recurrence skips only its explicitly excepted civil date', () {
      final cancelledWednesday = CivilDate(2026, 11, 4);
      final classItem = ScheduleItem(
        id: 'excepted-class',
        kind: ScheduleKind.classSession,
        title: 'Synthetic lecture',
        startDate: monday,
        intervals: [
          EventInterval.sameDay(startMinute: 9 * 60, endMinute: 10 * 60),
        ],
        recurrence: WeeklyRecurrence(
          weekdays: {DateTime.monday, DateTime.wednesday},
          until: CivilDate(2026, 11, 11),
          exceptionDates: {cancelledWednesday},
        ),
      );

      expect(
        engine
            .expand([classItem], monday, CivilDate(2026, 11, 11))
            .map((occurrence) => occurrence.date),
        [monday, CivilDate(2026, 11, 9), CivilDate(2026, 11, 11)],
      );
    });

    test('recurrence exceptions must target a scheduled day in the term', () {
      expect(
        () => ScheduleItem(
          id: 'invalid-exception',
          kind: ScheduleKind.classSession,
          title: 'Synthetic lecture',
          startDate: monday,
          intervals: [
            EventInterval.sameDay(startMinute: 9 * 60, endMinute: 10 * 60),
          ],
          recurrence: WeeklyRecurrence(
            weekdays: {DateTime.monday},
            until: CivilDate(2026, 11, 30),
            exceptionDates: {CivilDate(2026, 11, 4)},
          ),
        ),
        throwsArgumentError,
      );
    });

    test('overlapping work and class occurrences are reported', () {
      final shift = ScheduleItem(
        id: 'work',
        kind: ScheduleKind.work,
        title: 'Shift',
        startDate: monday,
        intervals: [
          EventInterval.sameDay(startMinute: 8 * 60, endMinute: 12 * 60),
        ],
      );
      final lecture = ScheduleItem(
        id: 'school',
        kind: ScheduleKind.classSession,
        title: 'Lecture',
        startDate: monday,
        intervals: [
          EventInterval.sameDay(startMinute: 11 * 60, endMinute: 13 * 60),
        ],
      );
      expect(
        engine.conflicts(engine.expand([shift, lecture], monday, monday)),
        hasLength(1),
      );
    });

    test('conflicts compare explicit IANA zones as absolute instants', () {
      final day = CivilDate(2026, 11, 2);
      final barbados = ScheduleItem(
        id: 'barbados-shift',
        kind: ScheduleKind.work,
        title: 'Synthetic shift',
        startDate: day,
        timeZoneId: 'America/Barbados',
        intervals: [
          EventInterval.sameDay(startMinute: 8 * 60, endMinute: 9 * 60),
        ],
      );
      final newYork = ScheduleItem(
        id: 'new-york-class',
        kind: ScheduleKind.classSession,
        title: 'Synthetic class',
        startDate: day,
        timeZoneId: 'America/New_York',
        intervals: [
          EventInterval.sameDay(
            startMinute: 7 * 60 + 30,
            endMinute: 8 * 60 + 30,
          ),
        ],
      );

      final analysis = engine.analyze(
        engine.expand([barbados, newYork], day, day),
      );
      expect(analysis.conflicts, hasLength(1));
      expect(analysis.timeIssues, isEmpty);
    });

    test('folds require an explicit choice and gaps are reported', () {
      final foldDate = CivilDate(2026, 11, 1);
      ScheduleItem foldItem(CivilTimeFoldChoice? choice) => ScheduleItem(
        id: 'fold',
        kind: ScheduleKind.classSession,
        title: 'Synthetic repeated-hour class',
        startDate: foldDate,
        timeZoneId: 'America/New_York',
        intervals: [
          EventInterval(
            startDayOffset: 0,
            startMinute: 90,
            endDayOffset: 0,
            endMinute: 150,
            startFoldChoice: choice,
          ),
        ],
      );

      final unresolved = engine.resolveOccurrence(
        EventOccurrence(item: foldItem(null), date: foldDate),
      );
      expect(unresolved.intervals, isEmpty);
      expect(
        unresolved.issues.single.kind,
        ScheduleTimeIssueKind.ambiguousStart,
      );

      final chosen = engine.resolveOccurrence(
        EventOccurrence(
          item: foldItem(CivilTimeFoldChoice.earlier),
          date: foldDate,
        ),
      );
      expect(chosen.issues, isEmpty);
      expect(
        chosen.intervals.single.end.difference(chosen.intervals.single.start),
        const Duration(hours: 2),
      );

      final gapDate = CivilDate(2026, 3, 8);
      final gap = ScheduleItem(
        id: 'gap',
        kind: ScheduleKind.classSession,
        title: 'Synthetic nonexistent-hour class',
        startDate: gapDate,
        timeZoneId: 'America/New_York',
        intervals: [EventInterval.sameDay(startMinute: 150, endMinute: 210)],
      );
      final gapResult = engine.resolveOccurrence(
        EventOccurrence(item: gap, date: gapDate),
      );
      expect(gapResult.intervals, isEmpty);
      expect(
        gapResult.issues.single.kind,
        ScheduleTimeIssueKind.nonexistentStart,
      );
    });

    test('legacy entries without a saved zone are flagged for review', () {
      final day = CivilDate(2026, 11, 5);
      final legacy = ScheduleItem(
        id: 'legacy-zone-entry',
        kind: ScheduleKind.work,
        title: 'Legacy split shift',
        startDate: day,
        intervals: [
          EventInterval.sameDay(startMinute: 8 * 60, endMinute: 10 * 60),
          EventInterval.sameDay(startMinute: 14 * 60, endMinute: 18 * 60),
        ],
      );

      final result = engine.resolveOccurrence(
        EventOccurrence(item: legacy, date: day),
      );

      expect(result.intervals, hasLength(2));
      expect(result.issues.map((issue) => issue.kind), [
        ScheduleTimeIssueKind.missingTimeZone,
        ScheduleTimeIssueKind.missingTimeZone,
      ]);
    });

    test('civil dates reject invalid calendar days', () {
      expect(CivilDate(2026, 2, 29).isValid, isFalse);
      expect(CivilDate(2028, 2, 29).isValid, isTrue);
      expect(
        () => engine.expand(
          const <ScheduleItem>[],
          CivilDate(2026, 2, 30),
          CivilDate(2026, 3, 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => ScheduleItem(
          id: 'invalid-term-end',
          kind: ScheduleKind.classSession,
          title: 'Class',
          startDate: monday,
          intervals: [
            EventInterval.sameDay(startMinute: 9 * 60, endMinute: 10 * 60),
          ],
          recurrence: WeeklyRecurrence(
            weekdays: {DateTime.monday},
            until: CivilDate(2026, 2, 30),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('a provided schedule time zone cannot be blank', () {
      expect(
        () => ScheduleItem(
          id: 'bad-zone',
          kind: ScheduleKind.work,
          title: 'Shift',
          startDate: monday,
          timeZoneId: '  ',
          intervals: [
            EventInterval.sameDay(startMinute: 7 * 60, endMinute: 15 * 60),
          ],
        ),
        throwsArgumentError,
      );
    });

    test(
      'recurrence bounds and clearing optional fields validate explicitly',
      () {
        expect(
          () => ScheduleItem(
            id: 'invalid-repeat',
            kind: ScheduleKind.classSession,
            title: 'Class',
            startDate: monday,
            intervals: [
              EventInterval.sameDay(startMinute: 9 * 60, endMinute: 10 * 60),
            ],
            recurrence: WeeklyRecurrence(
              weekdays: {DateTime.monday},
              until: CivilDate(2026, 11, 1),
            ),
          ),
          throwsArgumentError,
        );
        final item = ScheduleItem(
          id: 'entry',
          kind: ScheduleKind.work,
          title: 'Shift',
          startDate: monday,
          intervals: [
            EventInterval.sameDay(startMinute: 7 * 60, endMinute: 15 * 60),
          ],
          code: 'RMP',
          location: 'Gate 2',
          notes: 'Reminder',
        );
        final cleared = item.copyWith(code: null, location: null, notes: null);
        expect(cleared.code, isNull);
        expect(cleared.location, isNull);
        expect(cleared.notes, isNull);
      },
    );
  });
}
