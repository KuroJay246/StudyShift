import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads the destination passed by a native Android schedule widget tap.
class WidgetLaunchDestinationBridge {
  const WidgetLaunchDestinationBridge();

  static const MethodChannel _channel = MethodChannel('app.shiftstudy/widget');

  Future<String?> getInitialDestination() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final destination = await _channel.invokeMethod<String>(
        'initialDestination',
      );
      return switch (destination) {
        'today' || 'week' || 'work' || 'study' => destination,
        _ => null,
      };
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
