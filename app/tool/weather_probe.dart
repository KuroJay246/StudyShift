import 'package:shift_study/data/open_meteo_weather_service.dart';

Future<void> main() async {
  final service = OpenMeteoWeatherService();
  final places = await service.searchPlaces('Bridgetown');
  final place = places.where(
    (value) => value.name == 'Bridgetown' && value.label.contains('Barbados'),
  );
  if (place.isEmpty) {
    throw StateError('Open-Meteo did not return the synthetic Barbados place.');
  }
  final weather = await service.currentWeather(place.first);
  if (!weather.temperatureC.isFinite ||
      !weather.apparentTemperatureC.isFinite ||
      !weather.windSpeedKmh.isFinite ||
      weather.weatherCode < 0) {
    throw StateError('Open-Meteo returned incomplete weather data.');
  }
}
