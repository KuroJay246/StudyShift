import '../domain/schedule.dart';
import 'csv_schedule_import.dart';

enum CoworkerRosterMatchStatus { matched, unmatched, ambiguous }

class CoworkerRosterMatch {
  const CoworkerRosterMatch({
    required this.assignment,
    required this.status,
    this.existingShift,
    this.updatedShift,
  });

  final CoworkerRosterAssignment assignment;
  final CoworkerRosterMatchStatus status;
  final ScheduleItem? existingShift;
  final ScheduleItem? updatedShift;

  List<String> get updatedCoworkers =>
      updatedShift?.coworkers ?? const <String>[];
}

/// Matches coworker rows to saved timed work by start date and roster code.
/// It never creates an event; ambiguous rows are intentionally left untouched.
class CoworkerRosterMatcher {
  const CoworkerRosterMatcher();

  CoworkerRosterMatch match(
    CoworkerRosterAssignment assignment,
    Iterable<ScheduleItem> savedItems,
  ) {
    final code = _normalizeCode(assignment.code);
    final candidates = savedItems
        .where((item) {
          if (item.kind != ScheduleKind.work ||
              item.workCategory == WorkCategory.dayOff ||
              item.workCategory == WorkCategory.restDay ||
              item.workCategory == WorkCategory.leave ||
              item.hasNoTime ||
              item.startDate != assignment.date ||
              _normalizeCode(item.code ?? '') != code) {
            return false;
          }
          final employer = assignment.employer;
          return employer == null ||
              item.employerName?.trim().toLowerCase() ==
                  employer.trim().toLowerCase();
        })
        .toList(growable: false);

    if (candidates.isEmpty) {
      return CoworkerRosterMatch(
        assignment: assignment,
        status: CoworkerRosterMatchStatus.unmatched,
      );
    }
    if (candidates.length != 1) {
      return CoworkerRosterMatch(
        assignment: assignment,
        status: CoworkerRosterMatchStatus.ambiguous,
      );
    }
    final existing = candidates.single;
    final names = [...existing.coworkers];
    for (final name in assignment.coworkers) {
      if (!names.any((stored) => stored.toLowerCase() == name.toLowerCase())) {
        names.add(name);
      }
    }
    return CoworkerRosterMatch(
      assignment: assignment,
      status: CoworkerRosterMatchStatus.matched,
      existingShift: existing,
      updatedShift: existing.copyWith(coworkers: names),
    );
  }

  static String _normalizeCode(String code) =>
      code.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
}
