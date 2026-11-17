import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/domain/academic_term.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/presentation/screens/academic_terms_page.dart';

void main() {
  testWidgets(
    'empty academic terms show one add action without an overlapping FAB',
    (tester) async {
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
          child: const MaterialApp(home: AcademicTermsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add your academic term'), findsOneWidget);
      expect(find.text('Add term'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    },
  );

  testWidgets('saved academic terms keep a single floating add action', (
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
        .read(academicTermRepositoryProvider)
        .save(
          AcademicTerm(
            id: 'synthetic-term',
            institution: 'Example University',
            name: 'Autumn Term',
            startDate: CivilDate(2026, 9, 1),
            endDate: CivilDate(2026, 12, 15),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AcademicTermsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Autumn Term'), findsOneWidget);
    expect(find.byTooltip('Add term'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('academic term editor scrolls without overflowing on short screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 520);
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
        child: const MaterialApp(home: AcademicTermsPage()),
      ),
    );
    await tester.pumpAndSettle();
    final addTerm = find.text('Add term');
    await tester.ensureVisible(addTerm);
    await tester.tap(addTerm);
    await tester.pumpAndSettle();

    final saveButton = find.text('Save term');
    expect(saveButton, findsOneWidget);
    expect(tester.getRect(saveButton).bottom, lessThanOrEqualTo(520));
    expect(tester.takeException(), isNull);
  });

  testWidgets('academic term editor remains usable at large text in landscape', (
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
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.75),
            ),
            child: child!,
          ),
          home: const AcademicTermsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final addTerm = find.text('Add term');
    await tester.ensureVisible(addTerm);
    await tester.tap(addTerm);
    await tester.pumpAndSettle();

    final saveButton = find.text('Save term');
    expect(saveButton, findsOneWidget);
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    expect(tester.getRect(saveButton).bottom, lessThanOrEqualTo(411));
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('Enter an institution.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
