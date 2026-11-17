import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/platform/approximate_location_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.shiftstudy/location');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('returns a one-time approximate location as a weather place', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getApproximateLocation');
      return {'latitude': 13.1, 'longitude': -59.6};
    });

    final place = await const ApproximateWeatherLocationBridge().currentPlace();

    expect(place.name, 'Current area');
    expect(place.label, 'Approximate device location');
    expect(place.latitude, 13.1);
    expect(place.longitude, -59.6);
  });

  test('rejects invalid native coordinates', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'latitude': 91, 'longitude': -59.6},
    );

    expect(
      const ApproximateWeatherLocationBridge().currentPlace(),
      throwsFormatException,
    );
  });
}
