import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/open_meteo_weather_service.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/presentation/screens/weather_settings_page.dart';

class _WeatherService extends OpenMeteoWeatherService {
  var searches = 0;
  var forecasts = 0;

  @override
  Future<List<WeatherPlace>> searchPlaces(String query) async {
    searches++;
    return const [
      WeatherPlace(
        name: 'Bridgetown',
        label: 'Bridgetown, Saint Michael, Barbados',
        latitude: 13.10732,
        longitude: -59.62021,
      ),
    ];
  }

  @override
  Future<WeatherSnapshot> currentWeather(WeatherPlace place) async {
    forecasts++;
    return WeatherSnapshot(
      observedAt: DateTime(2026, 11, 14, 12),
      temperatureC: 29.8,
      apparentTemperatureC: 30.7,
      windSpeedKmh: 17,
      precipitationProbability: 10,
      weatherCode: 2,
      isDay: true,
      sunrise: DateTime(2026, 11, 14, 5, 56),
      sunset: DateTime(2026, 11, 14, 17, 28),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('weather starts offline until a place is searched and selected', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final service = _WeatherService();
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        openMeteoWeatherServiceProvider.overrideWith((ref) => service),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: const WeatherSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Approximate coordinates are sent only when you choose a place or '
        'refresh weather. '
        'StudyShift never uses background location.',
      ),
      findsOneWidget,
    );
    expect(service.searches, 0);
    expect(service.forecasts, 0);
    expect(
      (await PreferencesRepository(database).load()).weatherEnabled,
      isNot(true),
    );

    await tester.tap(find.text('Choose a place'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Bridgetown');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(service.searches, 1);
    expect(service.forecasts, 0);
    expect(find.text('Bridgetown, Saint Michael, Barbados'), findsOneWidget);

    await tester.tap(find.text('Bridgetown, Saint Michael, Barbados'));
    await tester.pumpAndSettle();

    final saved = await PreferencesRepository(database).load();
    expect(saved.weatherEnabled, isTrue);
    expect(saved.weatherLocationJson, contains('13.10732'));
    expect(service.forecasts, 1);
    expect(find.text('30°C · Partly cloudy'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text('Today preview'), findsOneWidget);
    expect(find.text('Bridgetown · Partly cloudy'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-weather-sun')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-weather-cloud')), findsOneWidget);
  });

  testWidgets('weather detail controls save and apply to Today preferences', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: const WeatherSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Layout'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('More details'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Wind speed'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Wind speed'));
    await tester.pumpAndSettle();

    final saved = await PreferencesRepository(database).load();
    expect(saved.effectiveWeatherLayout, WeatherLayout.moreDetails);
    expect(saved.showWeatherWindSpeed, isTrue);
  });

  testWidgets('location is requested only after consent and then saved', (
    tester,
  ) async {
    const locationChannel = MethodChannel('app.shiftstudy/location');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var locationRequests = 0;
    messenger.setMockMethodCallHandler(locationChannel, (call) async {
      locationRequests++;
      expect(call.method, 'getApproximateLocation');
      return {'latitude': 13.1, 'longitude': -59.6};
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(locationChannel, null),
    );

    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final service = _WeatherService();
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        openMeteoWeatherServiceProvider.overrideWith((ref) => service),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: const WeatherSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(locationRequests, 0);
    await tester.tap(find.text('Use my location'));
    await tester.pumpAndSettle();
    expect(locationRequests, 0);
    await tester.tap(find.text('Use location'));
    await tester.pumpAndSettle();

    final saved = await PreferencesRepository(database).load();
    expect(locationRequests, 1);
    expect(saved.weatherLocationJson, contains('Current area'));
    expect(saved.weatherEnabled, isTrue);
  });

  testWidgets('an unavailable location explains the manual fallback', (
    tester,
  ) async {
    const locationChannel = MethodChannel('app.shiftstudy/location');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(locationChannel, (call) async {
      throw PlatformException(code: 'location_unavailable');
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(locationChannel, null),
    );

    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: const WeatherSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use my location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use location'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The device could not get a location fix. Check Location is on, '
        'or choose a place manually.',
      ),
      findsOneWidget,
    );
    expect(find.text('Choose a place manually'), findsOneWidget);
  });
}
