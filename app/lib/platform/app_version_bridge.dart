import 'package:flutter/services.dart';

class InstalledAppVersion {
  const InstalledAppVersion({required this.name, required this.code});

  final String name;
  final int code;

  String get label => 'Version $name ($code)';

  static InstalledAppVersion fromPlatformValue(Object? value) {
    if (value is! Map) {
      throw const FormatException('App version information is unavailable.');
    }
    final name = value['name'];
    final code = value['code'];
    if (name is! String || name.trim().isEmpty || code is! int || code <= 0) {
      throw const FormatException('App version information is invalid.');
    }
    return InstalledAppVersion(name: name.trim(), code: code);
  }
}

class AppVersionBridge {
  const AppVersionBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('app.shiftstudy/app_version');

  final MethodChannel _channel;

  Future<InstalledAppVersion> readInstalledVersion() async =>
      InstalledAppVersion.fromPlatformValue(
        await _channel.invokeMethod<Object?>('getAppVersion'),
      );
}
