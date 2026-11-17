import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/domain/schedule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const widgetChannel = MethodChannel('app.shiftstudy/widget_snapshot');

  test(
    'Riverpod wires the local database, repositories and shared queries',
    () async {
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

      expect(
        await container.read(scheduleRepositoryProvider).getItems(),
        isEmpty,
      );
      expect(
        await container.read(preferencesRepositoryProvider).load(),
        isNotNull,
      );
      expect(
        container.read(scheduleQueriesProvider),
        same(container.read(scheduleQueriesProvider)),
      );
    },
  );

  test(
    'app startup and schedule edits republish the local widget snapshot',
    () async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      final firstSnapshot = Completer<Map<String, dynamic>>();
      final editedSnapshot = Completer<Map<String, dynamic>>();
      var writeCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(widgetChannel, (call) async {
            expect(call.method, 'saveSnapshot');
            final snapshot =
                jsonDecode(call.arguments as String) as Map<String, dynamic>;
            writeCount++;
            if (writeCount == 1) firstSnapshot.complete(snapshot);
            if (writeCount == 2) editedSnapshot.complete(snapshot);
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(widgetChannel, null),
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
      container.read(widgetSnapshotSyncProvider);

      expect(
        (await firstSnapshot.future.timeout(
          const Duration(seconds: 2),
        ))['today'],
        isEmpty,
      );

      final now = DateTime.now();
      await container
          .read(scheduleRepositoryProvider)
          .save(
            ScheduleItem(
              id: 'synthetic-work',
              kind: ScheduleKind.work,
              title: 'Test shift',
              startDate: CivilDate.fromDateTime(now),
              intervals: [
                EventInterval.sameDay(startMinute: 600, endMinute: 660),
              ],
            ),
          );

      final updated = await editedSnapshot.future.timeout(
        const Duration(seconds: 2),
      );
      expect((updated['today'] as List).single['id'], 'synthetic-work');
    },
  );
}
