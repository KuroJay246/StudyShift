import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/academic_term.dart';
import '../domain/schedule.dart';
import 'schedule_database.dart';
import 'schedule_import_history_repository.dart';

class ScheduleRepository {
  const ScheduleRepository(this.database);
  final ScheduleDatabase database;

  Stream<List<ScheduleItem>> watchItems() =>
      database.watchItems().asyncMap(_load);
  Future<List<ScheduleItem>> getItems() async =>
      _load(await database.getItems());

  Future<List<ScheduleItem>> _load(List<ScheduleRow> rows) async {
    final items = <ScheduleItem>[];
    for (final row in rows) {
      final parts = await database.getIntervals(row.id);
      final kind = ScheduleKind.values[row.kind];
      final categoryIndex =
          row.workCategory ??
          (row.isDayOff ? WorkCategory.dayOff.index : WorkCategory.shift.index);
      final workCategory = kind == ScheduleKind.work
          ? categoryIndex >= 0 && categoryIndex < WorkCategory.values.length
                ? WorkCategory.values[categoryIndex]
                : throw FormatException('Invalid stored work category.')
          : null;
      final weekdays = row.weekdays
          ?.split(',')
          .where((s) => s.isNotEmpty)
          .map(int.parse)
          .toSet();
      final exceptionDates = row.exceptionDates
          ?.split(',')
          .where((value) => value.isNotEmpty)
          .map(_date)
          .toSet();
      items.add(
        ScheduleItem(
          id: row.id,
          kind: kind,
          title: row.title,
          startDate: _date(row.startDate),
          timeZoneId: row.timeZoneId,
          intervals: parts
              .map(
                (part) => EventInterval(
                  startDayOffset: part.startDayOffset,
                  startMinute: part.startMinute,
                  endDayOffset: part.endDayOffset,
                  endMinute: part.endMinute,
                  startFoldChoice: _foldChoice(part.startFoldChoice),
                  endFoldChoice: _foldChoice(part.endFoldChoice),
                ),
              )
              .toList(),
          code: row.code,
          codeMeaning: row.codeMeaning,
          employerName: row.employerName,
          departmentName: row.departmentName,
          jobRole: row.jobRole,
          location: row.location,
          notes: row.notes,
          reportingInstruction: row.reportingInstruction,
          supervisorName: row.supervisorName,
          supervisorPhone: row.supervisorPhone,
          contactName: row.contactName,
          contactPhone: row.contactPhone,
          academicTermId: row.academicTermId,
          recurrence: weekdays == null
              ? null
              : WeeklyRecurrence(
                  weekdays: weekdays,
                  until: row.untilDate == null ? null : _date(row.untilDate!),
                  exceptionDates: exceptionDates ?? const {},
                ),
          workCategory: workCategory,
          deadlineType: kind == ScheduleKind.deadline
              ? _deadlineType(row.deadlineType)
              : null,
          allDay: row.allDay,
          isCompleted: row.isCompleted,
          actualIntervals: _decodeActualIntervals(row.actualIntervalsJson),
          importProvenance: _importProvenance(row),
          reminderMinutesBefore: row.reminderMinutesBefore,
        ),
      );
    }
    return items;
  }

  Future<void> save(ScheduleItem item) async {
    await _validateAcademicTerm(item);
    if ((item.departmentName?.length ?? 0) > 512 ||
        (item.jobRole?.length ?? 0) > 512) {
      throw const FormatException('A work department or role is too long.');
    }
    final weekdays = item.recurrence?.weekdays.toList();
    weekdays?.sort();
    final exceptionDates = item.recurrence?.exceptionDates.toList();
    exceptionDates?.sort();
    final row = ScheduleRowsCompanion.insert(
      id: item.id,
      kind: item.kind.index,
      title: item.title,
      startDate: item.startDate.toString(),
      timeZoneId: Value(item.timeZoneId),
      code: Value(item.code),
      codeMeaning: Value(item.codeMeaning),
      employerName: Value(item.employerName),
      departmentName: Value(item.departmentName),
      jobRole: Value(item.jobRole),
      location: Value(item.location),
      notes: Value(item.notes),
      reportingInstruction: Value(item.reportingInstruction),
      supervisorName: Value(item.supervisorName),
      supervisorPhone: Value(item.supervisorPhone),
      contactName: Value(item.contactName),
      contactPhone: Value(item.contactPhone),
      academicTermId: Value(item.academicTermId),
      weekdays: Value(weekdays?.join(',')),
      untilDate: Value(item.recurrence?.until?.toString()),
      exceptionDates: Value(exceptionDates?.join(',')),
      isDayOff: Value(item.isDayOff),
      workCategory: Value(item.workCategory?.index),
      deadlineType: Value(item.deadlineType?.index),
      allDay: Value(item.allDay),
      isCompleted: Value(item.isCompleted),
      actualIntervalsJson: Value(_encodeActualIntervals(item.actualIntervals)),
      importFormat: Value(item.importProvenance?.format),
      importUid: Value(item.importProvenance?.uid),
      importSourceName: Value(item.importProvenance?.sourceName),
      importSourceText: Value(item.importProvenance?.sourceText),
      importedAt: Value(
        item.importProvenance?.importedAt.toUtc().toIso8601String(),
      ),
      reminderMinutesBefore: Value(item.reminderMinutesBefore),
    );
    final intervals = item.intervals
        .map(
          (part) => IntervalRowsCompanion.insert(
            itemId: item.id,
            startDayOffset: part.startDayOffset,
            startMinute: part.startMinute,
            endDayOffset: part.endDayOffset,
            endMinute: part.endMinute,
            startFoldChoice: Value(part.startFoldChoice?.name),
            endFoldChoice: Value(part.endFoldChoice?.name),
          ),
        )
        .toList();
    await database.saveItem(row, intervals);
  }

  Future<void> _validateAcademicTerm(ScheduleItem item) async {
    final termId = item.academicTermId;
    if (termId == null) return;
    final row = await (database.select(
      database.academicTermRows,
    )..where((term) => term.id.equals(termId))).getSingleOrNull();
    if (row == null) {
      throw const FormatException('Choose an existing academic term.');
    }
    final term = AcademicTerm(
      id: row.id,
      institution: row.institution,
      name: row.name,
      startDate: _date(row.startDate),
      endDate: _date(row.endDate),
    );
    if (!term.contains(item.startDate)) {
      throw const FormatException(
        'The study event date must fall within its academic term.',
      );
    }
    final recurrence = item.recurrence;
    if (item.kind == ScheduleKind.classSession &&
        recurrence != null &&
        (recurrence.until == null ||
            recurrence.until!.compareTo(term.endDate) > 0)) {
      throw const FormatException(
        'Weekly classes linked to a term must end by the term end date.',
      );
    }
  }

  Future<void> delete(String id) => database.deleteItem(id);

  Future<ScheduleRestoreResult> restoreItems(
    List<ScheduleItem> items, {
    required bool replaceExisting,
  }) async {
    final incomingIds = <String>{};
    for (final item in items) {
      if (!incomingIds.add(item.id)) {
        throw const FormatException('The backup contains duplicate event IDs.');
      }
    }
    var inserted = 0;
    var skipped = 0;
    var removed = 0;
    await database.transaction(() async {
      final existingRows = await database.getItems();
      final existingIds = existingRows.map((row) => row.id).toSet();
      if (replaceExisting) {
        removed = existingRows.length;
        await database.delete(database.scheduleRows).go();
        existingIds.clear();
      }
      for (final item in items) {
        if (!existingIds.add(item.id)) {
          skipped++;
          continue;
        }
        await save(item);
        inserted++;
      }
    });
    return ScheduleRestoreResult(
      inserted: inserted,
      skipped: skipped,
      removed: removed,
    );
  }

  Future<ScheduleImportResult> importItems(
    List<ScheduleItem> items, {
    required bool replaceExisting,
    ScheduleImportHistoryDraft? historyDraft,
  }) async {
    final incomingIds = <String>{};
    if (items.any(
      (item) => item.importProvenance == null || !incomingIds.add(item.id),
    )) {
      throw const FormatException(
        'The import contains an event without source provenance or a duplicate identifier.',
      );
    }
    var inserted = 0;
    var replaced = 0;
    var skipped = 0;
    await database.transaction(() async {
      final existingIds = (await database.getItems())
          .map((row) => row.id)
          .toSet();
      for (final item in items) {
        if (existingIds.contains(item.id)) {
          if (!replaceExisting) {
            skipped++;
            continue;
          }
          replaced++;
        } else {
          inserted++;
        }
        await save(item);
      }
      if (historyDraft != null) {
        await ScheduleImportHistoryRepository(database).recordWithinTransaction(
          historyDraft,
          acceptedCount: inserted + replaced,
          additionalSkippedCount: skipped,
        );
      }
    });
    return ScheduleImportResult(
      inserted: inserted,
      replaced: replaced,
      skipped: skipped,
    );
  }

  CivilDate _date(String raw) {
    final pieces = raw.split('-').map(int.parse).toList();
    if (pieces.length != 3) throw FormatException('Invalid stored civil date.');
    return CivilDate(pieces[0], pieces[1], pieces[2]);
  }

  CivilTimeFoldChoice? _foldChoice(String? raw) => switch (raw) {
    null => null,
    'earlier' => CivilTimeFoldChoice.earlier,
    'later' => CivilTimeFoldChoice.later,
    _ => throw FormatException('Invalid stored civil-time fold choice.'),
  };

  ScheduleImportProvenance? _importProvenance(ScheduleRow row) {
    final values = [
      row.importFormat,
      row.importUid,
      row.importSourceName,
      row.importSourceText,
      row.importedAt,
    ];
    if (values.every((value) => value == null)) return null;
    if (values.any((value) => value == null)) {
      throw const FormatException('Stored import provenance is incomplete.');
    }
    final importedAt = DateTime.tryParse(row.importedAt!);
    if (importedAt == null || !importedAt.isUtc) {
      throw const FormatException('Stored import date is invalid.');
    }
    return ScheduleImportProvenance(
      format: row.importFormat!,
      uid: row.importUid!,
      sourceName: row.importSourceName!,
      sourceText: row.importSourceText!,
      importedAt: importedAt,
    );
  }
}

CivilTimeFoldChoice? _decodeFoldChoice(String? raw) => switch (raw) {
  null => null,
  'earlier' => CivilTimeFoldChoice.earlier,
  'later' => CivilTimeFoldChoice.later,
  _ => throw const FormatException('Invalid stored civil-time fold choice.'),
};

String? _encodeActualIntervals(List<EventInterval>? intervals) =>
    intervals == null
    ? null
    : jsonEncode([
        for (final interval in intervals)
          {
            'startDayOffset': interval.startDayOffset,
            'startMinute': interval.startMinute,
            'endDayOffset': interval.endDayOffset,
            'endMinute': interval.endMinute,
            'startFoldChoice': interval.startFoldChoice?.name,
            'endFoldChoice': interval.endFoldChoice?.name,
          },
      ]);

List<EventInterval>? _decodeActualIntervals(String? value) {
  if (value == null) return null;
  try {
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw const FormatException('Invalid actual intervals.');
    }
    return [
      for (final item in decoded)
        if (item is Map<String, dynamic>)
          EventInterval(
            startDayOffset: item['startDayOffset'] as int,
            startMinute: item['startMinute'] as int,
            endDayOffset: item['endDayOffset'] as int,
            endMinute: item['endMinute'] as int,
            startFoldChoice: _decodeFoldChoice(
              item['startFoldChoice'] as String?,
            ),
            endFoldChoice: _decodeFoldChoice(item['endFoldChoice'] as String?),
          )
        else
          throw const FormatException('Invalid actual interval.'),
    ];
  } on FormatException {
    rethrow;
  } on Object {
    throw const FormatException('Invalid actual intervals.');
  }
}

class ScheduleRestoreResult {
  const ScheduleRestoreResult({
    required this.inserted,
    required this.skipped,
    required this.removed,
  });

  final int inserted;
  final int skipped;
  final int removed;
}

class ScheduleImportResult {
  const ScheduleImportResult({
    required this.inserted,
    required this.replaced,
    required this.skipped,
  });

  final int inserted;
  final int replaced;
  final int skipped;
}

DeadlineType _deadlineType(int? index) {
  if (index == null || index < 0 || index >= DeadlineType.values.length) {
    throw const FormatException('Invalid stored deadline type.');
  }
  return DeadlineType.values[index];
}
