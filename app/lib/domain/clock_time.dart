/// A time of day represented as minutes after midnight, independent of the
/// user's 12/24-hour presentation preference.
class ClockTime {
  const ClockTime(this.minuteOfDay);

  final int minuteOfDay;

  bool get isValid => minuteOfDay >= 0 && minuteOfDay < 1440;

  static ClockTime parse(String input) {
    final value = input.trim();
    final twelveHour = RegExp(r'^(1[0-2]|[1-9]):([0-5][0-9])\s*(AM|PM)$', caseSensitive: false).firstMatch(value);
    if (twelveHour != null) {
      final hour = int.parse(twelveHour.group(1)!);
      final minute = int.parse(twelveHour.group(2)!);
      final suffix = twelveHour.group(3)!.toUpperCase();
      return ClockTime((hour % 12 + (suffix == 'PM' ? 12 : 0)) * 60 + minute);
    }
    final twentyFourHour = RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$').firstMatch(value);
    if (twentyFourHour != null) {
      final fields = value.split(':').map(int.parse).toList();
      return ClockTime(fields[0] * 60 + fields[1]);
    }
    throw FormatException('Enter a time as HH:mm or h:mm AM/PM.');
  }

  String format({required bool use24Hour}) {
    if (!isValid) throw RangeError.range(minuteOfDay, 0, 1439, 'minuteOfDay');
    final hour = minuteOfDay ~/ 60;
    final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
    if (use24Hour) return '${hour.toString().padLeft(2, '0')}:$minute';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute ${hour < 12 ? 'AM' : 'PM'}';
  }
}
