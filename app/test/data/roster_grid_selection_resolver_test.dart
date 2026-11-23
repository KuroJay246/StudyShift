import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/roster_grid_import.dart';
import 'package:shift_study/data/roster_grid_selection_resolver.dart';

void main() {
  const resolver = RosterGridSelectionResolver();

  test('resolves the reviewer-selected person row and preserves raw codes', () {
    const table = RosterGridCandidate(
      page: 2,
      headerTop: .12,
      columns: [
        RosterGridColumn(dayNumber: 16, weekday: DateTime.monday),
        RosterGridColumn(dayNumber: 17, weekday: DateTime.tuesday),
        RosterGridColumn(dayNumber: 18, weekday: DateTime.wednesday),
      ],
      rows: [
        RosterGridRow(
          label: 'Person A',
          cells: [
            RosterGridCell(text: ' A1 ', isAmbiguous: false),
            RosterGridCell(text: '???', isAmbiguous: true),
            RosterGridCell(text: '', isAmbiguous: false),
          ],
        ),
        RosterGridRow(
          label: 'Person B',
          cells: [
            RosterGridCell(text: 'VS', isAmbiguous: false),
            RosterGridCell(text: 'OFF', isAmbiguous: false),
            RosterGridCell(text: 'A2', isAmbiguous: false),
          ],
        ),
      ],
    );
    const detection = RosterGridDetection([table]);

    final result = resolver.resolve(
      detection: detection,
      candidateIndex: 0,
      selectedRowIndex: 0,
      firstDate: DateTime(2026, 11, 16),
    );

    expect(result.page, 2);
    expect(result.personLabel, 'Person A');
    expect(result.cells.map((cell) => cell.date), [
      DateTime(2026, 11, 16),
      DateTime(2026, 11, 17),
      DateTime(2026, 11, 18),
    ]);
    expect(result.cells.map((cell) => cell.rawCode), ['A1', '???', '']);
    expect(result.cells.map((cell) => cell.needsReview), [false, true, true]);
  });

  test(
    'requires explicit table and person choices when choices are invalid',
    () {
      const detection = RosterGridDetection([
        RosterGridCandidate(
          page: 0,
          headerTop: .1,
          columns: [RosterGridColumn(dayNumber: 16)],
          rows: [RosterGridRow(label: 'Person A', cells: [])],
        ),
      ]);

      expect(
        () => resolver.resolve(
          detection: detection,
          candidateIndex: 1,
          selectedRowIndex: 0,
          firstDate: DateTime(2026, 11, 16),
        ),
        throwsFormatException,
      );
      expect(
        () => resolver.resolve(
          detection: detection,
          candidateIndex: 0,
          selectedRowIndex: 1,
          firstDate: DateTime(2026, 11, 16),
        ),
        throwsFormatException,
      );
    },
  );
}
