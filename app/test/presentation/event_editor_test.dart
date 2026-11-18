import 'dart:ui' show Tristate;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/academic_term.dart';
import 'package:shift_study/domain/supervisor_profile.dart';
import 'package:shift_study/domain/work_code_legend.dart';
import 'package:shift_study/platform/device_time_zone.dart';
import 'package:shift_study/platform/local_reminders.dart';
import 'package:shift_study/presentation/screens/event_editor_page.dart';

class _TestTimeZone implements DeviceTimeZone {
  @override
  Future<String> getLocalIanaId() async => 'America/Barbados';
}

class _TestReminderService extends LocalReminderService {
  @override
  Future<ReminderPermissionResult> requestPermissions() async =>
      const ReminderPermissionResult(
        notificationsAllowed: true,
        exactTimingAllowed: true,
      );
}

void main() {
  testWidgets('new event form does not open the keyboard automatically', (
    tester,
  ) async {
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
        child: const MaterialApp(
          home: EventEditorPage(kind: ScheduleKind.work),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('date buttons keep the full date available on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
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
          home: EventEditorPage(
            kind: ScheduleKind.work,
            initialDate: CivilDate(2026, 11, 17),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final startDate = tester.widget<Text>(
      find.byKey(const ValueKey('event-start-date-value')),
    );
    final endDate = tester.widget<Text>(
      find.byKey(const ValueKey('event-end-date-value')),
    );
    expect(startDate.maxLines, 2);
    expect(startDate.overflow, isNull);
    expect(endDate.maxLines, 2);
    expect(endDate.overflow, isNull);
  });

  testWidgets('work editor explains where to manage saved roster references', (
    tester,
  ) async {
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
        child: const MaterialApp(
          home: EventEditorPage(kind: ScheduleKind.work),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Work details'),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Work details'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('manage-roster-references')),
      findsOneWidget,
    );
  });

  testWidgets('work interval controls remain compact on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
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
        child: const MaterialApp(
          home: EventEditorPage(kind: ScheduleKind.work),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final starts = tester.getRect(find.text('Starts'));
    final ends = tester.getRect(find.text('Ends'));
    expect(starts.left, greaterThanOrEqualTo(0));
    expect(ends.right, lessThanOrEqualTo(320));
    expect(
      find.ancestor(of: find.text('Starts'), matching: find.byType(Card)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing start date preserves a chosen end date', (
    tester,
  ) async {
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
          home: EventEditorPage(
            kind: ScheduleKind.work,
            initialDate: CivilDate(2026, 11, 17),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('End date'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await tester.tap(find.text('20').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final endDateBeforeStartChange = _dateButtonValue(tester, 'End date');

    await tester.tap(find.text('Start date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('18').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(_dateButtonValue(tester, 'End date'), endDateBeforeStartChange);
  });

  testWidgets('work time zone controls fit a narrow phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
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
        child: const MaterialApp(
          home: EventEditorPage(kind: ScheduleKind.work),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final timeZoneHeading = find.text('Advanced');
    await tester.scrollUntilVisible(
      timeZoneHeading,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(timeZoneHeading);
    await tester.pumpAndSettle();

    expect(find.text('Time zone'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('work and study event forms group fields by task', (
    tester,
  ) async {
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

    for (final (kind, labels) in [
      (
        ScheduleKind.work,
        [
          'Essential details',
          'Date and time',
          'Work details',
          'Additional details',
        ],
      ),
      (
        ScheduleKind.classSession,
        ['Essential details', 'Date and time', 'Additional details'],
      ),
    ]) {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: EventEditorPage(key: ValueKey(kind), kind: kind),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (kind == ScheduleKind.work) {
        expect(find.byKey(const ValueKey('work-employer-field')), findsNothing);
        expect(
          find.byKey(const ValueKey('work-code-assignment-field')),
          findsNothing,
        );
      }

      for (final label in labels) {
        if (label == 'Work details' || label == 'Additional details') {
          await tester.scrollUntilVisible(
            find.text(label),
            500,
            scrollable: find.byType(Scrollable).first,
          );
        }
        expect(find.text(label), findsOneWidget);
        if (label == 'Work details' || label == 'Additional details') {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }
      }
    }
  });

  testWidgets('work form can select a saved supervisor profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
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
    await container
        .read(supervisorRepositoryProvider)
        .save(
          const SupervisorProfile(
            id: 'synthetic-supervisor-profile',
            name: 'Synthetic Acting Supervisor',
            type: SupervisorType.acting,
            phone: '+1 246 555 0100',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: EventEditorPage(kind: ScheduleKind.work),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Additional details'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Additional details'));
    await tester.pumpAndSettle();

    final selector = find.byKey(const ValueKey('saved-supervisor-selector'));
    await tester.scrollUntilVisible(
      selector,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Synthetic Acting Supervisor'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('supervisor-name-field')),
          )
          .controller
          ?.text,
      'Synthetic Acting Supervisor',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('supervisor-phone-field')),
          )
          .controller
          ?.text,
      '+1 246 555 0100',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'work event uses matching shift-code assignment and time guidance',
    (tester) async {
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
      await container
          .read(workCodeLegendRepositoryProvider)
          .save(
            const WorkCodeLegend(
              id: 'test-legend',
              employer: 'Synthetic Air',
              code: 'R1',
              assignmentDetails: 'Synthetic arrivals and departures',
              startMinute: 360,
              endMinute: 840,
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: EventEditorPage(kind: ScheduleKind.work),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Synthetic shift',
      );
      await tester.scrollUntilVisible(
        find.text('Work details'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Work details'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('work-employer-field')),
        'Synthetic Air',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('work-department-field')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('work-department-field')),
        'Synthetic ramp operations',
      );
      await tester.enterText(
        find.byKey(const ValueKey('work-role-field')),
        'Ramp agent',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('work-code-field')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('work-code-field')),
        'R1',
      );
      await tester.pumpAndSettle();
      await _saveEvent(tester);
      expect(find.text('Enter a name.'), findsNothing);
      expect(find.text('Enter a time zone.'), findsNothing);
      expect(find.text('Choose at least one weekday.'), findsNothing);
      final saved =
          (await container.read(scheduleRepositoryProvider).getItems()).single;
      expect(saved.employerName, 'Synthetic Air');
      expect(saved.departmentName, 'Synthetic ramp operations');
      expect(saved.jobRole, 'Ramp agent');
      expect(saved.codeMeaning, 'Synthetic arrivals and departures');
      expect(saved.intervals, [
        EventInterval.sameDay(startMinute: 360, endMinute: 840),
      ]);
    },
  );

  testWidgets('work form offers saved roster codes for direct selection', (
    tester,
  ) async {
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
    await container
        .read(workCodeLegendRepositoryProvider)
        .save(
          const WorkCodeLegend(
            id: 'synthetic-direct-select',
            employer: 'Synthetic Air',
            code: 'R2',
            assignmentDetails: 'Synthetic evening operations',
            timeWindows: [
              WorkCodeTimeWindow(startMinute: 360, endMinute: 540),
              WorkCodeTimeWindow(startMinute: 720, endMinute: 960),
            ],
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: EventEditorPage(kind: ScheduleKind.work),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('event-title-field')),
      'Synthetic selected roster code',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Work details'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Work details'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('work-code-legend-selector')),
      findsOneWidget,
    );
    final selector = find.byKey(const ValueKey('work-code-legend-selector'));
    await tester.scrollUntilVisible(
      selector,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Synthetic Air · R2'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('work-code-field')))
          .controller
          ?.text,
      'R2',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('work-code-assignment-field')),
          )
          .controller
          ?.text,
      'Synthetic evening operations',
    );
    await _saveEvent(tester);

    final savedItems = await container
        .read(scheduleRepositoryProvider)
        .getItems();
    expect(
      savedItems,
      isNotEmpty,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .where((text) => text != null)
          .join(' | '),
    );
    final saved = savedItems.single;
    expect(saved.code, 'R2');
    expect(saved.codeMeaning, 'Synthetic evening operations');
    expect(saved.intervals, [
      EventInterval.sameDay(startMinute: 360, endMinute: 540),
      EventInterval.sameDay(startMinute: 720, endMinute: 960),
    ]);
  });

  testWidgets('editing split overnight work preserves end-day offsets', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final repository = ScheduleRepository(database);
    final item = ScheduleItem(
      id: 'synthetic-split-overnight',
      kind: ScheduleKind.work,
      title: 'Synthetic split overnight shift',
      startDate: CivilDate(2026, 11, 5),
      timeZoneId: 'America/Barbados',
      intervals: const [
        EventInterval(
          startDayOffset: 0,
          startMinute: 360,
          endDayOffset: 0,
          endMinute: 540,
        ),
        EventInterval(
          startDayOffset: 0,
          startMinute: 720,
          endDayOffset: 1,
          endMinute: 120,
        ),
      ],
    );
    await repository.save(item);
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
          home: EventEditorPage(kind: ScheduleKind.work, existing: item),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save event'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await _saveEvent(tester);

    final saved = (await repository.getItems()).single;
    expect(saved.intervals, item.intervals);
    expect(saved.intervals.last.endDayOffset, 1);
  });

  testWidgets('study color can be changed from the class add form', (
    tester,
  ) async {
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
        child: const MaterialApp(
          home: EventEditorPage(kind: ScheduleKind.classSession),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('e.g. Chemistry lecture'), findsOneWidget);
    expect(find.text('Study color'), findsOneWidget);
    expect(find.text('10:00 AM'), findsOneWidget);
    expect(find.text('11:30 AM'), findsOneWidget);
    await tester.tap(find.byTooltip('Choose Study color'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a calendar color'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.bySemanticsLabel('Violet calendar color'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calendar-color-violet')));
    await tester.pumpAndSettle();

    expect(
      (await PreferencesRepository(database).load()).schoolColor,
      0xFF7C4DFF,
    );
  });

  testWidgets('large text separates time and daylight-saving controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
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
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: const MaterialApp(
            home: EventEditorPage(kind: ScheduleKind.classSession),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final timeHeading = find.text('Time');
    final daylightSavingLabel = find.text('If the clock time repeats');
    await tester.ensureVisible(daylightSavingLabel);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(daylightSavingLabel).dy,
      greaterThan(tester.getBottomRight(timeHeading).dy),
    );
    expect(tester.takeException(), isNull);
  });

  for (final kind in [
    ScheduleKind.work,
    ScheduleKind.classSession,
    ScheduleKind.deadline,
  ]) {
    testWidgets('$kind editor renders at 175 percent text scale', (
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
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.75)),
            child: MaterialApp(home: EventEditorPage(kind: kind)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason:
            '$kind editor should remain scrollable without layout overflow.',
      );
      await tester.scrollUntilVisible(
        find.text('Additional details'),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Additional details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('timed examination form keeps detail sections usable at 175%', (
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
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.75)),
          child: const MaterialApp(
            home: EventEditorPage(
              kind: ScheduleKind.deadline,
              initialDeadlineType: DeadlineType.examination,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('School item'), findsOneWidget);
    expect(find.text('Examination'), findsOneWidget);
    expect(find.text('Date and time'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Additional details'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Additional details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('work entry saves the selected local reminder', (tester) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
        localReminderServiceProvider.overrideWith(
          (ref) => _TestReminderService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: EventEditorPage(kind: ScheduleKind.work),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'QA shift');
    await tester.scrollUntilVisible(
      find.text('Reminder'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 minutes before').last);
    await tester.pumpAndSettle();
    tester.testTextInput.hide();
    await tester.scrollUntilVisible(
      find.text('Save event'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Save event'));
    await _saveEvent(tester);

    final saved =
        (await container.read(scheduleRepositoryProvider).getItems()).single;
    expect(saved.reminderMinutesBefore, 15);
  });

  testWidgets('legacy event needs explicit time-zone review before saving', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final repository = ScheduleRepository(database);
    final legacy = ScheduleItem(
      id: 'legacy-event-without-zone',
      kind: ScheduleKind.work,
      title: 'Legacy shift',
      startDate: CivilDate(2026, 11, 5),
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 1020)],
    );
    await repository.save(legacy);
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
          home: EventEditorPage(kind: ScheduleKind.work, existing: legacy),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1800));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Time zone'), findsOneWidget);
    expect(find.text('Time zone · IANA ID'), findsNothing);
    final timeZoneField = tester.widget<TextFormField>(
      find.ancestor(
        of: find.text('Time zone'),
        matching: find.byType(TextFormField),
      ),
    );
    expect(timeZoneField.controller!.text, isEmpty);

    await tester.ensureVisible(find.text('Save event'));
    await _saveEvent(tester);
    expect(find.text('Enter a time zone.'), findsOneWidget);
    expect((await repository.getItems()).single.timeZoneId, isNull);

    final confirmZone = find.text('Use device time zone: America/Barbados');
    await tester.ensureVisible(confirmZone);
    await tester.tap(confirmZone);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save event'));
    await _saveEvent(tester);

    expect((await repository.getItems()).single.timeZoneId, 'America/Barbados');
  });

  testWidgets('manual work entry saves its default interval in local SQLite', (
    tester,
  ) async {
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
        child: const MaterialApp(
          home: EventEditorPage(kind: ScheduleKind.work),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'Synthetic ramp shift',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Work details'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Work details'));
    await tester.pumpAndSettle();
    final meaningField = find.widgetWithText(
      TextFormField,
      'Code assignment details · optional',
    );
    await tester.scrollUntilVisible(
      meaningField,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(meaningField, 'Synthetic roster code meaning');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Additional details'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Additional details'));
    await tester.tap(find.text('Additional details'));
    await tester.pumpAndSettle();
    final reportingField = find.widgetWithText(
      TextFormField,
      'Reporting instructions · optional',
    );
    await tester.scrollUntilVisible(
      reportingField,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(reportingField, 'Synthetic report at north gate');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    for (final (label, value) in [
      ('Supervisor · optional', 'Synthetic supervisor'),
      ('Supervisor phone · optional', '+1 246 555 0100'),
      ('Shift contact · optional', 'Synthetic operations desk'),
      ('Contact phone · optional', '+1 246 555 0101'),
    ]) {
      final field = find.widgetWithText(TextFormField, label);
      await tester.scrollUntilVisible(
        field,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(field, value);
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
    }
    await _saveEvent(tester);

    final saved = await container.read(scheduleRepositoryProvider).getItems();
    expect(saved, hasLength(1));
    expect(saved.single.title, 'Synthetic ramp shift');
    expect(saved.single.intervals, [
      EventInterval.sameDay(startMinute: 540, endMinute: 1020),
    ]);
    expect(saved.single.timeZoneId, 'America/Barbados');
    expect(saved.single.codeMeaning, 'Synthetic roster code meaning');
    expect(saved.single.reportingInstruction, 'Synthetic report at north gate');
    expect(saved.single.supervisorName, 'Synthetic supervisor');
    expect(saved.single.supervisorPhone, '+1 246 555 0100');
    expect(saved.single.contactName, 'Synthetic operations desk');
    expect(saved.single.contactPhone, '+1 246 555 0101');
  });

  testWidgets('work form can save a timed overtime entry', (tester) async {
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
        child: const MaterialApp(
          home: EventEditorPage(kind: ScheduleKind.work),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Synthetic OT');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();

    final categoryField = find.byType(DropdownButtonFormField<WorkCategory>);
    await tester.ensureVisible(categoryField);
    await tester.tap(categoryField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overtime').last);
    await tester.pumpAndSettle();
    await _saveEvent(tester);

    final saved =
        (await container.read(scheduleRepositoryProvider).getItems()).single;
    expect(saved.workCategory, WorkCategory.overtime);
    expect(saved.intervals.single.isValid, isTrue);
  });

  testWidgets('work editor saves an all-day rest day without fake hours', (
    tester,
  ) async {
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
        child: const MaterialApp(
          home: EventEditorPage(kind: ScheduleKind.work),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Roster rest day');
    await tester.tap(find.byType(DropdownButtonFormField<WorkCategory>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rest day').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Rest day · all day'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Starts'), findsNothing);
    expect(find.text('Rest day · all day'), findsOneWidget);
    tester.testTextInput.hide();
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    await _saveEvent(tester);

    final saved =
        (await container.read(scheduleRepositoryProvider).getItems()).single;
    expect(saved.workCategory, WorkCategory.restDay);
    expect(saved.hasNoTime, isTrue);
    expect(saved.intervals, isEmpty);
  });

  testWidgets('assignment editor saves a date-only deadline', (tester) async {
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
        child: const MaterialApp(
          home: EventEditorPage(
            kind: ScheduleKind.deadline,
            initialDeadlineType: DeadlineType.assignment,
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'Synthetic biology assignment',
    );
    await tester.pumpAndSettle();
    expect(find.text('Assignment · due this day'), findsOneWidget);
    expect(find.text('Starts'), findsNothing);
    tester.testTextInput.hide();
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    await _saveEvent(tester);

    final saved =
        (await container.read(scheduleRepositoryProvider).getItems()).single;
    expect(saved.kind, ScheduleKind.deadline);
    expect(saved.deadlineType, DeadlineType.assignment);
    expect(saved.hasNoTime, isTrue);
    expect(saved.intervals, isEmpty);
  });

  testWidgets('examination editor saves a timed school event', (tester) async {
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
        child: const MaterialApp(
          home: EventEditorPage(
            kind: ScheduleKind.deadline,
            initialDeadlineType: DeadlineType.examination,
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'Synthetic biology exam',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Additional details'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Additional details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Additional details'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('event-code-field')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('event-code-field')),
      'CS 101',
    );
    await tester.pumpAndSettle();
    tester.testTextInput.hide();
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    await _saveEvent(tester);

    final saved =
        (await container.read(scheduleRepositoryProvider).getItems()).single;
    expect(saved.kind, ScheduleKind.deadline);
    expect(saved.deadlineType, DeadlineType.examination);
    expect(saved.code, 'CS 101');
    expect(saved.hasNoTime, isFalse);
    expect(saved.intervals, hasLength(1));
  });

  testWidgets('weekly class entry saves the selected weekday', (tester) async {
    final semantics = tester.ensureSemantics();
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
        child: const MaterialApp(
          home: EventEditorPage(
            kind: ScheduleKind.classSession,
            initialDate: CivilDate(2026, 11, 6),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'Synthetic lecture',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Repeat weekly'));
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    expect(find.byType(FilterChip), findsWidgets);
    final tuesday = find.byType(FilterChip).at(1);
    await tester.scrollUntilVisible(
      tuesday,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(tuesday);
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final tuesdayNode = tester.getSemantics(find.bySemanticsLabel('Tuesday'));
    expect(
      tuesdayNode.getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(find.bySemanticsLabel('Thursday'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    await _saveEvent(tester);

    final saved = await container.read(scheduleRepositoryProvider).getItems();
    expect(saved.single.kind, ScheduleKind.classSession);
    expect(saved.single.startDate, const CivilDate(2026, 11, 6));
    expect(saved.single.recurrence?.weekdays, {DateTime.tuesday});
    semantics.dispose();
  });

  testWidgets('weekly class entry saves an optional recurrence end date', (
    tester,
  ) async {
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
        child: const MaterialApp(
          home: EventEditorPage(kind: ScheduleKind.classSession),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Term class');
    for (
      var attempt = 0;
      attempt < 4 && find.text('Repeat weekly').evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(find.text('Repeat weekly'), findsOneWidget);
    await tester.ensureVisible(find.text('Repeat weekly'));
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('End date · optional'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(find.byType(FilterChip), findsNWidgets(7));
    final tuesday = find.byType(FilterChip).at(1);
    await tester.tap(tuesday);
    final endDate = find.text('End date · optional');
    await tester.ensureVisible(endDate);
    await tester.tap(endDate);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    tester.testTextInput.hide();
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    await _saveEvent(tester);

    final saved = await container.read(scheduleRepositoryProvider).getItems();
    expect(saved.single.recurrence?.until, isNotNull);
    expect(
      saved.single.recurrence!.until!.compareTo(saved.single.startDate),
      greaterThanOrEqualTo(0),
    );
    expect(saved.single.recurrence!.until!.day, 25);
  });

  testWidgets('academic term bounds a recurring class from an outside date', (
    tester,
  ) async {
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
    final term = AcademicTerm(
      id: 'synthetic-term',
      institution: 'Example University',
      name: 'Autumn Term',
      startDate: CivilDate(2026, 9, 1),
      endDate: CivilDate(2026, 12, 15),
    );
    await container.read(academicTermRepositoryProvider).save(term);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: EventEditorPage(
            kind: ScheduleKind.classSession,
            initialDate: CivilDate(2026, 8, 15),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Synthetic term class',
    );
    await tester.scrollUntilVisible(
      find.text('Repeat weekly'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Repeat weekly'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(find.byType(FilterChip), findsNWidgets(7));
    final monday = find.byType(FilterChip).first;
    await tester.tap(monday);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Additional details'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Additional details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Additional details'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('academic-term-field')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('academic-term-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Example University · Autumn Term'));
    await tester.pumpAndSettle();
    expect(find.text('Example University · Autumn Term'), findsOneWidget);

    await _saveEvent(tester);

    final saved =
        (await container.read(scheduleRepositoryProvider).getItems()).single;
    expect(saved.academicTermId, term.id);
    expect(saved.startDate, term.startDate);
    expect(saved.recurrence?.until, term.endDate);
  });
}

String _dateButtonValue(WidgetTester tester, String label) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data)
      .toList();
  return texts[texts.indexOf(label) + 1]!;
}

Future<void> _saveEvent(WidgetTester tester) async {
  final button = find.text('Save event');
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(button, 400, scrollable: scrollable);
  // Give the bottom form action enough inset from the test viewport edge.
  await tester.drag(scrollable, const Offset(0, -80));
  await tester.pumpAndSettle();
  await tester.tap(button, warnIfMissed: false);
  await tester.pumpAndSettle();
}
