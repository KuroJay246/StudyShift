import '../domain/work_code_legend.dart';
import 'roster_grid_import.dart';

/// A conservative, unsaved proposal set parsed from a shift-legend table.
class RosterLegendDetection {
  const RosterLegendDetection({
    required this.definitions,
    required this.hasLegendHeading,
    required this.ignoredRows,
  });

  final List<WorkCodeLegend> definitions;
  final bool hasLegendHeading;

  /// Rows that contain time ranges but could not be tied to a legend code.
  final int ignoredRows;
}

/// Finds code/time/assignment rows only beneath an explicit "SHIFT LEGEND"
/// heading. It proposes reference data and never writes to the database.
class RosterLegendImportParser {
  const RosterLegendImportParser();

  static final _codePattern = RegExp(r'^[A-Z0-9]{1,6}$');
  static final _timeRangePattern = RegExp(
    r'(?<![A-Z0-9])((?:\d{1,2}:\d{2}|\d{3,4}))(?:\s*([AP])\.?M\.?)?\s*[-–]\s*((?:\d{1,2}:\d{2}|\d{3,4}))(?:\s*([AP])\.?M\.?)?(?![A-Z0-9])',
    caseSensitive: false,
  );
  static final _flightPattern = RegExp(
    r'\b[A-Z]{1,3}\s*\d{2,5}(?:/\d{1,4})?\b',
    caseSensitive: false,
  );
  static final _unparsedTimeFragmentPattern = RegExp(
    r'\b\d{3,4}\s*[-–]\s*\d{1,4}[OIl]\w*',
    caseSensitive: false,
  );

  /// Avoid preselecting OCR definitions whose assignment text still contains
  /// an unreadable time-like fragment. The parsed window may have come from a
  /// neighboring token; users can verify the source before selecting it.
  bool isSafeToPreselect(WorkCodeLegend definition) =>
      !_unparsedTimeFragmentPattern.hasMatch(definition.assignmentDetails);

  RosterLegendDetection detect(List<OcrTextToken> tokens) {
    if (tokens.length > 50000) {
      throw const FormatException(
        'The document contains too much text to review.',
      );
    }
    final pageRows = <int, List<List<OcrTextToken>>>{};
    for (final page in tokens.map((token) => token.page).toSet()) {
      pageRows[page] = _groupRows(tokens.where((token) => token.page == page));
    }

    final definitions = <WorkCodeLegend>[];
    var hasLegendHeading = false;
    var ignoredRows = 0;
    for (final pageEntry in pageRows.entries) {
      final rows = pageEntry.value;
      for (var headerIndex = 0; headerIndex < rows.length; headerIndex++) {
        final header = rows[headerIndex];
        if (!_isLegendHeading(header)) continue;
        hasLegendHeading = true;
        final headerLeft = header
            .map((token) => token.left)
            .reduce((a, b) => a < b ? a : b);
        final headerY = _centerY(header);

        for (
          var rowIndex = headerIndex + 1;
          rowIndex < rows.length;
          rowIndex++
        ) {
          final row = rows[rowIndex];
          if (_centerY(row) - headerY > .75) break;
          final parsed = _parseLegendRow(
            row,
            headerLeft: headerLeft,
            page: pageEntry.key,
            rowIndex: rowIndex,
          );
          if (parsed == null) {
            if (_containsTimeRange(row)) ignoredRows++;
            continue;
          }
          definitions.add(parsed);
        }
      }
    }
    return RosterLegendDetection(
      definitions: List.unmodifiable(_deduplicate(definitions)),
      hasLegendHeading: hasLegendHeading,
      ignoredRows: ignoredRows,
    );
  }

  WorkCodeLegend? _parseLegendRow(
    List<OcrTextToken> row, {
    required double headerLeft,
    required int page,
    required int rowIndex,
  }) {
    final sorted = [...row]..sort((a, b) => a.left.compareTo(b.left));
    final joined = sorted.map((token) => token.text.trim()).join(' ');
    final ranges = _timeRangePattern.allMatches(joined).toList();
    if (ranges.isEmpty) return null;
    final firstRange = ranges.first;
    final timeStart = _textOffsetToTokenLeft(sorted, joined, firstRange.start);
    if (timeStart == null) return null;

    final eligibleCodes = sorted.where((token) {
      final code = _normalize(token.text);
      final center = token.centerX;
      return _codePattern.hasMatch(code) &&
          token.left >= headerLeft - .015 &&
          center < timeStart &&
          timeStart - center <= .12;
    }).toList();
    if (eligibleCodes.isEmpty) return null;
    eligibleCodes.sort((a, b) => b.centerX.compareTo(a.centerX));
    final codeToken = eligibleCodes.first;
    final code = _normalize(codeToken.text);
    final tokensAfterCode = sorted
        .where((token) => token.centerX > codeToken.centerX)
        .toList();
    final rangeText = tokensAfterCode.map((token) => token.text).join(' ');
    final parsedRanges = _timeRangePattern
        .allMatches(rangeText)
        .map(_timeWindow)
        .toList();
    if (parsedRanges.isEmpty || parsedRanges.any((window) => window == null)) {
      return null;
    }
    final windows = parsedRanges.cast<WorkCodeTimeWindow>();
    if (windows.any((window) => !window.isValid)) return null;

    final remainder = rangeText
        .replaceAll(_timeRangePattern, ' ')
        .replaceAll(RegExp(r'[;|,]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final flights = _flightPattern
        .allMatches(remainder)
        .map(
          (match) =>
              match.group(0)!.replaceAll(RegExp(r'\s+'), '').toUpperCase(),
        )
        .toSet()
        .toList(growable: false);
    final details = remainder.isEmpty ? '' : remainder;
    final id = 'ocr-legend-$page-$rowIndex-$code';
    return WorkCodeLegend(
      id: id,
      code: code,
      assignmentDetails: details,
      flightIds: flights,
      timeWindows: List.unmodifiable(windows),
    );
  }

  WorkCodeTimeWindow? _timeWindow(RegExpMatch match) {
    final startText = match.group(1)!;
    final endText = match.group(3)!;
    final startMeridiem = match.group(2)?.toUpperCase();
    final endMeridiem = match.group(4)?.toUpperCase();
    final hasMeridiem = startMeridiem != null || endMeridiem != null;
    final isColonTime = startText.contains(':') || endText.contains(':');
    final has24HourEvidence = [startText, endText].any((value) {
      final hour = _hour(value);
      return hour != null && hour > 12;
    });
    if (isColonTime && !hasMeridiem && !has24HourEvidence) return null;

    final starts = _parseClockCandidates(startText, startMeridiem);
    final ends = _parseClockCandidates(endText, endMeridiem);
    if (starts.isEmpty || ends.isEmpty) return null;
    final durations = [
      for (final start in starts)
        for (final end in ends)
          (start: start, end: end, duration: (end - start + 1440) % 1440),
    ]..sort((a, b) => a.duration.compareTo(b.duration));
    final selected = durations.first;
    if (selected.duration == 0) return null;
    return WorkCodeTimeWindow(
      startMinute: selected.start,
      endMinute: selected.end,
      endDayOffset: selected.end <= selected.start ? 1 : 0,
    );
  }

  List<int> _parseClockCandidates(String value, String? meridiem) {
    final hour = _hour(value);
    final minute = _minute(value);
    if (hour == null || minute == null || minute > 59) return const [];

    if (meridiem != null) {
      if (hour < 1 || hour > 12) return const [];
      return [((hour % 12) + (meridiem == 'P' ? 12 : 0)) * 60 + minute];
    }
    if (hour > 23) return const [];
    if (hour == 0 || hour > 12 || !value.contains(':')) {
      return [hour * 60 + minute];
    }
    // With an AM/PM marker on the other endpoint, either meridiem may fit;
    // _timeWindow chooses the shortest valid positive interval. Without any
    // marker, colon-formatted 1–12-hour ranges are rejected as ambiguous.
    return [hour % 12 * 60 + minute, (hour % 12 + 12) * 60 + minute];
  }

  int? _hour(String value) {
    if (value.contains(':')) return int.tryParse(value.split(':').first);
    final digits = value.padLeft(4, '0');
    return int.tryParse(digits.substring(0, 2));
  }

  int? _minute(String value) {
    if (value.contains(':')) return int.tryParse(value.split(':').last);
    final digits = value.padLeft(4, '0');
    return int.tryParse(digits.substring(2));
  }

  List<WorkCodeLegend> _deduplicate(List<WorkCodeLegend> entries) {
    final result = <WorkCodeLegend>[];
    final keys = <String>{};
    for (final entry in entries) {
      final key = [
        entry.code,
        entry.timeWindows
            .map(
              (window) =>
                  '${window.startMinute}-${window.endMinute}-${window.endDayOffset}',
            )
            .join(','),
        entry.assignmentDetails.toLowerCase(),
      ].join('|');
      if (keys.add(key)) result.add(entry);
    }
    return result;
  }

  List<List<OcrTextToken>> _groupRows(Iterable<OcrTextToken> source) {
    final tokens = [...source]..sort((a, b) => a.centerY.compareTo(b.centerY));
    if (tokens.isEmpty) return const [];
    final rowGroups = <List<OcrTextToken>>[];
    var current = <OcrTextToken>[tokens.first];
    var currentY = tokens.first.centerY;
    var height = (tokens.first.bottom - tokens.first.top).abs();
    for (final token in tokens.skip(1)) {
      final tokenHeight = (token.bottom - token.top).abs();
      final tolerance = (height > 0 ? height : tokenHeight).clamp(.002, .012);
      if ((token.centerY - currentY).abs() > tolerance) {
        current.sort((a, b) => a.left.compareTo(b.left));
        rowGroups.add(current);
        current = <OcrTextToken>[];
      }
      current.add(token);
      currentY =
          current.map((item) => item.centerY).reduce((a, b) => a + b) /
          current.length;
      height =
          current
              .map((item) => (item.bottom - item.top).abs())
              .reduce((a, b) => a + b) /
          current.length;
    }
    current.sort((a, b) => a.left.compareTo(b.left));
    rowGroups.add(current);
    return rowGroups;
  }

  bool _isLegendHeading(List<OcrTextToken> row) {
    final text = row.map((token) => token.text).join(' ').toUpperCase();
    return RegExp(r'\bSHIFT\s+LEGEND\b').hasMatch(text);
  }

  bool _containsTimeRange(List<OcrTextToken> row) =>
      _timeRangePattern.hasMatch(row.map((token) => token.text).join(' '));

  double? _textOffsetToTokenLeft(
    List<OcrTextToken> tokens,
    String joined,
    int offset,
  ) {
    var textOffset = 0;
    for (final token in tokens) {
      final text = token.text.trim();
      if (offset >= textOffset && offset <= textOffset + text.length) {
        return token.left;
      }
      textOffset += text.length + 1;
    }
    return null;
  }

  double _centerY(List<OcrTextToken> row) =>
      row.map((token) => token.centerY).reduce((a, b) => a + b) / row.length;

  String _normalize(String text) =>
      text.trim().replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
}
