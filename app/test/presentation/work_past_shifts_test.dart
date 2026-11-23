import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/presentation/app_theme.dart';
import 'package:shift_study/presentation/screens/schedule_pages.dart';
import 'package:shift_study/presentation/widgets/schedule_event_tile.dart';

void main() {
  testWidgets('past shifts stay visible and older history expands on request', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = ScheduleRepository(database);
    final recentPast = ScheduleItem(
      id: 'past-recent',
      kind: ScheduleKind.work,
      title: 'Recent past roster shift',
      startDate: CivilDate(2026, 11, 20),
      intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 1020)],
    );
    final olderPast = ScheduleItem(
      id: 'past-old',
      kind: ScheduleKind.work,
      title: 'Older roster shift',
      startDate: CivilDate(2026, 9, 14),
      intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 1020)],
    );
    final nextShift = ScheduleItem(
      id: 'upcoming-next',
      kind: ScheduleKind.work,
      title: 'Next roster shift',
      startDate: CivilDate(2026, 11, 24),
      intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 1020)],
    );
    await repository.save(recentPast);
    await repository.save(olderPast);
    await repository.save(nextShift);
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
          home: Scaffold(
            body: WorkPage(clock: () => DateTime(2026, 11, 23, 9)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Past shifts'), findsOneWidget);
    expect(find.text('Recent past roster shift'), findsOneWidget);
    expect(find.text('Next roster shift'), findsOneWidget);
    expect(find.text('Older roster shift'), findsNothing);
    final recentTile = tester.widget<ScheduleEventTile>(
      find.byWidgetPredicate(
        (widget) =>
            widget is ScheduleEventTile && widget.item.id == recentPast.id,
      ),
    );
    expect(recentTile.statusLabel, isNull);
    expect(
      (await repository.getItems())
          .firstWhere((item) => item.id == recentPast.id)
          .isCompleted,
      isFalse,
    );

    await tester.ensureVisible(find.text('Show all past shifts'));
    await tester.tap(find.text('Show all past shifts'));
    await tester.pumpAndSettle();

    expect(find.text('Older roster shift'), findsOneWidget);
    expect(find.text('Show recent shifts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
