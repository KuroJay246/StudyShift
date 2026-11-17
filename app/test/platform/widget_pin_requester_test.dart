import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/platform/widget_pin_requester.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.shiftstudy/widget');

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('requests the selected widget family from the launcher', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'requestPin');
          expect(call.arguments, {'family': 'today'});
          return true;
        });

    expect(
      await WidgetPinRequester(channel: channel).requestPin(WidgetFamily.today),
      isTrue,
    );
  });

  test('returns false when the launcher cannot request a pin', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => false);

    expect(
      await WidgetPinRequester(channel: channel)
          .requestPin(WidgetFamily.nextEvent),
      isFalse,
    );
  });

  test('requests the dedicated next class and deadline widgets', () async {
    final families = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          families.add((call.arguments as Map)['family'] as String);
          return true;
        });

    final requester = WidgetPinRequester(channel: channel);
    await requester.requestPin(WidgetFamily.nextClass);
    await requester.requestPin(WidgetFamily.upcomingDeadline);

    expect(families, ['nextClass', 'upcomingDeadline']);
  });

  test('reads the count of widgets pinned in the current launcher', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'instanceCount');
          return 1;
        });

    expect(
      await WidgetPinRequester(channel: channel).installedInstanceCount(),
      1,
    );
  });
}
