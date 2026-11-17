import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/ics_schedule_import.dart';
import 'package:shift_study/domain/schedule.dart';

void main() {
  const parser = IcsScheduleImportParser();
  const source = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Shift Study QA//EN
BEGIN:VEVENT
DTSTAMP:20261001T120000Z
UID:overnight@example.test
DTSTART:20261107T010000Z
DTEND:20261107T050000Z
SUMMARY:Night shift review
LOCATION:Gate 2
DESCRIPTION:Imported\\nfor review
END:VEVENT
BEGIN:VEVENT
DTSTAMP:20261001T120000Z
UID:all-day@example.test
DTSTART;VALUE=DATE:20261108
DTEND;VALUE=DATE:20261109
SUMMARY:Study day
END:VEVENT
BEGIN:VEVENT
DTSTAMP:20261001T120000Z
UID:weekly@example.test
DTSTART;TZID=America/Barbados:20261109T090000
DTEND;TZID=America/Barbados:20261109T100000
RRULE:FREQ=WEEKLY;BYDAY=MO
SUMMARY:Weekly class
END:VEVENT
END:VCALENDAR''';

  test(
    'imports a single timed event and preserves the review source',
    () async {
      final preview = await parser.parse(
        source,
        sourceName: 'schedule.ics',
        floatingTimeZoneId: 'America/Barbados',
        importedAt: DateTime.utc(2026, 11, 6),
      );
      final overnight = preview.proposals.first.item;
      expect(overnight.title, 'Night shift review');
      expect(overnight.location, 'Gate 2');
      expect(overnight.startDate.toString(), '2026-11-06');
      expect(overnight.intervals.single.startMinute, 21 * 60);
      expect(overnight.intervals.single.endDayOffset, 1);
      expect(overnight.intervals.single.endMinute, 1 * 60);
      expect(overnight.timeZoneId, 'America/Barbados');
      expect(overnight.kind, ScheduleKind.personal);
      expect(overnight.importProvenance!.uid, 'overnight@example.test');
      expect(overnight.importProvenance!.sourceName, 'schedule.ics');
      expect(
        overnight.importProvenance!.sourceText,
        contains('UID:overnight@example.test'),
      );
    },
  );

  test('unknown or conflicting work categories need manual review', () async {
    const categorized = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//StudyShift QA//EN
BEGIN:VEVENT
DTSTAMP:20261001T120000Z
UID:unknown-work@example.test
DTSTART:20261107T130000Z
DTEND:20261107T140000Z
SUMMARY:Unknown work category
CATEGORIES:WORK,FLIGHT DUTY
END:VEVENT
BEGIN:VEVENT
DTSTAMP:20261001T120000Z
UID:conflicting-work@example.test
DTSTART:20261108T130000Z
DTEND:20261108T140000Z
SUMMARY:Conflicting category
CATEGORIES:WORK,OVERTIME,SCHOOL
END:VEVENT
END:VCALENDAR''';
    final preview = await parser.parse(
      categorized,
      sourceName: 'categories.ics',
      floatingTimeZoneId: 'America/Barbados',
    );

    expect(preview.proposals, isEmpty);
    expect(preview.notices, hasLength(2));
    expect(preview.notices[0].message, contains('recognized work category'));
    expect(
      preview.notices[1].message,
      contains('conflicting schedule categories'),
    );
  });

  test('imports date-only records as personal all-day events', () async {
    final preview = await parser.parse(
      source,
      sourceName: 'schedule.ics',
      floatingTimeZoneId: 'America/Barbados',
    );
    final allDay = preview.proposals.singleWhere(
      (proposal) => proposal.item.title == 'Study day',
    );
    expect(allDay.item.allDay, isTrue);
    expect(allDay.item.hasNoTime, isTrue);
    expect(allDay.item.intervals, isEmpty);
  });

  test('imports a supported weekly class as a recurring schedule', () async {
    final preview = await parser.parse(
      source,
      sourceName: 'schedule.ics',
      floatingTimeZoneId: 'America/Barbados',
    );
    final weekly = preview.proposals
        .singleWhere((proposal) => proposal.item.title == 'Weekly class')
        .item;
    expect(weekly.startDate.toString(), '2026-11-09');
    expect(weekly.recurrence?.weekdays, {DateTime.monday});
    expect(weekly.recurrence?.until, isNull);
    expect(preview.notices, isEmpty);
  });

  test(
    'groups exported weekly split occurrences into one recurring shift',
    () async {
      const exportedSeries = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//StudyShift//Android//EN
BEGIN:VEVENT
DTSTAMP:20261115T120000Z
UID:qa-weekly-split-20261116-part-1@example.test
DTSTART;TZID=America/Barbados:20261116T090000
DTEND;TZID=America/Barbados:20261116T120000
SUMMARY:Synthetic ramp shift (Part 1)
DESCRIPTION:Expanded from a weekly series through 2027-11-15.
CATEGORIES:WORK,SHIFT
X-SHIFT-STUDY-ID:qa-weekly-split
X-SHIFT-STUDY-TZID:America/Barbados
END:VEVENT
BEGIN:VEVENT
DTSTAMP:20261115T120000Z
UID:qa-weekly-split-20261116-part-2@example.test
DTSTART;TZID=America/Barbados:20261116T140000
DTEND;TZID=America/Barbados:20261116T180000
SUMMARY:Synthetic ramp shift (Part 2)
DESCRIPTION:Expanded from a weekly series through 2027-11-15.
CATEGORIES:WORK,SHIFT
X-SHIFT-STUDY-ID:qa-weekly-split
X-SHIFT-STUDY-TZID:America/Barbados
END:VEVENT
BEGIN:VEVENT
DTSTAMP:20261115T120000Z
UID:qa-weekly-split-20261130-part-1@example.test
DTSTART;TZID=America/Barbados:20261130T090000
DTEND;TZID=America/Barbados:20261130T120000
SUMMARY:Synthetic ramp shift (Part 1)
DESCRIPTION:Expanded from a weekly series through 2027-11-15.
CATEGORIES:WORK,SHIFT
X-SHIFT-STUDY-ID:qa-weekly-split
X-SHIFT-STUDY-TZID:America/Barbados
END:VEVENT
BEGIN:VEVENT
DTSTAMP:20261115T120000Z
UID:qa-weekly-split-20261130-part-2@example.test
DTSTART;TZID=America/Barbados:20261130T140000
DTEND;TZID=America/Barbados:20261130T180000
SUMMARY:Synthetic ramp shift (Part 2)
DESCRIPTION:Expanded from a weekly series through 2027-11-15.
CATEGORIES:WORK,SHIFT
X-SHIFT-STUDY-ID:qa-weekly-split
X-SHIFT-STUDY-TZID:America/Barbados
END:VEVENT
END:VCALENDAR''';

      final preview = await parser.parse(
        exportedSeries,
        sourceName: 'studyshift-export.ics',
        floatingTimeZoneId: 'America/Barbados',
        importedAt: DateTime.utc(2026, 11, 15),
      );

      expect(preview.proposals, hasLength(1));
      final shift = preview.proposals.single.item;
      expect(shift.id, 'qa-weekly-split');
      expect(shift.title, 'Synthetic ramp shift');
      expect(shift.kind, ScheduleKind.work);
      expect(shift.workCategory, WorkCategory.shift);
      expect(shift.startDate, CivilDate(2026, 11, 16));
      expect(shift.timeZoneId, 'America/Barbados');
      expect(shift.intervals, [
        EventInterval.sameDay(startMinute: 9 * 60, endMinute: 12 * 60),
        EventInterval.sameDay(startMinute: 14 * 60, endMinute: 18 * 60),
      ]);
      expect(shift.recurrence?.weekdays, {DateTime.monday});
      expect(shift.recurrence?.until, CivilDate(2026, 11, 30));
      expect(shift.recurrence?.exceptionDates, {CivilDate(2026, 11, 23)});
      expect(preview.notices, isEmpty);
    },
  );

  test(
    'rejects self-exported actual finish metadata before scheduled end',
    () async {
      const invalidActualEnd = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//StudyShift//Android//EN
BEGIN:VEVENT
DTSTAMP:20261115T120000Z
UID:invalid-actual-end@example.test
DTSTART;TZID=America/Barbados:20261116T090000
DTEND;TZID=America/Barbados:20261116T170000
SUMMARY:Completed shift
CATEGORIES:WORK,SHIFT
X-SHIFT-STUDY-ID:invalid-actual-end
X-SHIFT-STUDY-EXPORT:2
X-SHIFT-STUDY-PART:1
X-SHIFT-STUDY-PARTS:1
X-SHIFT-STUDY-COMPLETED:1
X-SHIFT-STUDY-ACTUAL-END:0;480;-
X-SHIFT-STUDY-TZID:America/Barbados
END:VEVENT
END:VCALENDAR''';
      final preview = await parser.parse(
        invalidActualEnd,
        sourceName: 'invalid-actual-end.ics',
        floatingTimeZoneId: 'America/Barbados',
      );

      expect(preview.proposals, isEmpty);
      expect(preview.notices.single.message, contains('cannot shorten'));
    },
  );

  test(
    'keeps weekly COUNT and EXDATE boundaries in the recurring model',
    () async {
      const recurring = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Shift Study QA//EN
BEGIN:VEVENT
DTSTAMP:20261001T120000Z
UID:bounded-weekly@example.test
DTSTART;TZID=America/Barbados:20261109T090000
DTEND;TZID=America/Barbados:20261109T100000
RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=4
EXDATE;TZID=America/Barbados:20261116T090000
SUMMARY:Bounded weekly class
END:VEVENT
END:VCALENDAR''';
      final preview = await parser.parse(
        recurring,
        sourceName: 'weekly.ics',
        floatingTimeZoneId: 'America/Barbados',
      );
      final recurrence = preview.proposals.single.item.recurrence!;
      expect(recurrence.until.toString(), '2026-11-30');
      expect(recurrence.exceptionDates.map((date) => date.toString()), [
        '2026-11-16',
      ]);
      expect(preview.notices, isEmpty);
    },
  );

  test(
    'reports recurrence patterns the schedule model cannot preserve',
    () async {
      const unsupported = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Shift Study QA//EN
BEGIN:VEVENT
DTSTAMP:20261001T120000Z
UID:biweekly@example.test
DTSTART;TZID=America/Barbados:20261109T090000
DTEND;TZID=America/Barbados:20261109T100000
RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO
SUMMARY:Biweekly class
END:VEVENT
END:VCALENDAR''';
      final preview = await parser.parse(
        unsupported,
        sourceName: 'biweekly.ics',
        floatingTimeZoneId: 'America/Barbados',
      );
      expect(preview.proposals, isEmpty);
      expect(preview.notices.single.message, contains('Only weekly'));
    },
  );

  test(
    'does not extend a timed UNTIL past its exact local clock time',
    () async {
      const timedUntil = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Shift Study QA//EN
BEGIN:VEVENT
DTSTAMP:20261001T120000Z
UID:timed-until@example.test
DTSTART;TZID=America/Barbados:20261109T090000
DTEND;TZID=America/Barbados:20261109T100000
RRULE:FREQ=WEEKLY;BYDAY=MO;UNTIL=20261123T123000Z
SUMMARY:Timed until class
END:VEVENT
END:VCALENDAR''';
      final preview = await parser.parse(
        timedUntil,
        sourceName: 'timed-until.ics',
        floatingTimeZoneId: 'America/Barbados',
      );
      expect(
        preview.proposals.single.item.recurrence?.until,
        CivilDate(2026, 11, 22),
      );
      expect(preview.notices, isEmpty);
    },
  );

  test('skips every record for a UID with a recurrence exception', () async {
    const modifiedSeries = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Shift Study QA//EN
BEGIN:VEVENT
DTSTAMP:20261001T120000Z
UID:override@example.test
DTSTART;TZID=America/Barbados:20261109T090000
DTEND;TZID=America/Barbados:20261109T100000
RRULE:FREQ=WEEKLY;BYDAY=MO
SUMMARY:Weekly class
END:VEVENT
BEGIN:VEVENT
DTSTAMP:20261001T120000Z
UID:override@example.test
RECURRENCE-ID;TZID=America/Barbados:20261116T090000
DTSTART;TZID=America/Barbados:20261116T110000
DTEND;TZID=America/Barbados:20261116T120000
SUMMARY:Moved class
END:VEVENT
END:VCALENDAR''';
    final preview = await parser.parse(
      modifiedSeries,
      sourceName: 'override.ics',
      floatingTimeZoneId: 'America/Barbados',
    );
    expect(preview.proposals, isEmpty);
    expect(preview.notices, hasLength(1));
    expect(
      preview.notices.single.message,
      contains('multiple calendar records'),
    );
  });

  test(
    'rejects clock-change ambiguity instead of selecting one occurrence',
    () async {
      const ambiguous = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Shift Study QA//EN
BEGIN:VEVENT
DTSTAMP:20261001T120000Z
UID:fold@example.test
DTSTART;TZID=Europe/London:20261025T013000
DTEND;TZID=Europe/London:20261025T023000
SUMMARY:Repeated time
END:VEVENT
END:VCALENDAR''';
      final preview = await parser.parse(
        ambiguous,
        sourceName: 'fold.ics',
        floatingTimeZoneId: 'America/Barbados',
      );
      expect(preview.proposals, isEmpty);
      expect(preview.notices.single.message, contains('repeated clock time'));
    },
  );

  test(
    'rejects malformed calendars, unknown zones, and oversized input',
    () async {
      await expectLater(
        parser.parse(
          'this is not a calendar',
          sourceName: 'bad.ics',
          floatingTimeZoneId: 'America/Barbados',
        ),
        throwsFormatException,
      );
      await expectLater(
        parser.parse(
          source,
          sourceName: 'schedule.ics',
          floatingTimeZoneId: 'Mars/Olympus',
        ),
        throwsFormatException,
      );
      await expectLater(
        parser.parse(
          List.filled(IcsScheduleImportParser.maxBytes + 1, 'x').join(),
          sourceName: 'large.ics',
          floatingTimeZoneId: 'America/Barbados',
        ),
        throwsFormatException,
      );
    },
  );
}
