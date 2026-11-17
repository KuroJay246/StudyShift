import 'package:flutter/services.dart';

enum WidgetFamily { nextEvent, today, week, nextClass, upcomingDeadline }

/// Requests that the current Android launcher pin the schedule widget.
/// `true` means the launcher accepted the request; the user may still decline.
class WidgetPinRequester {
  WidgetPinRequester({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('app.shiftstudy/widget');

  final MethodChannel _channel;

  Future<int> installedInstanceCount() async =>
      await _channel.invokeMethod<int>('instanceCount') ?? 0;

  Future<bool> requestPin(WidgetFamily family) async =>
      await _channel.invokeMethod<bool>('requestPin', {
        'family': family.name,
      }) ??
      false;
}
