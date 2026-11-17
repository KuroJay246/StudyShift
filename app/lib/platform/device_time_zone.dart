import 'package:flutter/services.dart';

abstract interface class DeviceTimeZone {
  Future<String> getLocalIanaId();
}

class AndroidDeviceTimeZone implements DeviceTimeZone {
  const AndroidDeviceTimeZone();

  static const _channel = MethodChannel('app.shiftstudy/time_zone');

  @override
  Future<String> getLocalIanaId() async {
    final id = await _channel.invokeMethod<String>('localIanaTimeZone');
    if (id == null || id.isEmpty) throw StateError('Android did not return a time-zone ID.');
    return id;
  }
}
