import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/platform/clock_alarm_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.shiftstudy/clock_alarm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('offers a one-time Clock alarm only within the next 24 hours', () {
    final now = DateTime(2026, 11, 14, 18);
    expect(
      canOfferClockAlarm(now.add(const Duration(minutes: 30)), now: now),
      isTrue,
    );
    expect(
      canOfferClockAlarm(now.add(const Duration(hours: 25)), now: now),
      isFalse,
    );
    expect(canOfferClockAlarm(now, now: now), isFalse);
  });

  test('passes the event instant and label to Android Clock', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final eventStart = DateTime.now().add(const Duration(minutes: 30));

    final opened = await const ClockAlarmBridge().openAlarm(
      eventStart: eventStart,
      label: 'Shift starts',
    );

    expect(opened, isTrue);
    expect(received?.method, 'openAlarm');
    expect(received?.arguments, {
      'eventStartMillis': eventStart.millisecondsSinceEpoch,
      'label': 'Shift starts',
    });
  });

  test('Android manifest declares the standard alarm handoff permission', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    expect(manifest, contains('com.android.alarm.permission.SET_ALARM'));
  });
}
