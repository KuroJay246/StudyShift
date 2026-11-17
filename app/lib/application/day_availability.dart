import 'package:timezone/timezone.dart' as tz;

import '../domain/civil_time_resolver.dart';
import '../domain/schedule.dart';
import '../domain/schedule_engine.dart';

class AvailablePeriod {
  const AvailablePeriod({required this.start, required this.end});

  /// Instants rendered in the user's device time zone.
  final DateTime start;
  final DateTime end;
}

/// Calculates only periods whose event times can be resolved without guessing.
class DayAvailability {
  const DayAvailability(this._engine);

  final ScheduleEngine _engine;

  List<AvailablePeriod>? calculate({
    required Iterable<EventOccurrence> occurrences,
    required CivilDate date,
    required String deviceTimeZoneId,
    required DateTime now,
  }) {
    final resolver = CivilTimeResolver();
    final tz.Location location;
    try {
      location = tz.getLocation(deviceTimeZoneId);
    } on tz.LocationNotFoundException {
      return null;
    }

    final dayStart = resolver.resolve(date, 0, deviceTimeZoneId).select(null);
    final nextDay = date.addDays(1);
    final dayEnd = resolver.resolve(nextDay, 0, deviceTimeZoneId).select(null);
    if (dayStart == null || dayEnd == null) return null;

    final nowInZone = tz.TZDateTime.from(now, location);
    var cursor = nowInZone.isAfter(dayStart) ? nowInZone : dayStart;
    if (!cursor.isBefore(dayEnd)) return const [];

    final busy = <ResolvedInterval>[];
    for (final occurrence in occurrences) {
      if (occurrence.item.hasNoTime || occurrence.item.intervals.isEmpty) {
        continue;
      }
      // Old records with no stored zone cannot be compared safely against the
      // device day, so leave availability blank until the user reviews them.
      if (occurrence.item.timeZoneId == null) return null;
      final resolved = _engine.resolveOccurrence(occurrence);
      if (resolved.issues.isNotEmpty) return null;
      for (final interval in resolved.intervals) {
        final start = interval.start.isAfter(cursor) ? interval.start : cursor;
        final end = interval.end.isBefore(dayEnd) ? interval.end : dayEnd;
        if (end.isAfter(start)) {
          busy.add(ResolvedInterval(start: start, end: end));
        }
      }
    }

    final points = <DateTime>[
      cursor,
      dayEnd,
      for (final interval in busy) interval.start,
      for (final interval in busy) interval.end,
    ]..sort((a, b) => a.compareTo(b));
    final periods = <AvailablePeriod>[];
    for (var index = 0; index + 1 < points.length; index++) {
      final start = points[index];
      final end = points[index + 1];
      if (!end.isAfter(start) || end.difference(start).inMinutes < 30) {
        continue;
      }
      // Local clock labels become ambiguous across a DST transition. Omit
      // those gaps instead of presenting a misleading duration or wall time.
      final localStart = tz.TZDateTime.from(start, location);
      final localEnd = tz.TZDateTime.from(end, location);
      if (localStart.timeZoneOffset != localEnd.timeZoneOffset) continue;
      final midpoint = start.add(end.difference(start) ~/ 2);
      // The sorted boundary points alternate between free and occupied
      // spans. Check the midpoint against the resolved busy intervals.
      final isBusy = busy.any(
        (interval) =>
            !midpoint.isBefore(interval.start) &&
            midpoint.isBefore(interval.end),
      );
      if (!isBusy) {
        periods.add(AvailablePeriod(start: localStart, end: localEnd));
      }
    }
    return List.unmodifiable(periods);
  }
}
