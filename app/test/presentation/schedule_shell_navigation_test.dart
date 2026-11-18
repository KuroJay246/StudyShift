import 'dart:ui' show Tristate;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/platform/device_time_zone.dart';
import 'package:shift_study/platform/local_reminders.dart';
import 'package:shift_study/presentation/app.dart';
import 'package:shift_study/presentation/app_theme.dart';
import 'package:shift_study/presentation/screens/event_editor_page.dart';
import 'package:shift_study/presentation/screens/schedule_pages.dart';
import 'package:shift_study/presentation/widgets/schedule_event_tile.dart';
import 'package:shift_study/presentation/widgets/today_hero.dart';

class _TestTimeZone implements DeviceTimeZone {
  @override
  Future<String> getLocalIanaId() async => 'America/Barbados';
}

class _MutableTimeZone implements DeviceTimeZone {
  String current = 'America/Barbados';

  @override
  Future<String> getLocalIanaId() async => current;
}

class _ReminderPermissionService extends LocalReminderService {
  _ReminderPermissionService(this.onRequest);

  final VoidCallback onRequest;

  @override
  Future<bool> requestNotificationPermission() async {
    onRequest();
    return true;
  }
}

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

  testWidgets('a Calendar widget launch opens the Week destination', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ScheduleShell(
            mode: ScheduleMode.workAndSchool,
            initialDestination: 'week',
            clock: () => DateTime(2026, 11, 8, 10),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Calendar'),
      ),
      findsOneWidget,
    );
    expect(find.text('Week'), findsOneWidget);
    expect(find.byTooltip('Set up reminders'), findsNothing);
    expect(find.text('This week is open'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Today'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Set up reminders'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Work'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Set up reminders'), findsNothing);
  });

  testWidgets('selecting a date in Week updates the visible day agenda', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final repository = ScheduleRepository(database);
    const selectedDay = CivilDate(2026, 11, 11);
    for (final event in [
      ScheduleItem(
        id: 'week-selected-work',
        kind: ScheduleKind.work,
        title: 'Synthetic ramp shift',
        startDate: selectedDay,
        intervals: [
          EventInterval.sameDay(startMinute: 9 * 60, endMinute: 10 * 60),
        ],
        timeZoneId: 'America/Barbados',
      ),
      ScheduleItem(
        id: 'week-selected-class',
        kind: ScheduleKind.classSession,
        title: 'Synthetic study class',
        startDate: selectedDay,
        intervals: [
          EventInterval.sameDay(startMinute: 9 * 60, endMinute: 10 * 60),
        ],
        timeZoneId: 'America/Barbados',
      ),
    ]) {
      await repository.save(event);
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
          home: ScheduleShell(
            mode: ScheduleMode.workAndSchool,
            initialDestination: 'week',
            clock: () => DateTime(2026, 11, 9, 10),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final wednesday = find.bySemanticsLabel('Wednesday, November 11, 2026');
    await tester.tap(wednesday);
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(wednesday).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      find.text('Wednesday, November 11, 2026 · 2 events'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('week-selected-day-timeline')), findsOneWidget);
    final selectedTimeline = find.byKey(
      const Key('week-selected-day-timeline'),
    );
    expect(
      find.descendant(
        of: selectedTimeline,
        matching: find.text('2 overlapping events'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(Key('week-overlap-group-$selectedDay-2')));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic ramp shift'), findsNWidgets(2));
    expect(find.text('Synthetic study class'), findsNWidgets(2));
  });

  testWidgets(
    'horizontal swipes move through destinations and tabs still work',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
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

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: ScheduleShell(
              mode: ScheduleMode.workAndSchool,
              clock: () => DateTime(2026, 11, 16, 9),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> swipeCurrentPageLeft() async {
        await tester.drag(
          find.byKey(const Key('schedule-primary-swipe-handle')),
          const Offset(-120, 0),
        );
        await tester.pumpAndSettle();
      }

      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      final weekPage = find.byType(WeekPage, skipOffstage: false);
      expect(tester.getTopLeft(weekPage).dx, greaterThan(0));
      await swipeCurrentPageLeft();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(tester.getTopLeft(weekPage).dx, closeTo(0, 0.1));

      await tester.drag(
        find.byKey(const Key('schedule-primary-swipe-handle')),
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(
        tester.getTopLeft(find.byType(WorkPage, skipOffstage: false)).dx,
        closeTo(0, 0.1),
      );

      await tester.dragFrom(const Offset(206, 500), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );

      await tester.drag(
        find.byKey(const Key('schedule-primary-swipe-handle')),
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );

      await swipeCurrentPageLeft();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3,
      );
      await tester.dragFrom(const Offset(206, 500), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );

      await tester.dragFrom(const Offset(206, 500), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Today'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );

      await tester.drag(
        find.byKey(const Key('schedule-primary-swipe-handle')),
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
    },
  );

  testWidgets('destination page follows the finger before the swipe ends', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ScheduleShell(
            mode: ScheduleMode.workAndSchool,
            clock: () => DateTime(2026, 11, 16, 9),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final weekPage = find.byType(WeekPage, skipOffstage: false);
    final startX = tester.getTopLeft(weekPage).dx;
    final swipeHandle = find.byKey(const Key('schedule-primary-swipe-handle'));
    final gesture = await tester.startGesture(tester.getCenter(swipeHandle));
    await gesture.moveBy(
      const Offset(-80, 0),
      timeStamp: const Duration(milliseconds: 100),
    );
    await tester.pump();

    expect(
      tester.getTopLeft(weekPage).dx,
      lessThan(startX - 20),
      reason: 'The adjacent destination should track a deliberate drag.',
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });

  testWidgets(
    'calendar body keeps its horizontal control; header swipe navigates pages',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
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

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: false),
              child: ScheduleShell(
                mode: ScheduleMode.workAndSchool,
                initialDestination: 'week',
                clock: () => DateTime(2026, 11, 16, 9),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final workPage = find.byType(WorkPage, skipOffstage: false);
      expect(tester.getTopLeft(workPage).dx, greaterThan(0));
      final weekPage = find.byType(WeekPage, skipOffstage: false);
      final startX = tester.getTopLeft(weekPage).dx;
      final weekTitle = find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Calendar'),
      );
      expect(weekTitle, findsOneWidget);
      expect(tester.getTopLeft(weekTitle).dx, lessThan(40));

      final verticalDrag = await tester.startGesture(const Offset(206, 520));
      await tester.pump();
      await verticalDrag.moveBy(
        const Offset(-100, 120),
        timeStamp: const Duration(milliseconds: 60),
      );
      await tester.pump();
      await verticalDrag.up();
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
        reason: 'A mostly vertical Calendar drag must remain a scroll gesture.',
      );
      expect(tester.getTopLeft(weekPage).dx, closeTo(startX, 0.1));

      final gesture = await tester.startGesture(const Offset(206, 520));
      await tester.pump();
      await gesture.moveBy(
        const Offset(-120, 0),
        timeStamp: const Duration(milliseconds: 40),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
        reason: 'Horizontal calendar content gestures stay on the calendar.',
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
        reason: 'The calendar must not switch destinations from body swipes.',
      );
      expect(tester.getTopLeft(weekPage).dx, closeTo(startX, 0.1));

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Calendar'),
        ),
      );
      await tester.pumpAndSettle();

      final rangeHeader = find.byKey(
        const ValueKey('week-range-navigation-header'),
      );
      expect(rangeHeader, findsOneWidget);
      await tester.drag(rangeHeader, const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
        reason: 'The week range header changes the calendar range only.',
      );
      expect(tester.getTopLeft(workPage).dx, greaterThan(0));
    },
  );

  testWidgets('device time-zone changes take effect when Today resumes', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final zone = _MutableTimeZone();
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => zone),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ScheduleShell(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(deviceTimeZoneIdProvider).value, 'America/Barbados');

    zone.current = 'America/New_York';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(container.read(deviceTimeZoneIdProvider).value, 'America/New_York');
  });

  testWidgets('week date range can wrap at large accessibility text sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.75)),
            child: ScheduleShell(
              mode: ScheduleMode.workAndSchool,
              initialDestination: 'week',
              clock: () => DateTime(2026, 11, 8, 10),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final range = tester.widget<Text>(
      find.byKey(const Key('week-range-label')),
    );
    expect(range.maxLines, 2);
    expect(range.softWrap, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only the selected destination runs its animations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ScheduleShell(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pump();

    final today = find.byType(TodayHero, skipOffstage: false);
    expect(TickerMode.valuesOf(tester.element(today)).enabled, isTrue);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Work'),
      ),
    );
    await tester.pump();

    expect(TickerMode.valuesOf(tester.element(today)).enabled, isFalse);
  });

  testWidgets('the reminder bell explains reminders before asking permission', (
    tester,
  ) async {
    var requests = 0;
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
        localReminderServiceProvider.overrideWith(
          (ref) => _ReminderPermissionService(() => requests++),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ScheduleShell(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Set up reminders'));
    await tester.pumpAndSettle();

    expect(requests, 0);
    expect(find.text('Shift and class reminders'), findsOneWidget);
    expect(find.textContaining('when you add a reminder'), findsOneWidget);
    await tester.tap(find.text('Enable reminders'));
    await tester.pumpAndSettle();

    expect(requests, 1);
    expect(find.text('Reminder notifications are enabled.'), findsOneWidget);
  });
  testWidgets('short landscape layout adapts navigation to a compact rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 24, bottom: 24),
                viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
              ),
              child: const ScheduleShell(mode: ScheduleMode.workAndSchool),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final emptyTitle = TodayHero.isNightForHour(DateTime.now().hour)
        ? 'A quiet night ahead'
        : 'A little room in your day';
    expect(find.byType(TodayHero), findsOneWidget);
    expect(
      find.text(greetingForLocalHour(DateTime.now().hour)),
      findsOneWidget,
    );
    expect(find.text('Next up'), findsOneWidget);
    expect(find.text('Nothing scheduled yet'), findsOneWidget);
    expect(find.text(emptyTitle), findsOneWidget);
    expect(
      find.text('Add a shift, class or plan whenever you’re ready.'),
      findsOneWidget,
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Add event'), findsOneWidget);
    await tester.tap(find.byTooltip('Add event'));
    await tester.pumpAndSettle();
    expect(find.text('Add to your schedule'), findsOneWidget);
    expect(find.text('Work shift'), findsOneWidget);
    expect(find.text('Class'), findsOneWidget);
    expect(find.text('Assignment'), findsOneWidget);
    expect(find.text('Examination'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byIcon(Icons.calendar_month_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This week is open'), findsOneWidget);
    expect(find.byKey(const Key('schedule-page-viewport')), findsOneWidget);
    expect(
      find.text('Add a shift, class or plan to start filling in your week.'),
      findsNothing,
      reason: 'A short landscape viewport should keep more of the time grid visible.',
    );
    expect(find.byKey(const Key('week-day-header-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty Today and Work keep Add in the top app bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ScheduleShell(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Add event'), findsOneWidget);

    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Add shift'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Study Add button describes the available school item choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ScheduleShell(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Study').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Exams'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exams'));
    await tester.pumpAndSettle();

    expect(find.text('Add exam'), findsOneWidget);
    expect(find.byTooltip('Add class'), findsNothing);
    expect(find.byTooltip('Add a class, assignment, or exam'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today moves Add to the toolbar when event cards are visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    const today = CivilDate(2026, 11, 7);
    final repository = ScheduleRepository(database);
    for (var index = 0; index < 8; index++) {
      final start = 7 * 60 + index * 70;
      await repository.save(
        ScheduleItem(
          id: 'qa-fab-event-$index',
          kind: ScheduleKind.work,
          title: 'QA FAB event $index',
          startDate: today,
          intervals: [
            EventInterval.sameDay(startMinute: start, endMinute: start + 45),
          ],
          timeZoneId: 'America/Barbados',
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
          home: ScheduleShell(
            mode: ScheduleMode.workAndSchool,
            clock: () => DateTime(2026, 11, 7, 12),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Add event'), findsOneWidget);

    final lastEvent = find.byWidgetPredicate(
      (widget) =>
          widget is ScheduleEventTile && widget.item.title == 'QA FAB event 7',
    );
    await tester.scrollUntilVisible(
      lastEvent,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(lastEvent, findsOneWidget);
    expect(
      tester
          .getRect(lastEvent)
          .overlaps(tester.getRect(find.byTooltip('Add event'))),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today follows local date rollover on resume', (tester) async {
    var clock = DateTime(2026, 11, 6, 23, 59);
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ScheduleShell(
            mode: ScheduleMode.workAndSchool,
            clock: () => clock,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(ScheduleShell)),
    );
    expect(
      find.text(localizations.formatFullDate(DateTime(2026, 11, 6))),
      findsOneWidget,
    );

    clock = DateTime(2026, 11, 7, 0, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(
      find.text(localizations.formatFullDate(DateTime(2026, 11, 7))),
      findsOneWidget,
    );
    expect(find.text('Today’s schedule'), findsOneWidget);

    await tester.tap(
      find.text(localizations.formatFullDate(DateTime(2026, 11, 7))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('8').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    clock = DateTime(2026, 11, 9, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(
      find.text(localizations.formatFullDate(DateTime(2026, 11, 8))),
      findsOneWidget,
    );
  });

  testWidgets('Today and Week preserve one focused date', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final today = CivilDate.fromDateTime(DateTime.now());
    final monthFocus = today.addDays(8);
    final viewedMonth = CivilDate(monthFocus.year, monthFocus.month, 1);
    final repository = ScheduleRepository(database);
    await repository.save(
      ScheduleItem(
        id: 'month-summary-shift',
        kind: ScheduleKind.work,
        title: 'Synthetic ramp shift',
        startDate: viewedMonth.addDays(1),
        intervals: [
          EventInterval.sameDay(startMinute: 9 * 60, endMinute: 17 * 60),
        ],
        timeZoneId: 'America/Barbados',
      ),
    );
    final nextMonth = DateTime(viewedMonth.year, viewedMonth.month + 1, 1);
    await repository.save(
      ScheduleItem(
        id: 'next-month-summary-plan',
        kind: ScheduleKind.personal,
        title: 'Synthetic next-month plan',
        startDate: CivilDate(nextMonth.year, nextMonth.month, nextMonth.day),
        intervals: const [],
        allDay: true,
      ),
    );
    await repository.save(
      ScheduleItem(
        id: 'month-summary-class',
        kind: ScheduleKind.classSession,
        title: 'Synthetic lecture',
        startDate: viewedMonth.addDays(2),
        intervals: [
          EventInterval.sameDay(startMinute: 10 * 60, endMinute: 11 * 60),
        ],
        timeZoneId: 'America/Barbados',
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
          home: const ScheduleShell(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(ScheduleShell)),
    );
    final todayLabel = localizations.formatFullDate(today.toDateTime());
    await tester.tap(find.text(todayLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${today.addDays(1).day}').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        MaterialLocalizations.of(tester.element(find.byType(ScheduleShell)))
            .formatFullDate(today.addDays(1).toDateTime()),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Calendar'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Today'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        MaterialLocalizations.of(tester.element(find.byType(ScheduleShell)))
            .formatFullDate(today.addDays(8).toDateTime()),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Calendar'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        MaterialLocalizations.of(tester.element(find.byType(ScheduleShell)))
            .formatMonthYear(today.addDays(8).toDateTime()),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('1 shift · 1 class'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(WeekPage),
        matching: find.textContaining('plan'),
      ),
      findsNothing,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<bool>),
        matching: find.text('Week'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Class'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(EventEditorPage),
        matching: find.text(
          MaterialLocalizations.of(tester.element(find.byType(EventEditorPage)))
              .formatMediumDate(today.addDays(8).toDateTime()),
        ),
      ),
      findsWidgets,
    );
  });
}
