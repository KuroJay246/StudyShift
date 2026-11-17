import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'schedule.dart';

enum CivilTimeStatus { unique, ambiguous, nonexistent, invalidTimeZone }

class CivilTimeResolution {
  const CivilTimeResolution(this.status, this.candidates);
  final CivilTimeStatus status;

  /// UTC instants rendered in the requested IANA zone. Two candidates mean a
  /// repeated wall time at a fall-back transition; callers must ask the user.
  final List<tz.TZDateTime> candidates;

  tz.TZDateTime? select(CivilTimeFoldChoice? foldChoice) => switch (status) {
    CivilTimeStatus.unique => candidates.single,
    CivilTimeStatus.ambiguous => switch (foldChoice) {
      CivilTimeFoldChoice.earlier => candidates.first,
      CivilTimeFoldChoice.later => candidates.last,
      null => null,
    },
    CivilTimeStatus.nonexistent => null,
    CivilTimeStatus.invalidTimeZone => null,
  };
}

class CivilTimeResolver {
  CivilTimeResolver() {
    if (!_initialized) {
      tzdata.initializeTimeZones();
      _initialized = true;
    }
  }

  static bool _initialized = false;

  CivilTimeResolution resolve(
    CivilDate date,
    int minuteOfDay,
    String ianaZoneId,
  ) {
    if (!date.isValid || minuteOfDay < 0 || minuteOfDay >= 1440) {
      throw ArgumentError('Date or minute-of-day is outside its valid range.');
    }
    final tz.Location location;
    try {
      location = tz.getLocation(ianaZoneId);
    } on tz.LocationNotFoundException {
      return const CivilTimeResolution(CivilTimeStatus.invalidTimeZone, []);
    }
    final wallAsUtc = DateTime.utc(
      date.year,
      date.month,
      date.day,
      minuteOfDay ~/ 60,
      minuteOfDay % 60,
    );
    final candidateMillis = <int>{};

    // Each known offset is a possible mapping from the wall value to UTC.
    // Re-rendering in the zone removes offsets that were not active then and
    // distinguishes ordinary time, DST folds, and DST gaps without guessing.
    for (final offset
        in location.zones.map((zone) => zone.offset.inMilliseconds).toSet()) {
      final utcMillis = wallAsUtc.millisecondsSinceEpoch - offset;
      final local = tz.TZDateTime.from(
        DateTime.fromMillisecondsSinceEpoch(utcMillis, isUtc: true),
        location,
      );
      if (local.year == date.year &&
          local.month == date.month &&
          local.day == date.day &&
          local.hour == minuteOfDay ~/ 60 &&
          local.minute == minuteOfDay % 60) {
        candidateMillis.add(utcMillis);
      }
    }
    final candidates = candidateMillis.toList()..sort();
    final zoned = candidates
        .map(
          (ms) => tz.TZDateTime.from(
            DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
            location,
          ),
        )
        .toList(growable: false);
    final status = switch (zoned.length) {
      0 => CivilTimeStatus.nonexistent,
      1 => CivilTimeStatus.unique,
      _ => CivilTimeStatus.ambiguous,
    };
    return CivilTimeResolution(status, zoned);
  }
}
