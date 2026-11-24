import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/data/work_overtime_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/presentation/app_theme.dart';
import 'package:shift_study/presentation/screens/schedule_pages.dart';
import 'package:shift_study/presentation/widgets/schedule_details_sheet.dart';

void main() {
  late ScheduleDatabase database;
  late ScheduleRepository scheduleRepository;
  late WorkOvertimeRepository overtimeRepository;

  setUp(() {
    database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    scheduleRepository = ScheduleRepository(database);
    overtimeRepository = WorkOvertimeRepository(database);
  });

  tearDown(() async => database.close());

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('logs extra duration without changing split shift intervals', (
    tester,
  ) async {
    final shift = ScheduleItem(
      id: 'synthetic-overtime-ui',
      kind: ScheduleKind.work,
      title: 'Synthetic split shift',
      startDate: CivilDate(2026, 11, 22),
      intervals: [
        EventInterval.sameDay(startMinute: 360, endMinute: 540),
        EventInterval.sameDay(startMinute: 780, endMinute: 960),
      ],
    );
    await scheduleRepository.save(shift);
    final container = createContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showScheduleDetails(context, ref, shift),
                child: const Text('Open shift'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open shift'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add overtime hours'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add overtime hours'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2');
    await tester.tap(find.text('Save hours'));
    await tester.pumpAndSettle();

    expect(
      await overtimeRepository.getForOccurrence(shift.id, shift.startDate),
      isNotNull,
    );
    final savedShift = (await scheduleRepository.getItems()).single;
    expect(savedShift.intervals, shift.intervals);
    expect(find.textContaining('Total 8h'), findsOneWidget);
    expect(
      find.textContaining('No daily threshold is set for this employer.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Overtime filter includes a shift with logged extra hours', (
    tester,
  ) async {
    final shift = ScheduleItem(
      id: 'synthetic-overtime-filter',
      kind: ScheduleKind.work,
      title: 'Synthetic early shift',
      startDate: CivilDate(2026, 11, 22),
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 900)],
    );
    await scheduleRepository.save(shift);
    await overtimeRepository.setForOccurrence(shift, shift.startDate, 120);
    final container = createContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: WorkPage(clock: () => DateTime(2026, 11, 22, 8)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overtime'));
    await tester.pumpAndSettle();

    expect(find.text('Synthetic early shift'), findsOneWidget);
    expect(find.text('Hours + extra'), findsOneWidget);
    expect(
      find.textContaining('Past roster dates through yesterday'),
      findsNothing,
    );
    expect(find.textContaining('Over 8h per shift'), findsNothing);
    expect(
      find.textContaining('Rostered: 6h · Extra logged: 2h · Total: 8h'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'month-to-date work summary excludes future shifts and includes training',
    (tester) async {
      await scheduleRepository.save(
        ScheduleItem(
          id: 'synthetic-month-past-shift',
          kind: ScheduleKind.work,
          title: 'Synthetic completed Sunday shift',
          startDate: CivilDate(2026, 11, 22),
          intervals: [EventInterval.sameDay(startMinute: 300, endMinute: 540)],
        ),
      );
      await overtimeRepository.setForOccurrence(
        (await scheduleRepository.getItems()).single,
        CivilDate(2026, 11, 22),
        120,
      );
      await scheduleRepository.save(
        ScheduleItem(
          id: 'synthetic-month-future-shift',
          kind: ScheduleKind.work,
          title: 'Synthetic future Tuesday shift',
          startDate: CivilDate(2026, 11, 24),
          intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 840)],
        ),
      );
      await scheduleRepository.save(
        ScheduleItem(
          id: 'synthetic-month-training',
          kind: ScheduleKind.work,
          title: 'Synthetic training',
          workCategory: WorkCategory.training,
          startDate: CivilDate(2026, 11, 20),
          intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 1020)],
        ),
      );
      await scheduleRepository.save(
        ScheduleItem(
          id: 'synthetic-month-day-off',
          kind: ScheduleKind.work,
          title: 'Synthetic day off',
          workCategory: WorkCategory.dayOff,
          startDate: CivilDate(2026, 11, 21),
          intervals: const [],
        ),
      );
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: WorkPage(clock: () => DateTime(2026, 11, 23, 9)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Work overview · November 2026'), findsOneWidget);
      expect(find.text('Hours + extra'), findsOneWidget);
      expect(find.text('7h'), findsOneWidget);
      expect(find.text('1 session'), findsOneWidget);
      final summaryCardHeights = ['Hours + extra', 'Shifts', 'Training'].map((
        label,
      ) {
        final card = find
            .ancestor(of: find.text(label).first, matching: find.byType(Card))
            .first;
        return tester.getSize(card).height;
      }).toSet();
      expect(
        summaryCardHeights,
        hasLength(1),
        reason: 'The three work summary cards should align to one height.',
      );
      expect(
        tester.widgetList<Text>(find.byType(Text)).map((text) => text.data),
        contains('6'),
        reason: 'Rendered summary values should include scheduled plus extra hours.',
      );
      expect(find.text('Shifts'), findsNWidgets(2));
      expect(find.text('Training'), findsNWidgets(2));
      expect(find.textContaining('Training: 1 session · 7h'), findsNothing);
      expect(find.textContaining('Days off: 1'), findsNothing);
      expect(find.textContaining('Overtime shifts: 1'), findsNothing);
      expect(find.textContaining('Extra hours logged: 2h'), findsNothing);
      expect(
        find.textContaining('Past roster dates through yesterday'),
        findsNothing,
      );
      expect(find.text('Synthetic future Tuesday shift'), findsOneWidget);
      expect(find.textContaining('Work overview'), findsOneWidget);
      expect(find.textContaining('This week'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('split intervals count as one rostered shift in the summary', (
    tester,
  ) async {
    const date = CivilDate(2026, 11, 22);
    for (final item in [
      ScheduleItem(
        id: 'synthetic-split-morning',
        kind: ScheduleKind.work,
        title: 'Synthetic split morning',
        startDate: date,
        code: 'A1',
        employerName: 'Synthetic employer',
        intervals: [EventInterval.sameDay(startMinute: 360, endMinute: 540)],
      ),
      ScheduleItem(
        id: 'synthetic-split-afternoon',
        kind: ScheduleKind.work,
        title: 'Synthetic split afternoon',
        startDate: date,
        code: 'A1',
        employerName: 'Synthetic employer',
        intervals: [EventInterval.sameDay(startMinute: 780, endMinute: 960)],
      ),
    ]) {
      await scheduleRepository.save(item);
    }
    final container = createContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: WorkPage(clock: () => DateTime(2026, 11, 23, 9)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final summaryCard = find
        .ancestor(of: find.text('Shifts').first, matching: find.byType(Card))
        .first;
    expect(
      find.descendant(of: summaryCard, matching: find.text('1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'matches a configured employer across split rows with a missing employer field',
    (tester) async {
      const date = CivilDate(2026, 11, 22);
      final morning = ScheduleItem(
        id: 'synthetic-cah-split-morning',
        kind: ScheduleKind.work,
        title: 'CAH A1 - Morning block',
        startDate: date,
        code: 'A1',
        intervals: [EventInterval.sameDay(startMinute: 360, endMinute: 540)],
      );
      final afternoon = ScheduleItem(
        id: 'synthetic-cah-split-afternoon',
        kind: ScheduleKind.work,
        title: 'CAH A1 - Afternoon block',
        startDate: date,
        code: 'A1',
        employerName: 'CAH',
        intervals: [EventInterval.sameDay(startMinute: 720, endMinute: 960)],
      );
      await scheduleRepository.save(morning);
      await scheduleRepository.save(afternoon);
      await overtimeRepository.setForOccurrence(afternoon, date, 180);
      await PreferencesRepository(database).setOvertimeThreshold('CAH', 8 * 60);
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: WorkPage(clock: () => DateTime(2026, 11, 23, 9)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final shiftCard = find
          .ancestor(of: find.text('Shifts').first, matching: find.byType(Card))
          .first;
      expect(
        find.descendant(of: shiftCard, matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Top-up to standard: 1h · Above threshold: 2h'),
        findsNothing,
      );
      await tester.tap(find.text('Overtime'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Top-up to standard: 1h · Above threshold: 2h'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('daily overtime replaces prior actual-time extension in totals', (
    tester,
  ) async {
    const date = CivilDate(2026, 11, 22);
    final morning = ScheduleItem(
      id: 'synthetic-daily-overtime-morning',
      kind: ScheduleKind.work,
      title: 'Synthetic morning block',
      startDate: date,
      code: 'A1',
      employerName: 'Synthetic employer',
      intervals: [EventInterval.sameDay(startMinute: 360, endMinute: 540)],
    );
    final afternoon = ScheduleItem(
      id: 'synthetic-daily-overtime-afternoon',
      kind: ScheduleKind.work,
      title: 'Synthetic afternoon block',
      startDate: date,
      code: 'A1',
      employerName: 'Synthetic employer',
      intervals: [EventInterval.sameDay(startMinute: 720, endMinute: 960)],
      actualIntervals: [
        EventInterval.sameDay(startMinute: 720, endMinute: 1020),
      ],
      isCompleted: true,
    );
    await scheduleRepository.save(morning);
    await scheduleRepository.save(afternoon);
    await overtimeRepository.setForOccurrence(morning, date, 60);
    await PreferencesRepository(database)
        .setOvertimeThreshold('Synthetic employer', 8 * 60);
    final container = createContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: WorkPage(clock: () => DateTime(2026, 11, 23, 9)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Top-up to standard: 1h · Above threshold: 0h'),
      findsNothing,
    );
    await tester.tap(find.text('Overtime'));
    await tester.pumpAndSettle();
    final hoursCard = find
        .ancestor(
          of: find.text('Hours + extra').first,
          matching: find.byType(Card),
        )
        .first;
    expect(
      find.descendant(of: hoursCard, matching: find.text('8')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Top-up to standard: 1h · Above threshold: 0h'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Overtime filter keeps the adjusted future recurrence date', (
    tester,
  ) async {
    final shift = ScheduleItem(
      id: 'synthetic-recurring-overtime-filter',
      kind: ScheduleKind.work,
      title: 'Synthetic recurring overtime shift',
      startDate: CivilDate(2026, 11, 23),
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 1020)],
      recurrence: WeeklyRecurrence(weekdays: {DateTime.monday}, until: null),
    );
    await scheduleRepository.save(shift);
    await overtimeRepository.setForOccurrence(
      shift,
      CivilDate(2026, 11, 30),
      120,
    );
    final container = createContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: WorkPage(clock: () => DateTime(2026, 11, 30, 8)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overtime'));
    await tester.pumpAndSettle();

    expect(find.text('Synthetic recurring overtime shift'), findsOneWidget);
    expect(find.textContaining('Nov 30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Overtime filter clearly shows logged past overtime', (
    tester,
  ) async {
    final shift = ScheduleItem(
      id: 'synthetic-past-overtime-history',
      kind: ScheduleKind.work,
      title: 'Synthetic completed overtime shift',
      employerName: 'Synthetic employer',
      startDate: CivilDate(2026, 11, 21),
      intervals: [EventInterval.sameDay(startMinute: 360, endMinute: 780)],
    );
    await scheduleRepository.save(shift);
    await overtimeRepository.setForOccurrence(shift, shift.startDate, 180);
    expect(
      (await overtimeRepository.getForOccurrence(
        shift.id,
        shift.startDate,
      ))?.minutes,
      180,
    );
    final container = createContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: WorkPage(clock: () => DateTime(2026, 11, 23, 8)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overtime'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('Past overtime'), findsOneWidget);
    expect(find.text('Synthetic completed overtime shift'), findsOneWidget);
    expect(find.textContaining('Extra logged: 3h'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Overtime filter keeps a shift that ended earlier today', (
    tester,
  ) async {
    final shift = ScheduleItem(
      id: 'synthetic-same-day-ended-overtime',
      kind: ScheduleKind.work,
      title: 'Synthetic shift ended today',
      employerName: 'Synthetic employer',
      startDate: CivilDate(2026, 11, 22),
      timeZoneId: 'America/Halifax',
      intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 1020)],
    );
    await scheduleRepository.save(shift);
    await overtimeRepository.setForOccurrence(shift, shift.startDate, 60);
    final container = createContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: WorkPage(clock: () => DateTime(2026, 11, 22, 17, 5)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overtime'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('Past overtime'), findsOneWidget);
    expect(find.text('Synthetic shift ended today'), findsOneWidget);
    expect(find.textContaining('Extra logged: 1h'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Overtime filter keeps past entries beside upcoming overtime', (
    tester,
  ) async {
    final pastShift = ScheduleItem(
      id: 'synthetic-past-overtime-with-upcoming',
      kind: ScheduleKind.work,
      title: 'Synthetic past overtime',
      startDate: CivilDate(2026, 11, 21),
      intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 1020)],
    );
    final upcomingShift = ScheduleItem(
      id: 'synthetic-upcoming-overtime-with-past',
      kind: ScheduleKind.work,
      title: 'Synthetic upcoming overtime',
      startDate: CivilDate(2026, 11, 23),
      intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 1020)],
    );
    await scheduleRepository.save(pastShift);
    await scheduleRepository.save(upcomingShift);
    await overtimeRepository.setForOccurrence(
      pastShift,
      pastShift.startDate,
      60,
    );
    await overtimeRepository.setForOccurrence(
      upcomingShift,
      upcomingShift.startDate,
      60,
    );
    final container = createContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: WorkPage(clock: () => DateTime(2026, 11, 22, 8)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overtime'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('Synthetic upcoming overtime'), findsOneWidget);
    expect(find.text('Past overtime'), findsOneWidget);
    expect(find.text('Synthetic past overtime'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Overtime shows split-shift hours under its employer daily rule',
    (tester) async {
      final shift = ScheduleItem(
        id: 'synthetic-split-overtime-threshold',
        kind: ScheduleKind.work,
        title: 'Synthetic split shift',
        employerName: 'Synthetic Ramp Co',
        startDate: CivilDate(2026, 11, 22),
        intervals: [
          EventInterval.sameDay(startMinute: 360, endMinute: 540),
          EventInterval.sameDay(startMinute: 720, endMinute: 960),
        ],
      );
      await scheduleRepository.save(shift);
      await overtimeRepository.setForOccurrence(shift, shift.startDate, 180);
      await PreferencesRepository(database)
          .setOvertimeThreshold('Synthetic Ramp Co', 8 * 60);
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: WorkPage(clock: () => DateTime(2026, 11, 22, 4)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overtime'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Top-up to standard: 1h · Above threshold: 2h'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Rostered: 7h · Extra logged: 3h · Total: 10h'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Overtime breakdown totals split segments saved as separate rows',
    (tester) async {
      final morning = ScheduleItem(
        id: 'synthetic-split-morning-row',
        kind: ScheduleKind.work,
        title: 'Synthetic split shift morning',
        employerName: 'Synthetic Ramp Co',
        startDate: CivilDate(2026, 11, 21),
        intervals: [EventInterval.sameDay(startMinute: 360, endMinute: 600)],
      );
      final afternoon = ScheduleItem(
        id: 'synthetic-split-afternoon-row',
        kind: ScheduleKind.work,
        title: 'Synthetic split shift afternoon',
        employerName: 'Synthetic Ramp Co',
        startDate: CivilDate(2026, 11, 21),
        intervals: [EventInterval.sameDay(startMinute: 780, endMinute: 960)],
      );
      await scheduleRepository.save(morning);
      await scheduleRepository.save(afternoon);
      await overtimeRepository.setForOccurrence(
        afternoon,
        afternoon.startDate,
        180,
      );
      await PreferencesRepository(database)
          .setOvertimeThreshold('Synthetic Ramp Co', 8 * 60);
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: WorkPage(clock: () => DateTime(2026, 11, 23, 8)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overtime'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Rostered: 7h · Extra logged: 3h · Total: 10h · Top-up to standard: 1h · Above threshold: 2h',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
