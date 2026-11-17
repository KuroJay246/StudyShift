import 'dart:convert';

import 'open_meteo_weather_service.dart';
import 'preferences_repository.dart';

class WeatherReading {
  const WeatherReading({
    required this.place,
    required this.snapshot,
    required this.fetchedAt,
    required this.isCached,
  });

  final WeatherPlace place;
  final WeatherSnapshot snapshot;
  final DateTime fetchedAt;
  final bool isCached;
}

class WeatherUnavailableException implements Exception {
  const WeatherUnavailableException();
}

WeatherPlace? decodeWeatherPlace(Object? value) {
  if (value is! Map<String, dynamic>) return null;
  final name = value['name'];
  final label = value['label'];
  final latitude = value['latitude'];
  final longitude = value['longitude'];
  if (name is! String ||
      label is! String ||
      latitude is! num ||
      longitude is! num ||
      !latitude.toDouble().isFinite ||
      !longitude.toDouble().isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    return null;
  }
  return WeatherPlace(
    name: name,
    label: label,
    latitude: latitude.toDouble(),
    longitude: longitude.toDouble(),
  );
}

Map<String, Object> encodeWeatherPlace(WeatherPlace place) => {
  'name': place.name,
  'label': place.label,
  'latitude': place.latitude,
  'longitude': place.longitude,
};

List<WeatherPlace> weatherPlacesFor(AppPreferences preferences) {
  final places = <WeatherPlace>[];
  final raw = preferences.weatherLocationsJson;
  if (raw != null) {
    try {
      final values = jsonDecode(raw);
      if (values is List) {
        for (final value in values) {
          final place = decodeWeatherPlace(value);
          if (place != null && !places.any((item) => _samePlace(item, place))) {
            places.add(place);
          }
        }
      }
    } on FormatException {
      // Fall through to the valid active location for legacy settings.
    }
  }
  final active = _decodePlaceString(preferences.weatherLocationJson);
  if (active != null && !places.any((item) => _samePlace(item, active))) {
    places.insert(0, active);
  }
  return places;
}

WeatherPlace? cycleWeatherPlace(
  AppPreferences preferences,
  WeatherPlace active,
  int direction,
) {
  final places = weatherPlacesFor(preferences);
  if (places.length < 2 || direction == 0) return null;
  final index = places.indexWhere((place) => _samePlace(place, active));
  if (index < 0) return places.first;
  return places[(index + direction) % places.length];
}

bool _samePlace(WeatherPlace a, WeatherPlace b) =>
    a.latitude.toStringAsFixed(4) == b.latitude.toStringAsFixed(4) &&
    a.longitude.toStringAsFixed(4) == b.longitude.toStringAsFixed(4);

WeatherPlace? _decodePlaceString(String? value) {
  if (value == null) return null;
  try {
    return decodeWeatherPlace(jsonDecode(value));
  } on FormatException {
    return null;
  }
}

class WeatherRepository {
  const WeatherRepository({required this.preferences, required this.service});

  final PreferencesRepository preferences;
  final OpenMeteoWeatherService service;

  Future<WeatherReading?> load(AppPreferences appPreferences) async {
    if (appPreferences.weatherEnabled != true) return null;
    final place = _decodePlace(appPreferences.weatherLocationJson);
    if (place == null) return null;

    try {
      final snapshot = await service.currentWeather(place);
      final fetchedAt = DateTime.now();
      await preferences.setWeatherSnapshot(
        jsonEncode({
          'place': {
            'name': place.name,
            'label': place.label,
            'latitude': place.latitude,
            'longitude': place.longitude,
          },
          'snapshot': snapshot.toJson(),
          'fetchedAt': fetchedAt.toIso8601String(),
        }),
      );
      return WeatherReading(
        place: place,
        snapshot: snapshot,
        fetchedAt: fetchedAt,
        isCached: false,
      );
    } on Object {
      final cached = _decodeSnapshot(appPreferences.weatherSnapshotJson);
      if (cached != null && _samePlace(cached.place, place)) return cached;
      throw const WeatherUnavailableException();
    }
  }

  WeatherPlace? _decodePlace(String? value) {
    return _decodePlaceString(value);
  }

  WeatherReading? _decodeSnapshot(String? value) {
    if (value == null) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map<String, dynamic>) return null;
      final placeJson = json['place'];
      final snapshotJson = json['snapshot'];
      final fetchedAt = DateTime.tryParse(json['fetchedAt']?.toString() ?? '');
      final place = placeJson is Map<String, dynamic>
          ? _decodePlace(jsonEncode(placeJson))
          : null;
      if (place == null ||
          snapshotJson is! Map<String, dynamic> ||
          fetchedAt == null) {
        return null;
      }
      return WeatherReading(
        place: place,
        snapshot: WeatherSnapshot.fromJson(snapshotJson),
        fetchedAt: fetchedAt,
        isCached: true,
      );
    } on FormatException {
      return null;
    }
  }
}
