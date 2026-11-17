import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../domain/work_code_legend.dart';
import 'schedule_database.dart';

class WorkCodeLegendRepository {
  const WorkCodeLegendRepository(this.database);

  final ScheduleDatabase database;

  Stream<List<WorkCodeLegend>> watchItems() =>
      database.select(database.workCodeLegendRows).watch().map(_sorted);

  Future<List<WorkCodeLegend>> getItems() async =>
      _sorted(await database.select(database.workCodeLegendRows).get());

  Future<void> save(WorkCodeLegend entry) async {
    final employer = entry.employer.trim();
    final code = entry.code.trim();
    final assignmentDetails = entry.assignmentDetails.trim();
    final windows = entry.timeWindows;
    if (entry.id.trim().isEmpty ||
        code.isEmpty ||
        windows.length > 2 ||
        windows.any((window) => !window.isValid) ||
        (windows.isEmpty &&
            ((entry.startMinute == null) != (entry.endMinute == null))) ||
        (windows.isEmpty && assignmentDetails.isEmpty)) {
      throw const FormatException(
        'Enter a code and its time range or assignment details. Check the time range.',
      );
    }
    if (entry.id.length > 256 ||
        employer.length > 512 ||
        code.length > 128 ||
        assignmentDetails.length > 4000) {
      throw const FormatException('A shift legend field is too long.');
    }
    final flightIds = _normalizeFlightIds(entry.flightIds);

    final rows = await database.select(database.workCodeLegendRows).get();
    final duplicate = rows.any(
      (row) =>
          row.id != entry.id &&
          row.employer.trim().toLowerCase() == employer.toLowerCase() &&
          row.code.trim().toUpperCase() == code.toUpperCase(),
    );
    if (duplicate) {
      throw const FormatException(
        'That code already exists for this employer.',
      );
    }
    await database
        .into(database.workCodeLegendRows)
        .insertOnConflictUpdate(
          WorkCodeLegendRowsCompanion.insert(
            id: entry.id,
            employer: employer,
            code: code,
            meaning: assignmentDetails,
            startMinute: Value(entry.startMinute),
            endMinute: Value(entry.endMinute),
            flightIdsJson: Value(jsonEncode(flightIds)),
            timeWindowsJson: Value(_encodeTimeWindows(windows)),
          ),
        );
  }

  Future<void> delete(String id) => (database.delete(
    database.workCodeLegendRows,
  )..where((row) => row.id.equals(id))).go();

  Future<void> restoreItems(
    List<WorkCodeLegend> entries, {
    required bool replaceExisting,
  }) async {
    // Validate the complete set before writing any restored rows.
    final seenIds = <String>{};
    final seenCodes = <String>{};
    for (final entry in entries) {
      final employer = entry.employer.trim().toLowerCase();
      final code = entry.code.trim().toUpperCase();
      final windows = entry.timeWindows;
      if (entry.id.trim().isEmpty ||
          code.isEmpty ||
          entry.assignmentDetails.length > 4000 ||
          _normalizeFlightIds(entry.flightIds).length !=
              entry.flightIds.length ||
          windows.length > 2 ||
          windows.any((window) => !window.isValid) ||
          (windows.isEmpty &&
              ((entry.startMinute == null) != (entry.endMinute == null))) ||
          (entry.assignmentDetails.trim().isEmpty && windows.isEmpty) ||
          !seenIds.add(entry.id) ||
          !seenCodes.add('$employer\u0000$code')) {
        throw const FormatException('Backup roster codes are invalid.');
      }
    }
    await database.transaction(() async {
      if (replaceExisting) {
        await database.delete(database.workCodeLegendRows).go();
      }
      for (final entry in entries) {
        final windows = entry.timeWindows;
        final existing = await database
            .select(database.workCodeLegendRows)
            .get();
        final duplicate = existing.any(
          (row) =>
              row.id == entry.id ||
              (row.employer.toLowerCase() ==
                      entry.employer.trim().toLowerCase() &&
                  row.code.toUpperCase() == entry.code.trim().toUpperCase()),
        );
        if (duplicate) continue;
        await database
            .into(database.workCodeLegendRows)
            .insertOnConflictUpdate(
              WorkCodeLegendRowsCompanion.insert(
                id: entry.id,
                employer: entry.employer.trim(),
                code: entry.code.trim(),
                meaning: entry.assignmentDetails.trim(),
                startMinute: Value(entry.startMinute),
                endMinute: Value(entry.endMinute),
                flightIdsJson: Value(
                  jsonEncode(_normalizeFlightIds(entry.flightIds)),
                ),
                timeWindowsJson: Value(_encodeTimeWindows(windows)),
              ),
            );
      }
    });
  }

  List<WorkCodeLegend> _sorted(List<WorkCodeLegendRow> rows) =>
      rows
          .map(
            (row) => WorkCodeLegend(
              id: row.id,
              employer: row.employer,
              code: row.code,
              assignmentDetails: row.meaning,
              startMinute: row.startMinute,
              endMinute: row.endMinute,
              flightIds: _decodeFlightIds(row.flightIdsJson),
              timeWindows: _decodeTimeWindows(row.timeWindowsJson),
            ),
          )
          .toList()
        ..sort((a, b) {
          final employer = a.employer.toLowerCase().compareTo(
            b.employer.toLowerCase(),
          );
          return employer != 0
              ? employer
              : a.code.toLowerCase().compareTo(b.code.toLowerCase());
        });

  static List<String> _normalizeFlightIds(List<String> values) {
    final result = <String>[];
    final seen = <String>{};
    for (final raw in values) {
      final id = raw.trim();
      if (id.isEmpty) continue;
      if (id.length > 32) {
        throw const FormatException('Check the associated flight codes.');
      }
      if (!seen.add(id.toUpperCase())) continue;
      result.add(id);
    }
    if (result.length > 100) {
      throw const FormatException('A shift code can list up to 100 flights.');
    }
    return result;
  }

  static List<String> _decodeFlightIds(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List || decoded.any((value) => value is! String)) {
      return const [];
    }
    return _normalizeFlightIds(decoded.cast<String>());
  }

  static String _encodeTimeWindows(List<WorkCodeTimeWindow> windows) =>
      jsonEncode([
        for (final window in windows)
          {
            'startMinute': window.startMinute,
            'endMinute': window.endMinute,
            'endDayOffset': window.endDayOffset,
          },
      ]);

  static List<WorkCodeTimeWindow> _decodeTimeWindows(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List || decoded.length > 2) return const [];
    final windows = <WorkCodeTimeWindow>[];
    for (final value in decoded) {
      if (value is! Map ||
          value['startMinute'] is! int ||
          value['endMinute'] is! int ||
          value['endDayOffset'] is! int) {
        return const [];
      }
      final window = WorkCodeTimeWindow(
        startMinute: value['startMinute'] as int,
        endMinute: value['endMinute'] as int,
        endDayOffset: value['endDayOffset'] as int,
      );
      if (!window.isValid) return const [];
      windows.add(window);
    }
    return windows;
  }
}
