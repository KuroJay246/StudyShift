import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/presentation/widgets/today_hero.dart';

void main() {
  testWidgets('weather swipe does not intercept the featured schedule card', (
    tester,
  ) async {
    var weatherSwipes = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TodayHero(
              greeting: 'Good Morning',
              hour: 9,
              dateLabel: 'Monday, November 23, 2026',
              isToday: true,
              onChooseDay: () {},
              onToday: () {},
              weatherPageKey: 'synthetic-place',
              weatherSummary: const SizedBox(
                key: ValueKey('weather-summary'),
                width: 96,
                height: 48,
              ),
              onWeatherSwipe: (_) => weatherSwipes++,
              featuredContent: const SizedBox(
                key: ValueKey('featured-schedule-card'),
                height: 110,
                child: Card(child: Center(child: Text('Next up'))),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.fling(
      find.byKey(const ValueKey('featured-schedule-card')),
      const Offset(-140, 0),
      900,
    );
    await tester.pump();

    expect(weatherSwipes, 0);
  });
}
