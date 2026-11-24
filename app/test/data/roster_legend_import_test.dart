import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/roster_legend_import.dart';
import 'package:shift_study/data/roster_grid_import.dart';
import 'package:shift_study/domain/work_code_legend.dart';

void main() {
  test('parses colon and AM/PM legend windows from OCR text', () {
    final result = const RosterLegendImportParser().detect([
      OcrTextToken(
        text: 'SHIFT LEGEND',
        left: .50,
        top: .10,
        right: .60,
        bottom: .11,
      ),
      OcrTextToken(text: 'Q7', left: .502, top: .13, right: .522, bottom: .14),
      OcrTextToken(
        text: '6:30 AM–9:30 AM / 12:00–4:00 PM',
        left: .532,
        top: .13,
        right: .72,
        bottom: .14,
      ),
    ]);

    expect(result.definitions, hasLength(1));
    expect(result.definitions.single.code, 'Q7');
    expect(result.definitions.single.timeWindows, const [
      WorkCodeTimeWindow(startMinute: 390, endMinute: 570),
      WorkCodeTimeWindow(startMinute: 720, endMinute: 960),
    ]);
  });

  test('parses a colon-formatted overnight legend window', () {
    final result = const RosterLegendImportParser().detect([
      OcrTextToken(
        text: 'SHIFT LEGEND',
        left: .50,
        top: .10,
        right: .60,
        bottom: .11,
      ),
      OcrTextToken(text: 'OVN', left: .502, top: .13, right: .522, bottom: .14),
      OcrTextToken(
        text: '11:30 PM–1:30 AM',
        left: .532,
        top: .13,
        right: .66,
        bottom: .14,
      ),
    ]);

    expect(result.definitions, hasLength(1));
    expect(result.definitions.single.timeWindows, const [
      WorkCodeTimeWindow(startMinute: 1410, endMinute: 90, endDayOffset: 1),
    ]);
  });

  test(
    'does not guess meridiem for ambiguous colon-formatted legend times',
    () {
      final result = const RosterLegendImportParser().detect([
        OcrTextToken(
          text: 'SHIFT LEGEND',
          left: .50,
          top: .10,
          right: .60,
          bottom: .11,
        ),
        OcrTextToken(
          text: 'Q7',
          left: .502,
          top: .13,
          right: .522,
          bottom: .14,
        ),
        OcrTextToken(
          text: '6:30–9:30',
          left: .532,
          top: .13,
          right: .60,
          bottom: .14,
        ),
      ]);

      expect(result.definitions, isEmpty);
      expect(result.ignoredRows, 1);
    },
  );

  test('extracts code windows and flight references from a titled legend', () {
    const tokens = <OcrTextToken>[
      OcrTextToken(
        text: 'SHIFT',
        left: .50,
        top: .10,
        right: .535,
        bottom: .11,
      ),
      OcrTextToken(
        text: 'LEGEND',
        left: .54,
        top: .10,
        right: .59,
        bottom: .11,
      ),
      OcrTextToken(text: 'Q7', left: .502, top: .13, right: .522, bottom: .14),
      OcrTextToken(
        text: '0630-0930/1200-1600',
        left: .532,
        top: .13,
        right: .625,
        bottom: .14,
      ),
      OcrTextToken(
        text: 'ZX1020;',
        left: .635,
        top: .13,
        right: .675,
        bottom: .14,
      ),
      OcrTextToken(
        text: 'YK204;',
        left: .68,
        top: .13,
        right: .715,
        bottom: .14,
      ),
      OcrTextToken(
        text: 'QW3601',
        left: .72,
        top: .13,
        right: .755,
        bottom: .14,
      ),
      // A code-like schedule cell to the left of the legend columns must not
      // be mistaken for a legend row.
      OcrTextToken(text: 'AL', left: .43, top: .15, right: .45, bottom: .16),
      OcrTextToken(text: 'OVN', left: .502, top: .17, right: .522, bottom: .18),
      OcrTextToken(
        text: '1830-0130',
        left: .532,
        top: .17,
        right: .58,
        bottom: .18,
      ),
      OcrTextToken(
        text: 'ZX3201/2;',
        left: .635,
        top: .17,
        right: .68,
        bottom: .18,
      ),
      OcrTextToken(
        text: 'TK4090',
        left: .685,
        top: .17,
        right: .72,
        bottom: .18,
      ),
      OcrTextToken(
        text: 'ROSTER',
        left: .50,
        top: .25,
        right: .55,
        bottom: .26,
      ),
      OcrTextToken(
        text: 'SUBJECT TO CHANGE',
        left: .56,
        top: .25,
        right: .72,
        bottom: .26,
      ),
    ];

    final result = const RosterLegendImportParser().detect(tokens);

    expect(result.definitions, hasLength(2));
    expect(result.definitions[0].code, 'Q7');
    expect(result.definitions[0].timeWindows, [
      const WorkCodeTimeWindow(startMinute: 390, endMinute: 570),
      const WorkCodeTimeWindow(startMinute: 720, endMinute: 960),
    ]);
    expect(result.definitions[0].flightIds, ['ZX1020', 'YK204', 'QW3601']);
    expect(result.definitions[1].code, 'OVN');
    expect(result.definitions[1].timeWindows, [
      const WorkCodeTimeWindow(
        startMinute: 1110,
        endMinute: 90,
        endDayOffset: 1,
      ),
    ]);
    expect(result.definitions[1].flightIds, ['ZX3201/2', 'TK4090']);
    expect(result.ignoredRows, 0);
  });

  test(
    'does not infer definitions from time rows without a legend heading',
    () {
      final result = const RosterLegendImportParser().detect(const [
        OcrTextToken(text: 'A1', left: .10, top: .10, right: .12, bottom: .11),
        OcrTextToken(
          text: '0600-0900',
          left: .14,
          top: .10,
          right: .20,
          bottom: .11,
        ),
      ]);

      expect(result.definitions, isEmpty);
      expect(result.hasLegendHeading, isFalse);
    },
  );

  test(
    'flags definitions with leftover OCR clock fragments for manual review',
    () {
      const uncertain = WorkCodeLegend(
        id: 'ocr-legend-uncertain',
        code: 'T8',
        assignmentDetails: '0610-09Ooo/1 ZX100 ExampleCarrier',
        timeWindows: [WorkCodeTimeWindow(startMinute: 180, endMinute: 960)],
      );
      const clear = WorkCodeLegend(
        id: 'ocr-legend-clear',
        code: 'Q7',
        assignmentDetails: 'ZX1000 QW3333',
        timeWindows: [WorkCodeTimeWindow(startMinute: 390, endMinute: 570)],
      );

      expect(
        const RosterLegendImportParser().isSafeToPreselect(uncertain),
        isFalse,
      );
      expect(const RosterLegendImportParser().isSafeToPreselect(clear), isTrue);
    },
  );
}
