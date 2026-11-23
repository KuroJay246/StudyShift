import 'schedule.dart';

/// Coworkers assigned to one dated occurrence of a work shift.
///
/// Recurring shifts keep occurrence assignments separately so importing a
/// roster date never changes coworker names across the whole series.
class WorkOccurrenceCoworkers {
  WorkOccurrenceCoworkers({
    required this.shiftItemId,
    required this.occurrenceDate,
    required this.rosterCode,
    this.employerName,
    required Iterable<String> coworkers,
  }) : coworkers = List.unmodifiable(_normalizeCoworkers(coworkers)) {
    if (shiftItemId.trim().isEmpty ||
        shiftItemId.length > 256 ||
        rosterCode.trim().isEmpty ||
        rosterCode.length > 128 ||
        (employerName?.length ?? 0) > 512 ||
        !occurrenceDate.isValid ||
        this.coworkers.length > 500 ||
        this.coworkers.any((name) => name.length > 256)) {
      throw const FormatException('Occurrence coworkers are invalid.');
    }
  }

  final String shiftItemId;
  final CivilDate occurrenceDate;
  final String rosterCode;
  final String? employerName;
  final List<String> coworkers;
}

List<String> _normalizeCoworkers(Iterable<String> coworkers) {
  final result = <String>[];
  for (final raw in coworkers) {
    final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty ||
        result.any((saved) => saved.toLowerCase() == name.toLowerCase())) {
      continue;
    }
    result.add(name);
  }
  return result;
}
