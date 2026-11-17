import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/platform/device_time_zone.dart';
import 'package:shift_study/presentation/app_theme.dart';
import 'package:shift_study/presentation/screens/schedule_pages.dart';

class _BarbadosTimeZone implements DeviceTimeZone {
  @override
  Future<String> getLocalIanaId() async => 'America/Barbados';
}

void main() {
  testWidgets('work filters scroll horizontally without wrapping', (
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
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: WorkPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsOneWidget,
    );
    for (final label in [
      'Shifts',
      'Days Off',
      'Overtime',
      'Leave',
      'Training',
    ]) {
      final chip = find.widgetWithText(ChoiceChip, label);
      await tester.ensureVisible(chip);
      final rect = tester.getRect(chip);
      expect(
        rect.left,
        greaterThanOrEqualTo(0),
        reason: '$label should be reachable by scrolling',
      );
      expect(
        rect.right,
        lessThanOrEqualTo(360),
        reason: '$label is clipped right',
      );
    }
  });

  testWidgets('work summary and legend lead filters and upcoming shifts', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: WorkPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Work overview (This week)')).dy,
      lessThan(tester.getTopLeft(find.text('Shift legend')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Shift legend')).dy,
      lessThan(tester.getTopLeft(find.widgetWithText(ChoiceChip, 'Shifts')).dy),
    );
    expect(
      tester.getTopLeft(find.widgetWithText(ChoiceChip, 'Shifts')).dy,
      lessThan(tester.getTopLeft(find.text('Upcoming shifts')).dy),
    );
  });

  testWidgets('an upcoming shift changes to happening now without restart', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final today = CivilDate.fromDateTime(DateTime.now());
    await ScheduleRepository(database).save(
      ScheduleItem(
        id: 'clock-transition-shift',
        kind: ScheduleKind.work,
        title: 'Synthetic 10 to 5 shift',
        startDate: today,
        intervals: [
          EventInterval.sameDay(startMinute: 10 * 60, endMinute: 17 * 60),
        ],
        timeZoneId: 'America/Barbados',
      ),
    );
    var now = DateTime(today.year, today.month, today.day, 9, 59);
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _BarbadosTimeZone()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: WorkPage(clock: () => now)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Synthetic 10 to 5 shift'), findsOneWidget);
    expect(find.text('Happening now'), findsNothing);

    now = DateTime(today.year, today.month, today.day, 10, 1);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();

    expect(find.text('Happening now'), findsOneWidget);
    expect(find.text('HAPPENING NOW'), findsOneWidget);
    expect(find.text('Synthetic 10 to 5 shift'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'expired shifts are omitted and recurring shifts advance to the next occurrence',
    (tester) async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      final today = CivilDate(2026, 11, 16);
      final repository = ScheduleRepository(database);
      for (final (id, title) in [
        ('expired-today', 'Expired shift today'),
        ('weekly-next', 'Weekly next shift'),
      ]) {
        await repository.save(
          ScheduleItem(
            id: id,
            kind: ScheduleKind.work,
            title: title,
            startDate: today,
            intervals: [
              EventInterval.sameDay(startMinute: 12 * 60, endMinute: 20 * 60),
            ],
            timeZoneId: 'America/Barbados',
            recurrence: id == 'weekly-next'
                ? WeeklyRecurrence(
                    weekdays: {DateTime.monday},
                    until: today.addDays(14),
                  )
                : null,
          ),
        );
      }
      final now = DateTime(2026, 11, 16, 21);
      final container = ProviderContainer(
        overrides: [
          scheduleDatabaseProvider.overrideWith((ref) {
            ref.onDispose(database.close);
            return database;
          }),
          deviceTimeZoneProvider.overrideWith((ref) => _BarbadosTimeZone()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: WorkPage(clock: () => now)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Expired shift today'), findsNothing);
      expect(find.text('Weekly next shift'), findsOneWidget);
      expect(find.textContaining('Nov 23'), findsOneWidget);
      expect(find.textContaining('Nov 16'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('work cards keep extended assignment text in event details', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final tomorrow = CivilDate.fromDateTime(DateTime.now()).addDays(1);
    await ScheduleRepository(database).save(
      ScheduleItem(
        id: 'compact-work-card',
        kind: ScheduleKind.work,
        title: 'Synthetic ramp shift',
        startDate: tomorrow,
        intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 1020)],
        timeZoneId: 'America/Barbados',
        code: 'AC',
        codeMeaning: 'Synthetic arriving and departing flights',
        reportingInstruction: 'Report to synthetic north gate',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _BarbadosTimeZone()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: WorkPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Synthetic ramp shift'), findsOneWidget);
    expect(
      find.text('Code assignment: Synthetic arriving and departing flights'),
      findsNothing,
    );
    expect(find.text('Report: Report to synthetic north gate'), findsNothing);

    await tester.tap(find.text('Synthetic ramp shift'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic arriving and departing flights'), findsWidgets);
    expect(find.text('Report to synthetic north gate'), findsWidgets);
  });

  testWidgets('overlapping active shifts are not listed as upcoming', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final today = CivilDate.fromDateTime(DateTime.now());
    final repository = ScheduleRepository(database);
    for (final (id, title, startMinute) in [
      ('active-shift-one', 'Synthetic active shift one', 9 * 60),
      ('active-shift-two', 'Synthetic active shift two', 10 * 60),
    ]) {
      await repository.save(
        ScheduleItem(
          id: id,
          kind: ScheduleKind.work,
          title: title,
          startDate: today,
          intervals: [
            EventInterval.sameDay(startMinute: startMinute, endMinute: 17 * 60),
          ],
          timeZoneId: 'America/Barbados',
        ),
      );
    }
    final now = DateTime(today.year, today.month, today.day, 11, 0);
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _BarbadosTimeZone()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: WorkPage(clock: () => now)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HAPPENING NOW'), findsNWidgets(2));
    expect(find.text('Synthetic active shift one'), findsOneWidget);
    expect(find.text('Synthetic active shift two'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('work shifts show a three-item preview with a See all toggle', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final repository = ScheduleRepository(database);
    final tomorrow = CivilDate.fromDateTime(DateTime.now()).addDays(1);
    for (var day = 0; day < 4; day++) {
      await repository.save(
        ScheduleItem(
          id: 'preview-shift-$day',
          kind: ScheduleKind.work,
          title: 'Preview shift ${day + 1}',
          startDate: tomorrow.addDays(day),
          intervals: [EventInterval.sameDay(startMinute: 360, endMinute: 840)],
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
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: WorkPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Preview shift 1'));
    await tester.pumpAndSettle();
    expect(find.text('Preview shift 1'), findsOneWidget);
    expect(find.text('Preview shift 2'), findsOneWidget);
    expect(find.text('Preview shift 3'), findsOneWidget);
    expect(find.text('Preview shift 4'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(find.text('See all'), findsOneWidget);

    await tester.ensureVisible(find.text('See all'));
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.text('Preview shift 4'), findsOneWidget);
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('work filters keep days off separate from timed duties', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final repository = ScheduleRepository(database);
    final tomorrow = CivilDate.fromDateTime(DateTime.now()).addDays(1);
    for (final item in [
      ScheduleItem(
        id: 'filter-shift',
        kind: ScheduleKind.work,
        title: 'Filter QA shift',
        startDate: tomorrow,
        intervals: [EventInterval.sameDay(startMinute: 360, endMinute: 840)],
        timeZoneId: 'America/Barbados',
      ),
      ScheduleItem(
        id: 'filter-training',
        kind: ScheduleKind.work,
        title: 'Filter QA training',
        startDate: tomorrow,
        intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 660)],
        timeZoneId: 'America/Barbados',
        workCategory: WorkCategory.training,
      ),
      ScheduleItem(
        id: 'filter-overtime',
        kind: ScheduleKind.work,
        title: 'Filter QA overtime',
        startDate: tomorrow,
        intervals: [EventInterval.sameDay(startMinute: 1020, endMinute: 1260)],
        timeZoneId: 'America/Barbados',
        workCategory: WorkCategory.overtime,
        isCompleted: true,
        actualIntervals: [
          EventInterval.sameDay(startMinute: 1020, endMinute: 1380),
        ],
      ),
      ScheduleItem(
        id: 'filter-leave',
        kind: ScheduleKind.work,
        title: 'Filter QA leave',
        startDate: tomorrow.addDays(1),
        intervals: const [],
        timeZoneId: 'America/Barbados',
        workCategory: WorkCategory.leave,
      ),
      ScheduleItem(
        id: 'filter-rest-day',
        kind: ScheduleKind.work,
        title: 'Filter QA rest day',
        startDate: tomorrow.addDays(2),
        intervals: const [],
        timeZoneId: 'America/Barbados',
        workCategory: WorkCategory.restDay,
      ),
      ScheduleItem(
        id: 'filter-day-off',
        kind: ScheduleKind.work,
        title: 'Filter QA day off',
        startDate: tomorrow.addDays(3),
        intervals: const [],
        timeZoneId: 'America/Barbados',
        workCategory: WorkCategory.dayOff,
      ),
    ]) {
      await repository.save(item);
    }
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: WorkPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Filter QA shift'), findsOneWidget);
    expect(find.text('Filter QA training'), findsNothing);
    expect(find.text('Filter QA overtime'), findsNothing);
    await tester.ensureVisible(find.text('Total hours'));
    expect(tester.widget<Text>(find.text('Total hours')).maxLines, 2);
    expect(find.text('16'), findsOneWidget);
    await tester.ensureVisible(find.text('Shifts').last);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Shifts and overtime are timed duties.'), findsOneWidget);
    expect(find.text('View full roster'), findsNothing);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Overtime'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Overtime'));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming overtime'), findsOneWidget);
    expect(find.text('Filter QA overtime'), findsOneWidget);
    expect(find.text('Filter QA shift'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Days Off'));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming days off'), findsOneWidget);
    expect(find.text('Filter QA shift'), findsNothing);
    expect(find.text('Filter QA training'), findsNothing);
    expect(find.text('Filter QA overtime'), findsNothing);
    expect(find.text('Filter QA leave'), findsNothing);
    expect(find.text('Filter QA rest day'), findsOneWidget);
    expect(find.text('Filter QA day off'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Filter QA leave'), findsOneWidget);
    expect(find.text('Filter QA shift'), findsNothing);
    expect(find.text('Filter QA rest day'), findsNothing);
  });

  testWidgets('study filters distinguish classes, assignments, and exams', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final repository = ScheduleRepository(database);
    final tomorrow = CivilDate.fromDateTime(DateTime.now()).addDays(1);
    for (final item in [
      ScheduleItem(
        id: 'filter-class',
        kind: ScheduleKind.classSession,
        title: 'Filter QA class',
        startDate: tomorrow,
        intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 690)],
        timeZoneId: 'America/Barbados',
      ),
      ScheduleItem(
        id: 'filter-assignment',
        kind: ScheduleKind.deadline,
        title: 'Filter QA assignment',
        startDate: tomorrow,
        intervals: const [],
        deadlineType: DeadlineType.assignment,
      ),
      ScheduleItem(
        id: 'filter-exam',
        kind: ScheduleKind.deadline,
        title: 'Filter QA exam',
        startDate: tomorrow,
        intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 630)],
        deadlineType: DeadlineType.examination,
        timeZoneId: 'America/Barbados',
      ),
    ]) {
      await repository.save(item);
    }
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: StudyPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Filter QA class'), findsOneWidget);
    expect(find.text('This week’s classes'), findsOneWidget);
    expect(find.text('Deadlines'), findsOneWidget);
    expect(find.text('Filter QA assignment'), findsOneWidget);
    expect(find.text('Filter QA exam'), findsOneWidget);

    await tester.tap(find.text('Assignments'));
    await tester.pumpAndSettle();
    expect(find.text('Filter QA assignment'), findsOneWidget);
    expect(find.text('Filter QA class'), findsNothing);
    expect(find.text('Filter QA exam'), findsNothing);
    expect(find.text('Deadlines'), findsNothing);

    await tester.tap(find.text('Exams'));
    await tester.pumpAndSettle();
    expect(find.text('Filter QA exam'), findsOneWidget);
    expect(find.text('Filter QA assignment'), findsNothing);
  });

  testWidgets('study empty states provide a relevant add action', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: StudyPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No upcoming classes'), findsOneWidget);
    expect(find.text('Add class'), findsOneWidget);
    await tester.tap(find.text('Assignments'));
    await tester.pumpAndSettle();
    expect(find.text('No upcoming assignments'), findsOneWidget);
    expect(
      find.text(
        "You're all caught up. Add an assignment when you have something due.",
      ),
      findsOneWidget,
    );
    expect(find.text('Add assignment'), findsOneWidget);
    await tester.tap(find.text('Exams'));
    await tester.pumpAndSettle();
    expect(find.text('No upcoming exams'), findsOneWidget);
    expect(find.text('Add exam'), findsOneWidget);
  });

  testWidgets(
    'study empty state stays specific when other categories have events',
    (tester) async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      await ScheduleRepository(database).save(
        ScheduleItem(
          id: 'unrelated-class',
          kind: ScheduleKind.classSession,
          title: 'Existing class',
          startDate: CivilDate.fromDateTime(DateTime.now()).addDays(1),
          intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 690)],
          timeZoneId: 'America/Barbados',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          scheduleDatabaseProvider.overrideWith((ref) {
            ref.onDispose(database.close);
            return database;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: StudyPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Assignments'));
      await tester.pumpAndSettle();
      expect(find.text('No upcoming assignments'), findsOneWidget);
      expect(find.text('Add assignment'), findsOneWidget);
      expect(find.text('Nothing in this filter'), findsNothing);

      await tester.tap(find.text('Exams'));
      await tester.pumpAndSettle();
      expect(find.text('No upcoming exams'), findsOneWidget);
      expect(find.text('Add exam'), findsOneWidget);
      expect(find.text('Nothing in this filter'), findsNothing);
    },
  );
}
