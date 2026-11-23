import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
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
      find.textContaining('Premium-eligible after 8h: 0h'),
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
    expect(find.text('Total hours'), findsOneWidget);
    expect(find.textContaining('Extra hours: 2h'), findsOneWidget);
    expect(find.textContaining('Over 8h per shift: 0h'), findsOneWidget);
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
            body: WorkPage(clock: () => DateTime(2026, 11, 23, 8)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overtime'));
    await tester.pumpAndSettle();

    expect(find.text('Synthetic recurring overtime shift'), findsOneWidget);
    expect(find.textContaining('Nov 30'), findsOneWidget);
    expect(find.textContaining('Extra hours: 2h'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
