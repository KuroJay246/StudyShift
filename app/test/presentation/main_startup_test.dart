import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/main.dart';
import 'package:shift_study/presentation/screens/schedule_pages.dart';

void main() {
  testWidgets('opens the requested destination while local shifts load', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWith(
            (ref) async => const AppPreferences(
              scheduleMode: ScheduleMode.workAndSchool,
            ),
          ),
          scheduleItemsProvider.overrideWith(
            (ref) => const Stream<List<ScheduleItem>>.empty(),
          ),
          widgetLaunchDestinationProvider.overrideWith(
            (ref) async => 'week',
          ),
          widgetSnapshotSyncProvider.overrideWithValue(null),
          localReminderSyncProvider.overrideWithValue(null),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Halifax',
          ),
        ],
        child: const MainApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(WeekPage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('StudyShift'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
