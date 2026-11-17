import '../domain/schedule.dart';
import '../domain/schedule_engine.dart';

class UpcomingScheduleEntry {
  const UpcomingScheduleEntry({
    required this.occurrence,
    required this.interval,
  });
  final EventOccurrence occurrence;
  final ResolvedInterval interval;
}

/// Shared read logic for Today, Week, conflict summaries and the Android
/// widget snapshot. Views call the same queries so their data stays aligned.
class ScheduleQueries {
  const ScheduleQueries(this._engine);
  final ScheduleEngine _engine;

  OccurrenceTimeResolution resolveOccurrence(EventOccurrence occurrence) =>
      _engine.resolveOccurrence(occurrence);

  List<EventOccurrence> forDay(Iterable<ScheduleItem> items, CivilDate day) =>
      forRange(items, day, day);

  List<EventOccurrence> forWeek(
    Iterable<ScheduleItem> items,
    CivilDate firstDay,
  ) => forRange(items, firstDay, firstDay.addDays(6));

  List<EventOccurrence> forRange(
    Iterable<ScheduleItem> items,
    CivilDate firstDay,
    CivilDate lastDay,
  ) {
    if (lastDay.compareTo(firstDay) < 0) {
      throw ArgumentError('Range end precedes start.');
    }
    final stableItems = List<ScheduleItem>.unmodifiable(items);
    final lookBack = stableItems
        .expand((item) => item.intervals)
        .fold<int>(
          1,
          (days, interval) =>
              interval.endDayOffset > days ? interval.endDayOffset : days,
        );
    if (lookBack > 3660) {
      throw ArgumentError('Event duration is too long to query safely.');
    }
    final searchStart = firstDay.addDays(-lookBack);
    return _engine
        .expand(stableItems, searchStart, lastDay)
        .where((occurrence) {
          if (occurrence.item.hasNoTime) {
            return occurrence.date.compareTo(firstDay) >= 0;
          }
          return occurrence.item.intervals.any((interval) {
            final startDate = occurrence.date.addDays(interval.startDayOffset);
            final endDate = occurrence.date.addDays(interval.endDayOffset);
            final startsByRangeEnd = startDate.compareTo(lastDay) <= 0;
            final endsAfterRangeStart =
                endDate.compareTo(firstDay) > 0 ||
                (endDate == firstDay && interval.endMinute > 0);
            return startsByRangeEnd && endsAfterRangeStart;
          });
        })
        .toList(growable: false);
  }

  List<ScheduleConflict> conflictsForRange(
    Iterable<ScheduleItem> items,
    CivilDate firstDay,
    CivilDate lastDay,
  ) => _engine.conflicts(forRange(items, firstDay, lastDay));

  ScheduleAnalysis analyzeRange(
    Iterable<ScheduleItem> items,
    CivilDate firstDay,
    CivilDate lastDay,
  ) => _engine.analyze(forRange(items, firstDay, lastDay));

  UpcomingScheduleEntry? nextUpcoming(
    Iterable<ScheduleItem> items,
    DateTime now, {
    int searchDays = 366,
  }) {
    if (searchDays < 1 || searchDays > 3660) {
      throw ArgumentError.value(
        searchDays,
        'searchDays',
        'Use 1 to 3660 days.',
      );
    }
    final today = CivilDate.fromDateTime(now);
    final through = today.addDays(searchDays);
    UpcomingScheduleEntry? next;
    for (final occurrence in forRange(items, today, through)) {
      for (final interval in _engine.resolveOccurrence(occurrence).intervals) {
        if (!interval.start.isBefore(now) &&
            (next == null || interval.start.isBefore(next.interval.start))) {
          next = UpcomingScheduleEntry(
            occurrence: occurrence,
            interval: interval,
          );
        }
      }
    }
    return next;
  }

  /// Returns the active timed interval, if any, at the supplied instant.
  /// Searching adjacent local dates keeps overnight events visible.
  UpcomingScheduleEntry? currentlyHappening(
    Iterable<ScheduleItem> items,
    DateTime now,
  ) {
    final active = currentlyHappeningEntries(items, now);
    return active.isEmpty ? null : active.first;
  }

  /// Returns every distinct active occurrence, newest start first.
  List<UpcomingScheduleEntry> currentlyHappeningEntries(
    Iterable<ScheduleItem> items,
    DateTime now,
  ) {
    final today = CivilDate.fromDateTime(now);
    final activeByOccurrence = <String, UpcomingScheduleEntry>{};
    for (final occurrence in forRange(
      items,
      today.addDays(-2),
      today.addDays(1),
    )) {
      for (final interval in _engine.resolveOccurrence(occurrence).intervals) {
        if (!interval.start.isAfter(now) && interval.end.isAfter(now)) {
          final key = '${occurrence.item.id}\u0000${occurrence.date}';
          final previous = activeByOccurrence[key];
          if (previous == null ||
              interval.start.isAfter(previous.interval.start)) {
            activeByOccurrence[key] = UpcomingScheduleEntry(
              occurrence: occurrence,
              interval: interval,
            );
          }
        }
      }
    }
    return activeByOccurrence.values.toList()..sort(
      (left, right) => right.interval.start.compareTo(left.interval.start),
    );
  }
}
