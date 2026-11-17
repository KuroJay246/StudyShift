import 'package:flutter/services.dart';

class ScheduleBackupFileBridge {
  const ScheduleBackupFileBridge();

  static const _channel = MethodChannel('app.shiftstudy/backup');

  Future<bool> save(Uint8List bytes, {required String fileName}) async =>
      await _channel.invokeMethod<bool>('saveBackup', {
        'bytes': bytes,
        'fileName': fileName,
      }) ??
      false;

  Future<Uint8List?> open() => _channel.invokeMethod<Uint8List?>('openBackup');
}
