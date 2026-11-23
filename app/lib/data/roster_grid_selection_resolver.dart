import 'roster_grid_import.dart';

/// Resolves a reviewer's explicit roster-table and person-row choices.
///
/// OCR only proposes table geometry. This resolver never guesses which table
/// or person is the owner's, and it preserves unreadable cells for review.
class RosterGridSelectionResolver {
  const RosterGridSelectionResolver({
    this._parser = const RosterGridImportParser(),
  });

  final RosterGridImportParser _parser;

  RosterGridSelection resolve({
    required RosterGridDetection detection,
    required int candidateIndex,
    required int selectedRowIndex,
    required DateTime firstDate,
    Map<int, DateTime> dateOverrides = const {},
    bool allowWeekdayMismatch = false,
  }) {
    if (candidateIndex < 0 || candidateIndex >= detection.candidates.length) {
      throw const FormatException('Select one of the detected roster tables.');
    }
    final table = detection.candidates[candidateIndex];
    if (selectedRowIndex < 0 || selectedRowIndex >= table.rows.length) {
      throw const FormatException('Select a person row from the roster table.');
    }
    final dates = _parser.mapDates(
      table,
      firstDate,
      dateOverrides: dateOverrides,
      allowWeekdayMismatch: allowWeekdayMismatch,
    );
    final row = table.rows[selectedRowIndex];
    final cells = List.generate(dates.length, (columnIndex) {
      if (columnIndex >= row.cells.length) {
        return RosterGridSelectionCell(
          date: dates[columnIndex],
          rawCode: '',
          needsReview: true,
        );
      }
      final cell = row.cells[columnIndex];
      return RosterGridSelectionCell(
        date: dates[columnIndex],
        rawCode: cell.text.trim(),
        needsReview: cell.isAmbiguous || cell.text.trim().isEmpty,
      );
    });
    return RosterGridSelection(
      page: table.page,
      personLabel: row.label.trim(),
      cells: List.unmodifiable(cells),
    );
  }
}

class RosterGridSelection {
  const RosterGridSelection({
    required this.page,
    required this.personLabel,
    required this.cells,
  });

  final int page;
  final String personLabel;
  final List<RosterGridSelectionCell> cells;
}

class RosterGridSelectionCell {
  const RosterGridSelectionCell({
    required this.date,
    required this.rawCode,
    required this.needsReview,
  });

  final DateTime date;
  final String rawCode;
  final bool needsReview;
}
