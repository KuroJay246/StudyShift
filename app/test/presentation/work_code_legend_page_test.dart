import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/supervisor_profile.dart';
import 'package:shift_study/domain/work_code_legend.dart';
import 'package:shift_study/presentation/screens/work_code_legend_page.dart';

void main() {
  testWidgets('legend separates searchable codes from supervisor contacts', (
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
        child: const MaterialApp(home: WorkCodeLegendPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shift legend'), findsOneWidget);
    expect(find.text('Codes'), findsOneWidget);
    expect(find.text('Supervisors'), findsOneWidget);
    expect(find.text('Coworkers'), findsOneWidget);
    expect(find.text('Search code or description'), findsOneWidget);
    expect(find.text('No work references saved'), findsOneWidget);

    await tester.tap(find.text('Coworkers'));
    await tester.pumpAndSettle();

    expect(find.text('No coworker assignments yet'), findsOneWidget);
    expect(find.text('Search coworkers or shifts'), findsOneWidget);
  });

  testWidgets('supervisor section adds a local contact profile', (
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
        child: const MaterialApp(home: WorkCodeLegendPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supervisors'));
    await tester.pumpAndSettle();
    expect(find.text('No supervisors saved'), findsOneWidget);

    await tester.tap(find.byTooltip('Add supervisor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Synthetic Supervisor',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone or contact number (optional)'),
      '555-0100',
    );
    await tester.tap(find.text('Save supervisor'));
    await tester.pumpAndSettle();

    expect(find.text('Synthetic Supervisor'), findsOneWidget);
    expect(find.text('555-0100'), findsOneWidget);
    expect(find.text('Permanent supervisors'), findsOneWidget);
  });

  testWidgets('coworkers section groups names with their roster shifts', (
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
    await container
        .read(scheduleRepositoryProvider)
        .save(
          ScheduleItem(
            id: 'synthetic-coworker-shift',
            kind: ScheduleKind.work,
            title: 'Synthetic morning shift',
            startDate: CivilDate(2026, 11, 18),
            intervals: [
              EventInterval.sameDay(startMinute: 360, endMinute: 540),
            ],
            workCategory: WorkCategory.shift,
            coworkers: const ['Synthetic coworker', 'Synthetic coworker'],
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WorkCodeLegendPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coworkers'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic coworker ×2'), findsOneWidget);
    expect(find.textContaining('Synthetic morning shift'), findsOneWidget);
    expect(find.textContaining('Nov 18'), findsOneWidget);
    expect(find.byTooltip('Add coworker'), findsNothing);
  });

  testWidgets('coworker roster cards stay compact with several names', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(411, 914);
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
    await container
        .read(scheduleRepositoryProvider)
        .save(
          ScheduleItem(
            id: 'synthetic-five-coworker-shift',
            kind: ScheduleKind.work,
            title: 'Synthetic afternoon shift',
            startDate: CivilDate(2026, 11, 24),
            intervals: [
              EventInterval.sameDay(startMinute: 600, endMinute: 1080),
            ],
            workCategory: WorkCategory.shift,
            coworkers: const [
              'Synthetic Alex',
              'Synthetic Bailey',
              'Synthetic Casey',
              'Synthetic Devon',
              'Synthetic Ellis',
            ],
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WorkCodeLegendPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coworkers'));
    await tester.pumpAndSettle();

    final shiftCard = tester.widgetList<Card>(find.byType(Card)).first;
    final height = tester.getSize(find.byWidget(shiftCard)).height;
    expect(height, lessThanOrEqualTo(245));
    final coworkerSummary = tester.widget<Text>(
      find.textContaining('Synthetic Alex'),
    );
    expect(
      find.bySemanticsLabel(RegExp('Coworkers assigned to this shift')),
      findsOneWidget,
    );
    for (final name in [
      'Synthetic Alex',
      'Synthetic Bailey',
      'Synthetic Casey',
      'Synthetic Devon',
      'Synthetic Ellis',
    ]) {
      expect(coworkerSummary.data, contains(name));
    }
    semantics.dispose();
  });

  testWidgets('supervisors are grouped by permanent and acting type', (
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
    final repository = container.read(supervisorRepositoryProvider);
    await repository.save(
      const SupervisorProfile(
        id: 'synthetic-permanent-supervisor',
        name: 'Synthetic Permanent Supervisor',
      ),
    );
    await repository.save(
      const SupervisorProfile(
        id: 'synthetic-second-permanent-supervisor',
        name: 'Synthetic Second Permanent Supervisor',
      ),
    );
    await repository.save(
      const SupervisorProfile(
        id: 'synthetic-acting-supervisor',
        name: 'Synthetic Acting Supervisor',
        type: SupervisorType.acting,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: const MaterialApp(home: WorkCodeLegendPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supervisors'));
    await tester.pumpAndSettle();

    expect(find.text('Permanent supervisors'), findsOneWidget);
    expect(find.text('Acting supervisors'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Permanent supervisors')).dy,
      lessThan(
        tester.getTopLeft(find.text('Synthetic Permanent Supervisor')).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.text('Synthetic Permanent Supervisor')).dy,
      lessThan(
        tester
            .getTopLeft(find.text('Synthetic Second Permanent Supervisor'))
            .dy,
      ),
    );
    final firstSupervisorCard = tester.getRect(
      find.ancestor(
        of: find.text('Synthetic Permanent Supervisor'),
        matching: find.byType(Card),
      ),
    );
    final secondSupervisorCard = tester.getRect(
      find.ancestor(
        of: find.text('Synthetic Second Permanent Supervisor'),
        matching: find.byType(Card),
      ),
    );
    expect(
      secondSupervisorCard.top - firstSupervisorCard.bottom,
      greaterThanOrEqualTo(12),
    );
    expect(
      tester.getTopLeft(find.text('Synthetic Second Permanent Supervisor')).dy,
      lessThan(tester.getTopLeft(find.text('Acting supervisors')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Acting supervisors')).dy,
      lessThan(tester.getTopLeft(find.text('Synthetic Acting Supervisor')).dy),
    );
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), 'acting');
    await tester.pumpAndSettle();
    expect(find.text('Permanent supervisors'), findsNothing);
    expect(find.text('Acting supervisors'), findsOneWidget);
    expect(find.text('Synthetic Acting Supervisor'), findsOneWidget);
    expect(find.text('Synthetic Permanent Supervisor'), findsNothing);
  });

  testWidgets('code card shows meaning, split time windows, and flight count', (
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
    await container
        .read(workCodeLegendRepositoryProvider)
        .save(
          const WorkCodeLegend(
            id: 'synthetic-a1-legend',
            code: 'A1',
            assignmentDetails: 'Split shift · Flights: SYN100, SYN200, SYN300',
            flightIds: ['SYN100', 'SYN200', 'SYN300'],
          ),
        );
    await container
        .read(workCodeLegendRepositoryProvider)
        .save(
          const WorkCodeLegend(
            id: 'synthetic-saved-only-legend',
            code: 'ZZSAVED',
            assignmentDetails: 'Saved only reference',
          ),
        );
    await container
        .read(scheduleRepositoryProvider)
        .save(
          ScheduleItem(
            id: 'synthetic-a1-morning-duty',
            kind: ScheduleKind.work,
            title: 'Synthetic A1 morning shift',
            startDate: CivilDate(2026, 11, 16),
            intervals: [
              EventInterval.sameDay(startMinute: 360, endMinute: 540),
            ],
            code: 'A1',
            codeMeaning: 'Split shift · Flights: SYN100, SYN200, SYN300',
            workCategory: WorkCategory.shift,
          ),
        );
    await container
        .read(scheduleRepositoryProvider)
        .save(
          ScheduleItem(
            id: 'synthetic-a1-afternoon-duty',
            kind: ScheduleKind.work,
            title: 'Synthetic A1 afternoon shift',
            startDate: CivilDate(2026, 11, 17),
            intervals: [
              EventInterval.sameDay(startMinute: 720, endMinute: 960),
            ],
            code: 'A1',
            codeMeaning: 'Split shift · Flights: SYN100, SYN200, SYN300',
            workCategory: WorkCategory.shift,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WorkCodeLegendPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Split shift'), findsOneWidget);
    expect(find.text('From your work roster'), findsOneWidget);
    expect(find.text('3 possible flights'), findsOneWidget);
    expect(find.textContaining('6–9 AM'), findsOneWidget);
    expect(find.textContaining('12–4 PM'), findsOneWidget);
    final morning = tester.getTopLeft(find.text('6–9 AM'));
    final afternoon = tester.getTopLeft(find.text('12–4 PM'));
    expect(morning.dy, afternoon.dy);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Add shift code'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ZZSAVED');
    await tester.pumpAndSettle();
    expect(find.text('Saved shift codes'), findsOneWidget);
    expect(find.text('From your work roster'), findsNothing);
  });

  testWidgets('grouped time variants show their shared shift description', (
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
    final repository = container.read(scheduleRepositoryProvider);
    await repository.save(
      ScheduleItem(
        id: 'synthetic-a1-morning-summary',
        kind: ScheduleKind.work,
        title: 'Synthetic A1 morning shift',
        startDate: CivilDate(2026, 11, 16),
        intervals: [EventInterval.sameDay(startMinute: 360, endMinute: 540)],
        code: 'A1',
        codeMeaning: 'Split shift - morning block',
        workCategory: WorkCategory.shift,
      ),
    );
    await repository.save(
      ScheduleItem(
        id: 'synthetic-a1-afternoon-summary',
        kind: ScheduleKind.work,
        title: 'Synthetic A1 afternoon shift',
        startDate: CivilDate(2026, 11, 17),
        intervals: [EventInterval.sameDay(startMinute: 720, endMinute: 960)],
        code: 'A1',
        codeMeaning: 'Split shift - afternoon block',
        workCategory: WorkCategory.shift,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WorkCodeLegendPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A1'), findsOneWidget);
    expect(find.text('Split shift'), findsOneWidget);
    expect(find.text('Split shift - afternoon block'), findsNothing);
    expect(find.text('Split shift - morning block'), findsNothing);
  });

  testWidgets('same code stays separate for different employers', (
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
    final legends = container.read(workCodeLegendRepositoryProvider);
    await legends.save(
      const WorkCodeLegend(
        id: 'employer-a-a1',
        employer: 'Employer A',
        code: 'A1',
        assignmentDetails: 'Morning arrivals',
        flightIds: ['SYN100'],
        startMinute: 360,
        endMinute: 540,
      ),
    );
    await legends.save(
      const WorkCodeLegend(
        id: 'employer-b-a1',
        employer: 'Employer B',
        code: 'A1',
        assignmentDetails: 'Afternoon departures',
        flightIds: ['SYN200'],
        startMinute: 720,
        endMinute: 960,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WorkCodeLegendPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNWidgets(2));
    expect(find.text('Employer A'), findsOneWidget);
    expect(find.text('Employer B'), findsOneWidget);
    expect(find.text('1 possible flight'), findsNWidgets(2));
    final employerACard = tester.getRect(
      find.ancestor(of: find.text('Employer A'), matching: find.byType(Card)),
    );
    final employerBCard = tester.getRect(
      find.ancestor(of: find.text('Employer B'), matching: find.byType(Card)),
    );
    expect(employerBCard.top - employerACard.bottom, greaterThanOrEqualTo(12));
    await tester.enterText(find.byType(TextField), 'Employer B');
    await tester.pumpAndSettle();
    expect(find.text('1 result'), findsOneWidget);
    expect(find.text('Afternoon departures'), findsOneWidget);
    expect(find.text('Morning arrivals'), findsNothing);
    await tester.tap(find.text('Afternoon departures'));
    await tester.pumpAndSettle();
    expect(find.text('SYN200'), findsOneWidget);
    expect(find.text('SYN100'), findsNothing);
  });

  testWidgets('search and detail sheet expose flights linked to a code', (
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
    await container
        .read(workCodeLegendRepositoryProvider)
        .save(
          const WorkCodeLegend(
            id: 'synthetic-a1-legend',
            code: 'A1',
            assignmentDetails: 'Split shift · Flights: SYN100, SYN200, SYN300',
            flightIds: ['SYN100', 'SYN200', 'SYN300'],
            startMinute: 360,
            endMinute: 540,
          ),
        );
    await container
        .read(scheduleRepositoryProvider)
        .save(
          ScheduleItem(
            id: 'synthetic-a1-reference',
            kind: ScheduleKind.work,
            title: 'Synthetic A1 roster entry',
            startDate: CivilDate(2026, 11, 16),
            intervals: [
              EventInterval.sameDay(startMinute: 360, endMinute: 540),
              EventInterval.sameDay(startMinute: 720, endMinute: 960),
            ],
            code: 'A1',
            codeMeaning: 'Split shift · Flights: SYN100, SYN200, SYN300',
            workCategory: WorkCategory.shift,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WorkCodeLegendPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'SYN100');
    await tester.pumpAndSettle();
    expect(find.text('1 result'), findsOneWidget);
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('Split shift'), findsOneWidget);

    await tester.tap(find.text('Split shift'));
    await tester.pumpAndSettle();
    expect(find.text('Possible flights'), findsOneWidget);
    expect(find.text('SYN100'), findsNWidgets(2));
    expect(find.text('SYN200'), findsOneWidget);
    expect(find.text('SYN300'), findsOneWidget);
    expect(
      find.text('Typical roster details · not live flight assignments'),
      findsOneWidget,
    );
  });

  testWidgets('single legend list fits phone width', (tester) async {
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1.2;
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
        child: const MaterialApp(home: WorkCodeLegendPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    expect(find.text('Flights'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('split code card shows both saved time windows', (tester) async {
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
    await container
        .read(workCodeLegendRepositoryProvider)
        .save(
          const WorkCodeLegend(
            id: 'synthetic-split-code',
            code: 'R2',
            assignmentDetails: 'Synthetic morning and evening operations',
            timeWindows: [
              WorkCodeTimeWindow(startMinute: 360, endMinute: 540),
              WorkCodeTimeWindow(startMinute: 720, endMinute: 960),
            ],
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WorkCodeLegendPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('6–9 AM'), findsOneWidget);
    expect(find.textContaining('12–4 PM'), findsOneWidget);
    expect(
      find.text('Synthetic morning and evening operations'),
      findsOneWidget,
    );
  });

  testWidgets('saved code form adds details and explicit flight references', (
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
        child: const MaterialApp(home: WorkCodeLegendPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add shift code'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Shift code'),
      'R1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Employer (optional)'),
      'Employer A',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Flights or assignment details'),
      'Synthetic departures duty',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Associated flight codes'),
      'SYN100, SYN200',
    );
    await tester.tap(find.text('Save shift code'));
    await tester.pumpAndSettle();

    expect(find.text('Add shift code'), findsNothing);
    expect(find.text('No work references saved'), findsNothing);
    expect(find.text('Synthetic departures duty'), findsOneWidget);
    await tester.tap(find.text('Synthetic departures duty'));
    await tester.pumpAndSettle();
    expect(find.text('Possible flights'), findsOneWidget);
    expect(find.text('Employer A'), findsOneWidget);
    expect(find.text('SYN100'), findsOneWidget);
    expect(find.text('SYN200'), findsOneWidget);
  });

  testWidgets('saved code details expose editing and preserve flight list', (
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
    await container
        .read(workCodeLegendRepositoryProvider)
        .save(
          const WorkCodeLegend(
            id: 'synthetic-editable-code',
            code: 'QX',
            assignmentDetails: 'Synthetic ramp reference',
            flightIds: ['SYN100', 'SYN200'],
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WorkCodeLegendPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit QX'), findsNothing);
    await tester.tap(find.text('Synthetic ramp reference'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit shift code'));
    await tester.pumpAndSettle();
    expect(find.text('Save shift code'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Associated flight codes'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Associated flight codes'),
      'SYN100, SYN300',
    );
    await tester.tap(find.text('Save shift code'));
    await tester.pumpAndSettle();
    expect(
      (await container.read(workCodeLegendRepositoryProvider).getItems())
          .single
          .flightIds,
      ['SYN100', 'SYN300'],
    );
  });

  testWidgets('roster-only code defines from its details sheet', (
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
    await container
        .read(scheduleRepositoryProvider)
        .save(
          ScheduleItem(
            id: 'synthetic-observed-code',
            kind: ScheduleKind.work,
            title: 'Synthetic ramp duty',
            startDate: CivilDate(2026, 11, 18),
            intervals: [
              EventInterval.sameDay(startMinute: 360, endMinute: 540),
            ],
            code: 'QX',
            codeMeaning: 'Synthetic ramp handling',
            workCategory: WorkCategory.shift,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WorkCodeLegendPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Define QX'), findsNothing);
    expect(find.text('Define shift code'), findsNothing);
    await tester.tap(find.text('Synthetic ramp handling'));
    await tester.pumpAndSettle();
    expect(find.text('Possible flights'), findsOneWidget);
    expect(find.text('Define shift code'), findsOneWidget);
    await tester.tap(find.text('Define shift code'));
    await tester.pumpAndSettle();
    expect(find.text('Add shift code'), findsOneWidget);
  });
}
