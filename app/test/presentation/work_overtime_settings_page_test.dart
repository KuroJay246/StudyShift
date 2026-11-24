import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/presentation/screens/work_overtime_settings_page.dart';

void main() {
  late ScheduleDatabase database;

  setUp(() {
    database = ScheduleDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => database.close());

  testWidgets('saves a daily overtime rule for one named employer', (
    tester,
  ) async {
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
        child: const MaterialApp(home: WorkOvertimeSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add employer rule'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InputDecorator>(
            find.descendant(
              of: find.byType(TextFormField).first,
              matching: find.byType(InputDecorator),
            ),
          )
          .decoration
          .hintText,
      'e.g. CAH',
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Synthetic Ramp Co',
    );
    await tester.enterText(find.byType(TextFormField).at(1), '8');
    await tester.tap(find.text('Save rule'));
    await tester.pumpAndSettle();

    final saved = await PreferencesRepository(database).load();
    expect(saved.overtimeThresholdForEmployer('Synthetic Ramp Co'), 8 * 60);
    expect(find.text('Synthetic Ramp Co'), findsOneWidget);
    expect(find.text('8 standard hours per day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
