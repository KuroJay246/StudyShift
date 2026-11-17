import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/domain/schedule.dart';
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
}
