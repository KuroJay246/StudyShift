import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/open_meteo_weather_service.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/weather_repository.dart';

void main() {
  late ScheduleDatabase database;
  late PreferencesRepository preferences;
  late _FakeWeatherService service;
  late WeatherRepository repository;
  final place = WeatherPlace(
    name: 'Bridgetown',
    label: 'Bridgetown, Barbados',
    latitude: 13.0975,
    longitude: -59.6167,
  );
  final snapshot = WeatherSnapshot(
    observedAt: DateTime(2026, 11, 14, 12),
    temperatureC: 29,
    apparentTemperatureC: 32,
    windSpeedKmh: 18,
    precipitationProbability: 20,
    weatherCode: 2,
    isDay: true,
    sunrise: DateTime(2026, 11, 14, 5, 52),
    sunset: DateTime(2026, 11, 14, 17, 30),
    hourlyForecast: [
      HourlyWeatherForecast(
        localTime: DateTime(2026, 11, 14, 13),
        temperatureC: 28,
        weatherCode: 61,
        isDay: true,
        windSpeedKmh: 15,
        precipitationProbability: 65,
      ),
    ],
  );

  setUp(() {
    database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    preferences = PreferencesRepository(database);
    service = _FakeWeatherService(snapshot);
    repository = WeatherRepository(preferences: preferences, service: service);
  });
  tearDown(() async => database.close());

  Future<void> configure({required bool enabled}) async {
    await preferences.setWeatherEnabled(enabled);
    await preferences.setWeatherLocation(
      jsonEncode({
        'name': place.name,
        'label': place.label,
        'latitude': place.latitude,
        'longitude': place.longitude,
      }),
    );
  }

  test('disabled weather never makes a provider request', () async {
    await configure(enabled: false);

    expect(await repository.load(await preferences.load()), isNull);
    expect(service.requestCount, 0);
  });

  test('opted-in weather is fetched and saved for offline fallback', () async {
    await configure(enabled: true);

    final reading = await repository.load(await preferences.load());
    final saved = await preferences.load();

    expect(reading?.place.label, 'Bridgetown, Barbados');
    expect(reading?.snapshot.temperatureC, 29);
    expect(reading?.isCached, isFalse);
    expect(saved.weatherSnapshotJson, contains('Bridgetown'));
    expect(saved.weatherSnapshotJson, contains('29.0'));
  });

  test('provider failure returns the last locally cached conditions', () async {
    await configure(enabled: true);
    await repository.load(await preferences.load());
    service.shouldFail = true;

    final reading = await repository.load(await preferences.load());

    expect(reading?.snapshot.temperatureC, 29);
    expect(reading?.isCached, isTrue);
    expect(reading?.snapshot.hourlyForecast.single.weatherCode, 61);
    expect(
      reading?.snapshot.hourlyForecast.single.precipitationProbability,
      65,
    );
  });

  test(
    'provider failure never shows a different saved place as current',
    () async {
      await configure(enabled: true);
      await repository.load(await preferences.load());
      await preferences.setWeatherLocation(
        jsonEncode({
          'name': 'Bristol',
          'label': 'Bristol, United Kingdom',
          'latitude': 51.4545,
          'longitude': -2.5879,
        }),
      );
      service.shouldFail = true;

      expect(
        repository.load(await preferences.load()),
        throwsA(isA<WeatherUnavailableException>()),
      );
    },
  );

  test(
    'saved weather places can be cycled without changing schedule time',
    () async {
      final bristol = const WeatherPlace(
        name: 'Bristol',
        label: 'Bristol, United Kingdom',
        latitude: 51.4545,
        longitude: -2.5879,
      );
      await preferences.setWeatherLocations(
        jsonEncode([
          {
            'name': place.name,
            'label': place.label,
            'latitude': place.latitude,
            'longitude': place.longitude,
          },
          {
            'name': bristol.name,
            'label': bristol.label,
            'latitude': bristol.latitude,
            'longitude': bristol.longitude,
          },
        ]),
      );
      await configure(enabled: true);
      final loaded = await preferences.load();

      final places = weatherPlacesFor(loaded);
      expect(places.map((p) => p.name), ['Bridgetown', 'Bristol']);
      expect(cycleWeatherPlace(loaded, place, 1)?.name, 'Bristol');
      expect(cycleWeatherPlace(loaded, bristol, 1)?.name, 'Bridgetown');
      expect(cycleWeatherPlace(loaded, place, -1)?.name, 'Bristol');
      expect(loaded.weatherLocationJson, contains('Bridgetown'));
    },
  );

  test(
    'weather local clock applies the saved place offset to a UTC instant',
    () {
      final local = WeatherSnapshot(
        observedAt: snapshot.observedAt,
        temperatureC: snapshot.temperatureC,
        apparentTemperatureC: snapshot.apparentTemperatureC,
        windSpeedKmh: snapshot.windSpeedKmh,
        precipitationProbability: snapshot.precipitationProbability,
        weatherCode: snapshot.weatherCode,
        isDay: snapshot.isDay,
        sunrise: snapshot.sunrise,
        sunset: snapshot.sunset,
        utcOffsetSeconds: -14400,
      ).localClockAt(DateTime.utc(2026, 11, 14, 16, 30));

      expect(local, DateTime.utc(2026, 11, 14, 12, 30));
    },
  );

  test(
    'invalid saved coordinates are ignored before any network call',
    () async {
      await preferences.setWeatherEnabled(true);
      await preferences.setWeatherLocation(
        '{"name":"Unknown","label":"Unknown","latitude":999,"longitude":0}',
      );

      expect(await repository.load(await preferences.load()), isNull);
      expect(service.requestCount, 0);
    },
  );
}

class _FakeWeatherService extends OpenMeteoWeatherService {
  _FakeWeatherService(this.snapshot)
    : super(
        geocodingEndpoint: Uri.parse('http://127.0.0.1/geocoding'),
        forecastEndpoint: Uri.parse('http://127.0.0.1/forecast'),
      );

  final WeatherSnapshot snapshot;
  bool shouldFail = false;
  int requestCount = 0;

  @override
  Future<WeatherSnapshot> currentWeather(WeatherPlace place) async {
    requestCount++;
    if (shouldFail) throw const SocketException('offline');
    return snapshot;
  }
}
