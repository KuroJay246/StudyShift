import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'schedule_database.g.dart';

class AcademicTermRows extends Table {
  TextColumn get id => text()();
  TextColumn get institution => text()();
  TextColumn get name => text()();
  TextColumn get startDate => text()();
  TextColumn get endDate => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ScheduleImportHistoryRows extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceType => text()();
  TextColumn get importedAt => text()();
  TextColumn get parserVersion => text()();
  IntColumn get proposedCount => integer()();
  IntColumn get acceptedCount => integer()();
  IntColumn get rejectedCount => integer()();
  IntColumn get skippedCount => integer()();
  IntColumn get warningsCount => integer()();
}

class ScheduleRows extends Table {
  TextColumn get id => text()();
  IntColumn get kind => integer()();
  TextColumn get title => text()();
  TextColumn get startDate => text()();
  TextColumn get timeZoneId => text().nullable()();
  TextColumn get code => text().nullable()();
  TextColumn get codeMeaning => text().nullable()();
  TextColumn get employerName => text().nullable()();
  TextColumn get departmentName => text().nullable()();
  TextColumn get jobRole => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get reportingInstruction => text().nullable()();
  TextColumn get supervisorName => text().nullable()();
  TextColumn get supervisorPhone => text().nullable()();
  TextColumn get contactName => text().nullable()();
  TextColumn get contactPhone => text().nullable()();
  TextColumn get coworkersJson => text().withDefault(const Constant('[]'))();
  TextColumn get academicTermId => text().nullable().references(
    AcademicTermRows,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get weekdays => text().nullable()();
  TextColumn get untilDate => text().nullable()();
  TextColumn get exceptionDates => text().nullable()();
  BoolColumn get isDayOff => boolean().withDefault(const Constant(false))();
  IntColumn get workCategory => integer().nullable()();
  IntColumn get deadlineType => integer().nullable()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get importFormat => text().nullable()();
  TextColumn get importUid => text().nullable()();
  TextColumn get importSourceName => text().nullable()();
  TextColumn get importSourceText => text().nullable()();
  TextColumn get importedAt => text().nullable()();
  IntColumn get reminderMinutesBefore => integer().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get actualIntervalsJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class IntervalRows extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get itemId =>
      text().references(ScheduleRows, #id, onDelete: KeyAction.cascade)();
  IntColumn get startDayOffset => integer()();
  IntColumn get startMinute => integer()();
  IntColumn get endDayOffset => integer()();
  IntColumn get endMinute => integer()();
  TextColumn get startFoldChoice => text().nullable()();
  TextColumn get endFoldChoice => text().nullable()();
}

class WorkOvertimeRows extends Table {
  TextColumn get shiftItemId =>
      text().references(ScheduleRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get occurrenceDate => text()();
  IntColumn get minutes => integer()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {shiftItemId, occurrenceDate};
}

class WorkOccurrenceCoworkerRows extends Table {
  TextColumn get shiftItemId =>
      text().references(ScheduleRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get occurrenceDate => text()();
  TextColumn get rosterCode => text()();
  TextColumn get employerName => text().nullable()();
  TextColumn get coworkersJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {shiftItemId, occurrenceDate};
}

class WorkCodeLegendRows extends Table {
  TextColumn get id => text()();
  TextColumn get employer => text()();
  TextColumn get code => text()();
  TextColumn get meaning => text()();
  IntColumn get startMinute => integer().nullable()();
  IntColumn get endMinute => integer().nullable()();
  TextColumn get flightIdsJson => text().withDefault(const Constant('[]'))();
  TextColumn get timeWindowsJson => text().withDefault(const Constant('[]'))();
  TextColumn get effectiveStartDate => text().nullable()();
  TextColumn get effectiveEndDate => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SupervisorProfileRows extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PreferenceRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    ScheduleRows,
    IntervalRows,
    PreferenceRows,
    WorkCodeLegendRows,
    AcademicTermRows,
    ScheduleImportHistoryRows,
    SupervisorProfileRows,
    WorkOvertimeRows,
    WorkOccurrenceCoworkerRows,
  ],
)
class ScheduleDatabase extends _$ScheduleDatabase {
  ScheduleDatabase() : super(driftDatabase(name: 'shift_study'));
  ScheduleDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 26;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(scheduleRows, scheduleRows.timeZoneId);
      if (from < 3) {
        await m.addColumn(intervalRows, intervalRows.startFoldChoice);
        await m.addColumn(intervalRows, intervalRows.endFoldChoice);
      }
      if (from < 4) {
        await m.addColumn(scheduleRows, scheduleRows.exceptionDates);
      }
      if (from < 5) {
        await m.addColumn(scheduleRows, scheduleRows.workCategory);
        await customStatement('''
          UPDATE schedule_rows
          SET work_category = CASE
            WHEN kind = 0 AND is_day_off = 1 THEN 4
            WHEN kind = 0 THEN 0
            ELSE NULL
          END
        ''');
      }
      if (from < 6) {
        await m.addColumn(scheduleRows, scheduleRows.deadlineType);
        await customStatement('''
          UPDATE schedule_rows
          SET deadline_type = 1
          WHERE kind = 3
        ''');
      }
      if (from < 7) {
        await m.addColumn(scheduleRows, scheduleRows.allDay);
        await m.addColumn(scheduleRows, scheduleRows.importFormat);
        await m.addColumn(scheduleRows, scheduleRows.importUid);
        await m.addColumn(scheduleRows, scheduleRows.importSourceName);
        await m.addColumn(scheduleRows, scheduleRows.importSourceText);
        await m.addColumn(scheduleRows, scheduleRows.importedAt);
      }
      if (from < 8) {
        await m.addColumn(scheduleRows, scheduleRows.reminderMinutesBefore);
      }
      if (from < 9) {
        await m.addColumn(scheduleRows, scheduleRows.reportingInstruction);
      }
      if (from < 10) {
        await m.addColumn(scheduleRows, scheduleRows.codeMeaning);
      }
      if (from < 11) {
        await m.addColumn(scheduleRows, scheduleRows.isCompleted);
      }
      if (from < 12) {
        await m.addColumn(scheduleRows, scheduleRows.supervisorName);
        await m.addColumn(scheduleRows, scheduleRows.supervisorPhone);
        await m.addColumn(scheduleRows, scheduleRows.contactName);
        await m.addColumn(scheduleRows, scheduleRows.contactPhone);
      }
      if (from < 13) {
        await m.addColumn(scheduleRows, scheduleRows.employerName);
        await m.createTable(workCodeLegendRows);
      }
      if (from < 14) {
        await m.createTable(academicTermRows);
        await m.addColumn(scheduleRows, scheduleRows.academicTermId);
      }
      // A work-code table first appears in v13. When creating it from an older
      // schema, Drift uses the current table declaration (already v16), so
      // only add these columns to databases that already had the table.
      if (from >= 13 && from < 15) {
        await m.addColumn(workCodeLegendRows, workCodeLegendRows.startMinute);
        await m.addColumn(workCodeLegendRows, workCodeLegendRows.endMinute);
      }
      if (from < 16) {
        await m.addColumn(scheduleRows, scheduleRows.departmentName);
        await m.addColumn(scheduleRows, scheduleRows.jobRole);
      }
      if (from < 17) {
        await m.addColumn(scheduleRows, scheduleRows.actualIntervalsJson);
      }
      if (from >= 13 && from < 18) {
        await m.addColumn(workCodeLegendRows, workCodeLegendRows.flightIdsJson);
      }
      if (from < 19) {
        await m.createTable(scheduleImportHistoryRows);
      }
      if (from < 20) {
        await m.createTable(supervisorProfileRows);
      }
      if (from >= 13 && from < 21) {
        await m.addColumn(
          workCodeLegendRows,
          workCodeLegendRows.timeWindowsJson,
        );
      }
      if (from < 22) {
        await m.addColumn(scheduleRows, scheduleRows.coworkersJson);
      }
      if (from < 23) await m.createTable(workOvertimeRows);
      if (from >= 23 && from < 24) {
        await m.addColumn(workOvertimeRows, workOvertimeRows.isCompleted);
      }
      if (from < 25) await m.createTable(workOccurrenceCoworkerRows);
      if (from >= 13 && from < 26) {
        await m.addColumn(
          workCodeLegendRows,
          workCodeLegendRows.effectiveStartDate,
        );
        await m.addColumn(
          workCodeLegendRows,
          workCodeLegendRows.effectiveEndDate,
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Stream<List<ScheduleRow>> watchItems() => select(scheduleRows).watch();

  Future<List<ScheduleRow>> getItems() => select(scheduleRows).get();

  Future<List<IntervalRow>> getIntervals(String itemId) =>
      (select(intervalRows)
            ..where((row) => row.itemId.equals(itemId))
            ..orderBy([
              (row) => OrderingTerm.asc(row.startDayOffset),
              (row) => OrderingTerm.asc(row.startMinute),
            ]))
          .get();

  Future<Map<String, List<IntervalRow>>> getIntervalsForItems(
    Iterable<String> itemIds,
  ) async {
    final ids = itemIds.toSet();
    if (ids.isEmpty) return const {};

    final rows =
        await (select(intervalRows)
              ..where((row) => row.itemId.isIn(ids))
              ..orderBy([
                (row) => OrderingTerm.asc(row.itemId),
                (row) => OrderingTerm.asc(row.startDayOffset),
                (row) => OrderingTerm.asc(row.startMinute),
              ]))
            .get();
    final intervalsByItem = <String, List<IntervalRow>>{};
    for (final row in rows) {
      intervalsByItem.putIfAbsent(row.itemId, () => []).add(row);
    }
    return intervalsByItem;
  }

  Future<void> saveItem(
    ScheduleRowsCompanion item,
    List<IntervalRowsCompanion> intervals,
  ) async {
    await transaction(() async {
      await into(scheduleRows).insertOnConflictUpdate(item);
      await (delete(
        intervalRows,
      )..where((row) => row.itemId.equals(item.id.value))).go();
      for (final part in intervals) {
        await into(intervalRows)
            .insert(part.copyWith(itemId: Value(item.id.value)));
      }
    });
  }

  Future<void> deleteItem(String id) async {
    await transaction(() async {
      await (delete(intervalRows)..where((row) => row.itemId.equals(id))).go();
      await (delete(scheduleRows)..where((row) => row.id.equals(id))).go();
    });
  }

  Future<Map<String, String>> getPreferences() async {
    final rows = await select(preferenceRows).get();
    return {for (final row in rows) row.key: row.value};
  }

  Future<void> setPreference(String key, String value) => into(preferenceRows)
      .insertOnConflictUpdate(
        PreferenceRowsCompanion.insert(key: key, value: value),
      );

  Future<void> deletePreference(String key) =>
      (delete(preferenceRows)..where((row) => row.key.equals(key))).go();

  Future<void> resetLocalData() => transaction(() async {
    await delete(intervalRows).go();
    await delete(scheduleRows).go();
    await delete(academicTermRows).go();
    await delete(workCodeLegendRows).go();
    await delete(supervisorProfileRows).go();
    await delete(scheduleImportHistoryRows).go();
    await delete(preferenceRows).go();
  });
}
