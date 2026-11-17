import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/schedule_queries.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/schedule_engine.dart';

void main() {
  const queries = ScheduleQueries(ScheduleEngine());
  final monday = CivilDate(2026, 11, 2);

  test('Today includes an overnight event that began on the previous date', () {
    final overnight = ScheduleItem(
      id: 'overnight',
      kind: ScheduleKind.work,
      title: 'Ramp shift',
      startDate: monday.addDays(-1),
      intervals: [
        EventInterval.overnight(startMinute: 22 * 60, endMinute: 6 * 60),
      ],
    );
    final today = queries.forDay([overnight], monday);
    expect(today, hasLength(1));
    expect(today.single.date, monday.addDays(-1));
    expect(today.single.intervals.single.end, DateTime(2026, 11, 2, 6));
  });

  test('Today and Week expose the same occurrence for the same date', () {
    final classEntry = ScheduleItem(
      id: 'class',
      kind: ScheduleKind.classSession,
      title: 'COMP 1010',
      startDate: monday,
      intervals: [
        EventInterval.sameDay(startMinute: 9 * 60, endMinute: 10 * 60),
      ],
      recurrence: WeeklyRecurrence(
        weekdays: {DateTime.monday, DateTime.wednesday},
        until: CivilDate(2026, 12, 1),
      ),
    );
    final today = queries.forDay([classEntry], monday);
    final week = queries.forWeek([classEntry], monday);
    expect(
      today.map((event) => (event.item.id, event.date)),
      containsAll(
        week
            .where((event) => event.date == monday)
            .map((event) => (event.item.id, event.date)),
      ),
    );
    expect(week.map((event) => event.date).toSet(), {
      monday,
      monday.addDays(2),
    });
  });

  test('next upcoming selects the earliest future split interval and ignores past events', () {
    final shift = ScheduleItem(
      id: 'split',
      kind: ScheduleKind.work,
      title: 'Split shift',
      startDate: monday,
      intervals: [
        EventInterval.sameDay(startMinute: 8 * 60, endMinute: 10 * 60),
        EventInterval.sameDay(startMinute: 16 * 60, endMinute: 18 * 60),
      ],
    );
    final next = queries.nextUpcoming([shift], DateTime(2026, 11, 2, 12));
    expect(next!.interval.start, DateTime(2026, 11, 2, 16));
  });

  test('current event is available while its interval is in progress', () {
    final shift = ScheduleItem(
      id: 'active-shift',
      kind: ScheduleKind.work,
      title: 'Synthetic active shift',
      startDate: monday,
      timeZoneId: 'America/Barbados',
      intervals: [
        EventInterval.sameDay(startMinute: 9 * 60, endMinute: 17 * 60),
      ],
    );

    final current = queries.currentlyHappening([
      shift,
    ], DateTime(2026, 11, 2, 12));

    expect(current?.occurrence.item.id, 'active-shift');
    expect(current?.interval.start, DateTime(2026, 11, 2, 9));
    expect(current?.interval.end, DateTime(2026, 11, 2, 17));
  });

  test('next upcoming compares entries by their stored IANA zones', () {
    final day = CivilDate(2026, 11, 2);
    final shift = ScheduleItem(
      id: 'barbados-shift',
      kind: ScheduleKind.work,
      title: 'Synthetic shift',
      startDate: day,
      timeZoneId: 'America/Barbados',
      intervals: [
        EventInterval.sameDay(startMinute: 8 * 60, endMinute: 9 * 60),
      ],
    );
    final lecture = ScheduleItem(
      id: 'new-york-class',
      kind: ScheduleKind.classSession,
      title: 'Synthetic class',
      startDate: day,
      timeZoneId: 'America/New_York',
      intervals: [
        EventInterval.sameDay(startMinute: 7 * 60 + 30, endMinute: 8 * 60 + 30),
      ],
    );
    final queries = ScheduleQueries(const ScheduleEngine());

    final next = queries.nextUpcoming([
      shift,
      lecture,
    ], DateTime.utc(2026, 11, 2, 12, 15));

    expect(next?.occurrence.item.id, 'new-york-class');
    expect(next?.interval.start.toUtc(), DateTime.utc(2026, 11, 2, 12, 30));
  });

  test('range analysis exposes unresolved DST wall times to the caller', () {
    final day = CivilDate(2026, 11, 1);
    final recurringClass = ScheduleItem(
      id: 'ambiguous-class',
      kind: ScheduleKind.classSession,
      title: 'Synthetic repeated-hour class',
      startDate: day,
      timeZoneId: 'America/New_York',
      intervals: [EventInterval.sameDay(startMinute: 90, endMinute: 150)],
    );
    final analysis = ScheduleQueries(const ScheduleEngine())
        .analyzeRange([recurringClass], day, day);

    expect(analysis.timeIssues, hasLength(1));
    expect(
      analysis.timeIssues.single.kind,
      ScheduleTimeIssueKind.ambiguousStart,
    );
  });
}
