import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

class WeatherPlace {
  const WeatherPlace({
    required this.name,
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String label;
  final double latitude;
  final double longitude;
}

class HourlyWeatherForecast {
  const HourlyWeatherForecast({
    required this.localTime,
    required this.temperatureC,
    required this.weatherCode,
    required this.isDay,
    required this.windSpeedKmh,
    required this.precipitationProbability,
  });

  final DateTime localTime;
  final double temperatureC;
  final int weatherCode;
  final bool isDay;
  final double windSpeedKmh;
  final int precipitationProbability;

  Map<String, Object?> toJson() => {
    'localTime': localTime.toIso8601String(),
    'temperatureC': temperatureC,
    'weatherCode': weatherCode,
    'isDay': isDay,
    'windSpeedKmh': windSpeedKmh,
    'precipitationProbability': precipitationProbability,
  };

  static HourlyWeatherForecast? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final localTime = DateTime.tryParse(value['localTime']?.toString() ?? '');
    final temperature = value['temperatureC'];
    final weatherCode = value['weatherCode'];
    final isDay = value['isDay'];
    final wind = value['windSpeedKmh'];
    final rain = value['precipitationProbability'];
    if (localTime == null ||
        temperature is! num ||
        !temperature.toDouble().isFinite ||
        weatherCode is! num ||
        isDay is! bool ||
        wind is! num ||
        !wind.toDouble().isFinite ||
        rain is! num) {
      return null;
    }
    return HourlyWeatherForecast(
      localTime: localTime,
      temperatureC: temperature.toDouble(),
      weatherCode: weatherCode.toInt(),
      isDay: isDay,
      windSpeedKmh: wind.toDouble(),
      precipitationProbability: rain.toInt().clamp(0, 100),
    );
  }
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.observedAt,
    required this.temperatureC,
    required this.apparentTemperatureC,
    required this.windSpeedKmh,
    required this.precipitationProbability,
    required this.weatherCode,
    required this.isDay,
    required this.sunrise,
    required this.sunset,
    this.utcOffsetSeconds = 0,
    this.hourlyForecast = const [],
  });

  final DateTime observedAt;
  final double temperatureC;
  final double apparentTemperatureC;
  final double windSpeedKmh;
  final int? precipitationProbability;
  final int weatherCode;
  final bool isDay;
  final DateTime? sunrise;
  final DateTime? sunset;

  /// UTC offset for the weather place at the observation time.
  /// Kept separate from the device and schedule time zones.
  final int utcOffsetSeconds;
  final List<HourlyWeatherForecast> hourlyForecast;

  DateTime localClockAt(DateTime instant) =>
      instant.toUtc().add(Duration(seconds: utcOffsetSeconds));

  Map<String, Object?> toJson() => {
    'observedAt': observedAt.toIso8601String(),
    'temperatureC': temperatureC,
    'apparentTemperatureC': apparentTemperatureC,
    'windSpeedKmh': windSpeedKmh,
    'precipitationProbability': precipitationProbability,
    'weatherCode': weatherCode,
    'isDay': isDay,
    'sunrise': sunrise?.toIso8601String(),
    'sunset': sunset?.toIso8601String(),
    'utcOffsetSeconds': utcOffsetSeconds,
    'hourlyForecast': [for (final hour in hourlyForecast) hour.toJson()],
  };

  factory WeatherSnapshot.fromJson(Map<String, Object?> json) {
    double number(String key) {
      final value = (json[key] as num?)?.toDouble();
      if (value == null || !value.isFinite) {
        throw const FormatException('Saved weather data is incomplete.');
      }
      return value;
    }

    DateTime? date(String key) => switch (json[key]) {
      final String value => DateTime.tryParse(value),
      _ => null,
    };

    final observedAt = date('observedAt');
    final hourlyForecastValues = json['hourlyForecast'];
    final weatherCode = (json['weatherCode'] as num?)?.toInt();
    final isDay = json['isDay'];
    if (observedAt == null || weatherCode == null || isDay is! bool) {
      throw const FormatException('Saved weather data is incomplete.');
    }
    return WeatherSnapshot(
      observedAt: observedAt,
      temperatureC: number('temperatureC'),
      apparentTemperatureC: number('apparentTemperatureC'),
      windSpeedKmh: number('windSpeedKmh'),
      precipitationProbability: (json['precipitationProbability'] as num?)
          ?.toInt(),
      weatherCode: weatherCode,
      isDay: isDay,
      sunrise: date('sunrise'),
      sunset: date('sunset'),
      utcOffsetSeconds: (json['utcOffsetSeconds'] as num?)?.toInt() ?? 0,
      hourlyForecast: hourlyForecastValues is List
          ? [
              for (final value in hourlyForecastValues)
                ?HourlyWeatherForecast.fromJson(value),
            ]
          : const [],
    );
  }
}

/// Keyless forecast client. Calls are made only after the user selects a place.
class OpenMeteoWeatherService {
  OpenMeteoWeatherService({
    HttpClient Function()? clientFactory,
    Uri? geocodingEndpoint,
    Uri? forecastEndpoint,
  }) : _clientFactory = clientFactory ?? HttpClient.new,
       _geocodingEndpoint =
           geocodingEndpoint ??
           Uri.https('geocoding-api.open-meteo.com', '/v1/search'),
       _forecastEndpoint =
           forecastEndpoint ?? Uri.https('api.open-meteo.com', '/v1/forecast');

  final HttpClient Function() _clientFactory;
  final Uri _geocodingEndpoint;
  final Uri _forecastEndpoint;

  Future<List<WeatherPlace>> searchPlaces(String query) async {
    final name = query.trim();
    if (name.length < 2) return const [];
    final uri = _geocodingEndpoint.replace(
      queryParameters: {
        ..._geocodingEndpoint.queryParameters,
        'name': name,
        'count': '8',
        'language': 'en',
        'format': 'json',
      },
    );
    final body = await _getJson(uri);
    final results = body['results'];
    if (results is! List) return const [];
    return [
      for (final result in results)
        if (result is Map<String, dynamic>) ?_placeFromJson(result),
    ];
  }

  Future<WeatherSnapshot> currentWeather(WeatherPlace place) async {
    final uri = _forecastEndpoint.replace(
      queryParameters: {
        ..._forecastEndpoint.queryParameters,
        'latitude': place.latitude.toString(),
        'longitude': place.longitude.toString(),
        'current': 'temperature_2m,apparent_temperature,precipitation,wind_speed_10m,weather_code,is_day',
        'hourly': 'temperature_2m,weather_code,is_day,wind_speed_10m,precipitation_probability',
        'daily': 'sunrise,sunset',
        'forecast_days': '2',
        'timezone': 'auto',
      },
    );
    final body = await _getJson(uri);
    final current = body['current'];
    if (current is! Map<String, dynamic>) {
      throw const FormatException('Weather provider returned no current data.');
    }
    final observedAt = DateTime.tryParse(current['time']?.toString() ?? '');
    final temperature = _number(current['temperature_2m']);
    final apparent = _number(current['apparent_temperature']);
    final wind = _number(current['wind_speed_10m']);
    final weatherCode = _integer(current['weather_code']);
    if (observedAt == null ||
        temperature == null ||
        apparent == null ||
        wind == null ||
        weatherCode == null ||
        current['is_day'] is! num) {
      throw const FormatException('Weather provider returned incomplete data.');
    }
    final hourly = body['hourly'];
    final rainChance = hourly is Map<String, dynamic>
        ? _precipitationChance(hourly, observedAt)
        : null;
    final daily = body['daily'];
    final sunrise = daily is Map<String, dynamic>
        ? _firstDate(daily['sunrise'])
        : null;
    final sunset = daily is Map<String, dynamic>
        ? _firstDate(daily['sunset'])
        : null;
    return WeatherSnapshot(
      observedAt: observedAt,
      temperatureC: temperature,
      apparentTemperatureC: apparent,
      windSpeedKmh: wind,
      precipitationProbability: rainChance,
      weatherCode: weatherCode,
      isDay: (current['is_day'] as num).toInt() == 1,
      sunrise: sunrise,
      sunset: sunset,
      utcOffsetSeconds: (body['utc_offset_seconds'] as num?)?.toInt() ?? 0,
      hourlyForecast: hourly is Map<String, dynamic>
          ? _nextHours(hourly, observedAt)
          : const [],
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = _clientFactory();
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Weather request failed (${response.statusCode}).');
      }
      final decoded = jsonDecode(
        await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 10)),
      );
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Weather provider returned invalid data.');
      }
      return decoded;
    } on TimeoutException {
      throw const HttpException('Weather request timed out.');
    } finally {
      client.close(force: true);
    }
  }

  WeatherPlace? _placeFromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final latitude = _number(json['latitude']);
    final longitude = _number(json['longitude']);
    if (name is! String ||
        name.trim().isEmpty ||
        latitude == null ||
        longitude == null) {
      return null;
    }
    final label = [name, json['admin1'], json['country']]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return WeatherPlace(
      name: name.trim(),
      label: label.toSet().join(', '),
      latitude: latitude,
      longitude: longitude,
    );
  }

  int? _precipitationChance(Map<String, dynamic> hourly, DateTime observedAt) {
    final times = hourly['time'];
    final probabilities = hourly['precipitation_probability'];
    if (times is! List || probabilities is! List) return null;
    final expectedHour = observedAt.toIso8601String().substring(0, 13);
    final index = times.indexWhere(
      (value) => value is String && value.startsWith(expectedHour),
    );
    if (index < 0 || index >= probabilities.length) return null;
    return _integer(probabilities[index])?.clamp(0, 100);
  }

  List<HourlyWeatherForecast> _nextHours(
    Map<String, dynamic> hourly,
    DateTime observedAt,
  ) {
    final times = hourly['time'];
    final temperatures = hourly['temperature_2m'];
    final codes = hourly['weather_code'];
    final dayFlags = hourly['is_day'];
    final winds = hourly['wind_speed_10m'];
    final rainChances = hourly['precipitation_probability'];
    if ([
      times,
      temperatures,
      codes,
      dayFlags,
      winds,
      rainChances,
    ].any((values) => values is! List)) {
      return const [];
    }
    final arrays = [
      times as List,
      temperatures as List,
      codes as List,
      dayFlags as List,
      winds as List,
      rainChances as List,
    ];
    final length = arrays.map((values) => values.length).reduce(math.min);
    final forecasts = <HourlyWeatherForecast>[];
    for (var index = 0; index < length; index++) {
      final localTime = DateTime.tryParse(times[index]?.toString() ?? '');
      final temperature = _number(temperatures[index]);
      final code = _integer(codes[index]);
      final isDay = _integer(dayFlags[index]);
      final wind = _number(winds[index]);
      final rain = _integer(rainChances[index]);
      if (localTime == null ||
          !localTime.isAfter(observedAt) ||
          temperature == null ||
          code == null ||
          isDay == null ||
          wind == null ||
          rain == null) {
        continue;
      }
      forecasts.add(
        HourlyWeatherForecast(
          localTime: localTime,
          temperatureC: temperature,
          weatherCode: code,
          isDay: isDay == 1,
          windSpeedKmh: wind,
          precipitationProbability: rain.clamp(0, 100),
        ),
      );
      if (forecasts.length == 6) break;
    }
    return forecasts;
  }

  DateTime? _firstDate(Object? values) =>
      values is List && values.isNotEmpty && values.first is String
      ? DateTime.tryParse(values.first as String)
      : null;

  double? _number(Object? value) =>
      value is num && value.toDouble().isFinite ? value.toDouble() : null;

  int? _integer(Object? value) => value is num ? value.toInt() : null;
}
