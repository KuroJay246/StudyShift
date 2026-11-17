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
    final hasStart = entry.startMinute != null;
    final hasEnd = entry.endMinute != null;
    if (entry.id.trim().isEmpty ||
        code.isEmpty ||
        (hasStart != hasEnd) ||
        (!hasStart && assignmentDetails.isEmpty) ||
        (hasStart &&
            (entry.startMinute! < 0 ||
                entry.startMinute! >= 1440 ||
                entry.endMinute! < 0 ||
                entry.endMinute! >= 1440))) {
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
      if (entry.id.trim().isEmpty ||
          code.isEmpty ||
          entry.assignmentDetails.length > 4000 ||
          _normalizeFlightIds(entry.flightIds).length !=
              entry.flightIds.length ||
          ((entry.startMinute == null) != (entry.endMinute == null)) ||
          (entry.startMinute != null &&
              (entry.startMinute! < 0 ||
                  entry.startMinute! >= 1440 ||
                  entry.endMinute! < 0 ||
                  entry.endMinute! >= 1440)) ||
          (entry.assignmentDetails.trim().isEmpty &&
              entry.startMinute == null) ||
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
}
