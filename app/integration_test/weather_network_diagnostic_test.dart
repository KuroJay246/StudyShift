import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shift_study/data/open_meteo_weather_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android can reach Open-Meteo geocoding for a synthetic query', (
    tester,
  ) async {
    final places = await OpenMeteoWeatherService().searchPlaces('Bridgetown');
    // Manual network smoke test. This contacts the live provider using only a
    // synthetic public place name; it is intentionally outside the unit suite.
    expect(places, isNotEmpty);
    expect(places.any((place) => place.label.contains('Barbados')), isTrue);
  });
}
