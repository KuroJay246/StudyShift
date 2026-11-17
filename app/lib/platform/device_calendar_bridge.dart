import 'package:flutter/services.dart';

/// Opens the device calendar's event editor with a user-reviewed draft.
/// StudyShift never reads or writes existing calendar records through this
/// bridge; the user decides whether and where to save the draft.
class DeviceCalendarBridge {
  const DeviceCalendarBridge();

  static const _channel = MethodChannel('app.shiftstudy/device_calendar');

  Future<bool> openDraft({
    required String title,
    required int startMillis,
    required int endMillis,
    required bool allDay,
    String? location,
    String? description,
  }) async {
    if (title.trim().isEmpty || endMillis <= startMillis) {
      throw ArgumentError('A calendar draft needs a title and valid times.');
    }
    return await _channel.invokeMethod<bool>('openEventDraft', {
          'title': title.trim(),
          'startMillis': startMillis,
          'endMillis': endMillis,
          'allDay': allDay,
          if (location?.trim().isNotEmpty ?? false)
            'location': location!.trim(),
          if (description?.trim().isNotEmpty ?? false)
            'description': description!.trim(),
        }) ??
        false;
  }
}
