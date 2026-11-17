import 'package:flutter/services.dart';

class ScheduleExportFileBridge {
  const ScheduleExportFileBridge();

  static const _channel = MethodChannel('app.shiftstudy/export');

  Future<bool> save(Uint8List bytes, {required String fileName}) async =>
      await _channel.invokeMethod<bool>('saveCalendar', {
        'bytes': bytes,
        'fileName': fileName,
      }) ??
      false;
}
