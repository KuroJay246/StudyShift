import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/presentation/app.dart';
import 'package:shift_study/presentation/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the populated Week page on the isolated review flavor', (
    tester,
  ) async {
    final container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox.shrink()),
      ),
    );

    final repository = container.read(scheduleRepositoryProvider);
    final oldQaItems = (await repository.getItems()).where(
      (item) => item.id.startsWith('qa-week-'),
    );
    for (final item in oldQaItems) {
      await repository.delete(item.id);
    }
    addTearDown(() async {
      final savedItems = await repository.getItems();
      for (final item in savedItems.where(
        (item) => item.id.startsWith('qa-week-'),
      )) {
        await repository.delete(item.id);
      }
      await container
          .read(widgetSnapshotPublisherProvider)
          .publish(await repository.getItems(), DateTime.now());
      container.dispose();
    });

    final today = CivilDate.fromDateTime(DateTime.now());
    const zone = 'America/Barbados';
    final fixtures = [
      ScheduleItem(
        id: 'qa-week-ramp',
        kind: ScheduleKind.work,
        title: 'QA ramp shift',
        startDate: today,
        timeZoneId: zone,
        intervals: [
          EventInterval.sameDay(startMinute: 9 * 60, endMinute: 17 * 60),
        ],
        code: 'QA1',
      ),
      ScheduleItem(
        id: 'qa-week-overlap',
        kind: ScheduleKind.work,
        title: 'QA overlap shift',
        startDate: today,
        timeZoneId: zone,
        intervals: [
          EventInterval.sameDay(
            startMinute: 10 * 60 + 30,
            endMinute: 14 * 60 + 30,
          ),
        ],
        code: 'QA2',
      ),
      ScheduleItem(
        id: 'qa-week-class',
        kind: ScheduleKind.classSession,
        title: 'QA Aviation Safety',
        startDate: today,
        timeZoneId: zone,
        intervals: [
          EventInterval.sameDay(startMinute: 11 * 60 + 30, endMinute: 13 * 60),
        ],
        location: 'QA room',
      ),
      ScheduleItem(
        id: 'qa-week-exam',
        kind: ScheduleKind.deadline,
        deadlineType: DeadlineType.examination,
        title: 'QA midterm exam',
        startDate: today,
        timeZoneId: zone,
        intervals: [
          EventInterval.sameDay(startMinute: 14 * 60, endMinute: 15 * 60),
        ],
      ),
    ];
    for (final item in fixtures) {
      await repository.save(item);
    }

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
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Week'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(find.byTooltip('Previous week'), findsOneWidget);
    expect(find.textContaining('QA ramp shift'), findsWidgets);
    expect(find.textContaining('QA Aviation Safety'), findsWidgets);
    expect(find.textContaining('4 overlapping events'), findsOneWidget);

    if (const bool.fromEnvironment('QA_CAPTURE_SCREEN')) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 8)),
      );
    }
  });
}
