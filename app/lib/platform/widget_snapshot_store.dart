import 'package:flutter/services.dart';

/// Persists a compact schedule projection in app-private Android preferences.
/// Native Android widgets read this snapshot and never access Drift directly.
class WidgetSnapshotStore {
  WidgetSnapshotStore({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('app.shiftstudy/widget_snapshot');

  final MethodChannel _channel;

  Future<void> save(String snapshotJson) async {
    final saved = await _channel.invokeMethod<bool>('saveSnapshot', snapshotJson);
    if (saved != true) {
      throw PlatformException(
        code: 'snapshot_not_saved',
        message: 'Android could not persist the latest widget schedule snapshot.',
      );
    }
  }
}
