import 'package:flutter/services.dart';

/// Opens the app's notification controls without changing their permission.
class NotificationSettingsBridge {
  const NotificationSettingsBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('app.shiftstudy/settings');

  final MethodChannel _channel;

  Future<bool> openNotificationSettings() async =>
      await _channel.invokeMethod<bool>('openNotificationSettings') ?? false;

  Future<bool> openExactAlarmSettings() async =>
      await _channel.invokeMethod<bool>('openExactAlarmSettings') ?? false;

  Future<bool> wasNotificationPermissionRequested() async =>
      await _channel.invokeMethod<bool>('wasNotificationPermissionRequested') ??
      false;

  Future<void> recordNotificationPermissionRequest() async {
    await _channel.invokeMethod<void>('recordNotificationPermissionRequest');
  }
}
