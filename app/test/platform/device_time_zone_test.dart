import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/platform/device_time_zone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.shiftstudy/time_zone');
  const source = AndroidDeviceTimeZone();

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('reads an IANA timezone ID through the Android bridge', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'localIanaTimeZone');
      return 'America/Barbados';
    });
    expect(await source.getLocalIanaId(), 'America/Barbados');
  });

  test('fails visibly when Android returns no timezone ID', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    await expectLater(source.getLocalIanaId(), throwsStateError);
  });
}
