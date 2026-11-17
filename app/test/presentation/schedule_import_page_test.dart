import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/data/work_code_legend_repository.dart';
import 'package:shift_study/data/csv_schedule_import.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/work_code_legend.dart';
import 'package:shift_study/presentation/screens/settings_page.dart';

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

  testWidgets('calendar import previews and saves only reviewed events', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openCalendar');
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
    await tester.tap(find.text('Import calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSV and Excel file format'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('code_meaning, reporting_instruction'),
      findsOneWidget,
    );
    expect(find.textContaining('department,job_role'), findsOneWidget);
    expect(find.textContaining('SYNTH-001'), findsOneWidget);
    await tester.tap(find.text('CSV and Excel file format'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose .ics, .csv or .xlsx file'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
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

  testWidgets('exam timetable OCR requires review before saving', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openOcrImport');
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
    await tester.tap(find.text('Import calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read an exam timetable'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(find.text('Introductory Biology'), findsOneWidget);
    expect(find.textContaining(' · Examination'), findsOneWidget);
    expect(find.text('Course code: BIOL1100'), findsOneWidget);
    expect(await ScheduleRepository(database).getItems(), isEmpty);
    await tester.ensureVisible(find.text('Add 1 selected'));
    await tester.tap(find.text('Add 1 selected'));
    await tester.pumpAndSettle();

    final imported = await ScheduleRepository(database).getItems();
    expect(imported, hasLength(1));
    expect(imported.single.kind, ScheduleKind.deadline);
    expect(imported.single.deadlineType, DeadlineType.examination);
    expect(imported.single.code, 'BIOL1100');
    expect(imported.single.importProvenance!.sourceName, 'synthetic-exams.pdf');
  });

  testWidgets('OCR reimport under a new filename is flagged and unchecked', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    var openCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fileChannel, (call) async {
          expect(call.method, 'openOcrImport');
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

    await tester.tap(find.text('Import calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read an exam timetable'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add 1 selected'));
    await tester.tap(find.text('Add 1 selected'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read an exam timetable'));
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
          expect(call.method, 'openOcrImport');
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
    await tester.tap(find.text('Import calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read an exam timetable'));
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
          expect(call.method, 'openCalendar');
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
    await tester.tap(find.text('Import calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose .ics, .csv or .xlsx file'));
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
          expect(call.method, 'openCalendar');
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
    await tester.tap(find.text('Import calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose .ics, .csv or .xlsx file'));
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

    await tester.tap(find.text('Import calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose .ics, .csv or .xlsx file'));
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
          expect(call.method, 'openCalendar');
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
    await tester.tap(find.text('Import calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose .ics, .csv or .xlsx file'));
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
            expect(call.method, 'openCalendar');
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
      await tester.tap(find.text('Import calendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose .ics, .csv or .xlsx file'));
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
          expect(call.method, 'openCalendar');
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
    await tester.tap(find.text('Import calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose .ics, .csv or .xlsx file'));
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
}
