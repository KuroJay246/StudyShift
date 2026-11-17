import 'dart:convert';

import '../application/schedule_queries.dart';
import '../domain/schedule.dart';
import '../domain/schedule_engine.dart';

/// Versioned, privacy-local projection shared with native Android widgets.
/// The widget never opens the app's SQLite database directly.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.generatedAt,
    required this.today,
    required this.todayResolutions,
    required this.next,
    required this.nextByFilter,
    required this.nextAllDayByFilter,
    required this.upcoming,
    required this.throughDate,
  });

  final DateTime generatedAt;
  final List<EventOccurrence> today;
  final List<OccurrenceTimeResolution> todayResolutions;
  final UpcomingScheduleEntry? next;
  final Map<String, UpcomingScheduleEntry?> nextByFilter;
  final Map<
    String,
    ({EventOccurrence occurrence, OccurrenceTimeResolution resolution})?
  >
  nextAllDayByFilter;
  final List<
    ({EventOccurrence occurrence, OccurrenceTimeResolution resolution})
  >
  upcoming;
  final CivilDate throughDate;

  factory WidgetSnapshot.forSchedule({
    required Iterable<ScheduleItem> items,
    required ScheduleQueries queries,
    required DateTime now,
  }) {
    final stableItems = List<ScheduleItem>.unmodifiable(items);
    final today = CivilDate.fromDateTime(now);
    final through = today.addDays(30);
    final occurrences = queries.forDay(stableItems, today);
    final allDayDeadlines = queries
        .forRange(
          stableItems.where(
            (item) =>
                item.kind == ScheduleKind.deadline && item.hasNoTime,
          ),
          today,
          today.addDays(366),
        )
        .where((occurrence) {
          return queries.resolveOccurrence(occurrence).intervals.isEmpty;
        })
        .toList(growable: false)
      ..sort((left, right) {
        final dateOrder = left.date.compareTo(right.date);
        return dateOrder != 0
            ? dateOrder
            : left.item.title.compareTo(right.item.title);
      });
    final nextAllDayDeadline = allDayDeadlines.isEmpty
        ? null
        : allDayDeadlines.first;
    final upcoming = queries
        .forRange(stableItems, today, through)
        .map(
          (occurrence) => (
            occurrence: occurrence,
            resolution: queries.resolveOccurrence(occurrence),
          ),
        )
        .toList(growable: false);
    return WidgetSnapshot(
      generatedAt: now,
      today: occurrences,
      todayResolutions: occurrences
          .map(queries.resolveOccurrence)
          .toList(growable: false),
      next: queries.nextUpcoming(stableItems, now),
      nextByFilter: {
        'all': queries.nextUpcoming(stableItems, now),
        'work': queries.nextUpcoming(
          stableItems.where((item) => item.kind == ScheduleKind.work),
          now,
        ),
        'study': queries.nextUpcoming(
          stableItems.where(
            (item) =>
                item.kind == ScheduleKind.classSession ||
                item.kind == ScheduleKind.deadline,
          ),
          now,
        ),
        'class': queries.nextUpcoming(
          stableItems.where((item) => item.kind == ScheduleKind.classSession),
          now,
        ),
        'deadline': queries.nextUpcoming(
          stableItems.where((item) => item.kind == ScheduleKind.deadline),
          now,
        ),
      },
      nextAllDayByFilter: {
        'deadline': nextAllDayDeadline == null
            ? null
            : (
                occurrence: nextAllDayDeadline,
                resolution: queries.resolveOccurrence(nextAllDayDeadline),
              ),
      },
      upcoming: upcoming,
      throughDate: through,
    );
  }

  Map<String, Object?> toJsonMap() => {
    'schemaVersion': 7,
    'generatedAtUtc': generatedAt.toUtc().toIso8601String(),
    'localDate': CivilDate.fromDateTime(generatedAt).toString(),
    'throughDate': throughDate.toString(),
    'today': [
      for (var index = 0; index < today.length; index++)
        _occurrenceMap(today[index], todayResolutions[index]),
    ],
    'next': next == null ? null : _upcomingMap(next!),
    'nextByFilter': {
      for (final entry in nextByFilter.entries)
        entry.key: entry.value == null ? null : _upcomingMap(entry.value!),
    },
    'nextAllDayByFilter': {
      for (final entry in nextAllDayByFilter.entries)
        entry.key: entry.value == null
            ? null
            : _occurrenceMap(entry.value!.occurrence, entry.value!.resolution),
    },
    'upcoming': [
      for (final entry in upcoming)
        _occurrenceMap(entry.occurrence, entry.resolution),
    ],
  };

  String encode() => jsonEncode(toJsonMap());

  Map<String, Object?> _occurrenceMap(
    EventOccurrence occurrence,
    OccurrenceTimeResolution resolution,
  ) => {
    'localDate': occurrence.date.toString(),
    'id': occurrence.item.id,
    'kind': occurrence.item.kind.name,
    'title': occurrence.item.title,
    'timeZoneId': occurrence.item.timeZoneId,
    'code': occurrence.item.code,
    'location': occurrence.item.location,
    'isDayOff': occurrence.item.isDayOff,
    'workCategory': occurrence.item.workCategory?.name,
    'intervals': resolution.intervals.map(_intervalMap).toList(growable: false),
    'timeIssues': resolution.issues
        .map((issue) => issue.kind.name)
        .toList(growable: false),
  };

  Map<String, Object?> _upcomingMap(UpcomingScheduleEntry entry) => {
    ..._occurrenceMap(
      entry.occurrence,
      OccurrenceTimeResolution(intervals: [entry.interval], issues: const []),
    ),
    'nextStartEpochMillis': entry.interval.start.millisecondsSinceEpoch,
  };

  Map<String, int> _intervalMap(ResolvedInterval interval) => {
    'startEpochMillis': interval.start.millisecondsSinceEpoch,
    'endEpochMillis': interval.end.millisecondsSinceEpoch,
  };
}
