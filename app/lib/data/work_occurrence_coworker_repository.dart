import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/schedule.dart';
import '../domain/work_occurrence_coworkers.dart';
import 'schedule_database.dart';
import 'schedule_repository.dart';

class WorkOccurrenceCoworkerRepository {
  const WorkOccurrenceCoworkerRepository(this.database);

  final ScheduleDatabase database;

  Stream<List<WorkOccurrenceCoworkers>> watchAll() => database
      .select(database.workOccurrenceCoworkerRows)
      .watch()
      .map((rows) => rows.map(_fromRow).toList(growable: false));

  Future<List<WorkOccurrenceCoworkers>> getAll() async =>
      (await database.select(database.workOccurrenceCoworkerRows).get())
          .map(_fromRow)
          .toList(growable: false);

  Future<WorkOccurrenceCoworkers?> getForOccurrence(
    String shiftItemId,
    CivilDate date,
  ) async {
    final row =
        await (database.select(database.workOccurrenceCoworkerRows)..where(
              (record) =>
                  record.shiftItemId.equals(shiftItemId) &
                  record.occurrenceDate.equals(date.toString()),
            ))
            .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<void> restoreItems(
    List<WorkOccurrenceCoworkers> assignments, {
    required bool replaceExisting,
  }) async {
    final keys = assignments
        .map((entry) => '${entry.shiftItemId}|${entry.occurrenceDate}')
        .toSet();
    if (keys.length != assignments.length) {
      throw const FormatException('Backup shift coworkers are invalid.');
    }
    await database.transaction(() async {
      if (replaceExisting) {
        await database.delete(database.workOccurrenceCoworkerRows).go();
      }
      final shifts = {
        for (final item in await ScheduleRepository(database).getItems())
          item.id: item,
      };
      for (final assignment in assignments) {
        final shift = shifts[assignment.shiftItemId];
        // A merge can legitimately skip a shift whose ID already belongs to a
        // different local event. Never attach that roster data to another row.
        if (shift == null && !replaceExisting) continue;
        if (shift == null ||
            !_isOccurrence(shift, assignment.occurrenceDate) ||
            shift.kind != ScheduleKind.work ||
            shift.workCategory != WorkCategory.shift ||
            shift.hasNoTime ||
            shift.code?.trim().toUpperCase() !=
                assignment.rosterCode.trim().toUpperCase() ||
            shift.employerName?.trim().toLowerCase() !=
                assignment.employerName?.trim().toLowerCase()) {
          throw const FormatException('Backup shift coworkers are invalid.');
        }
        await database
            .into(database.workOccurrenceCoworkerRows)
            .insertOnConflictUpdate(
              WorkOccurrenceCoworkerRowsCompanion.insert(
                shiftItemId: assignment.shiftItemId,
                occurrenceDate: assignment.occurrenceDate.toString(),
                rosterCode: assignment.rosterCode,
                employerName: Value(assignment.employerName),
                coworkersJson: jsonEncode(assignment.coworkers),
              ),
            );
      }
    });
  }

  bool _isOccurrence(ScheduleItem item, CivilDate date) {
    final recurrence = item.recurrence;
    if (recurrence == null) return date == item.startDate;
    return date.compareTo(item.startDate) >= 0 &&
        (recurrence.until == null || date.compareTo(recurrence.until!) <= 0) &&
        recurrence.weekdays.contains(date.weekday) &&
        !recurrence.exceptionDates.contains(date);
  }

  WorkOccurrenceCoworkers _fromRow(WorkOccurrenceCoworkerRow row) {
    final decoded = jsonDecode(row.coworkersJson);
    if (decoded is! List || decoded.any((name) => name is! String)) {
      throw const FormatException('Stored occurrence coworkers are invalid.');
    }
    return WorkOccurrenceCoworkers(
      shiftItemId: row.shiftItemId,
      occurrenceDate: _parseDate(row.occurrenceDate),
      rosterCode: row.rosterCode,
      employerName: row.employerName,
      coworkers: decoded.cast<String>(),
    );
  }

  CivilDate _parseDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      throw const FormatException('Stored occurrence date is invalid.');
    }
    final date = CivilDate(
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
      int.tryParse(parts[2]) ?? 0,
    );
    if (!date.isValid) {
      throw const FormatException('Stored occurrence date is invalid.');
    }
    return date;
  }
}
