import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/data/open_meteo_weather_service.dart';
import 'package:shift_study/data/weather_repository.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/platform/device_time_zone.dart';
import 'package:shift_study/presentation/app_theme.dart';
import 'package:shift_study/presentation/screens/schedule_pages.dart';
import 'package:shift_study/presentation/widgets/schedule_event_tile.dart';
import 'package:shift_study/presentation/widgets/today_hero.dart';

class _TestTimeZone implements DeviceTimeZone {
  @override
  Future<String> getLocalIanaId() async => 'America/Barbados';
}

WeatherReading _weatherReading(DateTime now, {double temperatureC = 29}) =>
    WeatherReading(
      place: const WeatherPlace(
        name: 'Bridgetown',
        label: 'Bridgetown, Barbados',
        latitude: 13.1,
        longitude: -59.6,
      ),
      snapshot: WeatherSnapshot(
        observedAt: now,
        temperatureC: temperatureC,
        apparentTemperatureC: 33,
        windSpeedKmh: 18,
        precipitationProbability: 40,
        weatherCode: 2,
        isDay: true,
        sunrise: null,
        sunset: null,
      ),
      fetchedAt: now,
      isCached: false,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  test('local greeting follows the complete clock-day cycle', () {
    expect(greetingForLocalHour(0), 'Goodnight');
    expect(greetingForLocalHour(5), 'Goodnight');
    expect(greetingForLocalHour(6), 'Good Morning');
    expect(greetingForLocalHour(11), 'Good Morning');
    expect(greetingForLocalHour(12), 'Good Afternoon');
    expect(greetingForLocalHour(14), 'Good Afternoon');
    expect(greetingForLocalHour(16), 'Good Afternoon');
    expect(greetingForLocalHour(17), 'Good Evening');
    expect(greetingForLocalHour(20), 'Good Evening');
    expect(greetingForLocalHour(21), 'Goodnight');
    expect(greetingForLocalHour(23), 'Goodnight');
    expect(TodayHero.isNightForHour(5), isTrue);
    expect(TodayHero.isNightForHour(6), isFalse);
    expect(TodayHero.isNightForHour(20), isFalse);
    expect(TodayHero.isNightForHour(21), isTrue);
  });

  test('night forecast changes an evening greeting to Goodnight', () {
    expect(greetingForWeather(localHour: 19, isDay: false), 'Goodnight');
    expect(greetingForWeather(localHour: 19, isDay: true), 'Good Evening');
    expect(greetingForWeather(localHour: 10, isDay: false), 'Goodnight');
  });

  test(
    'weather icon reflects conditions and switches clear sky from sun to moon',
    () {
      expect(
        weatherIconFor(code: 0, isDay: true, windSpeedKmh: 0),
        Icons.wb_sunny_rounded,
      );
      expect(
        weatherIconFor(code: 0, isDay: false, windSpeedKmh: 0),
        Icons.dark_mode_rounded,
      );
      expect(
        weatherIconFor(code: 1, isDay: true, windSpeedKmh: 0),
        Icons.wb_sunny_rounded,
      );
      expect(
        weatherIconFor(code: 2, isDay: true, windSpeedKmh: 0),
        Icons.wb_cloudy_rounded,
      );
      expect(
        weatherIconFor(code: 2, isDay: false, windSpeedKmh: 0),
        Icons.dark_mode_rounded,
      );
      expect(
        weatherIconFor(code: 3, isDay: true, windSpeedKmh: 0),
        Icons.cloud_rounded,
      );
      expect(
        weatherIconFor(code: 61, isDay: false, windSpeedKmh: 0),
        Icons.water_drop_rounded,
      );
      expect(
        weatherIconColorFor(code: 61, isDay: false, windSpeedKmh: 0),
        const Color(0xFF3487D8),
      );
      expect(
        weatherIconColorFor(code: 0, isDay: false, windSpeedKmh: 0),
        const Color(0xFF788498),
      );
    },
  );

  test('daylight hero sun keeps a warm color through the theme system', () {
    final noonSun = TodayHero.sunColorsForHour(12);
    final sunsetSun = TodayHero.sunColorsForHour(17);

    expect(noonSun, hasLength(3));
    expect(sunsetSun, hasLength(3));
    for (final color in [...noonSun, ...sunsetSun]) {
      expect(color.r, greaterThan(color.b));
    }
    expect(noonSun.last, isNot(sunsetSun.last));
  });

  test('sun artwork stays inside the greeting header above the date', () {
    expect(TodayHero.sunHaloRadius, 32);
    expect(TodayHero.sunDiscRadius, 18);
    expect(TodayHero.sunRayOuterRadius, 28);
    expect(TodayHero.celestialCenterY, 38);
    expect(
      TodayHero.celestialCenterY + TodayHero.sunRayOuterRadius,
      lessThanOrEqualTo(68),
    );
  });

  test('horizon waves are reserved for the daylight hero', () {
    expect(TodayHero.showsHorizonForTheme(isDark: false), isTrue);
    expect(TodayHero.showsHorizonForTheme(isDark: true), isFalse);
  });

  test(
    'weather summary owns the sky so no horizon overlaps the featured card',
    () {
      expect(TodayHero.showsHorizonWithWeather(isDark: false), isFalse);
      expect(TodayHero.showsHorizonWithWeather(isDark: true), isFalse);
    },
  );

  testWidgets('greeting and date area swipes change weather location', (
    tester,
  ) async {
    final swipes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TodayHero(
            greeting: 'Good Morning',
            hour: 9,
            dateLabel: 'Monday, November 16, 2026',
            isToday: true,
            onChooseDay: () {},
            onToday: () {},
            weatherSummary: const Text('30°'),
            weatherCaption: const Text('Bridgetown · Mainly clear'),
            onWeatherSwipe: swipes.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Good Morning'), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(swipes, [1]);

    await tester.drag(
      find.byKey(const ValueKey('today-weather-swipe-gap')),
      const Offset(-100, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(swipes, [1, 1]);

    await tester.drag(
      find.text('Monday, November 16, 2026'),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();
    expect(swipes, [1, 1, -1]);
  });

  testWidgets('weather location swipe transitions between summaries', (
    tester,
  ) async {
    const places = ['Bristol · 10°', 'Bridgetown · 27°'];
    var placeIndex = 0;
    var swipeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => TodayHero(
                greeting: 'Good Morning',
                hour: 9,
                dateLabel: 'Monday, November 16, 2026',
                isToday: true,
                onChooseDay: () {},
                onToday: () {},
                weatherPageKey: places[placeIndex],
                weatherSummary: Text(places[placeIndex]),
                onWeatherSwipe: (direction) {
                  swipeCount++;
                  setState(() => placeIndex = (placeIndex + direction) % 2);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Good Morning')),
    );
    await tester.pump();
    await gesture.moveBy(
      const Offset(-100, 0),
      timeStamp: const Duration(milliseconds: 50),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(swipeCount, 1);
    expect(find.text('Bristol · 10°'), findsOneWidget);
    expect(find.text('Bridgetown · 27°'), findsOneWidget);
    final oldLocation = tester.getTopLeft(find.text('Bristol · 10°'));
    final newLocation = tester.getTopLeft(find.text('Bridgetown · 27°'));
    expect(newLocation.dx, greaterThan(oldLocation.dx));

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bristol · 10°'), findsNothing);
    expect(find.text('Bridgetown · 27°'), findsOneWidget);
  });

  testWidgets('weather can be changed by swiping anywhere across Today hero', (
    tester,
  ) async {
    const places = ['Bristol · 10°', 'Bridgetown · 27°'];
    var placeIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => TodayHero(
                greeting: 'Good Morning',
                hour: 9,
                dateLabel: 'Monday, November 16, 2026',
                isToday: true,
                onChooseDay: () {},
                onToday: () {},
                weatherPageKey: places[placeIndex],
                weatherSummary: Text(places[placeIndex]),
                onWeatherSwipe: (direction) =>
                    setState(() => placeIndex = (placeIndex + direction) % 2),
                featuredContent: const Card(
                  child: SizedBox(
                    key: Key('today-featured-card'),
                    height: 96,
                    child: Center(child: Text('Next up')),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    await tester.drag(
      find.byKey(const Key('today-featured-card')),
      const Offset(-100, 0),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Bridgetown · 27°'), findsOneWidget);
  });

  test('sun and moon keep natural celestial colors across accent palettes', () {
    final naturalSun = TodayHero.sunColorsForHour(16);
    for (final accentTheme in AccentTheme.values.where(
      (theme) => theme != AccentTheme.studyShiftBlue,
    )) {
      final palette = AppTheme.light(accentTheme: accentTheme)
          .extension<SchedulePalette>()!;
      final colors = TodayHero.sunColorsForPalette(
        16,
        featuredStart: palette.featuredStart,
        featuredEnd: palette.featuredEnd,
        featuredWave: palette.featuredWave,
      );

      expect(colors, naturalSun, reason: accentTheme.name);
      expect(
        TodayHero.moonColorForAppearance(isDark: false),
        const Color(0xFFF2CC76),
        reason: accentTheme.name,
      );
      expect(
        TodayHero.moonOutlineColorForAppearance(isDark: false),
        const Color(0xFF786038),
        reason: accentTheme.name,
      );
    }

    final bluePalette = AppTheme.light().extension<SchedulePalette>()!;
    expect(
      TodayHero.sunColorsForPalette(
        12,
        featuredStart: bluePalette.featuredStart,
        featuredEnd: bluePalette.featuredEnd,
        featuredWave: bluePalette.featuredWave,
      ),
      TodayHero.sunColorsForHour(12),
    );
  });

  testWidgets('event cards separate event type from its original code', (
    tester,
  ) async {
    final date = CivilDate.fromDateTime(DateTime.now());
    final training = ScheduleItem(
      id: 'qa-training-card',
      kind: ScheduleKind.work,
      title: 'QA training',
      startDate: date,
      workCategory: WorkCategory.training,
      code: 'QA-TR',
      codeMeaning: 'Synthetic training detail',
      reportingInstruction: 'Synthetic report at north gate',
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 720)],
    );
    final exam = ScheduleItem(
      id: 'qa-exam-card',
      kind: ScheduleKind.deadline,
      title: 'QA examination',
      startDate: date,
      deadlineType: DeadlineType.examination,
      code: 'QA-COMP',
      intervals: [EventInterval.sameDay(startMinute: 780, endMinute: 900)],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ListView(
            children: [
              ScheduleEventTile(
                item: training,
                use24Hour: false,
                showExtendedWorkDetails: true,
                onTap: () {},
              ),
              ScheduleEventTile(item: exam, use24Hour: false, onTap: () {}),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Training'), findsOneWidget);
    expect(find.text('QA-TR'), findsOneWidget);
    expect(find.text('Report: Synthetic report at north gate'), findsOneWidget);
    expect(
      find.text('Code assignment: Synthetic training detail'),
      findsOneWidget,
    );
    expect(find.text('Examination'), findsOneWidget);
    expect(find.text('Course code: QA-COMP'), findsOneWidget);
  });

  testWidgets('work schedule cards lead with essential roster details', (
    tester,
  ) async {
    final item = ScheduleItem(
      id: 'compact-roster-card',
      kind: ScheduleKind.work,
      title: 'Synthetic ramp shift',
      startDate: CivilDate.fromDateTime(DateTime.now()),
      intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 1020)],
      code: 'AC',
      codeMeaning: 'Synthetic arrival and departure duties',
      reportingInstruction: 'Report at synthetic operations desk',
      location: 'Synthetic BGI ramp',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ScheduleEventTile(
            item: item,
            use24Hour: false,
            dateLabel: 'Mon, Nov 16',
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Synthetic ramp shift'), findsOneWidget);
    expect(find.text('AC · Mon, Nov 16 · 10:00 AM – 5:00 PM'), findsOneWidget);
    expect(find.text('Shift'), findsNothing);
    expect(find.text('Synthetic BGI ramp'), findsNothing);
    expect(
      find.text('Code assignment: Synthetic arrival and departure duties'),
      findsNothing,
    );
    expect(
      find.text('Report: Report at synthetic operations desk'),
      findsNothing,
    );
  });

  testWidgets('event card semantics include visible schedule status and date', (
    tester,
  ) async {
    final item = ScheduleItem(
      id: 'qa-accessible-active-shift',
      kind: ScheduleKind.work,
      title: 'Synthetic active shift',
      startDate: CivilDate(2026, 11, 16),
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 1020)],
      code: 'SYN',
      location: 'Synthetic ramp',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ScheduleEventTile(
            item: item,
            use24Hour: false,
            statusLabel: 'Happening now',
            countdownLabel: 'Ends in 6h 32m',
            dateLabel: 'Monday, November 16, 2026',
            conflict: true,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final accessibleCard = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.button == true &&
          widget.properties.label?.contains('Synthetic active shift') == true,
    );
    expect(accessibleCard, findsOneWidget);
    final semanticsLabel = tester
        .widget<Semantics>(accessibleCard)
        .properties
        .label!;
    expect(semanticsLabel, contains('Happening now'));
    expect(semanticsLabel, contains('Schedule conflict'));
    expect(semanticsLabel, contains('Ends in 6h 32m'));
    expect(semanticsLabel, contains('Monday, November 16, 2026'));
    expect(semanticsLabel, contains('Synthetic ramp'));
  });

  testWidgets('compact Today hero uses a side-by-side layout in landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1080);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final featured = SizedBox(
      key: const ValueKey('landscape-featured'),
      height: 120,
      child: const ColoredBox(color: Colors.blue),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ListView(
            children: [
              TodayHero(
                greeting: 'Goodnight',
                hour: 21,
                dateLabel: 'Friday, November 13, 2026',
                isToday: true,
                onChooseDay: () {},
                onToday: () {},
                featuredContent: featured,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final greeting = tester.getRect(find.text('Goodnight'));
    final featuredRect = tester.getRect(
      find.byKey(const ValueKey('landscape-featured')),
    );
    final dateButton = find.ancestor(
      of: find.text('Friday, November 13, 2026'),
      matching: find.byType(TextButton),
    );
    expect(
      greeting.right,
      lessThan(featuredRect.left),
      reason: 'The landscape greeting/date should share a row with Next up.',
    );
    expect(tester.getSize(dateButton).width, greaterThan(250));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the scheduled date for a next-day event', (tester) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final today = CivilDate.fromDateTime(DateTime.now());
    final tomorrow = today.addDays(1);
    await ScheduleRepository(database).save(
      ScheduleItem(
        id: 'next-day-event',
        kind: ScheduleKind.work,
        title: 'QA next-day shift',
        startDate: tomorrow,
        intervals: [
          EventInterval(
            startDayOffset: 0,
            startMinute: 540,
            endDayOffset: 0,
            endMinute: 1020,
          ),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TodayPage(
            selectedDay: today,
            clock: () => DateTime(today.year, today.month, today.day),
            onSelectedDateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dateLabel = MaterialLocalizations.of(
      tester.element(find.byType(TodayPage)),
    ).formatMediumDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day));
    expect(find.text('Next up · $dateLabel'), findsOneWidget);
    expect(find.text('in 33h'), findsOneWidget);
    expect(find.text('9:00 AM – 5:00 PM'), findsOneWidget);
    expect(find.text('QA next-day shift'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('QA next-day shift')).style?.color,
      Colors.white,
    );
  });

  testWidgets('shows the featured Next up card on an empty day', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final today = CivilDate.fromDateTime(DateTime.now());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: TodayPage(
            selectedDay: today,
            clock: () => DateTime(today.year, today.month, today.day, 9),
            onSelectedDateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Next up'), findsOneWidget);
    expect(find.text('Good Morning'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TodayHero),
        matching: find.text('Nothing scheduled yet'),
      ),
      findsOneWidget,
      reason: 'The featured card shares the painted Today hero surface.',
    );
    expect(find.text('Nothing scheduled yet'), findsOneWidget);
    expect(
      find.byIcon(Icons.event_note_outlined),
      findsOneWidget,
      reason: 'The empty Next up card should not duplicate the weather sun.',
    );
    expect(
      tester.widget<Text>(find.text('Nothing scheduled yet')).style?.color,
      Colors.white,
    );
    expect(
      find.text('Your next shift, class or plan will show here.'),
      findsOneWidget,
    );
    expect(find.text('A little room in your day'), findsOneWidget);
    expect(find.text('Your schedule is saved on this device.'), findsNothing);
  });

  testWidgets('available periods do not create a fixed study block draft', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final today = CivilDate.fromDateTime(DateTime.now());
    await ScheduleRepository(database).save(
      ScheduleItem(
        id: 'synthetic-study-gap-shift',
        kind: ScheduleKind.work,
        title: 'Synthetic afternoon shift',
        startDate: today,
        timeZoneId: 'America/Barbados',
        intervals: [
          EventInterval.sameDay(startMinute: 12 * 60, endMinute: 13 * 60),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TodayPage(
            selectedDay: today,
            clock: () => DateTime(today.year, today.month, today.day, 9),
            onSelectedDateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Available periods'), findsOneWidget);
    expect(find.text('Plan 60-minute study block'), findsNothing);
    expect(
      await container.read(scheduleRepositoryProvider).getItems(),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('past events show the all-done message in the Next up card', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final today = CivilDate.fromDateTime(DateTime.now());
    for (final (id, start, end) in [
      ('finished-first', 9 * 60, 10 * 60),
      ('finished-second', 11 * 60, 12 * 60),
    ]) {
      await ScheduleRepository(database).save(
        ScheduleItem(
          id: id,
          kind: ScheduleKind.work,
          title: 'Synthetic $id',
          startDate: today,
          intervals: [
            EventInterval.sameDay(startMinute: start, endMinute: end),
          ],
        ),
      );
    }
    await ScheduleRepository(database).save(
      ScheduleItem(
        id: 'tomorrow-upcoming',
        kind: ScheduleKind.work,
        title: 'Synthetic tomorrow shift',
        startDate: today.addDays(1),
        intervals: [
          EventInterval.sameDay(startMinute: 9 * 60, endMinute: 17 * 60),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TodayPage(
            selectedDay: today,
            clock: () => DateTime(today.year, today.month, today.day, 20),
            onSelectedDateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing else scheduled today'), findsOneWidget);
    expect(find.text('Nothing scheduled yet'), findsNothing);
    expect(find.text('Synthetic finished-first'), findsOneWidget);
    expect(find.text('Synthetic finished-second'), findsOneWidget);
  });

  testWidgets('shows the next shift after an all-day day off', (tester) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final today = CivilDate.fromDateTime(DateTime.now());
    final tomorrow = today.addDays(1);
    await ScheduleRepository(database).save(
      ScheduleItem(
        id: 'synthetic-day-off-today',
        kind: ScheduleKind.work,
        title: 'Synthetic day off',
        startDate: today,
        workCategory: WorkCategory.dayOff,
        intervals: const [],
      ),
    );
    await ScheduleRepository(database).save(
      ScheduleItem(
        id: 'synthetic-next-morning-shift',
        kind: ScheduleKind.work,
        title: 'Synthetic next morning shift',
        startDate: tomorrow,
        workCategory: WorkCategory.shift,
        intervals: [
          EventInterval.sameDay(startMinute: 9 * 60, endMinute: 17 * 60),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TodayPage(
            selectedDay: today,
            clock: () => DateTime(today.year, today.month, today.day, 20),
            onSelectedDateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dateLabel = MaterialLocalizations.of(
      tester.element(find.byType(TodayPage)),
    ).formatMediumDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day));
    expect(find.text('Next up · $dateLabel'), findsOneWidget);
    expect(find.text('Synthetic next morning shift'), findsOneWidget);
    expect(find.text('9:00 AM – 5:00 PM'), findsOneWidget);
    expect(find.text('Nothing else scheduled today'), findsNothing);
  });

  testWidgets('Today groups overlapping events in an expandable summary', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final today = CivilDate.fromDateTime(DateTime.now());
    final entries = [
      ('conflict-a', 'Synthetic early shift', 9 * 60, 11 * 60),
      ('conflict-b', 'Synthetic overlapping class', 10 * 60, 12 * 60),
      ('conflict-c', 'Synthetic later appointment', 11 * 60, 13 * 60),
    ];
    for (final (id, title, start, end) in entries) {
      await ScheduleRepository(database).save(
        ScheduleItem(
          id: id,
          kind: id == 'conflict-b'
              ? ScheduleKind.classSession
              : ScheduleKind.work,
          title: title,
          startDate: today,
          intervals: [
            EventInterval.sameDay(startMinute: start, endMinute: end),
          ],
        ),
      );
    }
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TodayPage(
            selectedDay: today,
            clock: () => DateTime(today.year, today.month, today.day, 8),
            onSelectedDateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 schedule conflicts'), findsOneWidget);
    expect(
      find.text('Some events overlap. Review conflicts →'),
      findsOneWidget,
    );
    expect(find.textContaining('overlaps with'), findsNothing);
    await tester.tap(find.text('2 schedule conflicts'));
    await tester.pumpAndSettle();
    expect(find.textContaining('overlaps with'), findsNWidgets(2));
    expect(find.text('Synthetic early shift'), findsWidgets);
    expect(find.text('Open Synthetic overlapping class'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps a compact weather placeholder visible while the forecast loads',
    (tester) async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      final now = DateTime.now();
      final pendingWeather = Completer<WeatherReading?>();
      final container = ProviderContainer(
        overrides: [
          scheduleDatabaseProvider.overrideWith((ref) {
            ref.onDispose(database.close);
            return database;
          }),
          deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
          appPreferencesProvider.overrideWith(
            (ref) async => const AppPreferences(weatherEnabled: true),
          ),
          weatherReadingProvider.overrideWith((ref) => pendingWeather.future),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: TodayPage(
              selectedDay: CivilDate.fromDateTime(now),
              clock: () => now,
              onSelectedDateChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Loading weather'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      pendingWeather.complete(null);
    },
  );

  testWidgets(
    'shows saved opt-in weather in Today in the local display style',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      final now = DateTime.now();
      final place = WeatherPlace(
        name: 'Bridgetown',
        label: 'Bridgetown, Saint Michael, Barbados',
        latitude: 13.1,
        longitude: -59.6,
      );
      final reading = WeatherReading(
        place: place,
        snapshot: WeatherSnapshot(
          observedAt: now,
          temperatureC: 29,
          apparentTemperatureC: 33,
          windSpeedKmh: 18,
          precipitationProbability: 40,
          weatherCode: 2,
          isDay: true,
          sunrise: DateTime(now.year, now.month, now.day, 5, 42),
          sunset: DateTime(now.year, now.month, now.day, 17, 31),
          hourlyForecast: [
            HourlyWeatherForecast(
              localTime: now.add(const Duration(hours: 1)),
              temperatureC: 28,
              weatherCode: 61,
              isDay: true,
              windSpeedKmh: 15,
              precipitationProbability: 65,
            ),
          ],
        ),
        fetchedAt: now,
        isCached: false,
      );
      final container = ProviderContainer(
        overrides: [
          scheduleDatabaseProvider.overrideWith((ref) {
            ref.onDispose(database.close);
            return database;
          }),
          deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
          appPreferencesProvider.overrideWith(
            (ref) async => const AppPreferences(weatherEnabled: true),
          ),
          weatherReadingProvider.overrideWith((ref) async => reading),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: TodayPage(
              selectedDay: CivilDate.fromDateTime(now),
              clock: () => now,
              onSelectedDateChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Bridgetown ·'), findsOneWidget);
      expect(find.text('29°'), findsOneWidget);
      expect(find.text('Bridgetown · Partly cloudy'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('today-weather-summary-transition')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('today-weather-caption-transition')),
        findsOneWidget,
      );
      final dateLabel = MaterialLocalizations.of(
        tester.element(find.byType(TodayHero)),
      ).formatFullDate(DateTime(now.year, now.month, now.day));
      expect(
        tester.getSize(find.text(dateLabel)).height,
        lessThanOrEqualTo(48),
      );
      expect(
        tester.getRect(find.text(dateLabel)).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.text('Bridgetown · Partly cloudy')).top,
        ),
        reason: 'The place and condition belong below the full date.',
      );
      expect(
        tester.getRect(find.text('Bridgetown · Partly cloudy')).bottom,
        lessThan(tester.getRect(find.text('Next up')).top),
        reason: 'The weather caption must finish before the Next up card.',
      );
      expect(find.byKey(const ValueKey('today-weather-sun')), findsOneWidget);
      expect(find.byKey(const ValueKey('today-weather-cloud')), findsOneWidget);
      final sunGlyph = tester.getRect(
        find.byKey(const ValueKey('today-weather-sun')),
      );
      final cloudGlyph = tester.getRect(
        find.byKey(const ValueKey('today-weather-cloud')),
      );
      expect(
        sunGlyph.overlaps(cloudGlyph),
        isTrue,
        reason: 'The cloud should layer in front of the sun.',
      );
      expect(
        cloudGlyph.top,
        greaterThan(sunGlyph.top),
        reason: 'The sun should remain visible above the cloud.',
      );
      expect(
        find.bySemanticsLabel('Sky with a softly glowing sun'),
        findsNothing,
        reason: 'The weather condition already supplies the celestial icon.',
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.contains('softly glowing sun') ??
                  false),
        ),
        findsNothing,
        reason: 'A hidden decorative sun must not contradict live weather.',
      );
      expect(
        find.descendant(
          of: find.byType(TodayHero),
          matching: find.textContaining('Bridgetown ·'),
        ),
        findsOneWidget,
        reason: 'The compact weather summary sits in the Today hero.',
      );
      await tester.tap(find.text('Bridgetown · Partly cloudy'));
      await tester.pumpAndSettle();
      expect(find.text('Partly cloudy'), findsOneWidget);
      expect(find.text('Feels like 33°C'), findsOneWidget);
      expect(find.textContaining('Rain 40%'), findsOneWidget);
      expect(find.textContaining('Sunrise 5:42 AM'), findsOneWidget);
      expect(find.textContaining('Sunset 5:31 PM'), findsOneWidget);
      expect(find.text('Coming up'), findsOneWidget);
      expect(find.textContaining('Rain 65%'), findsOneWidget);
    },
  );

  testWidgets('Today refreshes weather when the app resumes', (tester) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    // Keep the lifecycle refresh inside the same selected civil day even when
    // the test suite is run close to local midnight.
    var now = DateTime(2026, 11, 16, 10);
    var weatherLoads = 0;
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
        appPreferencesProvider.overrideWith(
          (ref) async => const AppPreferences(weatherEnabled: true),
        ),
        weatherReadingProvider.overrideWith((ref) async {
          weatherLoads++;
          return _weatherReading(
            now.add(Duration(minutes: weatherLoads)),
            temperatureC: 28 + weatherLoads.toDouble(),
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TodayPage(
            selectedDay: CivilDate.fromDateTime(now),
            clock: () => now,
            onSelectedDateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(weatherLoads, 1);

    now = now.add(const Duration(minutes: 16));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(weatherLoads, 2);
    expect(find.text('30°'), findsOneWidget);

    now = now.add(const Duration(minutes: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(weatherLoads, 2, reason: 'Resume refreshes are throttled.');
  });

  testWidgets('Today pull to refresh reloads weather and schedule', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    var now = DateTime.now();
    var weatherLoads = 0;
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
        appPreferencesProvider.overrideWith(
          (ref) async => const AppPreferences(weatherEnabled: true),
        ),
        weatherReadingProvider.overrideWith((ref) async {
          weatherLoads++;
          return _weatherReading(
            now.add(Duration(minutes: weatherLoads)),
            temperatureC: 28 + weatherLoads.toDouble(),
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TodayPage(
            selectedDay: CivilDate.fromDateTime(now),
            clock: () => now,
            onSelectedDateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(weatherLoads, 1);

    await tester.drag(find.byType(ListView).first, const Offset(0, 450));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(weatherLoads, 2);
    expect(find.text('30°'), findsOneWidget);
  });

  testWidgets('swiping Today weather switches and saves the active place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final preferencesRepository = PreferencesRepository(database);
    const places = [
      WeatherPlace(
        name: 'Bridgetown',
        label: 'Bridgetown, Barbados',
        latitude: 13.1,
        longitude: -59.6,
      ),
      WeatherPlace(
        name: 'Bristol',
        label: 'Bristol, United Kingdom',
        latitude: 51.45,
        longitude: -2.59,
      ),
    ];
    await preferencesRepository.setWeatherEnabled(true);
    await preferencesRepository.setWeatherLocations(
      jsonEncode(places.map(encodeWeatherPlace).toList()),
    );
    await preferencesRepository.setWeatherLocation(
      jsonEncode(encodeWeatherPlace(places.first)),
    );
    expect(weatherPlacesFor(await preferencesRepository.load()), hasLength(2));
    final now = DateTime(2026, 11, 16, 10);
    final bristolWeather = Completer<WeatherReading?>();
    WeatherReading readingFor(WeatherPlace place) => WeatherReading(
      place: place,
      snapshot: WeatherSnapshot(
        observedAt: now,
        temperatureC: place.name == 'Bristol' ? 12 : 29,
        apparentTemperatureC: place.name == 'Bristol' ? 10 : 33,
        windSpeedKmh: 8,
        precipitationProbability: 20,
        weatherCode: 2,
        isDay: true,
        sunrise: DateTime(now.year, now.month, now.day, 6),
        sunset: DateTime(now.year, now.month, now.day, 18),
        utcOffsetSeconds: place.name == 'Bristol' ? 0 : -4 * 60 * 60,
      ),
      fetchedAt: now,
      isCached: false,
    );
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
        weatherReadingProvider.overrideWith((ref) async {
          final preferences = await ref.watch(appPreferencesProvider.future);
          final place = decodeWeatherPlace(
            jsonDecode(preferences.weatherLocationJson!),
          )!;
          if (place.name == 'Bristol') return bristolWeather.future;
          return readingFor(place);
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TodayPage(
            selectedDay: CivilDate.fromDateTime(now),
            clock: () => now,
            onSelectedDateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bridgetown · Partly cloudy'), findsOneWidget);
    expect(find.bySemanticsLabel('Weather location 1 of 2'), findsOneWidget);
    expect(find.textContaining('Local '), findsNothing);
    await tester.fling(find.text('Good Morning'), const Offset(-260, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Bristol · Updating weather'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == 'Updating weather for Bristol',
      ),
      findsOneWidget,
    );
    bristolWeather.complete(readingFor(places.last));
    await tester.pumpAndSettle();

    final saved = await preferencesRepository.load();
    expect(saved.weatherLocationJson, contains('Bristol'));
    expect(find.text('Bristol · Partly cloudy'), findsOneWidget);
    expect(find.bySemanticsLabel('Weather location 2 of 2'), findsOneWidget);
    expect(find.textContaining('Local '), findsNothing);
    await tester.fling(
      find.text('Bristol · Partly cloudy'),
      const Offset(260, 0),
      1000,
    );
    await tester.pumpAndSettle();
    final switchedBack = await preferencesRepository.load();
    expect(switchedBack.weatherLocationJson, contains('Bridgetown'));
    expect(find.text('Bridgetown · Partly cloudy'), findsOneWidget);
    await tester.timedDrag(
      find.byKey(const ValueKey('today-weather-place-pager')),
      const Offset(-100, 0),
      const Duration(seconds: 2),
    );
    await tester.pumpAndSettle();
    final wrappedToLastPlace = await preferencesRepository.load();
    expect(wrappedToLastPlace.weatherLocationJson, contains('Bristol'));
    expect(find.text('Bristol · Partly cloudy'), findsOneWidget);
  });

  testWidgets('shows an active duty instead of an empty Next up panel', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final today = CivilDate.fromDateTime(DateTime.now());
    await ScheduleRepository(database).save(
      ScheduleItem(
        id: 'active-shift-today',
        kind: ScheduleKind.work,
        title: 'Synthetic active shift',
        startDate: today,
        workCategory: WorkCategory.shift,
        intervals: [
          EventInterval.sameDay(startMinute: 9 * 60, endMinute: 17 * 60),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TodayPage(
            selectedDay: today,
            clock: () => DateTime(today.year, today.month, today.day, 12),
            onSelectedDateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Happening now'), findsOneWidget);
    expect(find.text('Synthetic active shift'), findsNWidgets(2));
    expect(find.text('ends in 5h'), findsOneWidget);
    expect(find.text('Nothing scheduled yet'), findsNothing);
  });

  testWidgets('Today refreshes an upcoming shift when it starts', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final today = CivilDate.fromDateTime(DateTime.now());
    await ScheduleRepository(database).save(
      ScheduleItem(
        id: 'upcoming-shift-today-refresh',
        kind: ScheduleKind.work,
        title: 'Synthetic shift crosses start time',
        startDate: today,
        workCategory: WorkCategory.shift,
        intervals: [
          EventInterval.sameDay(startMinute: 10 * 60, endMinute: 17 * 60),
        ],
      ),
    );
    var now = DateTime(today.year, today.month, today.day, 9, 59);
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TodayPage(
            selectedDay: today,
            clock: () => now,
            onSelectedDateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Synthetic shift crosses start time'), findsNWidgets(2));
    expect(find.text('Happening now'), findsNothing);

    now = DateTime(today.year, today.month, today.day, 10, 1);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();

    expect(find.text('Happening now'), findsOneWidget);
    expect(find.text('Synthetic shift crosses start time'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses Goodnight and the night sky for a local night time', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final today = CivilDate.fromDateTime(DateTime.now());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: TodayPage(
            selectedDay: today,
            clock: () => DateTime(today.year, today.month, today.day, 21, 24),
            onSelectedDateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1300));

    expect(find.text('Goodnight'), findsOneWidget);
    expect(find.text('A quiet night ahead'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                'Night sky with a softly glowing crescent moon',
      ),
      findsOneWidget,
    );
    expect(find.text('A little room in your day'), findsNothing);
    expect(TodayHero.isNightForHour(21), isTrue);
    expect(TodayHero.isNightForHour(20), isFalse);
    expect(TodayHero.isNightForHour(17), isFalse);
  });

  testWidgets(
    'night weather keeps the compact Today layout and uses a moon icon',
    (tester) async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      final now = DateTime.now();
      final reading = WeatherReading(
        place: const WeatherPlace(
          name: 'Bridgetown',
          label: 'Bridgetown, Barbados',
          latitude: 13.1,
          longitude: -59.6,
        ),
        snapshot: WeatherSnapshot(
          observedAt: now,
          temperatureC: 26,
          apparentTemperatureC: 28,
          windSpeedKmh: 12,
          precipitationProbability: 20,
          weatherCode: 2,
          isDay: false,
          sunrise: DateTime(now.year, now.month, now.day, 5, 42),
          sunset: DateTime(now.year, now.month, now.day, 17, 31),
        ),
        fetchedAt: now,
        isCached: false,
      );
      final today = CivilDate.fromDateTime(now);
      final container = ProviderContainer(
        overrides: [
          scheduleDatabaseProvider.overrideWith((ref) {
            ref.onDispose(database.close);
            return database;
          }),
          deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
          appPreferencesProvider.overrideWith(
            (ref) async => const AppPreferences(weatherEnabled: true),
          ),
          weatherReadingProvider.overrideWith((ref) async => reading),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: TodayPage(
              selectedDay: today,
              clock: () => DateTime(now.year, now.month, now.day, 19),
              onSelectedDateChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Goodnight'), findsOneWidget);
      expect(find.text('A quiet night ahead'), findsOneWidget);
      expect(find.text('26°'), findsOneWidget);
      expect(find.byKey(const ValueKey('today-weather-moon')), findsOneWidget);
      expect(find.byKey(const ValueKey('today-weather-cloud')), findsOneWidget);
      final moonGlyph = tester.getRect(
        find.byKey(const ValueKey('today-weather-moon')),
      );
      final cloudGlyph = tester.getRect(
        find.byKey(const ValueKey('today-weather-cloud')),
      );
      expect(moonGlyph.overlaps(cloudGlyph), isTrue);
      expect(cloudGlyph.top, greaterThan(moonGlyph.top));
      expect(find.text('Bridgetown · Partly cloudy'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TodayHero),
          matching: find.textContaining('Bridgetown ·'),
        ),
        findsOneWidget,
        reason: 'Day and night use the same compact weather layout.',
      );
    },
  );

  testWidgets('weather greeting uses the selected place local daylight', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime.utc(2026, 11, 17, 4, 23);
    final reading = WeatherReading(
      place: const WeatherPlace(
        name: 'Bristol',
        label: 'Bristol, United Kingdom',
        latitude: 51.45,
        longitude: -2.59,
      ),
      snapshot: WeatherSnapshot(
        observedAt: now,
        temperatureC: 12,
        apparentTemperatureC: 10,
        windSpeedKmh: 8,
        precipitationProbability: 0,
        weatherCode: 0,
        isDay: true,
        sunrise: DateTime(2026, 11, 17, 7, 30),
        sunset: DateTime(2026, 11, 17, 16, 20),
        utcOffsetSeconds: 4 * 60 * 60,
      ),
      fetchedAt: now,
      isCached: false,
    );
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
        appPreferencesProvider.overrideWith(
          (ref) async => const AppPreferences(weatherEnabled: true),
        ),
        weatherReadingProvider.overrideWith((ref) async => reading),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TodayPage(
            selectedDay: CivilDate(2026, 11, 17),
            clock: () => now,
            onSelectedDateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Good Morning'), findsOneWidget);
    expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_rounded), findsNothing);
  });

  test('moon glow stays subtle and does not draw a light-mode disc', () {
    expect(TodayHero.moonGlowOpacity(isDark: false), 0);
    expect(TodayHero.moonGlowOpacity(isDark: true), lessThanOrEqualTo(.025));
  });

  testWidgets('today date opens its picker without arrows crossing the sky', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
      ],
    );
    addTearDown(container.dispose);
    final selectedDay = CivilDate.fromDateTime(DateTime.now());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: TodayPage(
            selectedDay: selectedDay,
            onSelectedDateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dateLabel =
        MaterialLocalizations.of(tester.element(find.byType(TodayPage)))
            .formatFullDate(
              DateTime(selectedDay.year, selectedDay.month, selectedDay.day),
            );
    expect(find.byTooltip('Previous day'), findsNothing);
    expect(find.byTooltip('Next day'), findsNothing);
    final dateButton = find.ancestor(
      of: find.text(dateLabel),
      matching: find.byType(TextButton),
    );
    final renderedDate = tester.renderObject<RenderParagraph>(
      find.text(dateLabel),
    );
    expect(
      renderedDate.didExceedMaxLines,
      isFalse,
      reason:
          'The Galaxy width must show the complete local date: '
          'paragraph=${renderedDate.size}, button=${tester.getSize(dateButton)}.',
    );
    expect(
      tester.getRect(dateButton).right,
      lessThan(
        tester.view.physicalSize.width / tester.view.devicePixelRatio * .8,
      ),
      reason: 'The date tap target must leave the painted sun area clear.',
    );
    await tester.tap(find.text(dateLabel));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });
}
