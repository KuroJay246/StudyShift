import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/data/schedule_database.dart';

void main() {
  late ScheduleDatabase database;
  late PreferencesRepository preferences;

  setUp(() {
    database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    preferences = PreferencesRepository(database);
  });
  tearDown(() async => database.close());

  test(
    'schedule mode, time format, appearance and accent persist locally',
    () async {
      await preferences.setScheduleMode(ScheduleMode.workAndSchool);
      await preferences.set24HourTime(true);
      await preferences.setTheme(ThemePreference.dark);
      await preferences.setAccentTheme(AccentTheme.teal);
      final loaded = await preferences.load();
      expect(loaded.scheduleMode, ScheduleMode.workAndSchool);
      expect(loaded.use24HourTime, isTrue);
      expect(loaded.theme, ThemePreference.dark);
      expect(loaded.accentTheme, AccentTheme.teal);
    },
  );

  test('unknown or corrupt local values fall back to unset defaults', () async {
    await database.setPreference('theme', 'unknown-theme');
    await database.setPreference('schedule_mode', 'bad-mode');
    await database.setPreference('use_24_hour_time', 'perhaps');
    final loaded = await preferences.load();
    expect(loaded.theme, isNull);
    expect(loaded.scheduleMode, isNull);
    expect(loaded.use24HourTime, isNull);
  });

  test('overtime thresholds persist separately for each employer', () async {
    await preferences.setOvertimeThreshold('Synthetic Ramp Co', 8 * 60);
    await preferences.setOvertimeThreshold('Synthetic Campus', 7 * 60);

    final loaded = await preferences.load();

    expect(loaded.overtimeThresholdForEmployer(' synthetic  ramp co '), 8 * 60);
    expect(loaded.overtimeThresholdForEmployer('Synthetic Campus'), 7 * 60);
    expect(loaded.overtimeThresholdForEmployer('Another Employer'), isNull);
    expect(
      loaded.overtimeEmployerLabel('synthetic ramp co'),
      'Synthetic Ramp Co',
    );
  });

  test(
    'overtime thresholds can be cleared without affecting other employers',
    () async {
      await preferences.setOvertimeThreshold('Synthetic Ramp Co', 8 * 60);
      await preferences.setOvertimeThreshold('Synthetic Campus', 7 * 60);

      await preferences.clearOvertimeThreshold('SYNTHETIC RAMP CO');
      final loaded = await preferences.load();

      expect(loaded.overtimeThresholdForEmployer('Synthetic Ramp Co'), isNull);
      expect(loaded.overtimeThresholdForEmployer('Synthetic Campus'), 7 * 60);
    },
  );

  test(
    'calendar color choices persist independently from the app accent',
    () async {
      await preferences.setAccentTheme(AccentTheme.teal);
      await preferences.setCalendarColor(
        CalendarColorCategory.work,
        0xFFE91E63,
      );
      await preferences.setCalendarColor(
        CalendarColorCategory.training,
        0xFFFF9800,
      );
      final loaded = await preferences.load();
      expect(loaded.accentTheme, AccentTheme.teal);
      expect(loaded.workColor, 0xFFE91E63);
      expect(loaded.trainingColor, 0xFFFF9800);
      expect(loaded.schoolColor, isNull);
    },
  );

  test(
    'weather opt-in, manually selected place and cached result persist',
    () async {
      await preferences.setWeatherEnabled(true);
      await preferences.setWeatherLocation(
        '{"name":"Bridgetown","label":"Bridgetown, Barbados","latitude":13.0975,"longitude":-59.6167}',
      );
      await preferences.setWeatherSnapshot(
        '{"observedAt":"2026-11-14T12:15:00.000","temperatureC":29.4}',
      );

      final loaded = await preferences.load();

      expect(loaded.weatherEnabled, isTrue);
      expect(loaded.weatherLocationJson, contains('Bridgetown'));
      expect(loaded.weatherSnapshotJson, contains('29.4'));
    },
  );

  test('weather presentation choices persist independently', () async {
    await preferences.setWeatherLayout(WeatherLayout.moreDetails);
    await preferences.setWeatherMetric(WeatherMetric.feelsLike, true);
    await preferences.setWeatherMetric(WeatherMetric.rainChance, false);
    await preferences.setWeatherMetric(WeatherMetric.windSpeed, true);
    await preferences.setWeatherMetric(WeatherMetric.sunriseSunset, true);
    await preferences.setWeatherMetric(WeatherMetric.lastUpdated, false);
    await preferences.setWeatherMetric(
      WeatherMetric.locationAndCondition,
      false,
    );

    final loaded = await preferences.load();

    expect(loaded.weatherLayout, WeatherLayout.moreDetails);
    expect(loaded.weatherShowFeelsLike, isTrue);
    expect(loaded.weatherShowRainChance, isFalse);
    expect(loaded.weatherShowWindSpeed, isTrue);
    expect(loaded.weatherShowSunriseSunset, isTrue);
    expect(loaded.weatherShowLastUpdated, isFalse);
    expect(loaded.weatherShowLocationAndCondition, isFalse);
  });

  test(
    'saved weather places persist while the active place remains explicit',
    () async {
      const placesJson =
          '[{"name":"Bridgetown","latitude":13.1,"longitude":-59.6},'
          '{"name":"Kingston","latitude":17.9,"longitude":-76.8}]';
      await preferences.setWeatherLocations(placesJson);
      await preferences.setWeatherLocation(
        '{"name":"Kingston","label":"Kingston, Jamaica",'
        '"latitude":17.9,"longitude":-76.8}',
      );

      final loaded = await preferences.load();

      expect(loaded.weatherLocationsJson, contains('Bridgetown'));
      expect(loaded.weatherLocationsJson, contains('Kingston'));
      expect(loaded.weatherLocationJson, contains('Kingston'));
    },
  );
}
