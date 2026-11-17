import 'package:flutter/material.dart';

String greetingForWeather({required int localHour, required bool? isDay}) {
  if (isDay == false) return 'Goodnight';
  return switch (localHour) {
    >= 6 && < 12 => 'Good Morning',
    >= 12 && < 17 => 'Good Afternoon',
    >= 17 && < 21 => 'Good Evening',
    _ => 'Goodnight',
  };
}

IconData weatherIconFor({
  required int code,
  required bool isDay,
  required double windSpeedKmh,
}) {
  if (code >= 95) return Icons.thunderstorm_rounded;
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return Icons.water_drop_rounded;
  }
  if (code >= 71 && code <= 86) return Icons.cloud_rounded;
  if (code == 45 || code == 48) return Icons.foggy;
  if (windSpeedKmh >= 35) return Icons.air_rounded;
  if (code == 0 || code == 1) {
    return isDay ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded;
  }
  if (code == 2) {
    return isDay ? Icons.wb_cloudy_rounded : Icons.dark_mode_rounded;
  }
  return Icons.cloud_rounded;
}

Color weatherIconColorFor({
  required int code,
  required bool isDay,
  required double windSpeedKmh,
  bool isDark = false,
}) {
  if (code >= 95) return const Color(0xFFF4B34A);
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return const Color(0xFF3487D8);
  }
  if (code >= 71 && code <= 86) return const Color(0xFF73B9E8);
  if (code == 45 || code == 48) return const Color(0xFF74869C);
  if (windSpeedKmh >= 35) return const Color(0xFF36AAB5);
  if (code == 0 || code == 1 || code == 2) {
    if (isDay) return const Color(0xFFFFB547);
    return isDark ? const Color(0xFFF3F6FF) : const Color(0xFF788498);
  }
  return const Color(0xFF74869C);
}

class WeatherConditionIcon extends StatelessWidget {
  const WeatherConditionIcon({
    super.key,
    required this.code,
    required this.isDay,
    required this.windSpeedKmh,
    this.size = 26,
  });

  final int code;
  final bool isDay;
  final double windSpeedKmh;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (code == 1 || code == 2) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return SizedBox(
        width: 40,
        height: 36,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 4,
              child: Icon(
                isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                key: ValueKey(
                  isDay ? 'today-weather-sun' : 'today-weather-moon',
                ),
                color: weatherIconColorFor(
                  code: code,
                  isDay: isDay,
                  windSpeedKmh: windSpeedKmh,
                  isDark: isDark,
                ),
                size: 22,
              ),
            ),
            Positioned(
              left: 2,
              bottom: 0,
              child: Icon(
                Icons.cloud_rounded,
                key: const ValueKey('today-weather-cloud'),
                color: isDark
                    ? const Color(0xFFBAC5D8)
                    : const Color(0xFF778BA2),
                size: 22,
              ),
            ),
          ],
        ),
      );
    }

    return Icon(
      weatherIconFor(code: code, isDay: isDay, windSpeedKmh: windSpeedKmh),
      color: weatherIconColorFor(
        code: code,
        isDay: isDay,
        windSpeedKmh: windSpeedKmh,
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
      size: size,
    );
  }
}
