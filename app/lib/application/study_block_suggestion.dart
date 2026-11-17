import '../domain/schedule.dart';
import 'day_availability.dart';

/// A deterministic, editable proposal contained entirely within free time.
class StudyBlockSuggestion {
  const StudyBlockSuggestion({
    required this.date,
    required this.startMinute,
    required this.endMinute,
  });

  static const duration = Duration(minutes: 60);

  final CivilDate date;
  final int startMinute;
  final int endMinute;

  static StudyBlockSuggestion? firstIn(Iterable<AvailablePeriod> periods) {
    for (final period in periods) {
      final subMinute = Duration(
        seconds: period.start.second,
        milliseconds: period.start.millisecond,
        microseconds: period.start.microsecond,
      );
      final roundUp = subMinute == Duration.zero
          ? Duration.zero
          : const Duration(minutes: 1) - subMinute;
      if (period.end.difference(period.start) < roundUp + duration) continue;
      final startMinute =
          period.start.hour * 60 +
          period.start.minute +
          (roundUp == Duration.zero ? 0 : 1);
      final endMinute = (startMinute + duration.inMinutes) % (24 * 60);
      return StudyBlockSuggestion(
        date: CivilDate.fromDateTime(period.start),
        startMinute: startMinute,
        endMinute: endMinute,
      );
    }
    return null;
  }
}
