import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/presentation/weather_condition_icon.dart';

void main() {
  test('clear night uses a plain crescent without a stray circle', () {
    expect(
      weatherIconFor(code: 0, isDay: false, windSpeedKmh: 0),
      Icons.dark_mode_rounded,
    );
  });

  for (final isDay in [true, false]) {
    testWidgets(
      'partly cloudy ${isDay ? 'day' : 'night'} glyph layers sky behind cloud',
      (tester) async {
        final skyKey = ValueKey(
          isDay ? 'today-weather-sun' : 'today-weather-moon',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: Center(
                child: WeatherConditionIcon(
                  code: 2,
                  isDay: isDay,
                  windSpeedKmh: 0,
                ),
              ),
            ),
          ),
        );

        final skyRect = tester.getRect(find.byKey(skyKey));
        final cloudRect = tester.getRect(
          find.byKey(const ValueKey('today-weather-cloud')),
        );
        expect(
          tester.widget<Icon>(find.byKey(skyKey)).icon,
          isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
        );
        expect(skyRect.width, 22);
        expect(cloudRect.width, 22);
        expect(skyRect.overlaps(cloudRect), isTrue);
        expect(
          skyRect.intersect(cloudRect).width,
          inInclusiveRange(8, 10),
          reason: 'The cloud should overlap the sun or moon enough to read as partly cloudy.',
        );
        expect(cloudRect.top, greaterThan(skyRect.top));
        expect(cloudRect.right, greaterThan(skyRect.left));
      },
    );
  }
}
