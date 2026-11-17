import 'schedule_database.dart';

enum ScheduleMode { workOnly, schoolOnly, workAndSchool, personalPlanner }

enum ThemePreference { system, light, dark }

enum AccentTheme { studyShiftBlue, teal, violet, amber, red }

enum WeatherLayout { compact, moreDetails }

enum WeatherMetric {
  locationAndCondition,
  feelsLike,
  rainChance,
  windSpeed,
  sunriseSunset,
  lastUpdated,
}

enum CalendarColorCategory { work, training, school, deadline, personal }

class AppPreferences {
  const AppPreferences({
    this.scheduleMode,
    this.use24HourTime,
    this.theme,
    this.accentTheme,
    this.workColor,
    this.trainingColor,
    this.schoolColor,
    this.deadlineColor,
    this.personalColor,
    this.weatherEnabled,
    this.weatherLocationJson,
    this.weatherLocationsJson,
    this.weatherSnapshotJson,
    this.weatherLayout,
    this.weatherShowLocationAndCondition,
    this.weatherShowFeelsLike,
    this.weatherShowRainChance,
    this.weatherShowWindSpeed,
    this.weatherShowSunriseSunset,
    this.weatherShowLastUpdated,
  });

  final ScheduleMode? scheduleMode;
  final bool? use24HourTime;
  final ThemePreference? theme;
  final AccentTheme? accentTheme;
  final int? workColor;
  final int? trainingColor;
  final int? schoolColor;
  final int? deadlineColor;
  final int? personalColor;
  final bool? weatherEnabled;
  final String? weatherLocationJson;
  final String? weatherLocationsJson;
  final String? weatherSnapshotJson;
  final WeatherLayout? weatherLayout;
  final bool? weatherShowLocationAndCondition;
  final bool? weatherShowFeelsLike;
  final bool? weatherShowRainChance;
  final bool? weatherShowWindSpeed;
  final bool? weatherShowSunriseSunset;
  final bool? weatherShowLastUpdated;

  bool get showWeatherLocationAndCondition =>
      weatherShowLocationAndCondition ?? true;
  bool get showWeatherFeelsLike => weatherShowFeelsLike ?? false;
  bool get showWeatherRainChance => weatherShowRainChance ?? true;
  bool get showWeatherWindSpeed => weatherShowWindSpeed ?? false;
  bool get showWeatherSunriseSunset => weatherShowSunriseSunset ?? false;
  bool get showWeatherLastUpdated => weatherShowLastUpdated ?? true;
  WeatherLayout get effectiveWeatherLayout =>
      weatherLayout ?? WeatherLayout.compact;

  static AppPreferences decode(Map<String, String> values) => AppPreferences(
    scheduleMode: _enumValue(ScheduleMode.values, values['schedule_mode']),
    use24HourTime: switch (values['use_24_hour_time']) {
      'true' => true,
      'false' => false,
      _ => null,
    },
    theme: _enumValue(ThemePreference.values, values['theme']),
    accentTheme: _enumValue(AccentTheme.values, values['accent_theme']),
    workColor: _colorValue(values['calendar_color_work']),
    trainingColor: _colorValue(values['calendar_color_training']),
    schoolColor: _colorValue(values['calendar_color_school']),
    deadlineColor: _colorValue(values['calendar_color_deadline']),
    personalColor: _colorValue(values['calendar_color_personal']),
    weatherEnabled: switch (values['weather_enabled']) {
      'true' => true,
      'false' => false,
      _ => null,
    },
    weatherLocationJson: values['weather_location'],
    weatherLocationsJson: values['weather_locations'],
    weatherSnapshotJson: values['weather_snapshot'],
    weatherLayout: _enumValue(WeatherLayout.values, values['weather_layout']),
    weatherShowLocationAndCondition: _boolValue(
      values['weather_metric_location'],
    ),
    weatherShowFeelsLike: _boolValue(values['weather_metric_feels_like']),
    weatherShowRainChance: _boolValue(values['weather_metric_rain_chance']),
    weatherShowWindSpeed: _boolValue(values['weather_metric_wind_speed']),
    weatherShowSunriseSunset: _boolValue(
      values['weather_metric_sunrise_sunset'],
    ),
    weatherShowLastUpdated: _boolValue(values['weather_metric_last_updated']),
  );

  static bool? _boolValue(String? value) => switch (value) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  static int? _colorValue(String? value) {
    if (value == null || value.length != 8) return null;
    return int.tryParse(value, radix: 16);
  }

  static T? _enumValue<T extends Enum>(List<T> values, String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

class PreferencesRepository {
  const PreferencesRepository(this.database);
  final ScheduleDatabase database;

  Future<AppPreferences> load() async =>
      AppPreferences.decode(await database.getPreferences());

  Future<void> setScheduleMode(ScheduleMode value) =>
      database.setPreference('schedule_mode', value.name);
  Future<void> set24HourTime(bool value) =>
      database.setPreference('use_24_hour_time', value.toString());
  Future<void> setTheme(ThemePreference value) =>
      database.setPreference('theme', value.name);
  Future<void> setAccentTheme(AccentTheme value) =>
      database.setPreference('accent_theme', value.name);

  Future<void> setCalendarColor(CalendarColorCategory category, int value) =>
      database.setPreference(
        'calendar_color_${category.name}',
        value.toRadixString(16).padLeft(8, '0'),
      );

  Future<void> clearCalendarColor(CalendarColorCategory category) =>
      database.deletePreference('calendar_color_${category.name}');

  Future<void> setWeatherEnabled(bool value) =>
      database.setPreference('weather_enabled', value.toString());

  Future<void> setWeatherLocation(String json) =>
      database.setPreference('weather_location', json);

  Future<void> setWeatherLocations(String json) =>
      database.setPreference('weather_locations', json);

  Future<void> clearWeatherLocation() =>
      database.deletePreference('weather_location');

  Future<void> clearWeatherLocations() =>
      database.deletePreference('weather_locations');

  Future<void> setWeatherLayout(WeatherLayout value) =>
      database.setPreference('weather_layout', value.name);

  Future<void> setWeatherMetric(WeatherMetric metric, bool value) =>
      database.setPreference(
        'weather_metric_${_weatherMetricKey(metric)}',
        value.toString(),
      );

  static String _weatherMetricKey(WeatherMetric metric) => switch (metric) {
    WeatherMetric.locationAndCondition => 'location',
    WeatherMetric.feelsLike => 'feels_like',
    WeatherMetric.rainChance => 'rain_chance',
    WeatherMetric.windSpeed => 'wind_speed',
    WeatherMetric.sunriseSunset => 'sunrise_sunset',
    WeatherMetric.lastUpdated => 'last_updated',
  };

  Future<void> setWeatherSnapshot(String json) =>
      database.setPreference('weather_snapshot', json);

  Future<void> clearWeatherSnapshot() =>
      database.deletePreference('weather_snapshot');

  Future<void> clear(String key) => database.deletePreference(key);
}
