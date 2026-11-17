import '../domain/academic_term.dart';
import '../domain/schedule.dart';
import 'schedule_database.dart';

class AcademicTermRepository {
  const AcademicTermRepository(this.database);

  final ScheduleDatabase database;

  Stream<List<AcademicTerm>> watchItems() =>
      database.select(database.academicTermRows).watch().map(_sorted);

  Future<List<AcademicTerm>> getItems() async =>
      _sorted(await database.select(database.academicTermRows).get());

  Future<AcademicTerm?> getById(String id) async {
    final row = await (database.select(
      database.academicTermRows,
    )..where((term) => term.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<void> save(AcademicTerm term) async {
    final normalized = AcademicTerm(
      id: term.id,
      institution: term.institution,
      name: term.name,
      startDate: term.startDate,
      endDate: term.endDate,
    );
    final existing = await getItems();
    final duplicate = existing.any(
      (value) =>
          value.id != term.id &&
          value.institution.toLowerCase() ==
              normalized.institution.toLowerCase() &&
          value.name.toLowerCase() == normalized.name.toLowerCase(),
    );
    if (duplicate) {
      throw const FormatException(
        'A term with that name already exists for this institution.',
      );
    }
    await _validateLinkedItems(normalized);
    await _write(normalized);
  }

  Future<void> _write(AcademicTerm term) => database
      .into(database.academicTermRows)
      .insertOnConflictUpdate(
        AcademicTermRowsCompanion.insert(
          id: term.id,
          institution: term.institution,
          name: term.name,
          startDate: term.startDate.toString(),
          endDate: term.endDate.toString(),
        ),
      );

  Future<void> _validateLinkedItems(AcademicTerm term) async {
    final linked = await (database.select(
      database.scheduleRows,
    )..where((item) => item.academicTermId.equals(term.id))).get();
    for (final item in linked) {
      final startDate = _readDate(item.startDate);
      final parts = item.weekdays?.split(',').where((part) => part.isNotEmpty);
      final repeats = parts != null && parts.isNotEmpty;
      final until = item.untilDate == null ? null : _readDate(item.untilDate!);
      if (!term.contains(startDate) ||
          (item.kind == ScheduleKind.classSession.index &&
              repeats &&
              (until == null || until.compareTo(term.endDate) > 0))) {
        throw const FormatException(
          'Update or unlink the study events before changing these term dates.',
        );
      }
    }
  }

  Future<void> delete(String id) => (database.delete(
    database.academicTermRows,
  )..where((term) => term.id.equals(id))).go();

  Future<Map<String, String>> restoreItems(
    List<AcademicTerm> incoming, {
    required bool replaceExisting,
  }) async {
    final incomingIds = <String>{};
    final incomingNames = <String>{};
    for (final term in incoming) {
      final naturalKey =
          '${term.institution.toLowerCase()}\u0000${term.name.toLowerCase()}';
      if (!incomingIds.add(term.id) || !incomingNames.add(naturalKey)) {
        throw const FormatException('Backup academic terms are invalid.');
      }
    }

    return database.transaction(() async {
      if (replaceExisting) {
        await database.delete(database.academicTermRows).go();
      }
      final existing = replaceExisting ? <AcademicTerm>[] : await getItems();
      final byId = {for (final term in existing) term.id: term};
      final byNaturalKey = {
        for (final term in existing)
          '${term.institution.toLowerCase()}\u0000${term.name.toLowerCase()}':
              term,
      };
      final remapped = <String, String>{};
      for (final term in incoming) {
        final naturalKey =
            '${term.institution.toLowerCase()}\u0000${term.name.toLowerCase()}';
        final current = byId[term.id];
        if (current != null &&
            '${current.institution.toLowerCase()}\u0000${current.name.toLowerCase()}' ==
                naturalKey) {
          remapped[term.id] = current.id;
          continue;
        }
        final matching = byNaturalKey[naturalKey];
        if (matching != null) {
          remapped[term.id] = matching.id;
          continue;
        }
        var restored = term;
        if (current != null) {
          var suffix = 1;
          var newId = '${term.id}-restored-$suffix';
          while (byId.containsKey(newId)) {
            suffix++;
            newId = '${term.id}-restored-$suffix';
          }
          restored = AcademicTerm(
            id: newId,
            institution: term.institution,
            name: term.name,
            startDate: term.startDate,
            endDate: term.endDate,
          );
        }
        await _write(restored);
        byId[restored.id] = restored;
        byNaturalKey[naturalKey] = term;
        remapped[term.id] = restored.id;
      }
      return remapped;
    });
  }

  List<AcademicTerm> _sorted(List<AcademicTermRow> rows) =>
      rows.map(_fromRow).toList()..sort((a, b) {
        final dateOrder = a.startDate.compareTo(b.startDate);
        if (dateOrder != 0) return dateOrder;
        final institutionOrder = a.institution.toLowerCase().compareTo(
          b.institution.toLowerCase(),
        );
        return institutionOrder != 0
            ? institutionOrder
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

  AcademicTerm _fromRow(AcademicTermRow row) => AcademicTerm(
    id: row.id,
    institution: row.institution,
    name: row.name,
    startDate: _readDate(row.startDate),
    endDate: _readDate(row.endDate),
  );

  CivilDate _readDate(String raw) {
    final parts = raw.split('-').map(int.tryParse).toList();
    if (parts.length != 3 || parts.any((part) => part == null)) {
      throw const FormatException('Stored academic term date is invalid.');
    }
    return CivilDate(parts[0]!, parts[1]!, parts[2]!);
  }
}
