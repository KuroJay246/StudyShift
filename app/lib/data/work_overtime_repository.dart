import 'package:drift/drift.dart';

import '../domain/schedule.dart';
import '../domain/work_overtime.dart';
import 'schedule_database.dart';
import 'schedule_repository.dart';

class WorkOvertimeRepository {
  const WorkOvertimeRepository(this.database);

  final ScheduleDatabase database;

  /// Completes a shift and replaces its logged extra duration atomically.
  /// Planned intervals remain unchanged; [overtimeMinutes] is the total extra
  /// time for this occurrence, including work during a split-shift gap.
  Future<void> completeOccurrence(
    ScheduleItem shift,
    CivilDate date, {
    int? overtimeMinutes,
  }) async {
    if (shift.kind != ScheduleKind.work ||
        shift.workCategory != WorkCategory.shift ||
        shift.hasNoTime ||
        !_isOccurrence(shift, date)) {
      throw const FormatException(
        'Choose a scheduled shift occurrence before completing it.',
      );
    }
    final adjustment = WorkOvertimeAdjustment(
      shiftItemId: shift.id,
      occurrenceDate: date,
      minutes: overtimeMinutes ?? 0,
      isCompleted: true,
    );
    await database.transaction(() async {
      await ScheduleRepository(database).save(
        shift.copyWith(isCompleted: shift.recurrence == null),
      );
      await _writeAdjustment(adjustment);
    });
  }

  /// Clears the completion state for just one shift occurrence. Logged extra
  /// hours remain available for correction until the user clears them.
  Future<void> undoOccurrenceCompletion(
    ScheduleItem shift,
    CivilDate date,
  ) async {
    if (shift.kind != ScheduleKind.work ||
        shift.workCategory != WorkCategory.shift ||
        shift.hasNoTime ||
        !_isOccurrence(shift, date)) {
      throw const FormatException(
        'Choose a scheduled shift occurrence before undoing completion.',
      );
    }
    await database.transaction(() async {
      if (shift.recurrence == null) {
        await ScheduleRepository(database).save(
          shift.copyWith(isCompleted: false, actualIntervals: null),
        );
      }
      final current = await getForOccurrence(shift.id, date);
      if (current == null || !current.isCompleted) return;
      if (current.minutes == 0) {
        await _deleteOccurrence(shift.id, date);
      } else {
        await _writeAdjustment(
          WorkOvertimeAdjustment(
            shiftItemId: current.shiftItemId,
            occurrenceDate: current.occurrenceDate,
            minutes: current.minutes,
            isCompleted: false,
          ),
        );
      }
    });
  }

  Stream<List<WorkOvertimeAdjustment>> watchAll() => database
      .select(database.workOvertimeRows)
      .watch()
      .map((rows) => rows.map(_fromRow).toList(growable: false));

  Future<List<WorkOvertimeAdjustment>> getAll() async =>
      (await database.select(database.workOvertimeRows).get())
          .map(_fromRow)
          .toList(growable: false);

  Future<WorkOvertimeAdjustment?> getForOccurrence(
    String shiftItemId,
    CivilDate date,
  ) async {
    final row =
        await (database.select(database.workOvertimeRows)..where(
              (record) =>
                  record.shiftItemId.equals(shiftItemId) &
                  record.occurrenceDate.equals(date.toString()),
            ))
            .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Replaces the total extra time logged for one scheduled shift occurrence.
  ///
  /// The shift intervals are never modified. A duration can therefore account
  /// for extra work during a split gap or after the planned finish time.
  Future<void> setForOccurrence(
    ScheduleItem shift,
    CivilDate date,
    int minutes,
  ) async {
    if (shift.kind != ScheduleKind.work ||
        shift.workCategory != WorkCategory.shift ||
        shift.hasNoTime ||
        !_isOccurrence(shift, date)) {
      throw const FormatException(
        'Choose a scheduled shift occurrence before adding overtime.',
      );
    }
    final current = await getForOccurrence(shift.id, date);
    final adjustment = WorkOvertimeAdjustment(
      shiftItemId: shift.id,
      occurrenceDate: date,
      minutes: minutes,
      isCompleted: current?.isCompleted ?? false,
    );
    await _writeAdjustment(adjustment);
  }

  Future<void> clearForOccurrence(String shiftItemId, CivilDate date) async {
    final current = await getForOccurrence(shiftItemId, date);
    if (current?.isCompleted == true) {
      await _writeAdjustment(
        WorkOvertimeAdjustment(
          shiftItemId: shiftItemId,
          occurrenceDate: date,
          minutes: 0,
          isCompleted: true,
        ),
      );
      return;
    }
    await _deleteOccurrence(shiftItemId, date);
  }

  Future<void> _deleteOccurrence(String shiftItemId, CivilDate date) async {
    await (database.delete(database.workOvertimeRows)..where(
          (record) =>
              record.shiftItemId.equals(shiftItemId) &
              record.occurrenceDate.equals(date.toString()),
        ))
        .go();
  }

  Future<void> _writeAdjustment(WorkOvertimeAdjustment adjustment) async {
    await database
        .into(database.workOvertimeRows)
        .insertOnConflictUpdate(
          WorkOvertimeRowsCompanion.insert(
            shiftItemId: adjustment.shiftItemId,
            occurrenceDate: adjustment.occurrenceDate.toString(),
            minutes: adjustment.minutes,
            isCompleted: Value(adjustment.isCompleted),
          ),
        );
  }

  Future<void> restoreItems(
    List<WorkOvertimeAdjustment> adjustments, {
    required bool replaceExisting,
  }) async {
    final keys = <String>{};
    final scheduleItems = await ScheduleRepository(database).getItems();
    final shifts = {for (final item in scheduleItems) item.id: item};
    for (final adjustment in adjustments) {
      final key = '${adjustment.shiftItemId}|${adjustment.occurrenceDate}';
      final shift = shifts[adjustment.shiftItemId];
      if (!keys.add(key) ||
          shift == null ||
          shift.kind != ScheduleKind.work ||
          shift.workCategory != WorkCategory.shift ||
          shift.hasNoTime ||
          !_isOccurrence(shift, adjustment.occurrenceDate)) {
        throw const FormatException('Backup overtime entries are invalid.');
      }
    }
    await database.transaction(() async {
      if (replaceExisting) {
        await database.delete(database.workOvertimeRows).go();
      }
      for (final adjustment in adjustments) {
        final companion = WorkOvertimeRowsCompanion.insert(
          shiftItemId: adjustment.shiftItemId,
          occurrenceDate: adjustment.occurrenceDate.toString(),
          minutes: adjustment.minutes,
          isCompleted: Value(adjustment.isCompleted),
        );
        if (replaceExisting) {
          await database
              .into(database.workOvertimeRows)
              .insertOnConflictUpdate(companion);
        } else {
          await database
              .into(database.workOvertimeRows)
              .insert(companion, onConflict: DoNothing());
        }
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

  WorkOvertimeAdjustment _fromRow(WorkOvertimeRow row) =>
      WorkOvertimeAdjustment(
        shiftItemId: row.shiftItemId,
        occurrenceDate: _readDate(row.occurrenceDate),
        minutes: row.minutes,
        isCompleted: row.isCompleted,
      );

  CivilDate _readDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      throw const FormatException('Invalid overtime date.');
    }
    final date = CivilDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    if (!date.isValid || date.toString() != value) {
      throw const FormatException('Invalid overtime date.');
    }
    return date;
  }
}
