import 'package:drift/drift.dart' show Value;

import '../domain/supervisor_profile.dart';
import 'schedule_database.dart';

class SupervisorRepository {
  const SupervisorRepository(this.database);

  final ScheduleDatabase database;

  Stream<List<SupervisorProfile>> watchItems() =>
      database.select(database.supervisorProfileRows).watch().map(_sorted);

  Future<List<SupervisorProfile>> getItems() async =>
      _sorted(await database.select(database.supervisorProfileRows).get());

  Future<void> save(SupervisorProfile profile) async {
    final name = profile.name.trim();
    final phone = profile.phone.trim();
    final notes = profile.notes.trim();
    if (profile.id.trim().isEmpty || name.isEmpty) {
      throw const FormatException('Enter a supervisor name.');
    }
    if (profile.id.length > 256 ||
        name.length > 256 ||
        phone.length > 128 ||
        notes.length > 2000) {
      throw const FormatException('A supervisor detail is too long.');
    }
    await database
        .into(database.supervisorProfileRows)
        .insertOnConflictUpdate(
          SupervisorProfileRowsCompanion.insert(
            id: profile.id,
            name: name,
            type: profile.type.name,
            phone: Value(phone.isEmpty ? null : phone),
            notes: Value(notes.isEmpty ? null : notes),
          ),
        );
  }

  Future<void> delete(String id) => (database.delete(
    database.supervisorProfileRows,
  )..where((row) => row.id.equals(id))).go();

  Future<void> restoreItems(
    List<SupervisorProfile> profiles, {
    required bool replaceExisting,
  }) async {
    final ids = <String>{};
    for (final profile in profiles) {
      if (profile.id.trim().isEmpty ||
          profile.name.trim().isEmpty ||
          profile.id.length > 256 ||
          profile.name.trim().length > 256 ||
          profile.phone.trim().length > 128 ||
          profile.notes.trim().length > 2000 ||
          !ids.add(profile.id)) {
        throw const FormatException('Backup supervisor contacts are invalid.');
      }
    }
    await database.transaction(() async {
      if (replaceExisting) {
        await database.delete(database.supervisorProfileRows).go();
      }
      for (final profile in profiles) {
        final exists = await (database.select(
          database.supervisorProfileRows,
        )..where((row) => row.id.equals(profile.id))).getSingleOrNull();
        if (exists != null) continue;
        await save(profile);
      }
    });
  }

  List<SupervisorProfile> _sorted(List<SupervisorProfileRow> rows) =>
      rows
          .map(
            (row) => SupervisorProfile(
              id: row.id,
              name: row.name,
              type: SupervisorType.values.firstWhere(
                (type) => type.name == row.type,
                orElse: () => SupervisorType.permanent,
              ),
              phone: row.phone ?? '',
              notes: row.notes ?? '',
            ),
          )
          .toList()
        ..sort((a, b) {
          final byType = a.type.index.compareTo(b.type.index);
          return byType != 0
              ? byType
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
}
