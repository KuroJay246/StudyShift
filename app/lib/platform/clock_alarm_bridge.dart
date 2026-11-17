import 'package:flutter/services.dart';

/// Opens the Android Clock app with a user-confirmed one-time alarm draft.
/// Android's standard AlarmClock intent supports a time of day rather than a
/// dated event, so this handoff is offered only for the next 24 hours.
class ClockAlarmBridge {
  const ClockAlarmBridge();

  static const _channel = MethodChannel('app.shiftstudy/clock_alarm');

  Future<bool> openAlarm({
    required DateTime eventStart,
    required String label,
  }) async {
    if (!canOfferClockAlarm(eventStart) || label.trim().isEmpty) return false;
    return await _channel.invokeMethod<bool>('openAlarm', {
          'eventStartMillis': eventStart.millisecondsSinceEpoch,
          'label': label.trim(),
        }) ??
        false;
  }
}

bool canOfferClockAlarm(DateTime eventStart, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final difference = eventStart.difference(current);
  return difference > Duration.zero && difference <= const Duration(hours: 24);
}
