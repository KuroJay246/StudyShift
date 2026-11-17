import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/platform/device_time_zone.dart';
import 'package:shift_study/platform/local_reminders.dart';
import 'package:shift_study/presentation/app.dart';
import 'package:shift_study/presentation/app_theme.dart';

class _TestTimeZone implements DeviceTimeZone {
  @override
  Future<String> getLocalIanaId() async => 'America/Barbados';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('a running app opens event details when its reminder is tapped', (
    tester,
  ) async {
    final taps = StreamController<ReminderDestination>();
    addTearDown(taps.close);
    await _showApp(tester, taps.stream, [_event()]);

    taps.add(_destination());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('a cold-start reminder opens its event after schedule load', (
    tester,
  ) async {
    await _showApp(tester, Stream.value(_destination()), [_event()]);
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('a reminder for a deleted event is safely ignored', (
    tester,
  ) async {
    await _showApp(tester, Stream.value(_destination()), const []);
    await tester.pumpAndSettle();

    expect(find.text('Reminder event'), findsNothing);
  });
}

Future<void> _showApp(
  WidgetTester tester,
  Stream<ReminderDestination> taps,
  List<ScheduleItem> items,
) async {
  tester.view.physicalSize = const Size(412, 915);
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
      deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
      scheduleItemsProvider.overrideWith((ref) => Stream.value(items)),
      reminderDestinationsProvider.overrideWith((ref) => taps),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const ScheduleShell(mode: ScheduleMode.workAndSchool),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ReminderDestination _destination() => const ReminderDestination(
  itemId: 'reminder-event',
  occurrenceDate: CivilDate(2026, 11, 16),
);

ScheduleItem _event() => ScheduleItem(
  id: 'reminder-event',
  kind: ScheduleKind.classSession,
  title: 'Reminder event',
  startDate: const CivilDate(2026, 11, 16),
  intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
  timeZoneId: 'America/Barbados',
  reminderMinutesBefore: 15,
);
