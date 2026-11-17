/// Text recognized from one word in a document, with its page-relative bounds.
/// Coordinates are normalized to 0..1 by the Android OCR bridge.
class OcrTextToken {
  const OcrTextToken({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.page = 0,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final int page;

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
}

class RosterGridColumn {
  const RosterGridColumn({required this.dayNumber, this.weekday});

  final int dayNumber;
  final int? weekday;
}

class RosterGridCell {
  const RosterGridCell({required this.text, required this.isAmbiguous});

  final String text;
  final bool isAmbiguous;
}

class RosterGridRow {
  const RosterGridRow({required this.label, required this.cells});

  final String label;
  final List<RosterGridCell> cells;
}

class RosterGridCandidate {
  const RosterGridCandidate({
    required this.page,
    required this.headerTop,
    required this.columns,
    required this.rows,
  });

  final int page;
  final double headerTop;
  final List<RosterGridColumn> columns;
  final List<RosterGridRow> rows;
}

class RosterGridDetection {
  const RosterGridDetection(this.candidates);

  final List<RosterGridCandidate> candidates;
}

/// Detects table geometry without assigning event meanings or saving data.
/// A reviewer must select the table, confirm its first date and choose a row.
class RosterGridImportParser {
  const RosterGridImportParser();

  static final _dayPattern = RegExp(
    r'^\s*([1-9]|[12]\d|3[01])(?:st|nd|rd|th)?\s*$',
    caseSensitive: false,
  );
  static final _weekdayPattern = RegExp(
    r'^(mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\.?$',
    caseSensitive: false,
  );
  static final _separatorsPattern = RegExp(r'[/|,;]');
  static const _rowTolerance = .014;

  RosterGridDetection detect(List<OcrTextToken> tokens) {
    if (tokens.length > 50000) {
      throw const FormatException(
        'The roster contains too much text to review.',
      );
    }
    final candidates = <RosterGridCandidate>[];
    for (final page in tokens.map((token) => token.page).toSet()) {
      final rows = _groupRows(tokens.where((token) => token.page == page));
      for (var index = 0; index < rows.length; index++) {
        final dateTokens =
            rows[index]
                .where((token) => _dayNumber(token.text) != null)
                .toList()
              ..sort((a, b) => a.centerX.compareTo(b.centerX));
        if (dateTokens.length < 3) continue;
        final dayNumbers = dateTokens.map((token) => _dayNumber(token.text)!);
        if (dayNumbers.toSet().length != dateTokens.length) continue;
        final columns = <RosterGridColumn>[];
        final centers = <double>[];
        for (final token in dateTokens) {
          final day = _dayNumber(token.text)!;
          if (columns.isNotEmpty &&
              (token.centerX - centers.last).abs() < .025) {
            continue;
          }
          final weekdayToken = _nearestWeekday(
            rows,
            token,
            dateRowIndex: index,
          );
          columns.add(
            RosterGridColumn(
              dayNumber: day,
              weekday: weekdayToken == null
                  ? null
                  : _weekday(weekdayToken.text),
            ),
          );
          centers.add(token.centerX);
        }
        if (columns.length < 3 || !_reasonableColumns(centers)) continue;
        final tableRows = _dataRows(rows, index, centers);
        if (tableRows.isEmpty) continue;
        candidates.add(
          RosterGridCandidate(
            page: page,
            headerTop:
                rows[index]
                    .map((token) => token.centerY)
                    .reduce((a, b) => a + b) /
                rows[index].length,
            columns: List.unmodifiable(columns),
            rows: List.unmodifiable(tableRows),
          ),
        );
      }
    }
    return RosterGridDetection(List.unmodifiable(_deduplicate(candidates)));
  }

  List<DateTime> mapDates(RosterGridCandidate table, DateTime firstDate) {
    if (table.columns.isEmpty ||
        table.columns.first.dayNumber != firstDate.day) {
      throw const FormatException(
        'Choose a first date that matches the first date column.',
      );
    }
    final dates = <DateTime>[];
    var year = firstDate.year;
    var month = firstDate.month;
    var previousDay = 0;
    for (var index = 0; index < table.columns.length; index++) {
      final column = table.columns[index];
      if (index > 0 && column.dayNumber < previousDay) {
        if (previousDay - column.dayNumber < 10) {
          throw const FormatException(
            'The roster date columns are out of order or combine separate tables.',
          );
        }
        month++;
        if (month > 12) {
          month = 1;
          year++;
        }
      } else if (index > 0 && column.dayNumber == previousDay) {
        throw const FormatException('The roster repeats a date column.');
      }
      final date = DateTime(year, month, column.dayNumber);
      if (date.year != year ||
          date.month != month ||
          date.day != column.dayNumber) {
        throw const FormatException('A roster date is not valid.');
      }
      if (column.weekday != null && date.weekday != column.weekday) {
        throw FormatException(
          'The weekday for date ${column.dayNumber} does not match the selected month and year.',
        );
      }
      dates.add(date);
      previousDay = column.dayNumber;
    }
    return List.unmodifiable(dates);
  }

  List<List<OcrTextToken>> _groupRows(Iterable<OcrTextToken> source) {
    final ordered = source.toList()
      ..sort((a, b) => a.centerY.compareTo(b.centerY));
    final rows = <List<OcrTextToken>>[];
    for (final token in ordered) {
      if (rows.isEmpty ||
          (rows.last.first.centerY - token.centerY).abs() > _rowTolerance) {
        rows.add([token]);
      } else {
        rows.last.add(token);
      }
    }
    for (final row in rows) {
      row.sort((a, b) => a.centerX.compareTo(b.centerX));
    }
    return rows;
  }

  List<RosterGridRow> _dataRows(
    List<List<OcrTextToken>> rows,
    int headerIndex,
    List<double> centers,
  ) {
    final spacing = centers[1] - centers[0];
    final firstDateBoundary = centers.first - spacing / 2;
    final cells = List.generate(centers.length, (index) {
      final left = index == 0
          ? centers[index] - spacing / 2
          : (centers[index - 1] + centers[index]) / 2;
      final right = index == centers.length - 1
          ? centers[index] + spacing / 2
          : (centers[index] + centers[index + 1]) / 2;
      return (left, right);
    });
    final result = <RosterGridRow>[];
    for (final row in rows.skip(headerIndex + 1)) {
      final label = row
          .where((token) => token.centerX < firstDateBoundary)
          .map((token) => token.text.trim())
          .where((text) => text.isNotEmpty)
          .join(' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (label.length < 2) continue;
      // ML Kit groups a whole horizontal line together. A name-like token
      // inside date columns can be a second side-by-side staff row, so keep
      // every code on that line unresolved instead of assigning it to the
      // first label.
      final embeddedLabel = _hasEmbeddedStaffLabel(row, firstDateBoundary);
      final rowCells = <RosterGridCell>[];
      var populated = false;
      for (final bounds in cells) {
        final text = row
            .where(
              (token) =>
                  token.centerX >= bounds.$1 && token.centerX < bounds.$2,
            )
            .map((token) => token.text.trim())
            .where((value) => value.isNotEmpty)
            .join(' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        populated |= text.isNotEmpty;
        rowCells.add(
          RosterGridCell(
            text: text,
            isAmbiguous: embeddedLabel || _separatorsPattern.hasMatch(text),
          ),
        );
      }
      if (populated) {
        result.add(
          RosterGridRow(label: label, cells: List.unmodifiable(rowCells)),
        );
      }
    }
    return result;
  }

  OcrTextToken? _nearestWeekday(
    List<List<OcrTextToken>> rows,
    OcrTextToken dateToken, {
    required int dateRowIndex,
  }) {
    final matches = <(OcrTextToken, double)>[];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      if ((rowIndex - dateRowIndex).abs() > 1) continue;
      for (final token in rows[rowIndex]) {
        if (_weekdayPattern.hasMatch(token.text.trim()) &&
            (token.centerX - dateToken.centerX).abs() < .04 &&
            (token.centerY - dateToken.centerY).abs() < .055) {
          matches.add((token, (token.centerY - dateToken.centerY).abs()));
        }
      }
    }
    if (matches.isEmpty) return null;
    matches.sort((a, b) => a.$2.compareTo(b.$2));
    return matches.first.$1;
  }

  int? _dayNumber(String text) {
    final match = _dayPattern.firstMatch(text.trim());
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  int? _weekday(String text) {
    final value = text.trim().toLowerCase();
    if (value.startsWith('mon')) return DateTime.monday;
    if (value.startsWith('tue')) return DateTime.tuesday;
    if (value.startsWith('wed')) return DateTime.wednesday;
    if (value.startsWith('thu')) return DateTime.thursday;
    if (value.startsWith('fri')) return DateTime.friday;
    if (value.startsWith('sat')) return DateTime.saturday;
    if (value.startsWith('sun')) return DateTime.sunday;
    return null;
  }

  bool _reasonableColumns(List<double> centers) {
    final gaps = [
      for (var i = 1; i < centers.length; i++) centers[i] - centers[i - 1],
    ];
    if (gaps.isEmpty) return false;
    final orderedGaps = [...gaps]..sort();
    final typicalGap = orderedGaps[orderedGaps.length ~/ 2];
    return gaps.every(
      (gap) => gap >= .025 && gap <= .25 && gap <= typicalGap * 1.6,
    );
  }

  bool _hasEmbeddedStaffLabel(
    List<OcrTextToken> row,
    double firstDateBoundary,
  ) {
    final insideDateColumns =
        row.where((token) => token.centerX >= firstDateBoundary).toList()
          ..sort((a, b) => a.left.compareTo(b.left));
    for (var index = 0; index < insideDateColumns.length; index++) {
      final token = insideDateColumns[index];
      final text = token.text.trim();
      if (RegExp(r'^[A-Z][a-z]{2,}$').hasMatch(text)) return true;
      final isUppercaseWord = RegExp(r'^[A-Z]{3,}$').hasMatch(text);
      final isInitial = RegExp(r'^[A-Z]$').hasMatch(text);
      if ((!isUppercaseWord && !isInitial) ||
          index + 1 >= insideDateColumns.length) {
        continue;
      }
      final next = insideDateColumns[index + 1];
      final nextText = next.text.trim();
      final gap = next.left - token.right;
      final nextIsSurname = RegExp(r'^[A-Z]{5,}$').hasMatch(nextText);
      final nextIsUppercaseWord = RegExp(r'^[A-Z]{3,}$').hasMatch(nextText);
      final initialPlusSurname =
          RegExp(r'^[A-Z]$').hasMatch(text) && nextIsSurname;
      if (((isUppercaseWord &&
                  nextIsUppercaseWord &&
                  text.length + nextText.length >= 12) ||
              initialPlusSurname) &&
          gap >= -.01 &&
          gap <= .025) {
        // OCR may preserve an all-caps or title-case staff name as two
        // adjacent word boxes. Treat it as another row label; all codes on
        // this visual line remain unresolved until the user reviews them.
        return true;
      }
    }
    return false;
  }

  List<RosterGridCandidate> _deduplicate(List<RosterGridCandidate> items) {
    final seen = <String>{};
    return items.where((item) {
      final key =
          '${item.page}:${item.columns.map((c) => c.dayNumber).join(',')}:'
          '${item.headerTop.toStringAsFixed(3)}';
      return seen.add(key);
    }).toList();
  }
}
