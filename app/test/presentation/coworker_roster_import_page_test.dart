import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/presentation/screens/coworker_roster_import_page.dart';

void main() {
  const channel = MethodChannel('app.shiftstudy/import');
  const csv =
      'date,code,coworkers\n'
      '2026-11-24,A1,"Synthetic Lee;Synthetic Sam"\n'
      '2026-11-26,ZZ,Synthetic Unmatched\n';

  testWidgets('updates only matched shift coworkers after confirmation', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = ScheduleRepository(database);
    final original = ScheduleItem(
      id: 'existing-shift',
      kind: ScheduleKind.work,
      title: 'Synthetic saved shift',
      startDate: const CivilDate(2026, 11, 24),
      intervals: const [
        EventInterval(
          startDayOffset: 0,
          startMinute: 9 * 60,
          endDayOffset: 0,
          endMinute: 17 * 60,
        ),
      ],
      timeZoneId: 'America/Barbados',
      code: 'A1',
      employerName: 'Synthetic employer',
      notes: 'Keep these existing notes',
      coworkers: const ['Synthetic Sam'],
    );
    await repository.save(original);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'openCalendar');
          return {
            'name': 'synthetic-coworkers.csv',
            'bytes': Uint8List.fromList(utf8.encode(csv)),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [scheduleDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: CoworkerRosterImportPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose coworker roster CSV'));
    await tester.pumpAndSettle();
    expect(find.text('1 matched · 1 unmatched · 0 ambiguous'), findsOneWidget);
    expect(find.text('No saved shift matches'), findsOneWidget);
    expect(await repository.getItems(), hasLength(1));

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update coworkers on 1 shift'));
    await tester.pumpAndSettle();
    expect(find.text('Update coworkers on saved shifts?'), findsOneWidget);
    await tester.tap(find.text('Update coworkers'));
    await tester.pumpAndSettle();

    final items = await repository.getItems();
    expect(items, hasLength(1));
    final updated = items.single;
    expect(updated.id, original.id);
    expect(updated.title, original.title);
    expect(updated.startDate, original.startDate);
    expect(updated.intervals, original.intervals);
    expect(updated.timeZoneId, original.timeZoneId);
    expect(updated.code, original.code);
    expect(updated.notes, original.notes);
    expect(updated.coworkers, ['Synthetic Sam', 'Synthetic Lee']);
  });
}
