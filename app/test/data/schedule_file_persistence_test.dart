import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/domain/schedule.dart';

void main() {
  test('synthetic entries survive database close and reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'shift-study-db-test-',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}schedule.sqlite',
    );
    final expected = ScheduleItem(
      id: 'persisted',
      kind: ScheduleKind.work,
      title: 'Synthetic shift',
      startDate: CivilDate(2026, 11, 2),
      intervals: [
        EventInterval.overnight(startMinute: 22 * 60, endMinute: 6 * 60),
      ],
      code: 'QX',
      codeMeaning: 'Synthetic training duty',
      reportingInstruction: 'Synthetic report at north gate',
    );
    var database = ScheduleDatabase.forTesting(NativeDatabase(file));
    await ScheduleRepository(database).save(expected);
    await database.close();

    database = ScheduleDatabase.forTesting(NativeDatabase(file));
    final restored = (await ScheduleRepository(database).getItems()).single;
    expect(restored.title, expected.title);
    expect(restored.startDate, expected.startDate);
    expect(restored.intervals, expected.intervals);
    expect(restored.codeMeaning, expected.codeMeaning);
    expect(restored.reportingInstruction, expected.reportingInstruction);
    await database.close();
    await directory.delete(recursive: true);
  });
}
