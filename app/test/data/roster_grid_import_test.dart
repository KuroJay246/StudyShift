import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/roster_grid_import.dart';

void main() {
  const parser = RosterGridImportParser();

  test('detects weekday and numbered date columns in a roster grid', () {
    final result = parser.detect(_sampleGrid());

    expect(result.candidates, hasLength(1));
    final table = result.candidates.single;
    expect(table.columns.map((column) => column.dayNumber), [16, 17, 18]);
    expect(table.columns.map((column) => column.weekday), [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
    ]);
    expect(table.rows.map((row) => row.label), ['Person One', 'Person Two']);
    expect(table.rows.first.cells.map((cell) => cell.text), [
      'A1',
      'OFF',
      'VS',
    ]);
  });

  test('keeps final date cells when roster columns are unevenly spaced', () {
    const tokens = [
      OcrTextToken(text: 'Mon 16', left: .22, top: .10, right: .28, bottom: .12),
      OcrTextToken(text: 'Tue 17', left: .29, top: .10, right: .35, bottom: .12),
      OcrTextToken(text: 'Wed 18', left: .36, top: .10, right: .42, bottom: .12),
      OcrTextToken(text: 'Thu 19', left: .47, top: .10, right: .53, bottom: .12),
      OcrTextToken(text: 'Person One', left: .02, top: .20, right: .13, bottom: .22),
      OcrTextToken(text: 'A1', left: .24, top: .20, right: .26, bottom: .22),
      OcrTextToken(text: 'OFF', left: .31, top: .20, right: .34, bottom: .22),
      OcrTextToken(text: 'VS', left: .38, top: .20, right: .40, bottom: .22),
      OcrTextToken(text: 'LO1', left: .53, top: .20, right: .55, bottom: .22),
    ];

    final table = parser.detect(tokens).candidates.single;

    expect(table.columns.map((column) => column.dayNumber), [16, 17, 18, 19]);
    expect(table.rows.single.label, 'Person One');
    expect(table.rows.single.cells.map((cell) => cell.text), [
      'A1',
      'OFF',
      'VS',
      'LO1',
    ]);
  });

  test('detects weekdays merged into numbered date header tokens', () {
    const tokens = [
      OcrTextToken(
        text: 'Mon 16',
        left: .17,
        top: .10,
        right: .23,
        bottom: .12,
      ),
      OcrTextToken(
        text: 'Tue 17',
        left: .29,
        top: .10,
        right: .35,
        bottom: .12,
      ),
      OcrTextToken(
        text: 'Wed 18',
        left: .41,
        top: .10,
        right: .48,
        bottom: .12,
      ),
      OcrTextToken(
        text: 'Person One',
        left: .02,
        top: .20,
        right: .13,
        bottom: .22,
      ),
      OcrTextToken(text: 'A1', left: .18, top: .20, right: .22, bottom: .22),
      OcrTextToken(text: 'OFF', left: .30, top: .20, right: .34, bottom: .22),
      OcrTextToken(text: 'VS', left: .42, top: .20, right: .46, bottom: .22),
    ];

    final detection = parser.detect(tokens);

    expect(detection.candidates, hasLength(1));
    final table = detection.candidates.single;
    expect(table.columns.map((column) => column.dayNumber), [16, 17, 18]);
    expect(table.columns.map((column) => column.weekday), [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
    ]);
    expect(parser.mapDates(table, DateTime(2026, 11, 16)), [
      DateTime(2026, 11, 16),
      DateTime(2026, 11, 17),
      DateTime(2026, 11, 18),
    ]);
  });

  test('applies a separate month and year header to numbered date columns', () {
    const tokens = [
      OcrTextToken(
        text: 'November',
        left: .25,
        top: .06,
        right: .38,
        bottom: .08,
      ),
      OcrTextToken(text: '2026', left: .39, top: .06, right: .44, bottom: .08),
      OcrTextToken(text: '16', left: .17, top: .10, right: .23, bottom: .12),
      OcrTextToken(text: '17', left: .29, top: .10, right: .35, bottom: .12),
      OcrTextToken(text: '18', left: .41, top: .10, right: .48, bottom: .12),
      OcrTextToken(
        text: 'Person One',
        left: .02,
        top: .20,
        right: .13,
        bottom: .22,
      ),
      OcrTextToken(text: 'A1', left: .18, top: .20, right: .22, bottom: .22),
      OcrTextToken(text: 'OFF', left: .30, top: .20, right: .34, bottom: .22),
      OcrTextToken(text: 'VS', left: .42, top: .20, right: .46, bottom: .22),
    ];

    final table = parser.detect(tokens).candidates.single;

    expect(table.columns.map((column) => column.month), [11, null, null]);
    expect(table.columns.map((column) => column.year), [2026, null, null]);
    expect(parser.mapDates(table, DateTime(2026, 11, 16)), [
      DateTime(2026, 11, 16),
      DateTime(2026, 11, 17),
      DateTime(2026, 11, 18),
    ]);
  });

  test('detects month-name date headers split across OCR word tokens', () {
    const tokens = [
      OcrTextToken(text: 'Nov', left: .15, top: .10, right: .19, bottom: .12),
      OcrTextToken(text: '16', left: .20, top: .10, right: .23, bottom: .12),
      OcrTextToken(text: 'Nov', left: .27, top: .10, right: .31, bottom: .12),
      OcrTextToken(text: '17', left: .32, top: .10, right: .35, bottom: .12),
      OcrTextToken(text: 'Nov', left: .39, top: .10, right: .43, bottom: .12),
      OcrTextToken(text: '18', left: .44, top: .10, right: .48, bottom: .12),
      OcrTextToken(
        text: 'Person One',
        left: .02,
        top: .20,
        right: .13,
        bottom: .22,
      ),
      OcrTextToken(text: 'A1', left: .18, top: .20, right: .22, bottom: .22),
      OcrTextToken(text: 'OFF', left: .30, top: .20, right: .34, bottom: .22),
      OcrTextToken(text: 'VS', left: .42, top: .20, right: .46, bottom: .22),
    ];

    final table = parser.detect(tokens).candidates.single;

    expect(table.columns.map((column) => column.month), [11, 11, 11]);
    expect(table.columns.map((column) => column.dayNumber), [16, 17, 18]);
    expect(parser.mapDates(table, DateTime(2026, 11, 16)), [
      DateTime(2026, 11, 16),
      DateTime(2026, 11, 17),
      DateTime(2026, 11, 18),
    ]);
  });

  test('maps month-name date headers that include an explicit year', () {
    const tokens = [
      OcrTextToken(
        text: '16 November 2026',
        left: .17,
        top: .10,
        right: .23,
        bottom: .12,
      ),
      OcrTextToken(
        text: '17 November 2026',
        left: .29,
        top: .10,
        right: .35,
        bottom: .12,
      ),
      OcrTextToken(
        text: '18 November 2026',
        left: .41,
        top: .10,
        right: .48,
        bottom: .12,
      ),
      OcrTextToken(
        text: 'Person One',
        left: .02,
        top: .20,
        right: .13,
        bottom: .22,
      ),
      OcrTextToken(text: 'A1', left: .18, top: .20, right: .22, bottom: .22),
      OcrTextToken(text: 'OFF', left: .30, top: .20, right: .34, bottom: .22),
      OcrTextToken(text: 'VS', left: .42, top: .20, right: .46, bottom: .22),
    ];

    final table = parser.detect(tokens).candidates.single;

    expect(table.columns.map((column) => column.year), [2026, 2026, 2026]);
    expect(parser.mapDates(table, DateTime(2026, 11, 16)), [
      DateTime(2026, 11, 16),
      DateTime(2026, 11, 17),
      DateTime(2026, 11, 18),
    ]);
  });

  test('rejects an impossible day in a month-name date header', () {
    const tokens = [
      OcrTextToken(
        text: '30 February 2026',
        left: .17,
        top: .10,
        right: .23,
        bottom: .12,
      ),
      OcrTextToken(
        text: '2 March 2026',
        left: .29,
        top: .10,
        right: .35,
        bottom: .12,
      ),
      OcrTextToken(
        text: '3 March 2026',
        left: .41,
        top: .10,
        right: .48,
        bottom: .12,
      ),
      OcrTextToken(
        text: 'Person One',
        left: .02,
        top: .20,
        right: .13,
        bottom: .22,
      ),
      OcrTextToken(text: 'A1', left: .18, top: .20, right: .22, bottom: .22),
      OcrTextToken(text: 'OFF', left: .30, top: .20, right: .34, bottom: .22),
      OcrTextToken(text: 'VS', left: .42, top: .20, right: .46, bottom: .22),
    ];

    final table = parser.detect(tokens).candidates.single;

    expect(
      () => parser.mapDates(table, DateTime(2026, 2, 28)),
      throwsFormatException,
    );
  });

  test('requires manual confirmation to match an explicit header year', () {
    const tokens = [
      OcrTextToken(
        text: '16 November 2026',
        left: .17,
        top: .10,
        right: .23,
        bottom: .12,
      ),
      OcrTextToken(
        text: '17 November 2026',
        left: .29,
        top: .10,
        right: .35,
        bottom: .12,
      ),
      OcrTextToken(
        text: '18 November 2026',
        left: .41,
        top: .10,
        right: .48,
        bottom: .12,
      ),
      OcrTextToken(
        text: 'Person One',
        left: .02,
        top: .20,
        right: .13,
        bottom: .22,
      ),
      OcrTextToken(text: 'A1', left: .18, top: .20, right: .22, bottom: .22),
      OcrTextToken(text: 'OFF', left: .30, top: .20, right: .34, bottom: .22),
      OcrTextToken(text: 'VS', left: .42, top: .20, right: .46, bottom: .22),
    ];

    final table = parser.detect(tokens).candidates.single;

    expect(
      () => parser.mapDates(table, DateTime(2025, 11, 16)),
      throwsFormatException,
    );
  });

  test('detects numbered dates merged before their weekday headers', () {
    const tokens = [
      OcrTextToken(
        text: '16 Mon',
        left: .17,
        top: .10,
        right: .23,
        bottom: .12,
      ),
      OcrTextToken(
        text: '17 Tue',
        left: .29,
        top: .10,
        right: .35,
        bottom: .12,
      ),
      OcrTextToken(
        text: '18 Wed',
        left: .41,
        top: .10,
        right: .48,
        bottom: .12,
      ),
      OcrTextToken(
        text: 'Person One',
        left: .02,
        top: .20,
        right: .13,
        bottom: .22,
      ),
      OcrTextToken(text: 'A1', left: .18, top: .20, right: .22, bottom: .22),
      OcrTextToken(text: 'OFF', left: .30, top: .20, right: .34, bottom: .22),
      OcrTextToken(text: 'VS', left: .42, top: .20, right: .46, bottom: .22),
    ];

    final detection = parser.detect(tokens);

    expect(detection.candidates, hasLength(1));
    expect(
      detection.candidates.single.columns.map((column) => column.weekday),
      [DateTime.monday, DateTime.tuesday, DateTime.wednesday],
    );
  });

  test('matches weekdays to their own columns in a dense roster header', () {
    const tokens = [
      OcrTextToken(text: 'Mon', left: .16, top: .10, right: .19, bottom: .12),
      OcrTextToken(text: 'Tue', left: .195, top: .10, right: .225, bottom: .12),
      OcrTextToken(text: 'Wed', left: .230, top: .10, right: .260, bottom: .12),
      OcrTextToken(text: 'Thu', left: .265, top: .10, right: .295, bottom: .12),
      OcrTextToken(text: '16', left: .16, top: .13, right: .19, bottom: .15),
      OcrTextToken(text: '17', left: .195, top: .13, right: .225, bottom: .15),
      OcrTextToken(text: '18', left: .230, top: .13, right: .260, bottom: .15),
      OcrTextToken(text: '19', left: .265, top: .13, right: .295, bottom: .15),
      OcrTextToken(
        text: 'Person One',
        left: .02,
        top: .21,
        right: .13,
        bottom: .23,
      ),
      OcrTextToken(text: 'A1', left: .16, top: .21, right: .19, bottom: .23),
      OcrTextToken(text: 'A2', left: .195, top: .21, right: .225, bottom: .23),
      OcrTextToken(text: 'VS', left: .230, top: .21, right: .260, bottom: .23),
      OcrTextToken(text: 'OFF', left: .265, top: .21, right: .295, bottom: .23),
    ];

    final table = parser.detect(tokens).candidates.single;

    expect(table.columns.map((column) => column.weekday), [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
    ]);
    expect(parser.mapDates(table, DateTime(2026, 11, 16)), [
      DateTime(2026, 11, 16),
      DateTime(2026, 11, 17),
      DateTime(2026, 11, 18),
      DateTime(2026, 11, 19),
    ]);
  });

  test(
    'detects full ISO date headers and maps their actual month and year',
    () {
      const tokens = [
        OcrTextToken(
          text: '2026-11-30',
          left: .16,
          top: .10,
          right: .24,
          bottom: .12,
        ),
        OcrTextToken(
          text: '2026-12-01',
          left: .41,
          top: .10,
          right: .49,
          bottom: .12,
        ),
        OcrTextToken(
          text: '2026-12-02',
          left: .66,
          top: .10,
          right: .74,
          bottom: .12,
        ),
        OcrTextToken(
          text: 'Person One',
          left: .02,
          top: .20,
          right: .13,
          bottom: .22,
        ),
        OcrTextToken(text: 'A1', left: .18, top: .20, right: .22, bottom: .22),
        OcrTextToken(text: 'VS', left: .44, top: .20, right: .48, bottom: .22),
        OcrTextToken(text: 'OFF', left: .70, top: .20, right: .74, bottom: .22),
      ];

      final table = parser.detect(tokens).candidates.single;

      expect(table.columns.map((column) => column.dayNumber), [30, 1, 2]);
      expect(parser.mapDates(table, DateTime(2026, 11, 30)), [
        DateTime(2026, 11, 30),
        DateTime(2026, 12, 1),
        DateTime(2026, 12, 2),
      ]);
    },
  );

  test('keeps vertically close staff rows separate using OCR text height', () {
    const tokens = [
      OcrTextToken(text: '16', left: .20, top: .10, right: .23, bottom: .11),
      OcrTextToken(text: '17', left: .30, top: .10, right: .33, bottom: .11),
      OcrTextToken(text: '18', left: .40, top: .10, right: .43, bottom: .11),
      OcrTextToken(
        text: 'Person One',
        left: .02,
        top: .20,
        right: .16,
        bottom: .208,
      ),
      OcrTextToken(text: 'A1', left: .20, top: .20, right: .23, bottom: .208),
      OcrTextToken(
        text: 'Person Two',
        left: .02,
        top: .211,
        right: .16,
        bottom: .219,
      ),
      OcrTextToken(text: 'VS', left: .30, top: .211, right: .33, bottom: .219),
    ];

    final table = parser.detect(tokens).candidates.single;

    expect(table.rows.map((row) => row.label), ['Person One', 'Person Two']);
    expect(table.rows.first.cells.first.text, 'A1');
    expect(table.rows.last.cells[1].text, 'VS');
  });

  test('cleans repeated and stray OCR marks from roster row labels', () {
    final tokens = [
      ..._sampleGrid(),
      const OcrTextToken(
        text: 'Person',
        left: .02,
        top: .35,
        right: .05,
        bottom: .37,
      ),
      const OcrTextToken(
        text: 'Person',
        left: .022,
        top: .351,
        right: .052,
        bottom: .371,
      ),
      const OcrTextToken(
        text: 'Person',
        left: .055,
        top: .35,
        right: .085,
        bottom: .37,
      ),
      const OcrTextToken(
        text: 'Worker!',
        left: .09,
        top: .35,
        right: .12,
        bottom: .37,
      ),
      const OcrTextToken(
        text: r'$',
        left: .125,
        top: .35,
        right: .13,
        bottom: .37,
      ),
      const OcrTextToken(
        text: 'A1',
        left: .18,
        top: .35,
        right: .22,
        bottom: .37,
      ),
    ];

    final table = parser.detect(tokens).candidates.single;

    expect(table.rows.last.label, 'Person Worker');
  });

  test('cleans duplicate OCR words and marker tokens in any token order', () {
    final tokens = [
      ..._sampleGrid(),
      const OcrTextToken(
        text: 'Cedar',
        left: .01,
        top: .35,
        right: .04,
        bottom: .37,
      ),
      const OcrTextToken(
        text: 'Cedar',
        left: .075,
        top: .35,
        right: .105,
        bottom: .37,
      ),
      const OcrTextToken(
        text: 'Quill',
        left: .11,
        top: .35,
        right: .135,
        bottom: .37,
      ),
      const OcrTextToken(
        text: 'Is',
        left: .10,
        top: .35,
        right: .12,
        bottom: .37,
      ),
      const OcrTextToken(
        text: 'ls',
        left: .132,
        top: .35,
        right: .138,
        bottom: .37,
      ),
      const OcrTextToken(
        text: 'A1',
        left: .18,
        top: .35,
        right: .22,
        bottom: .37,
      ),
      const OcrTextToken(
        text: 'Haskel',
        left: .01,
        top: .40,
        right: .06,
        bottom: .42,
      ),
      const OcrTextToken(
        text: 'Haskell',
        left: .07,
        top: .40,
        right: .13,
        bottom: .42,
      ),
      const OcrTextToken(
        text: 'A1',
        left: .18,
        top: .40,
        right: .22,
        bottom: .42,
      ),
    ];

    final table = parser.detect(tokens).candidates.single;

    expect(table.rows[table.rows.length - 2].label, 'Cedar Quill');
    expect(table.rows.last.label, 'Haskell');
  });

  test('maps chosen header to calendar dates and rejects weekday mismatch', () {
    final table = parser.detect(_sampleGrid()).candidates.single;

    expect(parser.mapDates(table, DateTime(2026, 11, 16)), [
      DateTime(2026, 11, 16),
      DateTime(2026, 11, 17),
      DateTime(2026, 11, 18),
    ]);
    expect(
      () => parser.mapDates(table, DateTime(2026, 11, 17)),
      throwsFormatException,
    );
  });

  test('allows a reviewed correction for an OCR date column', () {
    final table = parser.detect(_sampleGrid()).candidates.single;

    expect(
      parser.mapDates(
        table,
        DateTime(2026, 11, 16),
        dateOverrides: {1: DateTime(2026, 11, 18), 2: DateTime(2026, 11, 19)},
      ),
      [DateTime(2026, 11, 16), DateTime(2026, 11, 18), DateTime(2026, 11, 19)],
    );
  });

  test('a corrected OCR date bypasses an invalid recognized day number', () {
    const table = RosterGridCandidate(
      page: 0,
      headerTop: .1,
      columns: [
        RosterGridColumn(dayNumber: 16),
        RosterGridColumn(dayNumber: 32),
        RosterGridColumn(dayNumber: 18),
      ],
      rows: [],
    );

    expect(
      parser.mapDates(
        table,
        DateTime(2026, 11, 16),
        dateOverrides: {1: DateTime(2026, 11, 17)},
      ),
      [DateTime(2026, 11, 16), DateTime(2026, 11, 17), DateTime(2026, 11, 18)],
    );
  });

  test('rejects a correction for a nonexistent roster column', () {
    final table = parser.detect(_sampleGrid()).candidates.single;

    expect(
      () => parser.mapDates(
        table,
        DateTime(2026, 11, 16),
        dateOverrides: {3: DateTime(2026, 11, 19)},
      ),
      throwsFormatException,
    );
  });

  test(
    'rejects a small backwards date jump instead of guessing a new month',
    () {
      const table = RosterGridCandidate(
        page: 0,
        headerTop: .1,
        columns: [
          RosterGridColumn(dayNumber: 18),
          RosterGridColumn(dayNumber: 16),
          RosterGridColumn(dayNumber: 17),
        ],
        rows: [],
      );

      expect(
        () => parser.mapDates(table, DateTime(2026, 11, 18)),
        throwsFormatException,
      );
    },
  );

  test('maps legitimate late-month roster columns into the next month', () {
    const table = RosterGridCandidate(
      page: 0,
      headerTop: .1,
      columns: [
        RosterGridColumn(dayNumber: 20),
        RosterGridColumn(dayNumber: 21),
        RosterGridColumn(dayNumber: 1),
      ],
      rows: [],
    );

    expect(parser.mapDates(table, DateTime(2026, 11, 20)), [
      DateTime(2026, 11, 20),
      DateTime(2026, 11, 21),
      DateTime(2026, 12, 1),
    ]);
  });

  test('keeps an ambiguous multi-code cell unresolved', () {
    final tokens = [
      ..._sampleGrid(),
      OcrTextToken(text: 'A1/VS', left: .17, top: .20, right: .24, bottom: .22),
    ];
    final result = parser.detect(tokens);

    expect(result.candidates.single.rows.first.cells.first.isAmbiguous, isTrue);
  });

  test('does not infer a roster from a plain event list', () {
    final result = parser.detect(const [
      OcrTextToken(
        text: '2026-11-17 09:00 17:00 Ramp shift',
        left: .1,
        top: .1,
        right: .9,
        bottom: .12,
      ),
    ]);

    expect(result.candidates, isEmpty);
  });

  test('does not mistake numeric shift codes for numbered date headers', () {
    const tokens = [
      OcrTextToken(text: 'A1', left: .55, top: .13, right: .59, bottom: .15),
      OcrTextToken(text: 'LO2', left: .67, top: .13, right: .73, bottom: .15),
      OcrTextToken(text: 'VS3', left: .79, top: .13, right: .84, bottom: .15),
      OcrTextToken(
        text: 'Person One',
        left: .02,
        top: .20,
        right: .13,
        bottom: .22,
      ),
    ];

    expect(parser.detect(tokens).candidates, isEmpty);
  });

  test('keeps separate same-date roster tables on one page', () {
    final first = _sampleGrid();
    final second = [
      const OcrTextToken(
        text: 'Mon',
        left: .17,
        top: .50,
        right: .23,
        bottom: .52,
      ),
      const OcrTextToken(
        text: 'Tue',
        left: .29,
        top: .50,
        right: .35,
        bottom: .52,
      ),
      const OcrTextToken(
        text: 'Wed',
        left: .41,
        top: .50,
        right: .48,
        bottom: .52,
      ),
      const OcrTextToken(
        text: '16th',
        left: .17,
        top: .53,
        right: .23,
        bottom: .55,
      ),
      const OcrTextToken(
        text: '17th',
        left: .29,
        top: .53,
        right: .35,
        bottom: .55,
      ),
      const OcrTextToken(
        text: '18th',
        left: .41,
        top: .53,
        right: .48,
        bottom: .55,
      ),
      const OcrTextToken(
        text: 'Person Three',
        left: .02,
        top: .60,
        right: .13,
        bottom: .62,
      ),
      const OcrTextToken(
        text: 'VS',
        left: .18,
        top: .60,
        right: .22,
        bottom: .62,
      ),
      const OcrTextToken(
        text: 'A1',
        left: .30,
        top: .60,
        right: .34,
        bottom: .62,
      ),
      const OcrTextToken(
        text: 'LO1',
        left: .42,
        top: .60,
        right: .46,
        bottom: .62,
      ),
    ];

    final result = parser.detect([...first, ...second]);

    expect(result.candidates, hasLength(2));
    expect(result.candidates.last.rows.single.label, 'Person Three');
  });

  test('declines two roster grids arranged side by side on one date row', () {
    const tokens = [
      OcrTextToken(text: '16', left: .08, top: .10, right: .12, bottom: .12),
      OcrTextToken(text: '17', left: .13, top: .10, right: .17, bottom: .12),
      OcrTextToken(text: '18', left: .18, top: .10, right: .22, bottom: .12),
      OcrTextToken(text: '16', left: .40, top: .10, right: .44, bottom: .12),
      OcrTextToken(text: '17', left: .45, top: .10, right: .49, bottom: .12),
      OcrTextToken(text: '18', left: .50, top: .10, right: .54, bottom: .12),
      OcrTextToken(
        text: 'Person One',
        left: .01,
        top: .20,
        right: .06,
        bottom: .22,
      ),
      OcrTextToken(text: 'A1', left: .09, top: .20, right: .11, bottom: .22),
      OcrTextToken(text: 'VS', left: .14, top: .20, right: .16, bottom: .22),
      OcrTextToken(text: 'LO1', left: .19, top: .20, right: .21, bottom: .22),
      OcrTextToken(
        text: 'Person Two',
        left: .32,
        top: .20,
        right: .37,
        bottom: .22,
      ),
      OcrTextToken(text: 'AA', left: .41, top: .20, right: .43, bottom: .22),
      OcrTextToken(text: 'PM', left: .46, top: .20, right: .48, bottom: .22),
      OcrTextToken(text: 'VA', left: .51, top: .20, right: .53, bottom: .22),
    ];

    expect(parser.detect(tokens).candidates, isEmpty);
  });

  test('declines side by side roster grids with separate date runs', () {
    const tokens = [
      OcrTextToken(text: '1', left: .06, top: .10, right: .10, bottom: .12),
      OcrTextToken(text: '2', left: .12, top: .10, right: .16, bottom: .12),
      OcrTextToken(text: '3', left: .18, top: .10, right: .22, bottom: .12),
      OcrTextToken(text: '4', left: .28, top: .10, right: .32, bottom: .12),
      OcrTextToken(text: '5', left: .34, top: .10, right: .38, bottom: .12),
      OcrTextToken(text: '6', left: .40, top: .10, right: .44, bottom: .12),
      OcrTextToken(
        text: 'Person One',
        left: .01,
        top: .20,
        right: .05,
        bottom: .22,
      ),
      OcrTextToken(text: 'A1', left: .07, top: .20, right: .09, bottom: .22),
      OcrTextToken(text: 'VS', left: .13, top: .20, right: .15, bottom: .22),
      OcrTextToken(text: 'LO1', left: .19, top: .20, right: .21, bottom: .22),
      OcrTextToken(
        text: 'Person Two',
        left: .23,
        top: .20,
        right: .27,
        bottom: .22,
      ),
      OcrTextToken(text: 'AA', left: .29, top: .20, right: .31, bottom: .22),
      OcrTextToken(text: 'PM', left: .35, top: .20, right: .37, bottom: .22),
      OcrTextToken(text: 'VA', left: .41, top: .20, right: .43, bottom: .22),
    ];

    expect(parser.detect(tokens).candidates, isEmpty);
  });

  test('keeps rows with an embedded second staff label fully unresolved', () {
    const tokens = [
      OcrTextToken(text: '1', left: .06, top: .10, right: .10, bottom: .12),
      OcrTextToken(text: '2', left: .12, top: .10, right: .16, bottom: .12),
      OcrTextToken(text: '3', left: .18, top: .10, right: .22, bottom: .12),
      OcrTextToken(text: '4', left: .24, top: .10, right: .28, bottom: .12),
      OcrTextToken(text: '5', left: .30, top: .10, right: .34, bottom: .12),
      OcrTextToken(text: '6', left: .36, top: .10, right: .40, bottom: .12),
      OcrTextToken(
        text: 'Person One',
        left: .01,
        top: .20,
        right: .04,
        bottom: .22,
      ),
      OcrTextToken(text: 'A1', left: .07, top: .20, right: .09, bottom: .22),
      OcrTextToken(text: 'VS', left: .13, top: .20, right: .15, bottom: .22),
      OcrTextToken(text: 'LO1', left: .19, top: .20, right: .21, bottom: .22),
      OcrTextToken(
        text: 'Person',
        left: .225,
        top: .20,
        right: .24,
        bottom: .22,
      ),
      OcrTextToken(text: 'Two', left: .242, top: .20, right: .255, bottom: .22),
      OcrTextToken(text: 'AA', left: .25, top: .20, right: .27, bottom: .22),
      OcrTextToken(text: 'PM', left: .31, top: .20, right: .33, bottom: .22),
      OcrTextToken(text: 'VA', left: .37, top: .20, right: .39, bottom: .22),
    ];

    final table = parser.detect(tokens).candidates.single;

    expect(table.rows.single.cells.every((cell) => cell.isAmbiguous), isTrue);
  });

  test('keeps an all-caps embedded staff label fully unresolved', () {
    const tokens = [
      OcrTextToken(text: '1', left: .06, top: .10, right: .10, bottom: .12),
      OcrTextToken(text: '2', left: .12, top: .10, right: .16, bottom: .12),
      OcrTextToken(text: '3', left: .18, top: .10, right: .22, bottom: .12),
      OcrTextToken(text: '4', left: .24, top: .10, right: .28, bottom: .12),
      OcrTextToken(text: '5', left: .30, top: .10, right: .34, bottom: .12),
      OcrTextToken(text: '6', left: .36, top: .10, right: .40, bottom: .12),
      OcrTextToken(
        text: 'PERSON ONE',
        left: .01,
        top: .20,
        right: .04,
        bottom: .22,
      ),
      OcrTextToken(text: 'A1', left: .07, top: .20, right: .09, bottom: .22),
      OcrTextToken(text: 'VS', left: .13, top: .20, right: .15, bottom: .22),
      OcrTextToken(text: 'LO1', left: .19, top: .20, right: .21, bottom: .22),
      OcrTextToken(
        text: 'CHARLIE',
        left: .225,
        top: .20,
        right: .245,
        bottom: .22,
      ),
      OcrTextToken(
        text: 'DELTA',
        left: .247,
        top: .20,
        right: .275,
        bottom: .22,
      ),
      OcrTextToken(text: 'AA', left: .25, top: .20, right: .27, bottom: .22),
      OcrTextToken(text: 'PM', left: .31, top: .20, right: .33, bottom: .22),
      OcrTextToken(text: 'VA', left: .37, top: .20, right: .39, bottom: .22),
    ];

    final table = parser.detect(tokens).candidates.single;

    expect(table.rows.single.cells.every((cell) => cell.isAmbiguous), isTrue);
  });

  test('keeps an initial and all-caps surname fully unresolved', () {
    const tokens = [
      OcrTextToken(text: '1', left: .06, top: .10, right: .10, bottom: .12),
      OcrTextToken(text: '2', left: .12, top: .10, right: .16, bottom: .12),
      OcrTextToken(text: '3', left: .18, top: .10, right: .22, bottom: .12),
      OcrTextToken(text: '4', left: .24, top: .10, right: .28, bottom: .12),
      OcrTextToken(text: '5', left: .30, top: .10, right: .34, bottom: .12),
      OcrTextToken(text: '6', left: .36, top: .10, right: .40, bottom: .12),
      OcrTextToken(
        text: 'Person One',
        left: .01,
        top: .20,
        right: .04,
        bottom: .22,
      ),
      OcrTextToken(text: 'A1', left: .07, top: .20, right: .09, bottom: .22),
      OcrTextToken(text: 'VS', left: .13, top: .20, right: .15, bottom: .22),
      OcrTextToken(text: 'LO1', left: .19, top: .20, right: .21, bottom: .22),
      OcrTextToken(text: 'K', left: .225, top: .20, right: .228, bottom: .22),
      OcrTextToken(
        text: 'MORGAN',
        left: .230,
        top: .20,
        right: .258,
        bottom: .22,
      ),
      OcrTextToken(text: 'AA', left: .25, top: .20, right: .27, bottom: .22),
      OcrTextToken(text: 'PM', left: .31, top: .20, right: .33, bottom: .22),
      OcrTextToken(text: 'VA', left: .37, top: .20, right: .39, bottom: .22),
    ];

    final table = parser.detect(tokens).candidates.single;

    expect(table.rows.single.cells.every((cell) => cell.isAmbiguous), isTrue);
  });

  test('does not flag adjacent short uppercase shift codes as a name', () {
    const tokens = [
      OcrTextToken(text: '1', left: .06, top: .10, right: .10, bottom: .12),
      OcrTextToken(text: '2', left: .12, top: .10, right: .16, bottom: .12),
      OcrTextToken(text: '3', left: .18, top: .10, right: .22, bottom: .12),
      OcrTextToken(text: '4', left: .24, top: .10, right: .28, bottom: .12),
      OcrTextToken(text: '5', left: .30, top: .10, right: .34, bottom: .12),
      OcrTextToken(text: '6', left: .36, top: .10, right: .40, bottom: .12),
      OcrTextToken(
        text: 'Person One',
        left: .01,
        top: .20,
        right: .04,
        bottom: .22,
      ),
      OcrTextToken(text: 'A1', left: .07, top: .20, right: .09, bottom: .22),
      OcrTextToken(text: 'LAVS', left: .13, top: .20, right: .15, bottom: .22),
      OcrTextToken(text: 'OFF', left: .153, top: .20, right: .170, bottom: .22),
      OcrTextToken(text: 'LO1', left: .19, top: .20, right: .21, bottom: .22),
      OcrTextToken(text: 'AA', left: .25, top: .20, right: .27, bottom: .22),
      OcrTextToken(text: 'PM', left: .31, top: .20, right: .33, bottom: .22),
      OcrTextToken(text: 'VA', left: .37, top: .20, right: .39, bottom: .22),
    ];

    final table = parser.detect(tokens).candidates.single;

    expect(table.rows.single.cells.every((cell) => !cell.isAmbiguous), isTrue);
  });
}

List<OcrTextToken> _sampleGrid() => const [
  OcrTextToken(text: 'Mon', left: .17, top: .10, right: .23, bottom: .12),
  OcrTextToken(text: 'Tue', left: .29, top: .10, right: .35, bottom: .12),
  OcrTextToken(text: 'Wed', left: .41, top: .10, right: .48, bottom: .12),
  OcrTextToken(text: '16th', left: .17, top: .13, right: .23, bottom: .15),
  OcrTextToken(text: '17th', left: .29, top: .13, right: .35, bottom: .15),
  OcrTextToken(text: '18th', left: .41, top: .13, right: .48, bottom: .15),
  OcrTextToken(
    text: 'Person One',
    left: .02,
    top: .20,
    right: .13,
    bottom: .22,
  ),
  OcrTextToken(text: 'A1', left: .18, top: .20, right: .22, bottom: .22),
  OcrTextToken(text: 'OFF', left: .30, top: .20, right: .34, bottom: .22),
  OcrTextToken(text: 'VS', left: .42, top: .20, right: .46, bottom: .22),
  OcrTextToken(
    text: 'Person Two',
    left: .02,
    top: .28,
    right: .13,
    bottom: .30,
  ),
  OcrTextToken(text: 'X', left: .18, top: .28, right: .22, bottom: .30),
  OcrTextToken(text: 'A1', left: .30, top: .28, right: .34, bottom: .30),
  OcrTextToken(text: 'LO1', left: .42, top: .28, right: .46, bottom: .30),
];
