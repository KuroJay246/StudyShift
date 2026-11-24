import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/schedule_import_history_repository.dart';

void main() {
  test('database exposes only privacy-minimal import history fields', () async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final rows = await database
        .customSelect(
          'SELECT source_type, imported_at, parser_version, proposed_count, '
          'accepted_count, rejected_count, skipped_count, warnings_count '
          'FROM schedule_import_history_rows',
        )
        .get();

    expect(rows, isEmpty);

    final columns = await database
        .customSelect('PRAGMA table_info(schedule_import_history_rows)')
        .get();
    expect(columns.map((row) => row.read<String>('name')), [
      'id',
      'source_type',
      'imported_at',
      'parser_version',
      'proposed_count',
      'accepted_count',
      'rejected_count',
      'skipped_count',
      'warnings_count',
    ]);
  });

  test('history keeps only the newest 50 count-only summaries', () async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = ScheduleImportHistoryRepository(database);
    final base = DateTime.utc(2026, 11, 1);

    for (var index = 0; index < 51; index++) {
      await repository.record(
        ScheduleImportHistoryDraft(
          sourceType: ScheduleImportSourceType.csv,
          parserVersion: '1',
          importedAt: base.add(Duration(days: index)),
          proposedCount: 2,
          rejectedCount: 0,
          skippedCount: 1,
          warningsCount: 1,
        ),
        acceptedCount: 1,
      );
    }

    final history = await repository.getEntries();
    expect(history, hasLength(50));
    expect(history.first.importedAt, DateTime.utc(2026, 12, 21));
    expect(history.last.importedAt, DateTime.utc(2026, 11, 2));
    expect(
      history.every(
        (entry) => entry.sourceType == ScheduleImportSourceType.csv,
      ),
      isTrue,
    );
    expect(history.every((entry) => entry.parserVersion == '1'), isTrue);
  });

  test(
    'history rejects inconsistent batch totals without saving a row',
    () async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = ScheduleImportHistoryRepository(database);

      await expectLater(
        repository.record(
          ScheduleImportHistoryDraft(
            sourceType: ScheduleImportSourceType.ics,
            parserVersion: '1',
            importedAt: DateTime.utc(2026, 11, 1),
            proposedCount: 2,
            rejectedCount: 1,
            skippedCount: 0,
            warningsCount: 0,
          ),
          acceptedCount: 0,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await repository.getEntries(), isEmpty);
    },
  );

  test(
    'version 18 migration adds history and preserves prior schedule rows',
    () async {
      final database = ScheduleDatabase.forTesting(
        NativeDatabase.memory(
          setup: (db) {
            db.execute(
              'CREATE TABLE schedule_rows (id TEXT PRIMARY KEY, title TEXT)',
            );
            db.execute('''
              CREATE TABLE work_code_legend_rows (
                id TEXT PRIMARY KEY NOT NULL,
                employer TEXT NOT NULL DEFAULT '',
                code TEXT NOT NULL,
                meaning TEXT NOT NULL,
                start_minute INTEGER,
                end_minute INTEGER,
                flight_ids_json TEXT NOT NULL DEFAULT '[]'
              )
            ''');
            db.execute(
              "INSERT INTO schedule_rows (id, title) VALUES ('kept', 'Existing record')",
            );
            db.execute('PRAGMA user_version = 18');
          },
        ),
      );
      addTearDown(database.close);

      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      final preserved = await database
          .customSelect(
            'SELECT title FROM schedule_rows WHERE id = ?',
            variables: [Variable.withString('kept')],
          )
          .getSingle();
      final history = await database
          .customSelect('SELECT * FROM schedule_import_history_rows')
          .get();
      final occurrenceCoworkers = await database
          .customSelect('SELECT * FROM work_occurrence_coworker_rows')
          .get();
      final legendColumns = await database
          .customSelect('PRAGMA table_info(work_code_legend_rows)')
          .get();

      expect(version.read<int>('user_version'), 26);
      expect(preserved.read<String>('title'), 'Existing record');
      expect(history, isEmpty);
      expect(occurrenceCoworkers, isEmpty);
      expect(
        legendColumns.map((row) => row.read<String>('name')),
        containsAll(['effective_start_date', 'effective_end_date']),
      );
    },
  );
}
