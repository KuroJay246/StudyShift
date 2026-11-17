import 'package:drift/drift.dart';

import 'schedule_database.dart';

enum ScheduleImportSourceType {
  ics,
  csv,
  xlsx,
  pdfOcr,
  imageOcr,
  examTimetableOcr,
}

extension ScheduleImportSourceTypeLabel on ScheduleImportSourceType {
  String get label => switch (this) {
    ScheduleImportSourceType.ics => 'iCalendar',
    ScheduleImportSourceType.csv => 'CSV',
    ScheduleImportSourceType.xlsx => 'Excel',
    ScheduleImportSourceType.pdfOcr => 'PDF schedule scan',
    ScheduleImportSourceType.imageOcr => 'Schedule image scan',
    ScheduleImportSourceType.examTimetableOcr => 'Exam timetable scan',
  };

  /// Increment this source-specific value when its parser's output contract
  /// changes in a way that affects reviewed or saved imports.
  String get parserVersion => '1';
}

/// A user-confirmed import batch summary. It intentionally stores no file
/// name, path, contents, extracted text, or event details.
class ScheduleImportHistoryEntry {
  const ScheduleImportHistoryEntry({
    required this.id,
    required this.sourceType,
    required this.importedAt,
    required this.parserVersion,
    required this.proposedCount,
    required this.acceptedCount,
    required this.rejectedCount,
    required this.skippedCount,
    required this.warningsCount,
  });

  final int id;
  final ScheduleImportSourceType sourceType;
  final DateTime importedAt;
  final String parserVersion;
  final int proposedCount;
  final int acceptedCount;
  final int rejectedCount;
  final int skippedCount;
  final int warningsCount;
}

/// Metadata needed to record a confirmed import after its database result is
/// known. Counts refer only to reviewed proposals; parser notices are reported
/// separately as warnings.
class ScheduleImportHistoryDraft {
  const ScheduleImportHistoryDraft({
    required this.sourceType,
    required this.parserVersion,
    required this.proposedCount,
    required this.rejectedCount,
    required this.skippedCount,
    required this.warningsCount,
    required this.importedAt,
  });

  final ScheduleImportSourceType sourceType;
  final String parserVersion;
  final int proposedCount;
  final int rejectedCount;
  final int skippedCount;
  final int warningsCount;
  final DateTime importedAt;
}

class ScheduleImportHistoryRepository {
  const ScheduleImportHistoryRepository(this.database);

  static const retainedEntryLimit = 50;

  final ScheduleDatabase database;

  Stream<List<ScheduleImportHistoryEntry>> watchEntries() =>
      (database.select(database.scheduleImportHistoryRows)..orderBy([
            (row) => OrderingTerm.desc(row.importedAt),
            (row) => OrderingTerm.desc(row.id),
          ]))
          .watch()
          .map(_mapRows);

  Future<List<ScheduleImportHistoryEntry>> getEntries() async => _mapRows(
    await (database.select(database.scheduleImportHistoryRows)..orderBy([
          (row) => OrderingTerm.desc(row.importedAt),
          (row) => OrderingTerm.desc(row.id),
        ]))
        .get(),
  );

  Future<void> record(
    ScheduleImportHistoryDraft draft, {
    required int acceptedCount,
    int additionalSkippedCount = 0,
  }) => database.transaction(
    () => recordWithinTransaction(
      draft,
      acceptedCount: acceptedCount,
      additionalSkippedCount: additionalSkippedCount,
    ),
  );

  /// Called only from the transaction that commits the corresponding import.
  Future<void> recordWithinTransaction(
    ScheduleImportHistoryDraft draft, {
    required int acceptedCount,
    int additionalSkippedCount = 0,
  }) async {
    final skippedCount = draft.skippedCount + additionalSkippedCount;
    _validate(draft, acceptedCount, skippedCount);
    await database
        .into(database.scheduleImportHistoryRows)
        .insert(
          ScheduleImportHistoryRowsCompanion.insert(
            sourceType: draft.sourceType.name,
            importedAt: draft.importedAt.toUtc().toIso8601String(),
            parserVersion: draft.parserVersion,
            proposedCount: draft.proposedCount,
            acceptedCount: acceptedCount,
            rejectedCount: draft.rejectedCount,
            skippedCount: skippedCount,
            warningsCount: draft.warningsCount,
          ),
        );
    final excess =
        await (database.select(database.scheduleImportHistoryRows)
              ..orderBy([
                (row) => OrderingTerm.desc(row.importedAt),
                (row) => OrderingTerm.desc(row.id),
              ])
              ..limit(retainedEntryLimit, offset: retainedEntryLimit))
            .get();
    if (excess.isNotEmpty) {
      await (database.delete(
        database.scheduleImportHistoryRows,
      )..where((row) => row.id.isIn(excess.map((entry) => entry.id)))).go();
    }
  }

  Future<void> clear() =>
      database.delete(database.scheduleImportHistoryRows).go();

  List<ScheduleImportHistoryEntry> _mapRows(
    List<ScheduleImportHistoryRow> rows,
  ) => [
    for (final row in rows)
      ScheduleImportHistoryEntry(
        id: row.id,
        sourceType: _sourceType(row.sourceType),
        importedAt: _importedAt(row.importedAt),
        parserVersion: row.parserVersion,
        proposedCount: row.proposedCount,
        acceptedCount: row.acceptedCount,
        rejectedCount: row.rejectedCount,
        skippedCount: row.skippedCount,
        warningsCount: row.warningsCount,
      ),
  ];

  void _validate(
    ScheduleImportHistoryDraft draft,
    int acceptedCount,
    int skippedCount,
  ) {
    final counts = [
      draft.proposedCount,
      acceptedCount,
      draft.rejectedCount,
      skippedCount,
      draft.warningsCount,
    ];
    if (counts.any((count) => count < 0) ||
        acceptedCount + draft.rejectedCount + skippedCount !=
            draft.proposedCount ||
        draft.parserVersion.trim().isEmpty ||
        draft.parserVersion.length > 32) {
      throw const FormatException(
        'Import history counts or version are invalid.',
      );
    }
  }

  ScheduleImportSourceType _sourceType(String value) =>
      ScheduleImportSourceType.values.firstWhere(
        (source) => source.name == value,
        orElse: () => throw const FormatException(
          'Stored import history has an unknown source type.',
        ),
      );

  DateTime _importedAt(String value) {
    final date = DateTime.tryParse(value);
    if (date == null || !date.isUtc) {
      throw const FormatException('Stored import history date is invalid.');
    }
    return date;
  }
}
