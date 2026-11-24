import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/work_code_legend.dart';
import 'package:shift_study/domain/supervisor_profile.dart';
import 'package:shift_study/presentation/app_theme.dart';
import 'package:shift_study/presentation/screens/backup_restore_page.dart';
import 'package:shift_study/presentation/screens/settings_page.dart';

void main() {
  const channel = MethodChannel('app.shiftstudy/backup');

  testWidgets('backup and restore is reachable from More settings', (
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
          home: const SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Backup & restore'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Backup & restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backup & restore'));
    await tester.pumpAndSettle();
    expect(find.text('Keep a safe copy'), findsOneWidget);
    expect(find.text('Create backup'), findsOneWidget);
    expect(find.text('Choose backup file'), findsOneWidget);
  });

  testWidgets('backup passphrase dialog fits above an open keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
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
          home: const BackupRestorePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create backup'));
    await tester.tap(find.text('Create backup'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(() => tester.view.viewInsets = const FakeViewPadding());
    await tester.pumpAndSettle();

    expect(find.text('Protect your backup'), findsOneWidget);
    expect(find.text('Create encrypted file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid backup never changes saved events', (tester) async {
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
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await container
        .read(scheduleRepositoryProvider)
        .save(
          ScheduleItem(
            id: 'synthetic-protected-record',
            kind: ScheduleKind.personal,
            title: 'Keep this local event',
            startDate: CivilDate(2026, 11, 6),
            intervals: [
              EventInterval.sameDay(startMinute: 600, endMinute: 660),
            ],
          ),
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'openBackup');
          return Uint8List.fromList([
            0x7b,
            0x6e,
            0x6f,
            0x74,
            0x2d,
            0x6a,
            0x73,
            0x6f,
            0x6e,
          ]);
        });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const BackupRestorePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chooseFile = find.text('Choose backup file');
    await tester.ensureVisible(chooseFile);
    await tester.pumpAndSettle();
    await tester.tap(chooseFile);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'synthetic-passphrase',
    );
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Backup file is not valid.'), findsOneWidget);
    final saved = await container.read(scheduleRepositoryProvider).getItems();
    expect(saved.map((item) => item.title), ['Keep this local event']);
  });

  testWidgets('factory reset requires typing StudyShift before clearing data', (
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
            id: 'synthetic-reset-event',
            kind: ScheduleKind.personal,
            title: 'Synthetic reset test event',
            startDate: CivilDate(2026, 11, 17),
            intervals: [
              EventInterval.sameDay(startMinute: 600, endMinute: 660),
            ],
          ),
        );
    await database.setPreference('theme', 'dark');
    await container
        .read(workCodeLegendRepositoryProvider)
        .save(
          const WorkCodeLegend(
            id: 'synthetic-reset-code',
            code: 'TEST',
            assignmentDetails: 'Synthetic reset fixture',
          ),
        );
    await container
        .read(supervisorRepositoryProvider)
        .save(
          const SupervisorProfile(
            id: 'synthetic-reset-supervisor',
            name: 'Synthetic supervisor',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const BackupRestorePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Reset app data'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Reset app data'));
    await tester.pumpAndSettle();
    expect(find.text('Reset StudyShift?'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Type StudyShift to confirm'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'StudyShift ');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Reset permanently'),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField).last, 'StudyShift');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset permanently'));
    await tester.pumpAndSettle();

    expect(
      await container.read(scheduleRepositoryProvider).getItems(),
      isEmpty,
    );
    expect(
      await container.read(workCodeLegendRepositoryProvider).getItems(),
      isEmpty,
    );
    expect(
      await container.read(supervisorRepositoryProvider).getItems(),
      isEmpty,
    );
    expect(await database.getPreferences(), isEmpty);
  });
}
