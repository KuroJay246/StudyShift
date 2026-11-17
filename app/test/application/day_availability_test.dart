import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/day_availability.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/schedule_engine.dart';

void main() {
  const availability = DayAvailability(ScheduleEngine());
  final day = CivilDate(2026, 11, 5);

  test('returns remaining local gaps around resolved schedule events', () {
    final occurrences = [
      EventOccurrence(
        item: ScheduleItem(
          id: 'synthetic-one',
          kind: ScheduleKind.work,
          title: 'Synthetic shift',
          startDate: day,
          timeZoneId: 'America/Barbados',
          intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 600)],
        ),
        date: day,
      ),
      EventOccurrence(
        item: ScheduleItem(
          id: 'synthetic-two',
          kind: ScheduleKind.classSession,
          title: 'Synthetic lecture',
          startDate: day,
          timeZoneId: 'America/Barbados',
          intervals: [EventInterval.sameDay(startMinute: 660, endMinute: 720)],
        ),
        date: day,
      ),
    ];

    final periods = availability.calculate(
      occurrences: occurrences,
      date: day,
      deviceTimeZoneId: 'America/Barbados',
      now: DateTime.utc(2026, 11, 5, 12), // 08:00 in Barbados.
    );

    expect(periods, hasLength(3));
    expect(periods!.first.start.hour, 8);
    expect(periods.first.end.hour, 9);
    expect(periods[1].start.hour, 10);
    expect(periods[1].end.hour, 11);
    expect(periods.last.start.hour, 12);
    expect(periods.last.end.hour, 0);
  });

  test('omits availability when an event time cannot be resolved', () {
    final occurrence = EventOccurrence(
      item: ScheduleItem(
        id: 'synthetic-gap',
        kind: ScheduleKind.classSession,
        title: 'Synthetic DST class',
        startDate: CivilDate(2026, 3, 8),
        timeZoneId: 'America/New_York',
        intervals: [EventInterval.sameDay(startMinute: 150, endMinute: 210)],
      ),
      date: CivilDate(2026, 3, 8),
    );

    expect(
      availability.calculate(
        occurrences: [occurrence],
        date: CivilDate(2026, 3, 8),
        deviceTimeZoneId: 'America/Barbados',
        now: DateTime.utc(2026, 3, 8, 12),
      ),
      isNull,
    );
  });

  test(
    'converts schedule instants into the device zone before finding gaps',
    () {
      final summerDay = CivilDate(2026, 7, 2);
      final occurrence = EventOccurrence(
        item: ScheduleItem(
          id: 'synthetic-cross-zone-shift',
          kind: ScheduleKind.work,
          title: 'Synthetic Barbados shift',
          startDate: summerDay,
          timeZoneId: 'America/Barbados',
          intervals: [
            EventInterval.sameDay(startMinute: 1320, endMinute: 1380),
          ],
        ),
        date: summerDay,
      );

      final periods = availability.calculate(
        occurrences: [occurrence],
        date: summerDay,
        deviceTimeZoneId: 'America/Halifax',
        now: DateTime.utc(2026, 7, 2, 23), // 20:00 in Halifax.
      );

      expect(periods, hasLength(1));
      expect(periods!.single.start.hour, 20);
      expect(periods.single.end.hour, 23);
    },
  );
}
