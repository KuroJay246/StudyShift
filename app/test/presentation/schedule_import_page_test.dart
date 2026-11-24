import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/data/schedule_import_history_repository.dart';
import 'package:shift_study/data/supervisor_repository.dart';
import 'package:shift_study/data/work_code_legend_repository.dart';
import 'package:shift_study/data/work_occurrence_coworker_repository.dart';
import 'package:shift_study/data/csv_schedule_import.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/data/roster_grid_import.dart';
import 'package:shift_study/data/roster_legend_import.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/supervisor_profile.dart';
import 'package:shift_study/domain/work_code_legend.dart';
import 'package:shift_study/presentation/screens/settings_page.dart';

Future<void> selectRosterStaffRow(
  WidgetTester tester,
  String name, {
  int tableIndex = 0,
}) async {
  await tester.tap(find.byKey(ValueKey('roster-staff-row-$tableIndex')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> showBuildRosterReview(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Build shift review'),
    240,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('smart-import-list')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  const fileChannel = MethodChannel('app.shiftstudy/import');
  const examOcrText = '4/Dec/26 9:00 A.M. BIOL1100 Introductory Biology 2 HRS';
  const source = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Shift Study Test//EN
BEGIN:VEVENT
DTSTAMP:20261106T120000Z
UID:class@example.test
DTSTART;TZID=America/Barbados:20261110T090000
DTEND;TZID=America/Barbados:20261110T100000
SUMMARY:Chemistry lecture
LOCATION:Science 101
END:VEVENT
END:VCALENDAR''';

  testWidgets('Smart Import previews and saves only reviewed events', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          return {
            'name': 'classes.ics',
            'bytes': Uint8List.fromList(utf8.encode(source)),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Import coworkers to saved shifts'), findsNothing);
    expect(find.text('Import coworkers'), findsNothing);
    expect(find.text('Choose a file to get started'), findsOneWidget);
    expect(
      find.textContaining('Smart Import detects the file type and content'),
      findsOneWidget,
    );
    expect(find.text('Choose a file'), findsOneWidget);
    expect(find.text('Import coworkers'), findsNothing);
    expect(find.text('Read a PDF or schedule image offline'), findsNothing);
    expect(find.text('Read a roster table'), findsNothing);
    expect(find.text('Read an exam timetable'), findsNothing);
    await tester.tap(find.text('CSV and Excel file format'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'code_meaning,coworkers,coworker_codes,reporting_instruction',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('department, job_role'), findsOneWidget);
    expect(find.textContaining('date,end_date,title'), findsOneWidget);
    expect(find.textContaining('one row per interval'), findsOneWidget);
    expect(
      find.textContaining('Timed events also need start, end and a time_zone'),
      findsOneWidget,
    );
    expect(find.textContaining('SYNTH-001'), findsOneWidget);
    final sampleCsv = tester
        .widget<SelectableText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is SelectableText &&
                widget.data?.contains('SYNTH-001') == true,
          ),
        )
        .data!;
    final sample = await const CsvScheduleImportParser().parse(
      sampleCsv,
      sourceName: 'sample.csv',
    );
    expect(sample.proposals.first.item.coworkers, ['Synthetic coworker']);
    expect(
      sample.proposals.first.item.reportingInstruction,
      'Sample reporting text',
    );
    expect(sample.proposals.first.item.location, 'Sample location');
    await tester.tap(find.text('CSV and Excel file format'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.textContaining('Add other timetable files to the same review'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('Document recognized'), findsOneWidget);
    expect(find.text('Detected type'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);
    expect(find.text('ICS calendar'), findsOneWidget);
    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('Add reviewed schedule entries'), findsOneWidget);
    expect(find.text('Chemistry lecture'), findsOneWidget);
    expect(find.textContaining('classes.ics'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 1 selected'));
    await tester.pumpAndSettle();

    final items = await ScheduleRepository(database).getItems();
    expect(items, hasLength(1));
    expect(items.single.kind, ScheduleKind.personal);
    expect(items.single.title, 'Chemistry lecture');
    expect(items.single.startDate, CivilDate(2026, 11, 10));
    expect(items.single.intervals.single.startMinute, 9 * 60);
    expect(items.single.location, 'Science 101');
    expect(items.single.importProvenance!.uid, 'class@example.test');
    expect(items.single.importProvenance!.sourceName, 'classes.ics');

    final history = await database
        .customSelect(
          'SELECT source_type, parser_version, proposed_count, accepted_count, '
          'rejected_count, skipped_count, warnings_count '
          'FROM schedule_import_history_rows',
        )
        .getSingle();
    expect(history.read<String>('source_type'), 'ics');
    expect(history.read<String>('parser_version'), '1');
    expect(history.read<int>('proposed_count'), 1);
    expect(history.read<int>('accepted_count'), 1);
    expect(history.read<int>('rejected_count'), 0);
    expect(history.read<int>('skipped_count'), 0);
    expect(history.read<int>('warnings_count'), 0);
  });

  testWidgets('CSV roster matrix enters review without changing saved shifts', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    const csv =
        'Employee,Nov 23 2026,Nov 24 2026,Nov 25 2026\n'
        'Synthetic owner,AV,,\n'
        'Synthetic coworker,AV,,\n';
    final savedShift = ScheduleItem(
      id: 'synthetic-av-shift',
      kind: ScheduleKind.work,
      workCategory: WorkCategory.shift,
      title: 'Synthetic saved shift',
      startDate: CivilDate(2026, 11, 23),
      timeZoneId: 'America/Barbados',
      code: 'AV',
      employerName: 'Synthetic employer',
      intervals: [EventInterval.sameDay(startMinute: 750, endMinute: 1230)],
    );
    await ScheduleRepository(database).save(savedShift);
    await WorkCodeLegendRepository(database).save(
      const WorkCodeLegend(
        id: 'synthetic-av',
        employer: 'Synthetic employer',
        code: 'AV',
        timeWindows: [WorkCodeTimeWindow(startMinute: 750, endMinute: 1230)],
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          return {
            'name': 'synthetic-work-roster.csv',
            'bytes': Uint8List.fromList(utf8.encode(csv)),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Confirm roster dates'), findsOneWidget);
    final beforeReview = await ScheduleRepository(database).getItems();
    expect(beforeReview, hasLength(1));
    expect(beforeReview.single.id, savedShift.id);
    expect(beforeReview.single.coworkers, isEmpty);
  });

  testWidgets('appends a second roster file to the same reviewed batch', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    const first =
        'date,title,category,start,end,time_zone,employer,code,coworkers,coworker_codes\n'
        '2026-11-24,Synthetic roster A,shift,09:00,17:00,America/Barbados,Synthetic employer,A1,Synthetic Lee,A1';
    const second =
        'date,title,category,start,end,time_zone,employer,code,coworkers,coworker_codes\n'
        '2026-11-25,Synthetic roster B,shift,09:00,17:00,America/Barbados,Synthetic employer,A1,Synthetic Sam,A1';
    var selectedFile = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          selectedFile++;
          final source = selectedFile == 1 ? first : second;
          return {
            'name': 'synthetic-roster.csv',
            'bytes': Uint8List.fromList(utf8.encode(source)),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic roster A'), findsOneWidget);
    expect(find.text('Add another file to this import'), findsOneWidget);
    await tester.ensureVisible(find.text('Add another file to this import'));
    await tester.tap(find.text('Add another file to this import'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic roster A'), findsOneWidget);
    expect(find.text('Synthetic roster B'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(find.textContaining('files are staged together'), findsNothing);
    await tester.ensureVisible(find.text('Add 2 selected'));
    await tester.tap(find.text('Add 2 selected'));
    await tester.pumpAndSettle();

    final items = await ScheduleRepository(database).getItems();
    expect(items, hasLength(2));
    expect(items.map((item) => item.startDate.toString()).toSet(), {
      '2026-11-24',
      '2026-11-25',
    });
    expect(items.map((item) => item.coworkers.single).toSet(), {
      'Synthetic Lee',
      'Synthetic Sam',
    });
    expect(items.map((item) => item.importProvenance!.sourceName).toSet(), {
      'synthetic-roster.csv',
      'synthetic-roster (2).csv',
    });
    final history = await ScheduleImportHistoryRepository(database)
        .getEntries();
    expect(history.single.sourceType, ScheduleImportSourceType.batch);
    expect(selectedFile, 2);
  });

  testWidgets(
    'overlapping roster revisions with changed times require choosing one',
    (tester) async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      const firstCsv =
          'date,title,category,start,end,time_zone,employer,code\n'
          '2026-11-24,Synthetic earlier roster,shift,09:00,17:00,America/Barbados,Synthetic CAH,A1';
      const revisedCsv =
          'date,title,category,start,end,time_zone,employer,code\n'
          '2026-11-24,Synthetic revised roster,shift,10:00,18:00,America/Barbados,Synthetic CAH,A1';
      var fileIndex = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, (call) async {
            expect(call.method, 'openImport');
            final content = fileIndex++ == 0 ? firstCsv : revisedCsv;
            return {
              'name': fileIndex == 1
                  ? 'synthetic-old.csv'
                  : 'synthetic-new.csv',
              'bytes': Uint8List.fromList(utf8.encode(content)),
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(fileChannel, null);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scheduleDatabaseProvider.overrideWithValue(database),
            deviceTimeZoneIdProvider.overrideWith(
              (ref) async => 'America/Barbados',
            ),
          ],
          child: const MaterialApp(
            home: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smart Import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a file'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic earlier roster'), findsOneWidget);
      await tester.ensureVisible(find.text('Add another file to this import'));
      await tester.tap(find.text('Add another file to this import'));
      await tester.pumpAndSettle();

      expect(find.text('Synthetic earlier roster'), findsOneWidget);
      expect(find.text('Synthetic revised roster'), findsOneWidget);
      expect(find.text('Proposed events · 0 selected'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(CheckboxListTile, 'Synthetic revised roster'),
      );
      await tester.tap(
        find.widgetWithText(CheckboxListTile, 'Synthetic revised roster'),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add 1 selected'));
      await tester.tap(find.text('Add 1 selected'));
      await tester.pumpAndSettle();

      final saved = await ScheduleRepository(database).getItems();
      expect(saved, hasLength(1));
      expect(saved.single.title, 'Synthetic revised roster');
      expect(saved.single.intervals.single.startMinute, 10 * 60);
      expect(fileIndex, 2);
    },
  );

  testWidgets('ICS and CSV files share one reviewed import batch', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    const csv =
        'date,title,category,start,end,time_zone\n'
        '2026-11-11,Synthetic roster shift,shift,09:00,17:00,America/Barbados';
    var selectedFile = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          selectedFile++;
          return {
            'name': selectedFile == 1 ? 'classes.ics' : 'roster.csv',
            'bytes': Uint8List.fromList(
              utf8.encode(selectedFile == 1 ? source : csv),
            ),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(selectedFile, 1);
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('Chemistry lecture'), findsOneWidget);

    await tester.ensureVisible(find.text('Add another file to this import'));
    await tester.tap(find.text('Add another file to this import'));
    await tester.pumpAndSettle();
    expect(selectedFile, 2);
    expect(find.text('Chemistry lecture'), findsOneWidget);
    expect(find.text('Synthetic roster shift'), findsOneWidget);
    expect(find.text('Multiple timetable files'), findsOneWidget);

    await tester.ensureVisible(find.text('Add 2 selected'));
    await tester.tap(find.text('Add 2 selected'));
    await tester.pumpAndSettle();
    final items = await ScheduleRepository(database).getItems();
    expect(items, hasLength(2));
    expect(
      items.map((item) => item.title),
      containsAll(['Chemistry lecture', 'Synthetic roster shift']),
    );
    expect(
      items.map((item) => item.kind),
      containsAll([ScheduleKind.personal, ScheduleKind.work]),
    );
  });

  testWidgets(
    'Smart Import routes coworker-only CSV rows to saved shifts without creating events',
    (tester) async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final today = DateTime.now();
      final rosterMonth = today.month.toString().padLeft(2, '0');
      final rosterDay = today.day.toString().padLeft(2, '0');
      final rosterDate = '${today.year}-$rosterMonth-$rosterDay';
      final csv =
          'date,code,coworkers,coworker_codes\n'
          '$rosterDate,A1,Synthetic Coworker;Synthetic Bailey;Synthetic Casey,A1;A1;A1';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, (call) async {
            expect(call.method, 'openImport');
            return {
              'name': 'synthetic-coworkers.csv',
              'bytes': Uint8List.fromList(utf8.encode(csv)),
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(fileChannel, null);
      });

      final savedShift = ScheduleItem(
        id: 'synthetic-saved-a1-shift',
        kind: ScheduleKind.work,
        workCategory: WorkCategory.shift,
        title: 'Owner shift title',
        startDate: CivilDate(today.year, today.month, today.day),
        timeZoneId: 'America/Barbados',
        code: 'A1',
        employerName: 'Synthetic employer',
        intervals: [EventInterval.sameDay(startMinute: 360, endMinute: 540)],
      );
      await ScheduleRepository(database).save(savedShift);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scheduleDatabaseProvider.overrideWithValue(database),
            deviceTimeZoneIdProvider.overrideWith(
              (ref) async => 'America/Barbados',
            ),
          ],
          child: const MaterialApp(
            home: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smart Import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a file'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Document recognized'), findsOneWidget);
      expect(find.text('Employee roster'), findsOneWidget);
      expect(find.textContaining('Shift Legend · Coworkers'), findsOneWidget);
      expect(find.text('Update coworkers on matched shifts'), findsOneWidget);
      expect(find.textContaining('Found 2 saved sections'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Owner shift title'));
      expect(find.text('3 coworkers to add'), findsOneWidget);
      expect(find.text('Synthetic Coworker'), findsNothing);
      await tester.tap(
        find.ancestor(
          of: find.text('3 coworkers to add'),
          matching: find.byType(ExpansionTile),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Coworker'), findsOneWidget);
      expect(find.text('Synthetic Bailey'), findsOneWidget);
      expect(find.text('Synthetic Casey'), findsOneWidget);

      await tester.ensureVisible(find.text('Apply 1 selected'));
      await tester.tap(find.text('Apply 1 selected'));
      await tester.pumpAndSettle();
      final items = await ScheduleRepository(database).getItems();
      expect(items, hasLength(1));
      expect(items.single.id, savedShift.id);
      expect(items.single.title, savedShift.title);
      expect(items.single.intervals, savedShift.intervals);
      expect(items.single.coworkers, [
        'Synthetic Coworker',
        'Synthetic Bailey',
        'Synthetic Casey',
      ]);
    },
  );

  testWidgets('coworker-only CSV without individual codes starts unchecked', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final today = DateTime.now();
    final rosterMonth = today.month.toString().padLeft(2, '0');
    final rosterDay = today.day.toString().padLeft(2, '0');
    final rosterDate = '${today.year}-$rosterMonth-$rosterDay';
    final csv = 'date,code,coworkers\n$rosterDate,A1,Synthetic Same-Day Staff';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          return {
            'name': 'synthetic-unverified-coworkers.csv',
            'bytes': Uint8List.fromList(utf8.encode(csv)),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    final savedShift = ScheduleItem(
      id: 'synthetic-saved-a1-unverified-coworkers',
      kind: ScheduleKind.work,
      workCategory: WorkCategory.shift,
      title: 'Synthetic A1 shift',
      startDate: CivilDate(today.year, today.month, today.day),
      timeZoneId: 'America/Barbados',
      code: 'A1',
      employerName: 'Synthetic employer',
      intervals: [EventInterval.sameDay(startMinute: 360, endMinute: 540)],
    );
    await ScheduleRepository(database).save(savedShift);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('coworker codes are missing'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('coworker codes are missing'), findsOneWidget);
    await tester.ensureVisible(find.text(savedShift.title));
    final checkbox = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, savedShift.title),
    );
    expect(checkbox.value, isFalse);
    expect(
      (await ScheduleRepository(database).getItems()).single.coworkers,
      isEmpty,
    );
  });

  testWidgets(
    'coworker roster applies to every split interval with the same date and code',
    (tester) async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      const csv =
          'date,code,coworkers,coworker_codes\n'
          '2026-11-09,AL,Synthetic Coworker,AL';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, (call) async {
            expect(call.method, 'openImport');
            return {
              'name': 'synthetic-split-coworkers.csv',
              'bytes': Uint8List.fromList(utf8.encode(csv)),
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(fileChannel, null);
      });

      const date = CivilDate(2026, 11, 9);
      final morning = ScheduleItem(
        id: 'synthetic-al-morning',
        kind: ScheduleKind.work,
        workCategory: WorkCategory.shift,
        title: 'Synthetic AL split shift',
        startDate: date,
        timeZoneId: 'America/Barbados',
        code: 'AL',
        employerName: 'Synthetic employer',
        intervals: [EventInterval.sameDay(startMinute: 360, endMinute: 540)],
      );
      final afternoon = ScheduleItem(
        id: 'synthetic-al-afternoon',
        kind: ScheduleKind.work,
        workCategory: WorkCategory.shift,
        title: 'Synthetic AL split shift',
        startDate: date,
        timeZoneId: 'America/Barbados',
        code: 'AL',
        employerName: 'Synthetic employer',
        intervals: [EventInterval.sameDay(startMinute: 780, endMinute: 960)],
      );
      final repository = ScheduleRepository(database);
      await repository.save(morning);
      await repository.save(afternoon);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scheduleDatabaseProvider.overrideWithValue(database),
            deviceTimeZoneIdProvider.overrideWith(
              (ref) async => 'America/Barbados',
            ),
          ],
          child: const MaterialApp(
            home: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smart Import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a file'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Update coworkers on matched shifts'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.text('1 coworker to add'), findsNWidgets(2));
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(find.textContaining('Found 2 saved sections'), findsNothing);
      await tester.ensureVisible(find.text('Apply 2 selected'));
      await tester.tap(find.text('Apply 2 selected'));
      await tester.pumpAndSettle();

      final items = await repository.getItems();
      expect(items, hasLength(2));
      expect(items.map((item) => item.id).toSet(), {morning.id, afternoon.id});
      expect(items.map((item) => item.coworkers.single).toSet(), {
        'Synthetic Coworker',
      });
    },
  );

  testWidgets('keeps staged CSV rows while reviewing a roster table', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    const csv =
        'date,title,category,start,end,time_zone,employer,code,coworkers\n'
        '2026-11-24,Synthetic CSV shift,shift,09:00,17:00,America/Barbados,Synthetic employer,A1,Synthetic Lee';
    final dates = [
      for (var offset = 1; offset <= 3; offset++)
        DateTime.now().add(Duration(days: offset)),
    ];
    final columnLefts = [.16, .41, .66];
    final tokens = [
      for (var index = 0; index < dates.length; index++)
        {
          'text':
              '${dates[index].year}-${dates[index].month.toString().padLeft(2, '0')}-${dates[index].day.toString().padLeft(2, '0')}',
          'left': columnLefts[index],
          'top': .10,
          'right': columnLefts[index] + .08,
          'bottom': .12,
          'page': 0,
        },
      {
        'text': 'Synthetic staff row',
        'left': .02,
        'top': .20,
        'right': .12,
        'bottom': .22,
        'page': 0,
      },
      for (final entry in [('A1', .18), ('A1', .43), ('OFF', .68)])
        {
          'text': entry.$1,
          'left': entry.$2,
          'top': .20,
          'right': entry.$2 + .04,
          'bottom': .22,
          'page': 0,
        },
    ];
    expect(
      const RosterGridImportParser().detect([
        for (final token in tokens)
          OcrTextToken(
            text: token['text']! as String,
            left: token['left']! as double,
            top: token['top']! as double,
            right: token['right']! as double,
            bottom: token['bottom']! as double,
            page: token['page']! as int,
          ),
      ]).candidates,
      isNotEmpty,
    );
    var selectedFile = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          if (call.method == 'openImport' && selectedFile++ == 0) {
            return {
              'name': 'synthetic-first.csv',
              'bytes': Uint8List.fromList(utf8.encode(csv)),
            };
          }
          expect(call.method, 'openImport');

          return {
            'name': 'synthetic-second.pdf',
            'text': 'Synthetic scanned roster',
            'tokens': jsonEncode(tokens),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });
    await WorkCodeLegendRepository(database).save(
      const WorkCodeLegend(
        id: 'a1',
        code: 'A1',
        timeWindows: [WorkCodeTimeWindow(startMinute: 360, endMinute: 540)],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic CSV shift'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Synthetic CSV shift'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Add another file to this import'));
    await tester.tap(find.text('Add another file to this import'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic CSV shift'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('confirm-roster-dates')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-roster-dates')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('roster-staff-row-0')),
    );
    await tester.pumpAndSettle();
    await selectRosterStaffRow(tester, 'Synthetic staff row');
    await tester.scrollUntilVisible(
      find.text('Synthetic CSV shift'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Synthetic CSV shift'), findsOneWidget);
    await showBuildRosterReview(tester);
    await tester.tap(find.text('Build shift review'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Synthetic CSV shift'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Synthetic CSV shift'), findsOneWidget);
    expect(find.textContaining('A1'), findsWidgets);
    expect(find.text('Proposed events · 4 selected'), findsOneWidget);

    await tester.ensureVisible(find.text('Add 4 selected'));
    await tester.tap(find.text('Add 4 selected'));
    await tester.pumpAndSettle();
    final items = await ScheduleRepository(database).getItems();
    expect(items, hasLength(4));
    expect(items.map((item) => item.importProvenance!.sourceName).toSet(), {
      'synthetic-first.csv',
      'synthetic-second.pdf',
    });
  });

  testWidgets('exam timetable OCR requires review before saving', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final existingShift = ScheduleItem(
      id: 'synthetic-shift-similar-to-exam-ocr',
      kind: ScheduleKind.work,
      workCategory: WorkCategory.shift,
      title: 'Ramp shift with overlapping details',
      startDate: const CivilDate(2026, 12, 4),
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 660)],
      timeZoneId: 'America/Barbados',
      code: 'BIOL1100',
    );
    await ScheduleRepository(database).save(existingShift);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          return {'name': 'synthetic-exams.pdf', 'text': examOcrText};
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(find.text('Introductory Biology'), findsOneWidget);
    expect(find.textContaining(' · Examination'), findsOneWidget);
    expect(find.text('Course code: BIOL1100'), findsOneWidget);
    final beforeImport = await ScheduleRepository(database).getItems();
    expect(beforeImport, hasLength(1));
    expect(beforeImport.single.id, existingShift.id);
    await tester.ensureVisible(find.text('Add 1 selected'));
    await tester.tap(find.text('Add 1 selected'));
    await tester.pumpAndSettle();

    final imported = await ScheduleRepository(database).getItems();
    expect(imported, hasLength(2));
    expect(imported.first.id, existingShift.id);
    expect(imported.last.kind, ScheduleKind.deadline);
    expect(imported.last.deadlineType, DeadlineType.examination);
    expect(imported.last.code, 'BIOL1100');
    expect(imported.last.importProvenance!.sourceName, 'synthetic-exams.pdf');
  });

  testWidgets('duplicate exact exam OCR matches remain ambiguous', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    for (final suffix in ['one', 'two']) {
      await ScheduleRepository(database).save(
        ScheduleItem(
          id: 'synthetic-existing-exam-$suffix',
          kind: ScheduleKind.deadline,
          deadlineType: DeadlineType.examination,
          title: 'Introductory Biology',
          code: 'BIOL1100',
          startDate: const CivilDate(2026, 12, 4),
          intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 660)],
          timeZoneId: 'America/Barbados',
          importProvenance: ScheduleImportProvenance(
            format: 'exam-timetable-ocr',
            uid: 'synthetic-existing-exam-$suffix',
            sourceName: 'synthetic-previous-exams.pdf',
            sourceText: examOcrText,
            importedAt: DateTime.utc(2026, 11, 20),
          ),
        ),
      );
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          return {'name': 'synthetic-current-exams.pdf', 'text': examOcrText};
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Ambiguous match: multiple saved events match this import. Review before adding.',
      ),
      findsOneWidget,
    );
    final row = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile).first,
    );
    expect(row.value, isFalse);
    expect(row.onChanged, isNull);
    expect(find.text('Add 0 selected'), findsOneWidget);
    await tester.ensureVisible(find.text('Add 0 selected'));
    await tester.tap(find.text('Add 0 selected'));
    await tester.pumpAndSettle();
    expect(await ScheduleRepository(database).getItems(), hasLength(2));
  });

  testWidgets('general OCR does not match a saved shift by roster identity', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final existingShift = ScheduleItem(
      id: 'synthetic-shift-similar-to-general-ocr',
      kind: ScheduleKind.work,
      workCategory: WorkCategory.shift,
      title: 'BIOL1100 Different title',
      startDate: const CivilDate(2026, 12, 4),
      intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 660)],
      timeZoneId: 'America/Barbados',
      code: 'BIOL1100',
    );
    await ScheduleRepository(database).save(existingShift);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');

          return {
            'name': 'synthetic-general-ocr.pdf',
            'text': '2026-12-04 09:00 11:00 BIOL1100 Different title',
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose a file'));
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(find.text('BIOL1100 Different title'), findsOneWidget);
    expect(
      find.textContaining('Already saved with no schedule changes'),
      findsNothing,
    );
    expect(find.text('Add 1 selected'), findsOneWidget);
    expect(await ScheduleRepository(database).getItems(), hasLength(1));
    await tester.tap(find.text('Add 1 selected'));
    await tester.pumpAndSettle();

    final imported = await ScheduleRepository(database).getItems();
    expect(imported, hasLength(2));
    expect(imported.first.id, existingShift.id);
    expect(imported.last.kind, ScheduleKind.personal);
    expect(imported.last.title, 'BIOL1100 Different title');
  });

  testWidgets('canceling OCR privacy notice never opens the file picker', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    var ocrCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          if (call.method == 'extractSelectedOcr') ocrCalls++;
          if (call.method == 'openImport') {
            return {'name': 'synthetic.pdf', 'requiresOcr': true};
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Before using OCR'), findsOneWidget);
    expect(find.textContaining('technical diagnostics'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(ocrCalls, 0);
    expect(find.text('Before using OCR'), findsNothing);
  });

  testWidgets('full roster dates prefill the first-date confirmation', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final tokens = [
      for (final entry in [
        ('2026-11-30', .16),
        ('2026-12-01', .41),
        ('2026-12-02', .66),
      ])
        {
          'text': entry.$1,
          'left': entry.$2,
          'top': .10,
          'right': entry.$2 + .08,
          'bottom': .12,
          'page': 0,
        },
      {
        'text': 'Person One',
        'left': .02,
        'top': .20,
        'right': .13,
        'bottom': .22,
        'page': 0,
      },
      for (final entry in [('A1', .18), ('VS', .43), ('OFF', .68)])
        {
          'text': entry.$1,
          'left': entry.$2,
          'top': .20,
          'right': entry.$2 + .04,
          'bottom': .22,
          'page': 0,
        },
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          return {
            'name': 'synthetic-full-date-roster.pdf',
            'text': 'Synthetic roster table',
            'tokens': jsonEncode(tokens),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose a file'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('First roster date ·'), findsOneWidget);
    expect(
      find.text(
        'Detected dates · tap any date to correct it, then confirm the full sequence',
      ),
      findsOneWidget,
    );
    expect(find.text('Confirm roster dates'), findsOneWidget);
    await selectRosterStaffRow(tester, 'Person One');
    await tester.ensureVisible(
      find.byKey(const ValueKey('confirm-roster-dates')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Build shift review'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
      reason:
          'Shift drafts stay locked until every displayed date is reviewed.',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-roster-dates')));
    await tester.pumpAndSettle();
    expect(find.text('Dates confirmed'), findsOneWidget);
    await showBuildRosterReview(tester);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Build shift review'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNotNull,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('roster-date-column-2')),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, 120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('roster-date-column-2')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('3').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm roster dates'), findsOneWidget);
    await showBuildRosterReview(tester);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Build shift review'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
      reason: 'Changing any reviewed date must require confirmation again.',
    );
    expect(find.byKey(const ValueKey('roster-date-column-2')), findsOneWidget);
    expect(find.text('Build shift review'), findsOneWidget);
  });

  testWidgets('date-column corrections remain available after a bad mapping', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final tokens = [
      for (final entry in [
        ('2026-11-17', .16),
        ('2026-11-18', .41),
        ('2026-11-19', .66),
      ])
        {
          'text': entry.$1,
          'left': entry.$2,
          'top': .10,
          'right': entry.$2 + .08,
          'bottom': .12,
          'page': 0,
        },
      {
        'text': 'Person One',
        'left': .02,
        'top': .20,
        'right': .13,
        'bottom': .22,
        'page': 0,
      },
      for (final entry in [('A1', .18), ('VS', .43), ('OFF', .68)])
        {
          'text': entry.$1,
          'left': entry.$2,
          'top': .20,
          'right': entry.$2 + .04,
          'bottom': .22,
          'page': 0,
        },
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          return {
            'name': 'synthetic-date-correction-roster.pdf',
            'text': 'Synthetic roster table',
            'tokens': jsonEncode(tokens),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('roster-date-column-1')),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, 120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('roster-date-column-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('17').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Reviewed roster dates must be in increasing order without duplicates.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('roster-date-column-1')),
      findsOneWidget,
      reason: 'The invalid date sequence still needs a repair path.',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('roster-date-column-1')),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, 120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('roster-date-column-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('18').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Reviewed roster dates must be in increasing order without duplicates.',
      ),
      findsNothing,
      reason: 'Changing the bad column must recover the date sequence.',
    );
    expect(find.text('Confirm roster dates'), findsOneWidget);
    expect(await ScheduleRepository(database).getItems(), isEmpty);
  });

  testWidgets(
    'roster import previews and saves code definitions in the confirmed zone',
    (tester) async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final tokens = [
        for (final entry in [
          ('2026-11-17', .07),
          ('2026-11-18', .24),
          ('2026-11-19', .41),
        ])
          {
            'text': entry.$1,
            'left': entry.$2,
            'top': .10,
            'right': entry.$2 + .14,
            'bottom': .12,
            'page': 0,
          },
        {
          'text': 'Synthetic employee',
          'left': .01,
          'top': .20,
          'right': .05,
          'bottom': .22,
          'page': 0,
        },
        for (final entry in [('Q7', .12), ('OFF', .29), ('Q7', .46)])
          {
            'text': entry.$1,
            'left': entry.$2,
            'top': .20,
            'right': entry.$2 + .04,
            'bottom': .22,
            'page': 0,
          },
        {
          'text': 'SHIFT',
          'left': .64,
          'top': .30,
          'right': .68,
          'bottom': .31,
          'page': 0,
        },
        {
          'text': 'LEGEND',
          'left': .685,
          'top': .30,
          'right': .73,
          'bottom': .31,
          'page': 0,
        },
        {
          'text': 'Q7',
          'left': .642,
          'top': .34,
          'right': .662,
          'bottom': .35,
          'page': 0,
        },
        {
          'text': '0630-0930/1200-1600',
          'left': .67,
          'top': .34,
          'right': .78,
          'bottom': .35,
          'page': 0,
        },
        {
          'text': 'ZX1020;YK204;QW3601',
          'left': .80,
          'top': .34,
          'right': .96,
          'bottom': .35,
          'page': 0,
        },
      ];
      final grid = const RosterGridImportParser().detect([
        for (final token in tokens)
          OcrTextToken(
            text: token['text']! as String,
            left: (token['left']! as num).toDouble(),
            top: (token['top']! as num).toDouble(),
            right: (token['right']! as num).toDouble(),
            bottom: (token['bottom']! as num).toDouble(),
            page: token['page']! as int,
          ),
      ]);
      expect(grid.candidates, hasLength(1));
      expect(
        const RosterLegendImportParser().detect([
          for (final token in tokens)
            OcrTextToken(
              text: token['text']! as String,
              left: (token['left']! as num).toDouble(),
              top: (token['top']! as num).toDouble(),
              right: (token['right']! as num).toDouble(),
              bottom: (token['bottom']! as num).toDouble(),
              page: token['page']! as int,
            ),
        ]).definitions,
        hasLength(1),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, (call) async {
            expect(call.method, 'openImport');
            return {
              'name': 'synthetic-roster-with-legend.pdf',
              'text': 'Synthetic roster table',
              'tokens': jsonEncode(tokens),
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(fileChannel, null);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scheduleDatabaseProvider.overrideWithValue(database),
            deviceTimeZoneIdProvider.overrideWith(
              (ref) async => 'America/Halifax',
            ),
          ],
          child: const MaterialApp(
            home: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smart Import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a file'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('confirm-roster-dates')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-roster-dates')));
      await tester.pumpAndSettle();
      final rosterZone = find.byKey(const ValueKey('roster-time-zone'));
      expect(rosterZone, findsOneWidget);
      await tester.ensureVisible(rosterZone);
      await tester.enterText(rosterZone, 'America/Barbados');
      await tester.drag(
        find.byKey(const ValueKey('smart-import-list')),
        const Offset(0, 1200),
      );
      await tester.pumpAndSettle();
      final chooseFile = find.byKey(const ValueKey('smart-import-choose-file'));
      expect(chooseFile, findsOneWidget);
      await tester.ensureVisible(chooseFile);
      await tester.tap(chooseFile);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('confirm-roster-dates')),
      );
      await tester.tap(find.byKey(const ValueKey('confirm-roster-dates')));
      await tester.pumpAndSettle();
      final resetRosterZone = find.byKey(const ValueKey('roster-time-zone'));
      await tester.ensureVisible(resetRosterZone);
      final resetZoneText = tester.widget<EditableText>(
        find.descendant(
          of: resetRosterZone,
          matching: find.byType(EditableText),
        ),
      );
      expect(resetZoneText.controller.text, 'America/Halifax');
      await tester.enterText(resetRosterZone, 'America/Barbados');
      await tester.ensureVisible(
        find.byKey(const ValueKey('roster-staff-row-0')),
      );
      expect(find.text('Select your name in the roster'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('roster-coworker-scope')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('roster-staff-row-0')));
      await tester.pumpAndSettle();
      final staffSearch = find.byKey(const ValueKey('roster-staff-row-search'));
      expect(staffSearch, findsOneWidget);
      await tester.enterText(staffSearch, 'Synthetic employee');
      await tester.pumpAndSettle();
      final staffOption = find.byKey(const ValueKey('roster-staff-option-0'));
      expect(staffOption, findsOneWidget);
      await tester.tap(staffOption);
      await tester.pumpAndSettle();
      await showBuildRosterReview(tester);
      await tester.tap(find.text('Build shift review'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(
        find.text('Shift code definitions · 1'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data)
            .join(' | '),
      );
      expect(find.textContaining('ZX1020'), findsOneWidget);
      expect(find.textContaining('Q7'), findsWidgets);
      expect(find.byTooltip('Review or correct Q7'), findsOneWidget);
      await tester.tap(find.byTooltip('Review or correct Q7'));
      await tester.pumpAndSettle();
      expect(find.text('Review shift code'), findsOneWidget);
      expect(find.text('Use in import'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await WorkCodeLegendRepository(database).getItems(), isEmpty);
      await tester.ensureVisible(find.byTooltip('Review or correct Q7'));
      await tester.tap(find.byTooltip('Review or correct Q7'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Corrected Q7 duties',
      );
      await tester.tap(find.text('Use in import'));
      await tester.pumpAndSettle();
      expect(await WorkCodeLegendRepository(database).getItems(), isEmpty);
      final applyReviewedChanges = find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data?.startsWith('Apply ') ?? false),
      );
      await tester.ensureVisible(applyReviewedChanges);
      await tester.tap(applyReviewedChanges);
      await tester.pumpAndSettle();

      final savedLegends = await WorkCodeLegendRepository(database).getItems();
      expect(savedLegends, hasLength(1));
      expect(savedLegends.single.code, 'Q7');
      expect(savedLegends.single.assignmentDetails, 'Corrected Q7 duties');
      final saved = await ScheduleRepository(database).getItems();
      expect(saved, hasLength(3));
      expect(saved.where((item) => item.code == 'Q7'), hasLength(2));
      expect(
        saved.firstWhere((item) => item.code == 'Q7').title,
        'Corrected duties',
      );
      expect(saved.firstWhere((item) => item.code == 'Q7').intervals, [
        EventInterval.sameDay(startMinute: 390, endMinute: 570),
        EventInterval.sameDay(startMinute: 720, endMinute: 960),
      ]);
      expect(
        saved.firstWhere((item) => item.code == 'Q7').timeZoneId,
        'America/Barbados',
      );
    },
  );

  testWidgets(
    'roster OCR matches an existing shift despite a title difference',
    (tester) async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final today = DateTime.now();
      final nextDay = DateTime(today.year, today.month, today.day + 1);
      final followingDay = DateTime(today.year, today.month, today.day + 2);
      final tokens = [
        for (final entry in [
          (today.day, .20),
          (nextDay.day, .40),
          (followingDay.day, .60),
        ])
          {
            'text': '${entry.$1}',
            'left': entry.$2 - .02,
            'top': .10,
            'right': entry.$2 + .02,
            'bottom': .12,
            'page': 0,
          },
        {
          'text': 'Person One',
          'left': .02,
          'top': .20,
          'right': .12,
          'bottom': .22,
          'page': 0,
        },
        {
          'text': 'A1',
          'left': .18,
          'top': .20,
          'right': .22,
          'bottom': .22,
          'page': 0,
        },
        {
          'text': 'Synthetic Coworker',
          'left': .02,
          'top': .28,
          'right': .14,
          'bottom': .30,
          'page': 0,
        },
        {
          'text': 'A1',
          'left': .18,
          'top': .28,
          'right': .22,
          'bottom': .30,
          'page': 0,
        },
        {
          'text': 'UNMAPPED',
          'left': .38,
          'top': .20,
          'right': .42,
          'bottom': .22,
          'page': 0,
        },
        {
          'text': 'OFF',
          'left': .58,
          'top': .20,
          'right': .62,
          'bottom': .22,
          'page': 0,
        },
      ];
      final detectedTable = const RosterGridImportParser()
          .detect([
            for (final token in tokens)
              OcrTextToken(
                text: token['text']! as String,
                left: token['left']! as double,
                top: token['top']! as double,
                right: token['right']! as double,
                bottom: token['bottom']! as double,
              ),
          ])
          .candidates
          .single;
      expect(
        const RosterGridImportParser().coworkersForCell(
          detectedTable,
          selectedRow: 0,
          columnIndex: 0,
          code: 'A1',
          legends: const [
            WorkCodeLegend(
              id: 'a1',
              code: 'A1',
              employer: 'Synthetic employer',
              startMinute: 360,
              endMinute: 540,
            ),
          ],
        ),
        ['Synthetic Coworker'],
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, (call) async {
            expect(call.method, 'openImport');

            return {
              'name': 'synthetic-roster.pdf',
              'text': 'Synthetic roster table',
              'tokens': jsonEncode(tokens),
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(fileChannel, null);
      });
      await WorkCodeLegendRepository(database).save(
        const WorkCodeLegend(
          id: 'a1',
          code: 'A1',
          employer: 'Synthetic employer',
          startMinute: 360,
          endMinute: 540,
        ),
      );
      final existingShift = ScheduleItem(
        id: 'synthetic-owner-shift-before-roster-import',
        kind: ScheduleKind.work,
        workCategory: WorkCategory.shift,
        title: 'Owner entered ramp duty',
        startDate: () {
          final previousWeek = DateTime(
            today.year,
            today.month,
            today.day,
          ).subtract(const Duration(days: 7));
          return CivilDate(
            previousWeek.year,
            previousWeek.month,
            previousWeek.day,
          );
        }(),
        timeZoneId: 'America/Barbados',
        code: 'A1',
        employerName: 'Synthetic employer',
        intervals: [EventInterval.sameDay(startMinute: 390, endMinute: 570)],
        recurrence: WeeklyRecurrence(
          weekdays: {today.weekday},
          until: CivilDate(today.year, today.month, today.day).addDays(30),
        ),
      );
      await ScheduleRepository(database).save(existingShift);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scheduleDatabaseProvider.overrideWithValue(database),
            deviceTimeZoneIdProvider.overrideWith(
              (ref) async => 'America/Barbados',
            ),
          ],
          child: const MaterialApp(
            home: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smart Import'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose a file'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('roster-first-date')),
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, 120));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('roster-first-date')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Choose first date'), findsNothing);
      expect(
        find.text(
          'Detected dates · tap any date to correct it, then confirm the full sequence',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          MaterialLocalizations.of(
            tester.element(find.text('Build shift review')),
          ).formatMediumDate(today),
        ),
        findsWidgets,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('confirm-roster-dates')),
      );
      await tester.tap(find.byKey(const ValueKey('confirm-roster-dates')));
      await tester.pumpAndSettle();
      await selectRosterStaffRow(tester, 'Person One');
      await tester.ensureVisible(
        find.byKey(const ValueKey('roster-staff-row-0')),
      );
      final staffRowButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('roster-staff-row-0')),
      );
      expect(staffRowButton.onPressed, isNotNull);
      expect(find.text('Person One'), findsOneWidget);
      final buildAction = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Build shift review'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(buildAction.onPressed, isNotNull);
      await tester.tap(
        find.ancestor(
          of: find.text('Build shift review'),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('smart-import-list')),
        const Offset(0, 700),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Document recognized'));
      expect(find.text('Employee roster'), findsOneWidget);
      expect(find.textContaining('My Work Schedule'), findsOneWidget);
      expect(find.textContaining('Shift Legend · Coworkers'), findsOneWidget);
      expect(
        find.text('Add new entries and update matched coworkers'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('1 coworker to add'),
        240,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('smart-import-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Shift code: A1'), findsOneWidget);
      expect(find.text('Day off'), findsOneWidget);
      expect(find.text('1 coworker to add'), findsOneWidget);
      await tester.tap(
        find.ancestor(
          of: find.text('1 coworker to add'),
          matching: find.byType(ExpansionTile),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Coworker'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Codes to review · 1'),
        240,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('smart-import-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Codes to review · 1'), findsOneWidget);
      expect(find.textContaining('UNMAPPED'), findsOneWidget);
      final saved = await ScheduleRepository(database).getItems();
      expect(saved, hasLength(1));
      expect(saved.single.id, existingShift.id);
      expect(saved.single.title, 'Owner entered ramp duty');

      await tester.tap(find.byIcon(Icons.playlist_add_check_rounded));
      await tester.pump();
      expect(
        find.text(
          'Added 1, replaced 0, skipped 0. Updated coworkers for 1 saved shift entry.',
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      final applied = await ScheduleRepository(database).getItems();
      final retainedShift = applied.singleWhere(
        (item) => item.id == existingShift.id,
      );
      expect(applied, hasLength(2));
      expect(retainedShift.title, existingShift.title);
      expect(retainedShift.intervals, existingShift.intervals);
      expect(retainedShift.coworkers, isEmpty);
      final occurrenceCoworkers =
          await WorkOccurrenceCoworkerRepository(database).getForOccurrence(
            retainedShift.id,
            CivilDate(today.year, today.month, today.day),
          );
      expect(occurrenceCoworkers?.coworkers, ['Synthetic Coworker']);
    },
  );

  testWidgets('ambiguous roster shift matches stay unselected', (tester) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final today = DateTime.now();
    final nextDay = DateTime(today.year, today.month, today.day + 1);
    final followingDay = DateTime(today.year, today.month, today.day + 2);
    final tokens = [
      for (final entry in [
        (today.day, .20),
        (nextDay.day, .40),
        (followingDay.day, .60),
      ])
        {
          'text': '${entry.$1}',
          'left': entry.$2 - .02,
          'top': .10,
          'right': entry.$2 + .02,
          'bottom': .12,
          'page': 0,
        },
      {
        'text': 'Person One',
        'left': .02,
        'top': .20,
        'right': .12,
        'bottom': .22,
        'page': 0,
      },
      {
        'text': 'A1',
        'left': .18,
        'top': .20,
        'right': .22,
        'bottom': .22,
        'page': 0,
      },
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');

          return {
            'name': 'synthetic-ambiguous-roster.pdf',
            'text': 'Synthetic roster table',
            'tokens': jsonEncode(tokens),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });
    await WorkCodeLegendRepository(database).save(
      const WorkCodeLegend(
        id: 'a1',
        code: 'A1',
        employer: 'Synthetic employer',
        startMinute: 360,
        endMinute: 540,
      ),
    );
    for (final date in [
      CivilDate(today.year, today.month, today.day),
      CivilDate(nextDay.year, nextDay.month, nextDay.day),
      CivilDate(followingDay.year, followingDay.month, followingDay.day),
    ]) {
      for (final suffix in ['one', 'two']) {
        await ScheduleRepository(database).save(
          ScheduleItem(
            id: 'synthetic-duplicate-shift-$date-$suffix',
            kind: ScheduleKind.work,
            workCategory: WorkCategory.shift,
            title: 'Saved shift $suffix',
            startDate: date,
            timeZoneId: 'America/Barbados',
            code: 'A1',
            employerName: 'Synthetic employer',
            intervals: [
              EventInterval.sameDay(startMinute: 360, endMinute: 540),
            ],
          ),
        );
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('roster-first-date')));
    await tester.drag(find.byType(ListView).first, const Offset(0, 120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('roster-first-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('confirm-roster-dates')),
    );
    await tester.tap(find.byKey(const ValueKey('confirm-roster-dates')));
    await tester.pumpAndSettle();
    await selectRosterStaffRow(tester, 'Person One');
    await showBuildRosterReview(tester);
    await tester.tap(find.text('Build shift review'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Ambiguous match: multiple saved events match this import. Review before adding.',
      ),
      findsOneWidget,
    );
    final row = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile).first,
    );
    expect(row.value, isFalse);
    expect(row.onChanged, isNull);
    row.onChanged?.call(true);
    await tester.pumpAndSettle();
    expect(find.text('Add 0 selected'), findsOneWidget);
    expect(await ScheduleRepository(database).getItems(), hasLength(6));
  });

  testWidgets('OCR reimport under a new filename is flagged and unchecked', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    var openCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          openCount++;
          return {
            'name': openCount == 1
                ? 'synthetic-exams.pdf'
                : 'renamed-exams.pdf',
            'text': examOcrText,
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add 1 selected'));
    await tester.tap(find.text('Add 1 selected'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Already saved with no schedule changes'),
      findsOneWidget,
    );
    expect(find.text('Add 0 selected'), findsOneWidget);
    expect(await ScheduleRepository(database).getItems(), hasLength(1));
  });

  testWidgets('OCR reimport matches a previously saved legacy ID', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await ScheduleRepository(database).save(
      ScheduleItem(
        id: 'legacy-filename-derived-ocr-id',
        kind: ScheduleKind.deadline,
        deadlineType: DeadlineType.examination,
        title: 'Introductory Biology',
        code: 'BIOL1100',
        startDate: const CivilDate(2026, 12, 4),
        intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 660)],
        timeZoneId: 'America/Barbados',
        importProvenance: ScheduleImportProvenance(
          format: 'exam-timetable-ocr',
          uid: 'legacy-line-0-hash',
          sourceName: 'original-exams.pdf',
          sourceText: examOcrText,
          importedAt: DateTime.utc(2026, 11, 8),
        ),
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          return {'name': 'renamed-exams.pdf', 'text': examOcrText};
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Already saved with no schedule changes'),
      findsOneWidget,
    );
    expect(find.text('Add 0 selected'), findsOneWidget);
    expect(await ScheduleRepository(database).getItems(), hasLength(1));
  });

  testWidgets('reviewing an imported weekly event preserves its recurrence', (
    tester,
  ) async {
    const weekly = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Shift Study Test//EN
BEGIN:VEVENT
DTSTAMP:20261106T120000Z
UID:weekly-review@example.test
DTSTART;TZID=America/Barbados:20261109T090000
DTEND;TZID=America/Barbados:20261109T100000
RRULE:FREQ=WEEKLY;BYDAY=MO,WE;COUNT=6
EXDATE;TZID=America/Barbados:20261111T090000
SUMMARY:Weekly review class
END:VEVENT
END:VCALENDAR''';
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          return {
            'name': 'weekly-review.ics',
            'bytes': Uint8List.fromList(utf8.encode(weekly)),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(find.textContaining('Repeats weekly on Mon, Wed'), findsOneWidget);
    expect(await ScheduleRepository(database).getItems(), isEmpty);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review or correct'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Repeat pattern'), findsOneWidget);
    await tester.ensureVisible(find.text('Save review'));
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add 1 selected'));
    await tester.tap(find.text('Add 1 selected'));
    await tester.pumpAndSettle();
    final saved = (await ScheduleRepository(database).getItems()).single;
    expect(saved.recurrence?.weekdays, {DateTime.monday, DateTime.wednesday});
    expect(saved.recurrence?.until, CivilDate(2026, 11, 25));
    expect(saved.recurrence?.exceptionDates, {CivilDate(2026, 11, 11)});
  });

  testWidgets('CSV import previews and saves only after confirmation', (
    tester,
  ) async {
    const csv = '''date,title,category,start,end,time_zone,location
2026-11-10,Chemistry lecture,class,09:00,10:00,America/Barbados,Science 101
''';
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          return {
            'name': 'classes.csv',
            'bytes': Uint8List.fromList(utf8.encode(csv)),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(find.text('Chemistry lecture'), findsOneWidget);
    expect(find.textContaining('classes.csv'), findsOneWidget);
    expect(await ScheduleRepository(database).getItems(), isEmpty);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 1 selected'));
    await tester.pumpAndSettle();

    final items = await ScheduleRepository(database).getItems();
    expect(items, hasLength(1));
    expect(items.single.kind, ScheduleKind.classSession);
    expect(items.single.title, 'Chemistry lecture');
    expect(items.single.startDate, CivilDate(2026, 11, 10));
    expect(items.single.intervals.single.startMinute, 9 * 60);
    expect(items.single.location, 'Science 101');
    expect(items.single.importProvenance!.format, 'Shift & Study CSV v1');
    expect(items.single.importProvenance!.sourceName, 'classes.csv');

    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Already saved with no schedule changes'),
      findsOneWidget,
    );
    expect(find.text('Proposed events · 0 selected'), findsOneWidget);
    expect(
      (await ScheduleRepository(database).getItems()).single.title,
      'Chemistry lecture',
    );
  });

  testWidgets(
    'roster day off with a new source ID is matched to the saved day',
    (tester) async {
      var csv = '''source_id,date,title,category,code,employer,notes
roster-first,2026-11-17,CAH - Day off,day_off,X,,New roster
''';
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, (call) async {
            expect(call.method, 'openImport');
            return {
              'name': 'roster.csv',
              'bytes': Uint8List.fromList(utf8.encode(csv)),
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(fileChannel, null);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scheduleDatabaseProvider.overrideWithValue(database),
            deviceTimeZoneIdProvider.overrideWith(
              (ref) async => 'America/Barbados',
            ),
          ],
          child: const MaterialApp(
            home: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> openAndReviewRoster() async {
        await tester.tap(find.text('Smart Import'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose a file'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -800));
        await tester.pumpAndSettle();
      }

      await openAndReviewRoster();
      await tester.ensureVisible(find.text('Add 1 selected'));
      await tester.tap(find.text('Add 1 selected'));
      await tester.pumpAndSettle();
      final original = (await ScheduleRepository(database).getItems()).single;
      expect(original.employerName, isNull);

      csv = '''source_id,date,title,category,code,employer,notes
roster-revised,2026-11-17,CAH - Day off,day_off,X,CAH,New roster
''';
      await openAndReviewRoster();

      expect(find.text('Proposed events · 0 selected'), findsOneWidget);
      expect(
        find.textContaining('Changed since saved: employer'),
        findsOneWidget,
      );
      expect(
        (await ScheduleRepository(database).getItems()).single.employerName,
        isNull,
      );

      await tester.tap(find.byType(CheckboxListTile).last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add 1 selected'));
      await tester.tap(find.text('Add 1 selected'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace matching'));
      await tester.pumpAndSettle();

      final replaced = await ScheduleRepository(database).getItems();
      expect(replaced, hasLength(1));
      expect(replaced.single.id, original.id);
      expect(replaced.single.employerName, 'CAH');
    },
  );

  testWidgets('work CSV details can be corrected before they are saved', (
    tester,
  ) async {
    const csv = '''date,title,category,start,end,time_zone,employer,code,reporting_instruction,supervisor_name,supervisor_phone,contact_name,contact_phone
2026-11-10,Sample work shift,shift,21:00,05:00,America/Barbados,Synthetic Employer,S1,Original reporting text,Synthetic supervisor,+1 246 555 0100,Synthetic operations desk,+1 246 555 0101
''';
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await WorkCodeLegendRepository(database).save(
      const WorkCodeLegend(
        id: 'synthetic-import-legend',
        employer: 'Synthetic Employer',
        code: 'S1',
        meaning: 'Legend-derived synthetic duty',
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          return {
            'name': 'sample-work.csv',
            'bytes': Uint8List.fromList(utf8.encode(csv)),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('Sample work shift'), findsOneWidget);
    expect(await ScheduleRepository(database).getItems(), isEmpty);

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review or correct'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('import-event-code')));
    await tester.enterText(
      find.byKey(const ValueKey('import-event-code')),
      'SYNTH-2',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('import-code-meaning')),
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('import-code-meaning')),
          )
          .controller!
          .text,
      'Legend-derived synthetic duty',
    );
    await tester.enterText(
      find.byKey(const ValueKey('import-code-meaning')),
      'Corrected sample meaning',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('import-reporting-instruction')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('import-reporting-instruction')),
      'Corrected reporting text',
    );
    for (final (key, value) in [
      ('import-supervisor-name', 'Corrected synthetic supervisor'),
      ('import-supervisor-phone', '+1 246 555 0102'),
      ('import-contact-name', 'Corrected synthetic desk'),
      ('import-contact-phone', '+1 246 555 0103'),
    ]) {
      final field = find.byKey(ValueKey(key));
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }
    await tester.ensureVisible(find.text('Save review'));
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 1 selected'));
    await tester.pumpAndSettle();

    final saved = (await ScheduleRepository(database).getItems()).single;
    expect(saved.code, 'SYNTH-2');
    expect(saved.codeMeaning, 'Corrected sample meaning');
    expect(saved.reportingInstruction, 'Corrected reporting text');
    expect(saved.supervisorName, 'Corrected synthetic supervisor');
    expect(saved.supervisorPhone, '+1 246 555 0102');
    expect(saved.contactName, 'Corrected synthetic desk');
    expect(saved.contactPhone, '+1 246 555 0103');
    expect(saved.intervals.single.endDayOffset, 1);
  });

  testWidgets(
    'changed CSV source rows are compared and replace only on confirmation',
    (tester) async {
      const oldCsv = '''source_id,date,title,category,start,end,time_zone
WORK-001,2026-11-10,Sample work shift,shift,09:00,17:00,America/Barbados
''';
      const updatedCsv = '''source_id,date,title,category,start,end,time_zone
WORK-001,2026-11-11,Sample work shift revised,shift,10:00,18:00,America/Barbados
''';
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final original = (await const CsvScheduleImportParser().parse(
        oldCsv,
        sourceName: 'roster.csv',
      )).proposals.single.item;
      await ScheduleRepository(database).save(original);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, (call) async {
            expect(call.method, 'openImport');
            return {
              'name': 'roster.csv',
              'bytes': Uint8List.fromList(utf8.encode(updatedCsv)),
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(fileChannel, null);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scheduleDatabaseProvider.overrideWithValue(database),
            deviceTimeZoneIdProvider.overrideWith(
              (ref) async => 'America/Barbados',
            ),
          ],
          child: const MaterialApp(
            home: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smart Import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a file'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();

      expect(find.text('Sample work shift revised'), findsOneWidget);
      expect(
        find.textContaining('Changed since saved: title, date, time'),
        findsOneWidget,
      );
      expect(
        (await ScheduleRepository(database).getItems()).single.title,
        'Sample work shift',
      );

      await tester.tap(find.byType(CheckboxListTile).last);
      await tester.pumpAndSettle();
      expect(find.text('Proposed events · 1 selected'), findsOneWidget);
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text('Replace matching saved events'),
          matching: find.byType(SwitchListTile),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Proposed events · 1 selected'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add 1 selected'));
      await tester.pumpAndSettle();
      expect(find.text('Replace saved events?'), findsOneWidget);
      expect(
        (await ScheduleRepository(database).getItems()).single.title,
        'Sample work shift',
      );
      await tester.tap(find.text('Replace matching'));
      await tester.pumpAndSettle();

      final replaced = await ScheduleRepository(database).getItems();
      expect(replaced, hasLength(1));
      expect(replaced.single.id, original.id);
      expect(replaced.single.title, 'Sample work shift revised');
      expect(replaced.single.startDate, CivilDate(2026, 11, 11));
      expect(replaced.single.intervals.single.startMinute, 10 * 60);
    },
  );

  testWidgets('CSV split intervals stay together during review and save', (
    tester,
  ) async {
    const csv = '''source_id,date,title,category,start,end,time_zone
WORK-SPLIT-7,2026-11-10,Sample work shift,shift,09:00,12:00,America/Barbados
WORK-SPLIT-7,2026-11-10,Sample work shift,shift,14:00,18:00,America/Barbados
''';
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          return {
            'name': 'split-roster.csv',
            'bytes': Uint8List.fromList(utf8.encode(csv)),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('9:00 AM – 12:00 PM · 2:00 PM – 6:00 PM'),
      findsOneWidget,
    );
    expect(await ScheduleRepository(database).getItems(), isEmpty);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 1 selected'));
    await tester.pumpAndSettle();

    final imported = await ScheduleRepository(database).getItems();
    expect(imported, hasLength(1));
    expect(imported.single.intervals, hasLength(2));
    expect(imported.single.intervals[0].startMinute, 9 * 60);
    expect(imported.single.intervals[0].endMinute, 12 * 60);
    expect(imported.single.intervals[1].startMinute, 14 * 60);
    expect(imported.single.intervals[1].endMinute, 18 * 60);
  });

  testWidgets('alternate roster headings can be mapped before review', (
    tester,
  ) async {
    const csv = '''Work day,Duty name,Duty type,Clock in,Clock out,Zone,Roster,Supervisor,Supervisor phone,Contact,Contact phone
2026-11-18,Synthetic ramp shift,shift,10:00,17:00,America/Barbados,AC,Synthetic supervisor,+12465550100,Synthetic desk,+12465550101
''';
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          return {
            'name': 'synthetic-roster.csv',
            'bytes': Uint8List.fromList(utf8.encode(csv)),
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Match your roster columns'), findsOneWidget);
    expect(await ScheduleRepository(database).getItems(), isEmpty);

    Future<void> choose(String field, String header) async {
      await tester.drag(find.byType(ListView).first, const Offset(0, -650));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(ValueKey('column-map-$field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('column-map-$field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(header).last);
      await tester.pumpAndSettle();
    }

    await choose('date', 'Work day');
    await choose('title', 'Duty name');
    await choose('category', 'Duty type');
    await tester.ensureVisible(find.text('Optional fields'));
    await tester.tap(find.text('Optional fields'));
    await tester.pumpAndSettle();
    await choose('start', 'Clock in');
    await choose('end', 'Clock out');
    await choose('time_zone', 'Zone');
    await choose('code', 'Roster');
    await choose('supervisor_name', 'Supervisor');
    await choose('supervisor_phone', 'Supervisor phone');
    await choose('contact_name', 'Contact');
    await choose('contact_phone', 'Contact phone');
    await tester.ensureVisible(find.text('Match columns and preview'));
    await tester.tap(find.text('Match columns and preview'));
    await tester.pumpAndSettle();

    expect(find.text('Synthetic ramp shift'), findsOneWidget);
    expect(await ScheduleRepository(database).getItems(), isEmpty);
    await tester.ensureVisible(find.text('Add 1 selected'));
    await tester.tap(find.text('Add 1 selected'));
    await tester.pumpAndSettle();
    final saved = (await ScheduleRepository(database).getItems()).single;
    expect(saved.code, 'AC');
    expect(saved.supervisorName, 'Synthetic supervisor');
    expect(saved.supervisorPhone, '+12465550100');
    expect(saved.contactName, 'Synthetic desk');
    expect(saved.contactPhone, '+12465550101');
    expect(saved.importProvenance!.sourceName, 'synthetic-roster.csv');
  });

  testWidgets('a roster code is not used as the imported shift title', (
    tester,
  ) async {
    const csv =
        '''date,title,category,start,end,time_zone,employer,code,code_meaning
2026-11-24,AV - Passenger ramp operations,shift,10:00,17:00,America/Barbados,Synthetic Airport,AV,Passenger ramp operations
''';
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          return {
            'name': 'synthetic-code-title.csv',
            'bytes': Uint8List.fromList(utf8.encode(csv)),
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('Passenger ramp operations'), findsOneWidget);
    expect(find.text('AV'), findsNothing);
    expect(await ScheduleRepository(database).getItems(), isEmpty);
  });

  testWidgets(
    'Smart Import previews and saves explicitly grouped supervisors',
    (tester) async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      const rosterText = '''
Permanent Supervisors:
Synthetic Permanent Lead
Acting Supervisors:
Synthetic Acting Lead
Employees:
Synthetic Ramp Agent
''';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, (call) async {
            expect(call.method, 'openImport');
            return {
              'name': 'synthetic-supervisor-roster.pdf',
              'text': rosterText,
              'tokens': jsonEncode(const <Map<String, Object>>[]),
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(fileChannel, null),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scheduleDatabaseProvider.overrideWithValue(database),
            deviceTimeZoneIdProvider.overrideWith(
              (ref) async => 'America/Barbados',
            ),
          ],
          child: const MaterialApp(
            home: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smart Import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a file'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -800));
      await tester.pumpAndSettle();

      expect(
        find.text('Supervisor profiles · 2'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data)
            .join(' | '),
      );
      expect(find.text('Synthetic Permanent Lead'), findsOneWidget);
      expect(find.text('Synthetic Acting Lead'), findsOneWidget);
      expect(find.text('Synthetic Ramp Agent'), findsNothing);
      expect(await SupervisorRepository(database).getItems(), isEmpty);

      await tester.ensureVisible(find.text('Apply 2 selected'));
      await tester.tap(find.text('Apply 2 selected'));
      await tester.pumpAndSettle();
      final profiles = await SupervisorRepository(database).getItems();
      expect(profiles.map((profile) => (profile.name, profile.type)).toList(), [
        ('Synthetic Permanent Lead', SupervisorType.permanent),
        ('Synthetic Acting Lead', SupervisorType.acting),
      ]);
      expect(await ScheduleRepository(database).getItems(), isEmpty);
    },
  );

  testWidgets(
    'unlabelled roster staff need a reviewed role before becoming supervisors',
    (tester) async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      const csv =
          'Employee,Nov 23 2026,Nov 24 2026,Nov 25 2026\n'
          'Synthetic Agent,A1,A1,OFF\n'
          'Synthetic Acting Lead,OFF,VA,VA\n';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, (call) async {
            expect(call.method, 'openImport');
            return {
              'name': 'synthetic-unlabelled-roster.csv',
              'bytes': Uint8List.fromList(utf8.encode(csv)),
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(fileChannel, null),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scheduleDatabaseProvider.overrideWithValue(database),
            deviceTimeZoneIdProvider.overrideWith(
              (ref) async => 'America/Barbados',
            ),
          ],
          child: const MaterialApp(
            home: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smart Import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a file'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(await SupervisorRepository(database).getItems(), isEmpty);
      await tester.drag(find.byType(ListView).first, const Offset(0, -800));
      await tester.pumpAndSettle();
      final assignSupervisorRoles = find.text(
        'Assign supervisor roles from this roster',
      );
      await tester.scrollUntilVisible(
        assignSupervisorRoles,
        180,
        scrollable: find
            .ancestor(
              of: assignSupervisorRoles,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Assign supervisor roles from this roster'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('roster-supervisor-staff')),
      );
      await tester.tap(find.byKey(const ValueKey('roster-supervisor-staff')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic Acting Lead').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('roster-supervisor-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acting supervisor').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-roster-supervisor')));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Acting Lead'), findsOneWidget);
      expect(await SupervisorRepository(database).getItems(), isEmpty);

      await tester.ensureVisible(find.text('Apply 1 selected'));
      await tester.tap(find.text('Apply 1 selected'));
      await tester.pumpAndSettle();
      final profiles = await SupervisorRepository(database).getItems();
      expect(profiles, hasLength(1));
      expect(profiles.single.name, 'Synthetic Acting Lead');
      expect(profiles.single.type, SupervisorType.acting);
      expect(await ScheduleRepository(database).getItems(), isEmpty);
    },
  );

  testWidgets(
    'CSV roster reimport matches a saved shift by date code and time',
    (tester) async {
      const csv = '''date,title,category,start,end,time_zone,employer,code
2026-11-24,AV roster entry,shift,12:30,20:30,America/Barbados,CAH,AV
''';
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final existing = ScheduleItem(
        id: 'saved-shift-av-2026-11-24',
        kind: ScheduleKind.work,
        workCategory: WorkCategory.shift,
        title: 'CAH Ramp shift',
        startDate: const CivilDate(2026, 11, 24),
        intervals: [EventInterval.sameDay(startMinute: 750, endMinute: 1230)],
        timeZoneId: 'America/Barbados',
        employerName: 'CAH',
        code: 'AV',
      );
      await ScheduleRepository(database).save(existing);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, (call) async {
            expect(call.method, 'openImport');
            return {
              'name': 'updated-roster.csv',
              'bytes': Uint8List.fromList(utf8.encode(csv)),
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(fileChannel, null);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scheduleDatabaseProvider.overrideWithValue(database),
            deviceTimeZoneIdProvider.overrideWith(
              (ref) async => 'America/Barbados',
            ),
          ],
          child: const MaterialApp(
            home: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smart Import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a file'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();

      expect(find.text('Proposed events · 0 selected'), findsOneWidget);
      expect(find.textContaining('Changed since saved: title'), findsOneWidget);
      expect(await ScheduleRepository(database).getItems(), hasLength(1));
    },
  );

  testWidgets('ambiguous CSV shift matches stay unselected', (tester) async {
    const csv = '''date,title,category,start,end,time_zone,employer,code
2026-11-24,AV roster entry,shift,12:30,20:30,America/Barbados,CAH,AV
''';
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    for (final id in ['saved-shift-av-a', 'saved-shift-av-b']) {
      await ScheduleRepository(database).save(
        ScheduleItem(
          id: id,
          kind: ScheduleKind.work,
          workCategory: WorkCategory.shift,
          title: 'CAH Ramp shift',
          startDate: const CivilDate(2026, 11, 24),
          intervals: [EventInterval.sameDay(startMinute: 750, endMinute: 1230)],
          timeZoneId: 'America/Barbados',
          employerName: 'CAH',
          code: 'AV',
        ),
      );
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openImport');
          return {
            'name': 'updated-roster.csv',
            'bytes': Uint8List.fromList(utf8.encode(csv)),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileChannel, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDatabaseProvider.overrideWithValue(database),
          deviceTimeZoneIdProvider.overrideWith(
            (ref) async => 'America/Barbados',
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(mode: ScheduleMode.workAndSchool),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Ambiguous match: multiple saved events'),
      findsOneWidget,
    );
    expect(find.text('Proposed events · 0 selected'), findsOneWidget);
    expect(await ScheduleRepository(database).getItems(), hasLength(2));
  });
}
