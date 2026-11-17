import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/domain/supervisor_profile.dart';
import 'package:shift_study/presentation/app_theme.dart';
import 'package:shift_study/presentation/screens/work_code_legend_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android keeps permanent and acting supervisor groups distinct', (
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
    final repository = container.read(supervisorRepositoryProvider);
    await repository.save(
      const SupervisorProfile(
        id: 'qa-supervisor-permanent',
        name: 'QA Permanent Supervisor',
      ),
    );
    await repository.save(
      const SupervisorProfile(
        id: 'qa-supervisor-acting',
        name: 'QA Acting Supervisor',
        type: SupervisorType.acting,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const WorkCodeLegendPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supervisors'));
    await tester.pumpAndSettle();

    expect(find.text('Permanent supervisors'), findsOneWidget);
    expect(find.text('QA Permanent Supervisor'), findsOneWidget);
    expect(find.text('Acting supervisors'), findsOneWidget);
    expect(find.text('QA Acting Supervisor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
