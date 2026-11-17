import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/work_code_legend_repository.dart';
import 'package:shift_study/domain/work_code_legend.dart';

void main() {
  test('legend stores multiple time windows with overnight offsets', () async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = WorkCodeLegendRepository(database);
    const entry = WorkCodeLegend(
      id: 'synthetic-split-code',
      employer: 'Synthetic Airport Services',
      code: 'A1',
      assignmentDetails: 'Synthetic morning and afternoon duties',
      timeWindows: [
        WorkCodeTimeWindow(startMinute: 360, endMinute: 540),
        WorkCodeTimeWindow(startMinute: 720, endMinute: 960),
      ],
    );

    await repository.save(entry);

    final saved = (await repository.getItems()).single;
    expect(saved.timeWindows, entry.timeWindows);
    expect(saved.startMinute, isNull);
    expect(saved.endMinute, isNull);
  });

  test(
    'legend entries persist, update, delete, and allow employer-specific codes',
    () async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = WorkCodeLegendRepository(database);
      final first = WorkCodeLegend(
        id: 'synthetic-legend-1',
        employer: 'Synthetic Airport Services',
        code: 'RA',
        assignmentDetails: 'Synthetic arrivals and departures',
        startMinute: 360,
        endMinute: 840,
        flightIds: ['AA100', 'LI200'],
      );
      await repository.save(first);
      await repository.save(
        WorkCodeLegend(
          id: 'synthetic-legend-2',
          employer: 'Synthetic Airport Services',
          code: 'TR',
          assignmentDetails: 'Synthetic training assignment',
        ),
      );
      await repository.save(
        WorkCodeLegend(
          id: 'synthetic-legend-3',
          employer: 'Synthetic Cargo Group',
          code: 'RA',
          assignmentDetails: 'Synthetic alternate assignment',
        ),
      );

      await repository.save(
        first.copyWith(assignmentDetails: 'Updated synthetic assignment'),
      );
      final entries = await repository.getItems();
      expect(entries, hasLength(3));
      expect(
        entries.singleWhere((entry) => entry.id == first.id).assignmentDetails,
        'Updated synthetic assignment',
      );
      expect(
        entries.singleWhere((entry) => entry.id == first.id).startMinute,
        360,
      );
      expect(
        entries.singleWhere((entry) => entry.id == first.id).endMinute,
        840,
      );
      expect(entries.singleWhere((entry) => entry.id == first.id).flightIds, [
        'AA100',
        'LI200',
      ]);
      await repository.save(
        first.copyWith(flightIds: [' aa100 ', 'AA100', 'LI200']),
      );
      expect(
        (await repository.getItems())
            .singleWhere((entry) => entry.id == first.id)
            .flightIds,
        ['aa100', 'LI200'],
      );
      await expectLater(
        repository.save(
          WorkCodeLegend(
            id: 'synthetic-duplicate',
            employer: 'Synthetic Airport Services',
            code: 'ra',
            assignmentDetails: 'Duplicate code',
          ),
        ),
        throwsA(isA<FormatException>()),
      );

      await expectLater(
        repository.save(
          const WorkCodeLegend(
            id: 'synthetic-invalid-range',
            code: 'BAD',
            assignmentDetails: 'Synthetic assignment',
            startMinute: 360,
          ),
        ),
        throwsA(isA<FormatException>()),
      );

      await repository.delete(first.id);
      expect((await repository.getItems()).map((entry) => entry.id), {
        'synthetic-legend-2',
        'synthetic-legend-3',
      });
    },
  );
}
