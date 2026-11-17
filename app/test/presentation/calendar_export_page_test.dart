import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/presentation/design/studyshift_spacing.dart';
import 'package:shift_study/presentation/screens/calendar_export_page.dart';
import 'package:shift_study/presentation/screens/settings_page.dart';

void main() {
  const exportChannel = MethodChannel('app.shiftstudy/export');

  testWidgets('calendar export follows shared page and card spacing', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CalendarExportPage()));

    final list = tester.widget<ListView>(find.byType(ListView));
    expect(
      list.padding,
      const EdgeInsets.fromLTRB(
        StudyShiftSpacing.pageMargin,
        StudyShiftSpacing.pageMargin,
        StudyShiftSpacing.pageMargin,
        StudyShiftSpacing.x8,
      ),
    );
    expect(
      tester
          .widgetList<Padding>(
            find.descendant(
              of: find.byType(Card),
              matching: find.byType(Padding),
            ),
          )
          .any(
            (padding) =>
                padding.padding ==
                const EdgeInsets.all(StudyShiftSpacing.cardPadding),
          ),
      isTrue,
    );
  });

  testWidgets('exports a confirmed local schedule through the file bridge', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await ScheduleRepository(database).save(
      ScheduleItem(
        id: 'export-shift',
        kind: ScheduleKind.work,
        title: 'Synthetic export shift',
        startDate: CivilDate.fromDateTime(
          DateTime.now().add(const Duration(days: 2)),
        ),
        intervals: [
          EventInterval.sameDay(startMinute: 9 * 60, endMinute: 17 * 60),
        ],
        timeZoneId: 'America/Barbados',
      ),
    );

    Uint8List? savedBytes;
    String? savedFileName;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(exportChannel, (call) async {
          expect(call.method, 'saveCalendar');
          savedBytes = call.arguments['bytes'] as Uint8List;
          savedFileName = call.arguments['fileName'] as String;
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(exportChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [scheduleDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save .ics file'));
    await tester.pumpAndSettle();

    expect(
      savedFileName,
      matches(RegExp(r'^shift-study-\d{4}-\d{2}-\d{2}\.ics$')),
    );
    final calendar = utf8.decode(savedBytes!);
    expect(calendar, contains('SUMMARY:Synthetic export shift'));
    expect(calendar, contains('CATEGORIES:WORK,SHIFT'));
    expect(find.text('Calendar file saved.'), findsOneWidget);
  });
}
