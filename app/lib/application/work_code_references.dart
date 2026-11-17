import '../domain/schedule.dart';

class ObservedWorkCodePattern {
  const ObservedWorkCodePattern({required this.intervals, required this.dates});

  final List<EventInterval> intervals;
  final List<CivilDate> dates;
}

class ObservedWorkCodeReference {
  const ObservedWorkCodeReference({
    required this.employerName,
    required this.code,
    required this.assignmentDetails,
    required this.patterns,
    required this.rosterDates,
  });

  final String? employerName;
  final String code;
  final List<String> assignmentDetails;
  final List<ObservedWorkCodePattern> patterns;
  final List<CivilDate> rosterDates;
}

/// Groups roster observations by employer and code so split and alternate time
/// windows stay under one reusable reference without combining employers.
List<ObservedWorkCodeReference> observedWorkCodeReferences(
  Iterable<ScheduleItem> items,
) {
  final byEmployerAndCode = <String, _MutableCodeReference>{};
  for (final item in items) {
    if (item.kind != ScheduleKind.work) continue;
    final code = item.code?.trim() ?? '';
    if (code.isEmpty) continue;
    final employerName = item.employerName?.trim() ?? '';
    final key = '${employerName.toLowerCase()}\u0000${code.toLowerCase()}';
    final reference = byEmployerAndCode.putIfAbsent(
      key,
      () => _MutableCodeReference(employerName, code),
    );
    final details = item.codeMeaning?.trim() ?? '';
    if (details.isNotEmpty) reference.assignments.add(details);
    reference.dates.add(item.startDate);
    if (item.intervals.isEmpty) continue;
    final immutableIntervals = List<EventInterval>.unmodifiable(item.intervals);
    final patternKey = immutableIntervals
        .map(
          (interval) =>
              '${interval.startDayOffset}:${interval.startMinute}:${interval.endDayOffset}:${interval.endMinute}',
        )
        .join('|');
    reference.patterns
        .putIfAbsent(patternKey, () => _MutablePattern(immutableIntervals))
        .dates
        .add(item.startDate);
  }
  final result = [
    for (final reference in byEmployerAndCode.values)
      ObservedWorkCodeReference(
        employerName: reference.employerName.isEmpty
            ? null
            : reference.employerName,
        code: reference.code,
        assignmentDetails: List.unmodifiable(reference.assignments),
        patterns: List.unmodifiable([
          for (final pattern in reference.patterns.values)
            ObservedWorkCodePattern(
              intervals: pattern.intervals,
              dates: List.unmodifiable(pattern.dates.toList()..sort()),
            ),
        ]),
        rosterDates: List.unmodifiable(reference.dates.toList()..sort()),
      ),
  ];
  result.sort((left, right) {
    final byCode = left.code.toLowerCase().compareTo(right.code.toLowerCase());
    return byCode != 0
        ? byCode
        : (left.employerName ?? '').toLowerCase().compareTo(
            (right.employerName ?? '').toLowerCase(),
          );
  });
  return result;
}

class _MutableCodeReference {
  _MutableCodeReference(this.employerName, this.code);

  final String employerName;
  final String code;
  final assignments = <String>{};
  final dates = <CivilDate>{};
  final patterns = <String, _MutablePattern>{};
}

class _MutablePattern {
  _MutablePattern(this.intervals);

  final List<EventInterval> intervals;
  final dates = <CivilDate>{};
}
