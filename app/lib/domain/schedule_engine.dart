import 'civil_time_resolver.dart';
import 'schedule.dart';

enum ScheduleTimeIssueKind {
  ambiguousStart,
  ambiguousEnd,
  nonexistentStart,
  nonexistentEnd,
  invalidTimeZone,
  invalidResolvedInterval,
  missingTimeZone,
}

class ScheduleTimeIssue {
  const ScheduleTimeIssue({
    required this.occurrence,
    required this.intervalIndex,
    required this.kind,
  });

  final EventOccurrence occurrence;
  final int intervalIndex;
  final ScheduleTimeIssueKind kind;
}

class OccurrenceTimeResolution {
  const OccurrenceTimeResolution({
    required this.intervals,
    required this.issues,
  });

  final List<ResolvedInterval> intervals;
  final List<ScheduleTimeIssue> issues;
}

class ScheduleConflict {
  const ScheduleConflict({required this.first, required this.second});
  final EventOccurrence first;
  final EventOccurrence second;
}

class ScheduleAnalysis {
  const ScheduleAnalysis({required this.conflicts, required this.timeIssues});

  final List<ScheduleConflict> conflicts;
  final List<ScheduleTimeIssue> timeIssues;
}

class ScheduleEngine {
  const ScheduleEngine();

  /// Expands weekly entries only inside the requested inclusive date range.
  /// Event dates are local civil dates and use the device's local zone when
  /// converted to instants for comparison.
  List<EventOccurrence> expand(
    Iterable<ScheduleItem> items,
    CivilDate from,
    CivilDate through,
  ) {
    if (!from.isValid || !through.isValid) {
      throw ArgumentError('Expansion range needs valid civil dates.');
    }
    if (through.compareTo(from) < 0) {
      throw ArgumentError('Range end precedes start.');
    }
    final result = <EventOccurrence>[];
    final maxDays = DateTime.utc(
      through.year,
      through.month,
      through.day,
    ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
    if (maxDays > 3660) {
      throw ArgumentError('Expansion range is limited to ten years.');
    }
    for (final item in items) {
      if (item.recurrence == null &&
          (item.startDate.compareTo(from) < 0 ||
              item.startDate.compareTo(through) > 0)) {
        continue;
      }
      var date = item.startDate;
      if (date.compareTo(from) < 0) date = from;
      final lastDate = item.recurrence?.until;
      while (date.compareTo(through) <= 0) {
        final isInTerm = lastDate == null || date.compareTo(lastDate) <= 0;
        final isOccurrence = item.recurrence == null
            ? date == item.startDate
            : item.recurrence!.weekdays.contains(date.weekday) &&
                  !item.recurrence!.exceptionDates.contains(date);
        if (isInTerm && isOccurrence) {
          result.add(EventOccurrence(item: item, date: date));
        }
        date = date.addDays(1);
      }
    }
    result.sort(_compareOccurrences);
    return result;
  }

  List<ScheduleConflict> conflicts(Iterable<EventOccurrence> occurrences) {
    return analyze(occurrences).conflicts;
  }

  ScheduleAnalysis analyze(Iterable<EventOccurrence> occurrences) {
    final sorted = [...occurrences]..sort(_compareOccurrences);
    final found = <ScheduleConflict>[];
    final timeIssues = <ScheduleTimeIssue>[];
    final resolved = <EventOccurrence, List<ResolvedInterval>>{};
    for (final occurrence in sorted) {
      final result = resolveOccurrence(occurrence);
      resolved[occurrence] = result.intervals;
      timeIssues.addAll(result.issues);
    }

    for (var i = 0; i < sorted.length; i++) {
      final a = sorted[i];
      for (var j = i + 1; j < sorted.length; j++) {
        final b = sorted[j];
        if (a.item.id == b.item.id) continue;
        if (_overlaps(resolved[a]!, resolved[b]!)) {
          found.add(ScheduleConflict(first: a, second: b));
        }
      }
    }
    return ScheduleAnalysis(conflicts: found, timeIssues: timeIssues);
  }

  OccurrenceTimeResolution resolveOccurrence(EventOccurrence occurrence) {
    if (occurrence.item.hasNoTime) {
      return OccurrenceTimeResolution(intervals: const [], issues: const []);
    }
    if (occurrence.item.timeZoneId == null) {
      final local = [...occurrence.intervals]
        ..sort((a, b) => a.start.compareTo(b.start));
      return OccurrenceTimeResolution(
        intervals: local,
        issues: [
          for (var index = 0; index < occurrence.item.intervals.length; index++)
            ScheduleTimeIssue(
              occurrence: occurrence,
              intervalIndex: index,
              kind: ScheduleTimeIssueKind.missingTimeZone,
            ),
        ],
      );
    }

    final resolver = CivilTimeResolver();
    final resolved = <ResolvedInterval>[];
    final issues = <ScheduleTimeIssue>[];
    for (var index = 0; index < occurrence.item.intervals.length; index++) {
      final part = occurrence.item.intervals[index];
      final startDate = occurrence.date.addDays(part.startDayOffset);
      final endDate = occurrence.date.addDays(part.endDayOffset);
      final startResolution = resolver.resolve(
        startDate,
        part.startMinute,
        occurrence.item.timeZoneId!,
      );
      final endResolution = resolver.resolve(
        endDate,
        part.endMinute,
        occurrence.item.timeZoneId!,
      );
      final start = startResolution.select(part.startFoldChoice);
      final end = endResolution.select(part.endFoldChoice);

      if (start == null) {
        issues.add(
          ScheduleTimeIssue(
            occurrence: occurrence,
            intervalIndex: index,
            kind: startResolution.status == CivilTimeStatus.ambiguous
                ? ScheduleTimeIssueKind.ambiguousStart
                : startResolution.status == CivilTimeStatus.invalidTimeZone
                ? ScheduleTimeIssueKind.invalidTimeZone
                : ScheduleTimeIssueKind.nonexistentStart,
          ),
        );
      }
      if (end == null) {
        issues.add(
          ScheduleTimeIssue(
            occurrence: occurrence,
            intervalIndex: index,
            kind: endResolution.status == CivilTimeStatus.ambiguous
                ? ScheduleTimeIssueKind.ambiguousEnd
                : endResolution.status == CivilTimeStatus.invalidTimeZone
                ? ScheduleTimeIssueKind.invalidTimeZone
                : ScheduleTimeIssueKind.nonexistentEnd,
          ),
        );
      }
      if (start == null || end == null) continue;
      if (!end.isAfter(start)) {
        issues.add(
          ScheduleTimeIssue(
            occurrence: occurrence,
            intervalIndex: index,
            kind: ScheduleTimeIssueKind.invalidResolvedInterval,
          ),
        );
        continue;
      }
      resolved.add(ResolvedInterval(start: start, end: end));
    }

    final sorted = [...resolved]..sort((a, b) => a.start.compareTo(b.start));
    for (var index = 1; index < sorted.length; index++) {
      if (sorted[index].start.isBefore(sorted[index - 1].end)) {
        issues.add(
          ScheduleTimeIssue(
            occurrence: occurrence,
            intervalIndex: -1,
            kind: ScheduleTimeIssueKind.invalidResolvedInterval,
          ),
        );
      }
    }
    return OccurrenceTimeResolution(intervals: sorted, issues: issues);
  }

  bool _overlaps(List<ResolvedInterval> a, List<ResolvedInterval> b) {
    for (final left in a) {
      for (final right in b) {
        if (left.start.isBefore(right.end) && right.start.isBefore(left.end)) {
          return true;
        }
      }
    }
    return false;
  }

  int _compareOccurrences(EventOccurrence a, EventOccurrence b) {
    final dayOrder = a.date.compareTo(b.date);
    if (dayOrder != 0) return dayOrder;
    final aStart =
        resolveOccurrence(a).intervals.firstOrNull?.start ??
        a.intervals.firstOrNull?.start ??
        a.date.toDateTime();
    final bStart =
        resolveOccurrence(b).intervals.firstOrNull?.start ??
        b.intervals.firstOrNull?.start ??
        b.date.toDateTime();
    return aStart.compareTo(bStart);
  }
}

extension _IterableFirst<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
