import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/open_meteo_weather_service.dart';

void main() {
  late HttpServer server;
  late OpenMeteoWeatherService service;
  final requests = <HttpRequest>[];

  setUp(() async {
    requests.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request);
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/geocoding') {
        request.response.write(
          jsonEncode({
            'results': [
              {
                'name': 'Bridgetown',
                'admin1': 'Saint Michael',
                'country': 'Barbados',
                'latitude': 13.0975,
                'longitude': -59.6167,
                'timezone': 'America/Barbados',
              },
            ],
          }),
        );
      } else {
        request.response.write(
          jsonEncode({
            'current': {
              'time': '2026-11-14T12:15',
              'temperature_2m': 29.4,
              'apparent_temperature': 32.1,
              'precipitation': 0.0,
              'wind_speed_10m': 18.2,
              'weather_code': 2,
              'is_day': 1,
            },
            'hourly': {
              'time': [
                '2026-11-14T12:00',
                '2026-11-14T13:00',
                '2026-11-14T14:00',
              ],
              'precipitation_probability': [20, 45, 0],
              'temperature_2m': [29.0, 30.5, 28.2],
              'weather_code': [2, 3, 61],
              'is_day': [1, 1, 1],
              'wind_speed_10m': [18.2, 22.0, 19.1],
            },
            'daily': {
              'sunrise': ['2026-11-14T05:52'],
              'sunset': ['2026-11-14T17:30'],
            },
            'utc_offset_seconds': -14400,
          }),
        );
      }
      await request.response.close();
    });
    service = OpenMeteoWeatherService(
      geocodingEndpoint: Uri.parse('http://127.0.0.1:${server.port}/geocoding'),
      forecastEndpoint: Uri.parse('http://127.0.0.1:${server.port}/forecast'),
    );
  });

  tearDown(() async => server.close(force: true));

  test('search returns usable place choices without a provider key', () async {
    final places = await service.searchPlaces(' Bridgetown ');

    expect(places, hasLength(1));
    expect(places.single.name, 'Bridgetown');
    expect(places.single.label, 'Bridgetown, Saint Michael, Barbados');
    expect(places.single.latitude, 13.0975);
    expect(places.single.longitude, -59.6167);
    expect(requests.single.uri.queryParameters['name'], 'Bridgetown');
    expect(requests.single.uri.queryParameters['count'], '8');
  });

  test('weather uses local time to select the current rain chance', () async {
    final place = WeatherPlace(
      name: 'Bridgetown',
      label: 'Bridgetown, Barbados',
      latitude: 13.0975,
      longitude: -59.6167,
    );

    final weather = await service.currentWeather(place);

    expect(weather.temperatureC, 29.4);
    expect(weather.apparentTemperatureC, 32.1);
    expect(weather.windSpeedKmh, 18.2);
    expect(weather.precipitationProbability, 20);
    expect(weather.hourlyForecast, hasLength(2));
    expect(weather.hourlyForecast[0].localTime, DateTime(2026, 11, 14, 13));
    expect(weather.hourlyForecast[0].temperatureC, 30.5);
    expect(weather.hourlyForecast[0].weatherCode, 3);
    expect(weather.hourlyForecast[0].precipitationProbability, 45);
    expect(weather.hourlyForecast[1].weatherCode, 61);
    expect(weather.hourlyForecast[1].precipitationProbability, 0);
    expect(weather.weatherCode, 2);
    expect(weather.isDay, isTrue);
    expect(weather.utcOffsetSeconds, -14400);
    expect(weather.sunrise, DateTime(2026, 11, 14, 5, 52));
    expect(weather.sunset, DateTime(2026, 11, 14, 17, 30));
    expect(requests.single.uri.queryParameters['latitude'], '13.0975');
    expect(requests.single.uri.queryParameters['daily'], contains('sunset'));
    expect(
      requests.single.uri.queryParameters['hourly'],
      contains('precipitation_probability'),
    );
    expect(
      requests.single.uri.queryParameters['hourly'],
      contains('temperature_2m'),
    );
    expect(requests.single.uri.queryParameters['forecast_days'], '2');
    expect(requests.single.uri.queryParameters['timezone'], 'auto');
  });

  test('short search text does not send an unnecessary request', () async {
    expect(await service.searchPlaces(' B '), isEmpty);
    expect(requests, isEmpty);
  });

  test('older saved weather snapshots remain valid without hourly data', () {
    final snapshot = WeatherSnapshot.fromJson({
      'observedAt': '2026-11-14T12:15:00',
      'temperatureC': 29,
      'apparentTemperatureC': 32,
      'windSpeedKmh': 18,
      'precipitationProbability': 20,
      'weatherCode': 2,
      'isDay': true,
      'sunrise': '2026-11-14T05:52:00',
      'sunset': '2026-11-14T17:30:00',
    });

    expect(snapshot.hourlyForecast, isEmpty);
    expect(snapshot.temperatureC, 29);
    expect(snapshot.utcOffsetSeconds, 0);
  });
}
