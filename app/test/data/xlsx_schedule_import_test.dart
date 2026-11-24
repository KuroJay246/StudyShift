import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/xlsx_schedule_import.dart';

void main() {
  const parser = XlsxScheduleImportParser();

  test('detects a date-across-columns roster matrix in XLSX', () {
    final detection = parser.detectRosterGrid(
      Uint8List.fromList(
        _workbook(
          matrixRows: [
            ['Employee', 'Nov 23 2026', 'Nov 24 2026', 'Nov 25 2026'],
            ['Synthetic owner', 'AV', 'OFF', 'VC'],
            ['Synthetic coworker', 'AV', 'A1', 'OFF'],
          ],
        ),
      ),
    );

    expect(detection.candidates, hasLength(1));
    expect(detection.candidates.single.rows.map((row) => row.label), [
      'Synthetic owner',
      'Synthetic coworker',
    ]);
  });

  test('parses documented inline-string schedule rows for review', () async {
    final preview = await parser.parse(
      Uint8List.fromList(_workbook()),
      sourceName: 'synthetic.xlsx',
      importedAt: DateTime.utc(2026, 11, 6),
    );

    expect(preview.proposals, hasLength(1));
    final item = preview.proposals.single.item;
    expect(item.title, 'Synthetic ramp shift');
    expect(item.startDate.toString(), '2026-11-07');
    expect(item.intervals.single.startMinute, 22 * 60);
    expect(item.intervals.single.endDayOffset, 1);
    expect(item.intervals.single.endMinute, 6 * 60);
    expect(item.intervals, hasLength(1));
    expect(
      preview.proposals.single.sourceText,
      contains('Synthetic ramp shift'),
    );
  });

  test(
    'event rows keep only coworkers whose paired code matches the shift',
    () async {
      final preview = await parser.parse(
        Uint8List.fromList(
          _workbook(
            headers: [
              'date',
              'title',
              'category',
              'start',
              'end',
              'time_zone',
              'code',
              'coworkers',
              'coworker_codes',
            ],
            values: [
              '2026-11-25',
              'Afternoon shift',
              'shift',
              '12:00',
              '20:00',
              'America/Barbados',
              'AV',
              'Synthetic Same Code;Synthetic Other Code',
              'AV;PM',
            ],
          ),
        ),
        sourceName: 'mixed-roster.xlsx',
      );

      expect(preview.proposals, hasLength(1));
      expect(preview.proposals.single.item.coworkers, ['Synthetic Same Code']);
      expect(preview.notices, hasLength(1));
      expect(preview.notices.single.message, contains('1 coworker'));
    },
  );

  test('event rows do not attach unverified coworker names', () async {
    final preview = await parser.parse(
      Uint8List.fromList(
        _workbook(
          headers: [
            'date',
            'title',
            'category',
            'start',
            'end',
            'time_zone',
            'code',
            'coworkers',
          ],
          values: [
            '2026-11-25',
            'Afternoon shift',
            'shift',
            '12:00',
            '20:00',
            'America/Barbados',
            'AV',
            'Synthetic coworker',
          ],
        ),
      ),
      sourceName: 'unverified-coworkers.xlsx',
    );

    expect(preview.proposals, hasLength(1));
    expect(preview.proposals.single.item.coworkers, isEmpty);
    expect(preview.notices, hasLength(1));
    expect(preview.notices.single.message, contains('codes are missing'));
  });

  test('parses coworker-only roster columns without event fields', () async {
    final preview = parser.parseCoworkerRoster(
      Uint8List.fromList(
        _workbook(
          headers: ['date', 'roster_code', 'coworkers'],
          values: ['2026-11-24', 'A1', 'Synthetic Sam;Synthetic Lee'],
        ),
      ),
    );

    expect(preview.assignments, hasLength(1));
    expect(preview.assignments.single.date.toString(), '2026-11-24');
    expect(preview.assignments.single.code, 'A1');
    expect(preview.assignments.single.coworkers, [
      'Synthetic Sam',
      'Synthetic Lee',
    ]);
  });

  test('keeps only coworkers with the selected shift code', () async {
    final preview = parser.parseCoworkerRoster(
      Uint8List.fromList(
        _workbook(
          headers: ['date', 'roster_code', 'coworkers', 'coworker_codes'],
          values: [
            '2026-11-24',
            'A1',
            'Synthetic Same Code;Synthetic Other Code',
            'A1;VC',
          ],
        ),
      ),
    );

    expect(preview.assignments, hasLength(1));
    expect(preview.assignments.single.coworkers, ['Synthetic Same Code']);
    expect(preview.assignments.single.sameRosterCodeVerified, isTrue);
    expect(preview.notices.join(' '), contains('1 coworker'));
  });

  test('coworker roster workbook rejects formulas before parsing names', () {
    expect(
      () => parser.parseCoworkerRoster(
        Uint8List.fromList(
          _workbook(
            headers: ['date', 'code', 'coworkers'],
            values: ['2026-11-24', 'A1', 'Synthetic coworker'],
            formula: true,
          ),
        ),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('formulas'),
        ),
      ),
    );
  });

  test('inspects and maps alternate Excel headings locally', () async {
    final bytes = Uint8List.fromList(
      _workbook(
        headers: [
          'Work day',
          'Duty name',
          'Duty type',
          'Clock in',
          'Clock out',
          'Zone',
        ],
      ),
    );
    expect(parser.inspectHeaders(bytes), [
      'Work day',
      'Duty name',
      'Duty type',
      'Clock in',
      'Clock out',
      'Zone',
    ]);
    final preview = await parser.parse(
      bytes,
      sourceName: 'synthetic-alternate.xlsx',
      headerMapping: {
        'Work day': 'date',
        'Duty name': 'title',
        'Duty type': 'category',
        'Clock in': 'start',
        'Clock out': 'end',
        'Zone': 'time_zone',
      },
      importedAt: DateTime.utc(2026, 11, 6),
    );
    expect(preview.proposals, hasLength(1));
    expect(preview.proposals.single.item.title, 'Synthetic ramp shift');
    expect(preview.proposals.single.item.intervals.single.endDayOffset, 1);
  });

  test(
    'rejects formulas instead of accepting cached spreadsheet values',
    () async {
      await expectLater(
        parser.parse(
          Uint8List.fromList(_workbook(formula: true)),
          sourceName: 'formula.xlsx',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('formulas'),
          ),
        ),
      );
    },
  );

  test('rejects hidden worksheet rows before decoding', () async {
    await expectLater(
      parser.parse(
        Uint8List.fromList(_workbook(hiddenRow: true)),
        sourceName: 'hidden.xlsx',
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Unhide'),
        ),
      ),
    );
  });

  test('rejects a non-XLSX ZIP without expanding arbitrary entries', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('payload.txt', 4, utf8.encode('test')));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
    await expectLater(
      parser.parse(bytes, sourceName: 'not-a-workbook.xlsx'),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'rejects a deflate stream that exceeds its declared output size',
    () async {
      final archive = Archive()
        ..addFile(ArchiveFile('payload.txt', 10000, utf8.encode('A' * 10000)));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
      final data = ByteData.sublistView(bytes);
      var eocd = -1;
      for (var offset = bytes.length - 22; offset >= 0; offset--) {
        if (data.getUint32(offset, Endian.little) == 0x06054b50) {
          eocd = offset;
          break;
        }
      }
      final central = data.getUint32(eocd + 16, Endian.little);
      final local = data.getUint32(central + 42, Endian.little);
      data.setUint32(central + 24, 1, Endian.little);
      data.setUint32(local + 22, 1, Endian.little);

      await expectLater(
        parser.parse(bytes, sourceName: 'oversized-entry.xlsx'),
        throwsA(isA<FormatException>()),
      );
    },
  );
}

List<int> _workbook({
  bool formula = false,
  bool hiddenRow = false,
  List<String>? headers,
  List<String>? values,
  List<List<String>>? matrixRows,
}) {
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
  final rowsToEncode =
      matrixRows ??
      [
        headers ?? ['date', 'title', 'category', 'start', 'end', 'time_zone'],
        values ??
            [
              '2026-11-07',
              'Synthetic ramp shift',
              'shift',
              '22:00',
              '06:00',
              'America/Barbados',
            ],
      ];
  final rows = <String>[];
  for (var rowIndex = 0; rowIndex < rowsToEncode.length; rowIndex++) {
    final cells = <String>[];
    for (
      var columnIndex = 0;
      columnIndex < rowsToEncode[rowIndex].length;
      columnIndex++
    ) {
      final reference =
          '${String.fromCharCode(65 + columnIndex)}${rowIndex + 1}';
      final value = rowsToEncode[rowIndex][columnIndex];
      final formulaNode = formula && rowIndex == 1 && columnIndex == 1
          ? '<f>"Synthetic ramp shift"</f><v>Synthetic ramp shift</v>'
          : '<is><t>$value</t></is>';
      cells.add('<c r="$reference" t="inlineStr">$formulaNode</c>');
    }
    final hidden = rowIndex == 1 && hiddenRow ? ' hidden="1"' : '';
    rows.add('<row r="${rowIndex + 1}"$hidden>${cells.join()}</row>');
  }
  add(
    'xl/worksheets/sheet1.xml',
    '''<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>${rows.join()}</sheetData></worksheet>''',
  );
  return ZipEncoder().encode(archive)!;
}
