import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/csv_schedule_import.dart';
import 'package:shift_study/data/coworker_roster_matcher.dart';
import 'package:shift_study/domain/schedule.dart';

void main() {
  const matcher = CoworkerRosterMatcher();
  final assignment = CoworkerRosterAssignment(
    date: const CivilDate(2026, 11, 24),
    code: 'A1',
    coworkers: const ['Synthetic Sam', 'Synthetic Lee'],
    sourceRows: const [2],
  );

  test('updates coworkers on a unique date and code match only', () {
    final existing = _shift(
      id: 'saved-shift',
      title: 'Saved ramp shift',
      coworkers: const ['Synthetic Sam'],
    );

    final result = matcher.match(assignment, [existing]);

    expect(result.status, CoworkerRosterMatchStatus.matched);
    expect(result.existingShift?.id, 'saved-shift');
    expect(result.updatedCoworkers, ['Synthetic Sam', 'Synthetic Lee']);
    expect(result.updatedShift?.title, existing.title);
    expect(result.updatedShift?.intervals, existing.intervals);
    expect(result.updatedShift?.startDate, existing.startDate);
    expect(existing.coworkers, ['Synthetic Sam']);
  });

  test('does not create a shift when no saved date and code match exists', () {
    final result = matcher.match(assignment, const []);

    expect(result.status, CoworkerRosterMatchStatus.unmatched);
    expect(result.updatedShift, isNull);
  });

  test('marks repeated matching shifts ambiguous without changing either', () {
    final result = matcher.match(assignment, [
      _shift(id: 'first', title: 'First shift'),
      _shift(id: 'second', title: 'Second shift'),
    ]);

    expect(result.status, CoworkerRosterMatchStatus.ambiguous);
    expect(result.existingShift, isNull);
    expect(result.updatedShift, isNull);
  });
}

ScheduleItem _shift({
  required String id,
  required String title,
  List<String> coworkers = const [],
}) => ScheduleItem(
  id: id,
  kind: ScheduleKind.work,
  title: title,
  startDate: const CivilDate(2026, 11, 24),
  intervals: const [
    EventInterval(
      startDayOffset: 0,
      startMinute: 9 * 60,
      endDayOffset: 0,
      endMinute: 17 * 60,
    ),
  ],
  timeZoneId: 'America/Barbados',
  code: 'A1',
  employerName: 'Synthetic employer',
  coworkers: coworkers,
  workCategory: WorkCategory.shift,
);
