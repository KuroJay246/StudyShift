import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/presentation/app_theme.dart';
import 'package:shift_study/presentation/screens/schedule_search_page.dart';
import 'package:shift_study/presentation/screens/settings_page.dart';

void main() {
  testWidgets('search matches event details and category filters', (
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
        id: 'synthetic-search-class',
        kind: ScheduleKind.classSession,
        title: 'Chemistry lab',
        startDate: CivilDate(2026, 11, 9),
        intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
        code: 'CHEM1200',
        location: 'Science building',
        notes: 'Bring calculator',
      ),
    );
    await repository.save(
      ScheduleItem(
        id: 'synthetic-search-shift',
        kind: ScheduleKind.work,
        title: 'Ramp training',
        startDate: CivilDate(2026, 11, 10),
        intervals: [EventInterval.sameDay(startMinute: 480, endMinute: 720)],
        workCategory: WorkCategory.training,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ScheduleSearchPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 events'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'chem1200');
    await tester.pumpAndSettle();
    expect(find.text('Chemistry lab'), findsOneWidget);
    expect(find.text('Ramp training'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(find.text('Ramp training'), findsOneWidget);
    expect(find.text('Chemistry lab'), findsNothing);

    await tester.enterText(find.byType(TextField), 'not on the schedule');
    await tester.pumpAndSettle();
    expect(find.text('No matching events'), findsOneWidget);
  });

  testWidgets('search is reachable from More settings', (tester) async {
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
    await tester.tap(find.text('Find an event'));
    await tester.pumpAndSettle();
    expect(find.text('Find an event'), findsOneWidget);
    expect(find.text('Search your schedule'), findsOneWidget);
  });
}
