import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/work_code_references.dart';
import 'package:shift_study/domain/schedule.dart';

void main() {
  test('groups one code across roster dates and preserves split patterns', () {
    final shift = ScheduleItem(
      id: 'shift-one',
      kind: ScheduleKind.work,
      title: 'Synthetic ramp shift',
      startDate: CivilDate(2026, 11, 15),
      intervals: [
        EventInterval.sameDay(startMinute: 360, endMinute: 540),
        EventInterval.sameDay(startMinute: 600, endMinute: 840),
      ],
      code: 'A1',
      codeMeaning: 'Synthetic arrivals',
      workCategory: WorkCategory.shift,
    );
    final duplicate = shift.copyWith(title: 'Another matching shift');
    final secondPattern = ScheduleItem(
      id: 'shift-two',
      kind: ScheduleKind.work,
      title: 'Synthetic ramp shift',
      startDate: CivilDate(2026, 11, 20),
      intervals: [EventInterval.sameDay(startMinute: 720, endMinute: 960)],
      code: 'A1',
      codeMeaning: 'Synthetic departure block',
      workCategory: WorkCategory.shift,
    );
    final classSession = ScheduleItem(
      id: 'class-one',
      kind: ScheduleKind.classSession,
      title: 'Synthetic course',
      startDate: CivilDate(2026, 11, 15),
      intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
      code: 'A1',
    );

    final observed = observedWorkCodeReferences([
      shift,
      duplicate,
      secondPattern,
      classSession,
    ]);

    expect(observed, hasLength(1));
    expect(observed.single.code, 'A1');
    expect(observed.single.assignmentDetails, [
      'Synthetic arrivals',
      'Synthetic departure block',
    ]);
    expect(observed.single.patterns, hasLength(2));
    expect(observed.single.patterns.first.intervals, hasLength(2));
    expect(observed.single.patterns.first.intervals[0].startMinute, 360);
    expect(observed.single.patterns.first.intervals[1].startMinute, 600);
    expect(observed.single.patterns.last.intervals.single.startMinute, 720);
    expect(observed.single.rosterDates, [
      CivilDate(2026, 11, 15),
      CivilDate(2026, 11, 20),
    ]);
  });

  test('keeps matching codes separate when employers differ', () {
    final items = [
      ScheduleItem(
        id: 'employer-a-a1',
        kind: ScheduleKind.work,
        title: 'Synthetic employer A shift',
        startDate: CivilDate(2026, 11, 15),
        employerName: 'Employer A',
        intervals: [EventInterval.sameDay(startMinute: 360, endMinute: 540)],
        code: 'A1',
        codeMeaning: 'Synthetic arrivals',
      ),
      ScheduleItem(
        id: 'employer-b-a1',
        kind: ScheduleKind.work,
        title: 'Synthetic employer B shift',
        startDate: CivilDate(2026, 11, 16),
        employerName: 'Employer B',
        intervals: [EventInterval.sameDay(startMinute: 720, endMinute: 960)],
        code: 'A1',
        codeMeaning: 'Synthetic departures',
      ),
    ];

    final observed = observedWorkCodeReferences(items);

    expect(observed, hasLength(2));
    expect(observed.map((reference) => reference.assignmentDetails), [
      ['Synthetic arrivals'],
      ['Synthetic departures'],
    ]);
  });
}
