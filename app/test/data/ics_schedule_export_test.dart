import 'dart:convert';

import 'package:firstfloor_calendar/firstfloor_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/ics_schedule_export.dart';
import 'package:shift_study/data/ics_schedule_import.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/schedule_engine.dart';

void main() {
  const exporter = IcsScheduleExport(ScheduleEngine());
  const parser = IcsScheduleImportParser();
  final now = DateTime.utc(2026, 11, 6, 12);

  test(
    'exports split, overnight, all-day and recurring schedule entries',
    () async {
      final items = [
        ScheduleItem(
          id: 'overnight',
          kind: ScheduleKind.work,
          title: 'Ramp; shift, A',
          startDate: CivilDate(2026, 11, 7),
          intervals: [
            EventInterval.overnight(startMinute: 22 * 60, endMinute: 6 * 60),
          ],
          timeZoneId: 'America/Halifax',
          location: 'Airport, north',
          workCategory: WorkCategory.shift,
          reportingInstruction: 'Synthetic report at service desk',
          code: 'QX',
          codeMeaning: 'Synthetic ramp duty',
          coworkers: const ['Synthetic teammate A', 'Synthetic teammate B'],
        ),
        ScheduleItem(
          id: 'split',
          kind: ScheduleKind.work,
          title: 'Split shift',
          startDate: CivilDate(2026, 11, 8),
          intervals: [
            EventInterval.sameDay(startMinute: 9 * 60, endMinute: 10 * 60),
            EventInterval.sameDay(startMinute: 14 * 60, endMinute: 15 * 60),
          ],
          timeZoneId: 'America/Barbados',
        ),
        ScheduleItem(
          id: 'rest',
          kind: ScheduleKind.work,
          title: 'Rest day',
          startDate: CivilDate(2026, 11, 5),
          intervals: const [],
          workCategory: WorkCategory.restDay,
        ),
        ScheduleItem(
          id: 'class-series',
          kind: ScheduleKind.classSession,
          title: 'Chemistry',
          startDate: CivilDate(2026, 11, 2),
          intervals: [
            EventInterval.sameDay(startMinute: 9 * 60, endMinute: 10 * 60),
          ],
          timeZoneId: 'America/Barbados',
          recurrence: WeeklyRecurrence(
            weekdays: {DateTime.monday},
            until: CivilDate(2026, 11, 16),
            exceptionDates: {CivilDate(2026, 11, 9)},
          ),
        ),
        ScheduleItem(
          id: 'overtime',
          kind: ScheduleKind.work,
          title: 'Overtime cover',
          startDate: CivilDate(2026, 11, 6),
          intervals: [
            EventInterval.sameDay(startMinute: 1080, endMinute: 1260),
          ],
          timeZoneId: 'America/Barbados',
          workCategory: WorkCategory.overtime,
        ),
      ];

      final bytes = exporter.encode(items, now: now);
      final ics = utf8.decode(bytes);
      final unfoldedIcs = ics.replaceAll('\r\n ', '');
      final parsed = CalendarParser().parseFromString(ics);
      expect(parsed.events, hasLength(6));
      expect(ics, contains('CATEGORIES:WORK,OVERTIME'));
      expect(ics, contains(r'SUMMARY:Ramp\; shift\, A'));
      expect(ics, contains(r'LOCATION:Airport\, north'));
      expect(
        unfoldedIcs,
        contains(r'Reporting instructions: Synthetic report at service desk'),
      );
      expect(
        unfoldedIcs,
        contains(r'Code assignment / flights: Synthetic ramp duty'),
      );
      expect(ics, contains('SUMMARY:Split shift'));
      expect(ics, isNot(contains('Part 1')));
      expect(ics, contains('RRULE:FREQ=WEEKLY;BYDAY=MO'));
      expect(ics, contains('EXDATE;TZID=America/Barbados:20261109T090000'));
      expect(ics, contains('DTSTART;VALUE=DATE:20261105'));
      expect(ics, contains('DTEND;VALUE=DATE:20261106'));
      expect(ics, contains('DTSTART;TZID=America/Halifax:20261107T220000'));
      expect(ics, isNot(contains('DTSTART;TZID=America/Barbados:20261109T')));

      final imported = await parser.parse(
        ics,
        sourceName: 'schedule.ics',
        floatingTimeZoneId: 'America/Barbados',
        importedAt: now,
      );
      expect(imported.proposals.first.item.coworkers, [
        'Synthetic teammate A',
        'Synthetic teammate B',
      ]);
      expect(imported.proposals, hasLength(5));
      final importedShift = imported.proposals.singleWhere(
        (entry) => entry.item.title == 'Ramp; shift, A',
      );
      expect(importedShift.item.kind, ScheduleKind.work);
      expect(importedShift.item.workCategory, WorkCategory.shift);
      final importedOvertime = imported.proposals.singleWhere(
        (entry) => entry.item.title == 'Overtime cover',
      );
      expect(importedOvertime.item.workCategory, WorkCategory.overtime);
      final importedRestDay = imported.proposals.singleWhere(
        (entry) => entry.item.title == 'Rest day',
      );
      expect(importedRestDay.item.workCategory, WorkCategory.restDay);
      final importedClass = imported.proposals.singleWhere(
        (entry) => entry.item.title == 'Chemistry',
      );
      expect(importedClass.item.kind, ScheduleKind.classSession);
      expect(importedClass.item.recurrence?.weekdays, {DateTime.monday});
      expect(importedClass.item.recurrence?.exceptionDates, {
        CivilDate(2026, 11, 9),
      });
      final importedSplit = imported.proposals.singleWhere(
        (entry) => entry.item.id == 'split',
      );
      expect(importedSplit.item.title, 'Split shift');
      expect(importedSplit.item.intervals, hasLength(2));
      expect(importedSplit.item.intervals[0].startMinute, 9 * 60);
      expect(importedSplit.item.intervals[1].startMinute, 14 * 60);
      expect(imported.proposals.first.item.timeZoneId, 'America/Halifax');
      expect(
        imported.proposals.map((entry) => entry.item.title),
        contains('Rest day'),
      );
      expect(
        imported.proposals.map((entry) => entry.item.title),
        contains('Split shift'),
      );
      expect(imported.notices, isEmpty);
      expect(imported.proposals.last.item.timeZoneId, 'America/Barbados');
    },
  );

  test('rejects timed legacy entries whose time zone needs review', () {
    final legacy = ScheduleItem(
      id: 'legacy',
      kind: ScheduleKind.work,
      title: 'Untimed-zone shift',
      startDate: CivilDate(2026, 11, 7),
      intervals: [
        EventInterval.sameDay(startMinute: 9 * 60, endMinute: 10 * 60),
      ],
    );

    expect(
      () => exporter.encode([legacy], now: now),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Untimed-zone shift'),
        ),
      ),
    );
  });

  test(
    'round trips completed overtime and split-shift actual intervals',
    () async {
      final overtime = ScheduleItem(
        id: 'completed-overtime',
        kind: ScheduleKind.work,
        title: 'Completed ramp shift',
        startDate: CivilDate(2026, 11, 7),
        intervals: [
          EventInterval.sameDay(startMinute: 9 * 60, endMinute: 17 * 60),
        ],
        timeZoneId: 'America/Barbados',
        workCategory: WorkCategory.shift,
        isCompleted: true,
        actualIntervals: [
          EventInterval.sameDay(startMinute: 9 * 60, endMinute: 19 * 60),
        ],
      );
      final split = ScheduleItem(
        id: 'completed-split',
        kind: ScheduleKind.work,
        title: 'Completed split shift',
        startDate: CivilDate(2026, 11, 8),
        intervals: [
          EventInterval.sameDay(startMinute: 9 * 60, endMinute: 12 * 60),
          EventInterval.sameDay(startMinute: 14 * 60, endMinute: 18 * 60),
        ],
        timeZoneId: 'America/Barbados',
        workCategory: WorkCategory.shift,
        isCompleted: true,
        actualIntervals: [
          EventInterval.sameDay(startMinute: 9 * 60, endMinute: 12 * 60),
          EventInterval.sameDay(startMinute: 14 * 60, endMinute: 20 * 60),
        ],
      );

      final ics = utf8.decode(exporter.encode([overtime, split], now: now));
      expect(ics, contains('DTEND;TZID=America/Barbados:20261107T170000'));
      expect(ics, contains('X-SHIFT-STUDY-COMPLETED:1'));
      expect(ics, contains('X-SHIFT-STUDY-ACTUAL-END:0;1140;-'));
      final preview = await parser.parse(
        ics,
        sourceName: 'completed-shifts.ics',
        floatingTimeZoneId: 'America/Barbados',
        importedAt: now,
      );

      expect(preview.notices, isEmpty);
      final importedOvertime = preview.proposals
          .singleWhere((proposal) => proposal.item.id == overtime.id)
          .item;
      expect(importedOvertime.intervals, overtime.intervals);
      expect(importedOvertime.isCompleted, isTrue);
      expect(importedOvertime.actualIntervals, overtime.actualIntervals);
      final importedSplit = preview.proposals
          .singleWhere((proposal) => proposal.item.id == split.id)
          .item;
      expect(importedSplit.intervals, split.intervals);
      expect(importedSplit.isCompleted, isTrue);
      expect(importedSplit.actualIntervals, split.actualIntervals);
    },
  );
}
