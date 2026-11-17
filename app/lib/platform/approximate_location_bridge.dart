import 'package:flutter/services.dart';

import '../data/open_meteo_weather_service.dart';

/// Requests a one-time Android approximate location only after the user taps
/// “Use my location”. No background or precise-location access is requested.
class ApproximateWeatherLocationBridge {
  const ApproximateWeatherLocationBridge();

  static const _channel = MethodChannel('app.shiftstudy/location');

  Future<WeatherPlace> currentPlace() async {
    final value = await _channel.invokeMapMethod<String, Object?>(
      'getApproximateLocation',
    );
    final latitude = (value?['latitude'] as num?)?.toDouble();
    final longitude = (value?['longitude'] as num?)?.toDouble();
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('The device returned an invalid location.');
    }
    return WeatherPlace(
      name: 'Current area',
      label: 'Approximate device location',
      latitude: latitude,
      longitude: longitude,
    );
  }
}
