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
  const RosterGridColumn({
    required this.dayNumber,
    this.weekday,
    this.month,
    this.year,
  });

  final int dayNumber;
  final int? weekday;
  final int? month;
  final int? year;
}

class _RosterDateHeader {
  const _RosterDateHeader({required this.day, this.month, this.year});

  final int day;
  final int? month;
  final int? year;
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
    r'^\s*(?:mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)[,./ -]+([1-9]|[12]\d|3[01])(?:st|nd|rd|th)?\s*$|^\s*([1-9]|[12]\d|3[01])(?:st|nd|rd|th)?\s*$',
    caseSensitive: false,
  );
  static final _isoDatePattern = RegExp(
    r'^\s*(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\s*$',
  );
  static final _weekdayInTextPattern = RegExp(
    r'\b(mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b',
    caseSensitive: false,
  );
  static final _separatorsPattern = RegExp(r'[/|,;]');

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
                .where((token) => _dateHeader(token.text) != null)
                .toList()
              ..sort((a, b) => a.centerX.compareTo(b.centerX));
        if (dateTokens.length < 3) continue;
        final dateHeaders = dateTokens
            .map((token) => _dateHeader(token.text)!)
            .toList(growable: false);
        final dateKeys = dateHeaders.map((header) {
          if (header.month == null) return 'day:${header.day}';
          return '${header.year ?? ''}-${header.month}-${header.day}';
        });
        if (dateKeys.toSet().length != dateTokens.length) continue;
        final columns = <RosterGridColumn>[];
        final centers = <double>[];
        for (var dateIndex = 0; dateIndex < dateTokens.length; dateIndex++) {
          final token = dateTokens[dateIndex];
          final header = dateHeaders[dateIndex];
          final day = header.day;
          if (columns.isNotEmpty &&
              (token.centerX - centers.last).abs() < .025) {
            continue;
          }
          final neighboringGaps = <double>[
            if (dateIndex > 0)
              (token.centerX - dateTokens[dateIndex - 1].centerX).abs(),
            if (dateIndex + 1 < dateTokens.length)
              (dateTokens[dateIndex + 1].centerX - token.centerX).abs(),
          ];
          final weekdaySearchRadius = neighboringGaps.isEmpty
              ? .02
              : (neighboringGaps.reduce((a, b) => a < b ? a : b) * .45)
                    .clamp(.005, .04)
                    .toDouble();
          final weekdayToken = _nearestWeekday(
            rows,
            token,
            dateRowIndex: index,
            maxHorizontalDistance: weekdaySearchRadius,
          );
          columns.add(
            RosterGridColumn(
              dayNumber: day,
              weekday:
                  _weekdayFromText(token.text) ??
                  (weekdayToken == null
                      ? null
                      : _weekdayFromText(weekdayToken.text)),
              month: header.month,
              year: header.year,
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
        table.columns.first.dayNumber != firstDate.day ||
        (table.columns.first.month != null &&
            table.columns.first.month != firstDate.month) ||
        (table.columns.first.year != null &&
            table.columns.first.year != firstDate.year)) {
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
      if (column.year != null) {
        year = column.year!;
      }
      if (column.month != null) {
        if (index > 0 && column.year == null && column.month! < month) {
          year++;
        }
        month = column.month!;
      } else if (index > 0 && column.dayNumber < previousDay) {
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
      } else if (column.month == null &&
          index > 0 &&
          column.dayNumber == previousDay) {
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
    final heights = ordered.map((token) => token.bottom - token.top).toList()
      ..sort();
    final medianHeight = heights.isEmpty ? 0 : heights[heights.length ~/ 2];
    final rowTolerance = (medianHeight * .9).clamp(.004, .014).toDouble();
    final rows = <List<OcrTextToken>>[];
    for (final token in ordered) {
      if (rows.isEmpty ||
          (rows.last.first.centerY - token.centerY).abs() > rowTolerance) {
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
      final label = _rowLabel(
        row.where((token) => token.centerX < firstDateBoundary),
      );
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

  String _rowLabel(Iterable<OcrTextToken> source) {
    final words = <(String, OcrTextToken)>[];
    for (final token in source) {
      for (final rawWord in token.text.split(RegExp(r'\s+'))) {
        final word = rawWord.replaceAll(RegExp(r'^[!$|]+|[!$|]+$'), '').trim();
        if (word.isEmpty || !RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(word)) continue;
        if (_looksLikeRosterMarker((word, token))) continue;
        final normalized = word.toLowerCase();
        final isRepeatedCopy = words.any((existing) {
          if (existing.$1.toLowerCase() != normalized) return false;
          final previous = existing.$2;
          final overlapWidth =
              (previous.right < token.right ? previous.right : token.right) -
              (previous.left > token.left ? previous.left : token.left);
          final overlapHeight =
              (previous.bottom < token.bottom
                  ? previous.bottom
                  : token.bottom) -
              (previous.top > token.top ? previous.top : token.top);
          final intersection =
              (overlapWidth > 0 ? overlapWidth : 0) *
              (overlapHeight > 0 ? overlapHeight : 0);
          final previousArea =
              (previous.right - previous.left) *
              (previous.bottom - previous.top);
          final tokenArea =
              (token.right - token.left) * (token.bottom - token.top);
          final smallerArea = previousArea < tokenArea
              ? previousArea
              : tokenArea;
          final verticalDistance = (previous.centerY - token.centerY).abs();
          final horizontalGap = (previous.right <= token.left)
              ? token.left - previous.right
              : (token.right <= previous.left)
              ? previous.left - token.right
              : 0.0;
          final nearbyRepeatedWord =
              verticalDistance <= .015 && horizontalGap <= .03;
          return (smallerArea > 0 && intersection / smallerArea >= .1) ||
              nearbyRepeatedWord;
        });
        if (!isRepeatedCopy) words.add((word, token));
      }
    }
    final cleanedWords = <(String, OcrTextToken)>[];
    for (final candidate in words) {
      if (cleanedWords.isNotEmpty) {
        final previous = cleanedWords.last;
        if (previous.$1.toLowerCase() == candidate.$1.toLowerCase()) {
          continue;
        }
        if (_looksLikeRepeatedOcrWord(previous, candidate)) {
          if (candidate.$1.length > previous.$1.length) {
            cleanedWords[cleanedWords.length - 1] = candidate;
          }
          continue;
        }
      }
      cleanedWords.add(candidate);
    }
    return cleanedWords.map((word) => word.$1).join(' ');
  }

  bool _looksLikeRepeatedOcrWord(
    (String, OcrTextToken) previous,
    (String, OcrTextToken) candidate,
  ) {
    if (previous.$1.length < 5 || candidate.$1.length < 5) return false;
    final left = previous.$1.toLowerCase();
    final right = candidate.$1.toLowerCase();
    if (!_editDistanceAtMostOne(left, right)) return false;
    final a = previous.$2;
    final b = candidate.$2;
    final verticalDistance = (a.centerY - b.centerY).abs();
    final horizontalGap = a.right <= b.left
        ? b.left - a.right
        : b.right <= a.left
        ? a.left - b.right
        : 0.0;
    return verticalDistance <= .015 && horizontalGap <= .06;
  }

  bool _editDistanceAtMostOne(String left, String right) {
    if ((left.length - right.length).abs() > 1) return false;
    var leftIndex = 0;
    var rightIndex = 0;
    var edits = 0;
    while (leftIndex < left.length && rightIndex < right.length) {
      if (left[leftIndex] == right[rightIndex]) {
        leftIndex++;
        rightIndex++;
        continue;
      }
      edits++;
      if (edits > 1) return false;
      if (left.length > right.length) {
        leftIndex++;
      } else if (right.length > left.length) {
        rightIndex++;
      } else {
        leftIndex++;
        rightIndex++;
      }
    }
    if (leftIndex < left.length || rightIndex < right.length) edits++;
    return edits <= 1;
  }

  bool _looksLikeRosterMarker((String, OcrTextToken) candidate) {
    final text = candidate.$1.toLowerCase();
    // Decorative roster marks after names can be recognized as an S or "Is"
    // even when OCR gives them a full-width text box.
    if (text == 's' || text == 'is') return true;
    final token = candidate.$2;
    final width = token.right - token.left;
    final height = token.bottom - token.top;
    if (RegExp(r'^[il1|]{1,2}s$').hasMatch(text)) {
      return height > 0 && width / height <= 1;
    }
    if (!RegExp(r'^[il1|]{1,2}$').hasMatch(text)) return false;
    return height > 0 && width / height <= .65;
  }

  OcrTextToken? _nearestWeekday(
    List<List<OcrTextToken>> rows,
    OcrTextToken dateToken, {
    required int dateRowIndex,
    required double maxHorizontalDistance,
  }) {
    final matches = <(OcrTextToken, double)>[];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      if ((rowIndex - dateRowIndex).abs() > 1) continue;
      for (final token in rows[rowIndex]) {
        if (_weekdayFromText(token.text) != null &&
            (token.centerX - dateToken.centerX).abs() < maxHorizontalDistance &&
            (token.centerY - dateToken.centerY).abs() < .055) {
          matches.add((token, (token.centerY - dateToken.centerY).abs()));
        }
      }
    }
    if (matches.isEmpty) return null;
    matches.sort((a, b) => a.$2.compareTo(b.$2));
    return matches.first.$1;
  }

  _RosterDateHeader? _dateHeader(String text) {
    final iso = _isoDatePattern.firstMatch(text);
    if (iso != null) {
      final year = int.tryParse(iso.group(1)!);
      final month = int.tryParse(iso.group(2)!);
      final day = int.tryParse(iso.group(3)!);
      if (year != null && month != null && day != null) {
        return _RosterDateHeader(day: day, month: month, year: year);
      }
      return null;
    }
    final match = _dayPattern.firstMatch(text.trim());
    if (match == null) return null;
    final day = int.tryParse(match.group(1) ?? match.group(2)!);
    return day == null ? null : _RosterDateHeader(day: day);
  }

  int? _weekdayFromText(String text) {
    final match = _weekdayInTextPattern.firstMatch(text.trim());
    if (match == null) return null;
    final value = match.group(1)!.toLowerCase();
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
      final columnsKey = item.columns
          .map((column) {
            return '${column.year ?? ''}-${column.month ?? ''}-${column.dayNumber}';
          })
          .join(',');
      final key =
          '${item.page}:$columnsKey:${item.headerTop.toStringAsFixed(3)}';
      return seen.add(key);
    }).toList();
  }
}
