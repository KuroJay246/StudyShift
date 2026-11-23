import 'dart:convert';

import 'package:archive/archive.dart';
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
    await tester.tap(find.text('Choose coworker roster file'));
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

  testWidgets('imports Excel coworker rows without creating schedule events', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = ScheduleRepository(database);
    final original = ScheduleItem(
      id: 'existing-excel-shift',
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
      notes: 'Preserve existing schedule details',
    );
    await repository.save(original);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'openCalendar');
          return {
            'name': 'synthetic-coworkers.xlsx',
            'bytes': Uint8List.fromList(_xlsxCoworkers()),
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
    await tester.tap(find.text('Choose coworker roster file'));
    await tester.pumpAndSettle();
    expect(find.text('1 matched · 0 unmatched · 0 ambiguous'), findsOneWidget);
    expect(await repository.getItems(), hasLength(1));

    await tester.tap(find.text('Update coworkers on 1 shift'));
    await tester.pumpAndSettle();
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
    expect(updated.coworkers, ['Synthetic Lee', 'Synthetic Sam']);
  });
}

List<int> _xlsxCoworkers() {
  final archive = Archive();
  void add(String name, String contents) {
    final bytes = utf8.encode(contents);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add(
    'xl/workbook.xml',
    '''<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Roster" sheetId="1" r:id="rId1"/></sheets></workbook>''',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>''',
  );
  add('xl/worksheets/sheet1.xml', '''<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
<row r="1"><c r="A1" t="inlineStr"><is><t>date</t></is></c><c r="B1" t="inlineStr"><is><t>roster_code</t></is></c><c r="C1" t="inlineStr"><is><t>coworkers</t></is></c></row>
<row r="2"><c r="A2" t="inlineStr"><is><t>2026-11-24</t></is></c><c r="B2" t="inlineStr"><is><t>A1</t></is></c><c r="C2" t="inlineStr"><is><t>Synthetic Lee;Synthetic Sam</t></is></c></row>
</sheetData></worksheet>''');
  return ZipEncoder().encode(archive)!;
}
