import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/platform/device_time_zone.dart';
import 'package:shift_study/presentation/app.dart';
import 'package:shift_study/presentation/app_theme.dart';
import 'package:shift_study/presentation/screens/event_editor_page.dart';

class _TestTimeZone implements DeviceTimeZone {
  @override
  Future<String> getLocalIanaId() async => 'America/Barbados';
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

  for (final (mode, expectedKind) in [
    (ScheduleMode.workOnly, ScheduleKind.work),
    (ScheduleMode.schoolOnly, ScheduleKind.classSession),
    (ScheduleMode.personalPlanner, ScheduleKind.personal),
  ]) {
    testWidgets('$mode adds its configured event type from Week', (
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
            home: ScheduleShell(mode: mode),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byTooltip(switch (mode) {
          ScheduleMode.workOnly => 'Add shift',
          ScheduleMode.schoolOnly => 'Add class',
          ScheduleMode.personalPlanner => 'Add plan',
          ScheduleMode.workAndSchool => 'Add event',
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EventEditorPage), findsOneWidget);
      expect(
        tester.widget<EventEditorPage>(find.byType(EventEditorPage)).kind,
        expectedKind,
      );
      expect(find.text('Personal event'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Calendar'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add event'));
      await tester.pumpAndSettle();
      expect(find.byType(EventEditorPage), findsOneWidget);
      expect(
        tester.widget<EventEditorPage>(find.byType(EventEditorPage)).kind,
        expectedKind,
      );
    });
  }

  testWidgets('Work + School Add sheet opens each schedule type', (
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
    await tester.tap(find.byTooltip('Add event'));
    await tester.pumpAndSettle();
    expect(find.text('Work shift'), findsOneWidget);
    expect(find.text('Class'), findsOneWidget);
    expect(find.text('Personal event'), findsNothing);
    await tester.tap(find.text('Work shift'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EventEditorPage>(find.byType(EventEditorPage)).kind,
      ScheduleKind.work,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Calendar'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add event'));
    await tester.pumpAndSettle();
    expect(find.text('Work shift'), findsOneWidget);
    expect(find.text('Class'), findsOneWidget);
    expect(find.text('Assignment'), findsOneWidget);
    expect(find.text('Examination'), findsOneWidget);
    expect(find.text('Personal event'), findsNothing);
    await tester.tap(find.text('Examination'));
    await tester.pumpAndSettle();
    final editor = tester.widget<EventEditorPage>(find.byType(EventEditorPage));
    expect(editor.kind, ScheduleKind.deadline);
    expect(editor.initialDeadlineType, DeadlineType.examination);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assignment'));
    await tester.pumpAndSettle();
    final assignmentEditor = tester.widget<EventEditorPage>(
      find.byType(EventEditorPage),
    );
    expect(assignmentEditor.kind, ScheduleKind.deadline);
    expect(assignmentEditor.initialDeadlineType, DeadlineType.assignment);
  });

  testWidgets('Study navigation can start a date-only assignment', (
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
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Study'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add class'));
    await tester.pumpAndSettle();
    expect(find.text('Class'), findsOneWidget);
    expect(find.text('Assignment'), findsOneWidget);
    expect(find.text('Examination'), findsOneWidget);
    await tester.tap(find.text('Assignment'));
    await tester.pumpAndSettle();

    final editor = tester.widget<EventEditorPage>(find.byType(EventEditorPage));
    expect(editor.kind, ScheduleKind.deadline);
    expect(editor.initialDeadlineType, DeadlineType.assignment);
    expect(find.text('Assignment · due this day'), findsOneWidget);
    expect(find.text('Starts'), findsNothing);
  });

  testWidgets('Study add chooser keeps Examination visible in landscape', (
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
          home: const ScheduleShell(
            mode: ScheduleMode.workAndSchool,
            initialDestination: 'study',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add class'));
    await tester.pumpAndSettle();

    final examination = tester.getRect(find.text('Examination'));
    expect(examination.top, greaterThanOrEqualTo(0));
    expect(examination.bottom, lessThanOrEqualTo(411));
    expect(tester.takeException(), isNull);
  });
}
