import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/presentation/widgets/schedule_details_sheet.dart';

void main() {
  testWidgets(
    'event detail actions fit narrow phone width with clear spacing',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      final shift = ScheduleItem(
        id: 'synthetic-narrow-actions',
        kind: ScheduleKind.work,
        title: 'Synthetic shift',
        startDate: CivilDate.fromDateTime(DateTime.now()),
        intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 1020)],
      );
      await ScheduleRepository(database).save(shift);
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
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () => showScheduleDetails(context, ref, shift),
                  child: const Text('Open narrow actions'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open narrow actions'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final deleteRect = tester.getRect(find.text('Delete'));
      final finishRect = tester.getRect(find.text('Finish shift'));
      final editRect = tester.getRect(find.text('Edit event'));
      expect(finishRect.overlaps(deleteRect), isFalse);
      expect(editRect.left, greaterThanOrEqualTo(0));
      expect(editRect.right, lessThanOrEqualTo(320));
    },
  );

  testWidgets('future shift cannot be marked finished before its start', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final repository = ScheduleRepository(database);
    final tomorrow = CivilDate.fromDateTime(
      DateTime.now().add(const Duration(days: 1)),
    );
    final shift = ScheduleItem(
      id: 'synthetic-future-shift-completion',
      kind: ScheduleKind.work,
      workCategory: WorkCategory.shift,
      title: 'Synthetic future shift',
      startDate: tomorrow,
      timeZoneId: 'UTC',
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 600)],
    );
    await repository.save(shift);
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
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showScheduleDetails(context, ref, shift),
                child: const Text('Open future shift'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open future shift'));
    await tester.pumpAndSettle();

    final finishButton = find.ancestor(
      of: find.text('Finish shift'),
      matching: find.byType(OutlinedButton),
    );
    expect(finishButton, findsOneWidget);
    expect(tester.widget<OutlinedButton>(finishButton).onPressed, isNull);
    expect(find.text('Available after the shift starts.'), findsOneWidget);
    expect((await repository.getItems()).single.isCompleted, isFalse);
  });

  testWidgets('main event actions stay near the top of long shift details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final shift = ScheduleItem(
      id: 'synthetic-long-shift-details',
      kind: ScheduleKind.work,
      workCategory: WorkCategory.shift,
      title: 'Synthetic ramp shift',
      startDate: CivilDate.fromDateTime(
        DateTime.now().subtract(const Duration(days: 1)),
      ),
      timeZoneId: 'UTC',
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 1020)],
      employerName: 'Synthetic airline handling',
      departmentName: 'Synthetic ramp operations',
      jobRole: 'Synthetic ground operative',
      reportingInstruction: ' '.padRight(220, 'Report at synthetic station. '),
      notes: ' '.padRight(220, 'Synthetic operational notes. '),
      supervisorName: 'Synthetic supervisor',
      supervisorPhone: '+10000000000',
      contactName: 'Synthetic desk',
      contactPhone: '+10000000001',
      code: 'SYN',
      codeMeaning: 'Synthetic roster description',
    );
    await ScheduleRepository(database).save(shift);
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
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showScheduleDetails(context, ref, shift),
                child: const Text('Open populated shift'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open populated shift'));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.text('Finish shift')).bottom, lessThan(800));
    expect(tester.getRect(find.text('Delete')).bottom, lessThan(800));
  });

  testWidgets('work details show the saved department and job role', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final work = ScheduleItem(
      id: 'synthetic-work-details',
      kind: ScheduleKind.work,
      title: 'Synthetic ramp duty',
      startDate: CivilDate(2026, 11, 14),
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 1020)],
      departmentName: 'Synthetic ramp operations',
      jobRole: 'Ramp agent',
    );
    await ScheduleRepository(database).save(work);
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
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showScheduleDetails(context, ref, work),
                child: const Text('Open work details'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open work details'));
    await tester.pumpAndSettle();

    expect(
      find.text('Department or team: Synthetic ramp operations'),
      findsOneWidget,
    );
    expect(find.text('Job role: Ramp agent'), findsOneWidget);
  });

  testWidgets('a deadline can be marked complete from its details', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final repository = ScheduleRepository(database);
    final assignment = ScheduleItem(
      id: 'synthetic-completable-assignment',
      kind: ScheduleKind.deadline,
      deadlineType: DeadlineType.assignment,
      title: 'Synthetic assignment completion check',
      startDate: CivilDate(2026, 11, 12),
      intervals: const [],
      code: 'CS 101',
    );
    await repository.save(assignment);
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
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      showScheduleDetails(context, ref, assignment),
                  child: const Text('Open assignment details'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open assignment details'));
    await tester.pumpAndSettle();

    expect(find.text('Not completed'), findsOneWidget);
    expect(find.text('Course code: CS 101'), findsOneWidget);
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();

    final saved = (await repository.getItems()).single;
    expect(saved.id, assignment.id);
    expect(saved.isCompleted, isTrue);
  });

  testWidgets('shift wrap-up records completion without overtime', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final repository = ScheduleRepository(database);
    final yesterday = CivilDate.fromDateTime(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final overtime = ScheduleItem(
      id: 'synthetic-overtime-completion',
      kind: ScheduleKind.work,
      workCategory: WorkCategory.overtime,
      title: 'Synthetic overtime shift',
      startDate: yesterday,
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 600)],
    );
    await repository.save(overtime);
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
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showScheduleDetails(context, ref, overtime),
                child: const Text('Open overtime details'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open overtime details'));
    await tester.pumpAndSettle();

    expect(find.text('Not completed'), findsOneWidget);
    await tester.tap(find.text('Finish shift'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No overtime'));
    await tester.pumpAndSettle();

    final saved = (await repository.getItems()).single;
    expect(saved.isCompleted, isTrue);
    expect(saved.workCategory, WorkCategory.overtime);
    expect(saved.intervals, overtime.intervals);
    expect(saved.actualIntervals, overtime.intervals);

    await tester.tap(find.text('Open overtime details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Actual finish:'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    final cleared = (await repository.getItems()).single;
    expect(cleared.isCompleted, isFalse);
    expect(cleared.actualIntervals, isNull);
  });

  testWidgets('shift wrap-up saves the selected overtime finish', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final repository = ScheduleRepository(database);
    final shift = ScheduleItem(
      id: 'synthetic-overtime-finish-time',
      kind: ScheduleKind.work,
      workCategory: WorkCategory.shift,
      title: 'Synthetic scheduled shift',
      startDate: CivilDate.fromDateTime(
        DateTime.now().subtract(const Duration(days: 1)),
      ),
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 600)],
    );
    await repository.save(shift);
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
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showScheduleDetails(context, ref, shift),
                child: const Text('Open scheduled shift'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open scheduled shift'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish shift'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overtime'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to text input mode'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.last, '30');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final saved = (await repository.getItems()).single;
    expect(saved.isCompleted, isTrue);
    expect(saved.intervals.single.endMinute, 600);
    expect(saved.actualIntervals!.single.endMinute, 630);
  });

  testWidgets('a recurring daylight-saving gap explains safe next actions', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final gapDate = CivilDate(2026, 3, 8);
    final weeklyClass = ScheduleItem(
      id: 'synthetic-spring-gap-class',
      kind: ScheduleKind.classSession,
      title: 'Synthetic Sunday class',
      startDate: CivilDate(2026, 3, 1),
      timeZoneId: 'America/New_York',
      intervals: [EventInterval.sameDay(startMinute: 150, endMinute: 210)],
      recurrence: WeeklyRecurrence(
        weekdays: {DateTime.sunday},
        until: CivilDate(2026, 3, 15),
      ),
    );
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
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showScheduleDetails(
                    context,
                    ref,
                    weeklyClass,
                    occurrenceDate: gapDate,
                  ),
                  child: const Text('Open gap occurrence'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open gap occurrence'));
    await tester.pumpAndSettle();

    expect(find.text('Time needs review'), findsOneWidget);
    expect(
      find.text(
        'Part 1: the start time falls in a daylight-saving clock gap on this date.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Change the series time for every week, or skip this date to leave the other occurrences unchanged.',
      ),
      findsOneWidget,
    );
    expect(find.text('Edit series'), findsOneWidget);

    await tester.ensureVisible(find.text('Skip this occurrence'));
    await tester.tap(find.text('Skip this occurrence'));
    await tester.pumpAndSettle();
    expect(
      (await container.read(scheduleRepositoryProvider).getItems())
          .single
          .recurrence!
          .exceptionDates,
      {gapDate},
    );
  });

  testWidgets('legacy event details call out the missing time zone', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final legacy = ScheduleItem(
      id: 'legacy-zone-details',
      kind: ScheduleKind.work,
      title: 'Legacy shift',
      startDate: CivilDate(2026, 11, 5),
      intervals: [EventInterval.sameDay(startMinute: 480, endMinute: 960)],
      supervisorName: 'Synthetic supervisor',
      supervisorPhone: '+1 246 555 0100',
      contactName: 'Synthetic operations desk',
      contactPhone: '+1 246 555 0101',
    );
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
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showScheduleDetails(context, ref, legacy),
                  child: const Text('Open legacy details'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open legacy details'));
    await tester.pumpAndSettle();

    expect(
      find.text('Time zone not saved. Edit this event to review or set one.'),
      findsOneWidget,
    );
    expect(find.text('Edit event'), findsOneWidget);
    expect(find.text('Supervisor: Synthetic supervisor'), findsOneWidget);
    expect(find.text('Supervisor phone: +1 246 555 0100'), findsOneWidget);
    expect(
      find.text('Shift contact: Synthetic operations desk'),
      findsOneWidget,
    );
    expect(find.text('Contact phone: +1 246 555 0101'), findsOneWidget);
  });

  testWidgets('open details refresh after the saved item changes', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final repository = ScheduleRepository(database);
    final item = ScheduleItem(
      id: 'synthetic-editable-class',
      kind: ScheduleKind.classSession,
      title: 'Original title',
      startDate: CivilDate(2026, 11, 4),
      intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
    );
    await repository.save(item);
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
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showScheduleDetails(context, ref, item),
                  child: const Text('Open details'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    expect(find.text('Original title'), findsOneWidget);

    await repository.save(
      ScheduleItem(
        id: item.id,
        kind: item.kind,
        title: 'Updated title',
        startDate: item.startDate,
        intervals: item.intervals,
      ),
    );
    container.invalidate(scheduleItemsProvider);
    await tester.pumpAndSettle();

    expect(find.text('Updated title'), findsOneWidget);
    expect(find.text('Original title'), findsNothing);
  });

  testWidgets('moved one-time event details use the saved date', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final repository = ScheduleRepository(database);
    const oldDate = CivilDate(2026, 11, 6);
    const newDate = CivilDate(2026, 11, 7);
    final item = ScheduleItem(
      id: 'synthetic-moved-event',
      kind: ScheduleKind.work,
      title: 'Synthetic moved shift',
      startDate: oldDate,
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 1020)],
    );
    await repository.save(item);
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
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showScheduleDetails(
                    context,
                    ref,
                    item,
                    occurrenceDate: oldDate,
                  ),
                  child: const Text('Open moved event'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open moved event'));
    await tester.pumpAndSettle();

    final localizations = MaterialLocalizations.of(
      tester.element(find.text('Synthetic moved shift')),
    );
    expect(
      find.text(localizations.formatMediumDate(oldDate.toDateTime())),
      findsOneWidget,
    );

    await repository.save(
      ScheduleItem(
        id: item.id,
        kind: item.kind,
        title: item.title,
        startDate: newDate,
        intervals: item.intervals,
      ),
    );
    container.invalidate(scheduleItemsProvider);
    await tester.pumpAndSettle();

    expect(
      find.text(localizations.formatMediumDate(newDate.toDateTime())),
      findsOneWidget,
    );
    expect(
      find.text(localizations.formatMediumDate(oldDate.toDateTime())),
      findsNothing,
    );
  });

  testWidgets('a recurring occurrence can be skipped and restored', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final repository = ScheduleRepository(database);
    final skippedDate = CivilDate(2026, 11, 11); // Wednesday
    var occurrenceDate = skippedDate;
    var item = ScheduleItem(
      id: 'synthetic-weekly-class',
      kind: ScheduleKind.classSession,
      title: 'Synthetic lecture',
      startDate: CivilDate(2026, 11, 4),
      intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
      recurrence: WeeklyRecurrence(
        weekdays: {DateTime.wednesday},
        until: CivilDate(2026, 11, 30),
      ),
    );
    await repository.save(item);
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    Widget harness() => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showScheduleDetails(
                  context,
                  ref,
                  item,
                  occurrenceDate: occurrenceDate,
                ),
                child: const Text('Open occurrence'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(harness());
    await tester.tap(find.text('Open occurrence'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip this occurrence'));
    await tester.pumpAndSettle();

    item = (await repository.getItems()).single;
    expect(item.recurrence!.exceptionDates, {skippedDate});

    // A canceled date is no longer in the agenda; restore it from another
    // occurrence's series details, where the exception history is visible.
    occurrenceDate = CivilDate(2026, 11, 18);
    await tester.pumpWidget(harness());
    await tester.tap(find.text('Open occurrence'));
    await tester.pumpAndSettle();
    final canceledLabel = MaterialLocalizations.of(
      tester.element(find.text('Synthetic lecture')),
    ).formatShortDate(DateTime(2026, 11, 11));
    final restoreAction = find.text('Restore $canceledLabel');
    await tester.ensureVisible(restoreAction);
    await tester.tap(restoreAction);
    await tester.pumpAndSettle();
    expect(
      (await repository.getItems()).single.recurrence!.exceptionDates,
      isEmpty,
    );
  });
}
