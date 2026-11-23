import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:xml/xml.dart';

import 'csv_schedule_import.dart';
import 'schedule_import_models.dart';

/// Reads small, reviewed Shift & Study XLSX tables. Workbook content is
/// bounded and inspected before the spreadsheet decoder expands it in memory.
class XlsxScheduleImportParser {
  const XlsxScheduleImportParser({
    this._csvParser = const CsvScheduleImportParser(),
  });

  final CsvScheduleImportParser _csvParser;

  static const maxBytes = 5 * 1024 * 1024;
  static const maxExpandedBytes = 12 * 1024 * 1024;
  static const maxEntries = 128;
  static const maxSheets = 8;
  static const maxRowsPerSheet = 500;
  static const maxColumns = 32;

  Future<ScheduleImportPreview> parse(
    Uint8List bytes, {
    required String sourceName,
    Map<String, String>? headerMapping,
    DateTime? importedAt,
  }) async {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('This Excel file is empty or too large.');
    }
    final archive = _inspectZip(bytes);
    final workbookFile = archive.findFile('xl/workbook.xml');
    if (workbookFile == null) {
      throw const FormatException('Choose a valid .xlsx workbook.');
    }
    final workbookXml = _parseXml(
      Uint8List.fromList(workbookFile.content as List<int>),
    );
    final sheets = workbookXml.findAllElements('sheet').toList();
    if (sheets.isEmpty || sheets.length > maxSheets) {
      throw const FormatException('This workbook needs 1 to 8 worksheets.');
    }
    if (sheets.any(
      (sheet) =>
          sheet.getAttribute('state') != null &&
          sheet.getAttribute('state') != 'visible',
    )) {
      throw const FormatException('Unhide all worksheets before importing.');
    }

    var totalRows = 0;
    for (final entry in archive.files.where(
      (file) =>
          file.isFile &&
          file.name.startsWith('xl/worksheets/') &&
          file.name.endsWith('.xml'),
    )) {
      final document = _parseXml(
        Uint8List.fromList(entry.content as List<int>),
      );
      if (document.findAllElements('f').isNotEmpty) {
        throw const FormatException(
          'Remove formulas from the workbook before importing.',
        );
      }
      if (document
              .findAllElements('row')
              .any(
                (row) =>
                    row.getAttribute('hidden') == '1' ||
                    row.getAttribute('hidden') == 'true',
              ) ||
          document
              .findAllElements('col')
              .any(
                (column) =>
                    column.getAttribute('hidden') == '1' ||
                    column.getAttribute('hidden') == 'true',
              )) {
        throw const FormatException(
          'Unhide all rows and columns before importing.',
        );
      }
      final rowNodes = document.findAllElements('row').toList();
      totalRows += rowNodes.length;
      if (rowNodes.length > maxRowsPerSheet ||
          totalRows > CsvScheduleImportParser.maxRows) {
        throw const FormatException(
          'This workbook has too many rows to review at once.',
        );
      }
      for (final row in rowNodes) {
        final rowNumber = int.tryParse(row.getAttribute('r') ?? '');
        if (rowNumber == null || rowNumber > maxRowsPerSheet + 1) {
          throw const FormatException(
            'A worksheet has an unsupported sparse row layout.',
          );
        }
      }
      for (final cell in document.findAllElements('c')) {
        final reference = cell.getAttribute('r') ?? '';
        final match = RegExp(r'^([A-Z]+)([1-9][0-9]*)$').firstMatch(reference);
        if (match == null ||
            _columnNumber(match.group(1)!) > maxColumns ||
            int.parse(match.group(2)!) > maxRowsPerSheet + 1) {
          throw const FormatException(
            'A worksheet cell is outside the supported review area.',
          );
        }
      }
    }

    final decoder = XlsxDecoder(archive);
    final proposals = <ScheduleImportProposal>[];
    final notices = <ScheduleImportNotice>[];
    for (final sheet in sheets) {
      final name = sheet.getAttribute('name') ?? '';
      final table = decoder.tables[name];
      if (table == null || table.rows.isEmpty) continue;
      if (table.rows.length > maxRowsPerSheet + 1 ||
          table.maxCols > maxColumns) {
        throw const FormatException(
          'A worksheet is larger than its supported review area.',
        );
      }
      final rows = table.rows
          .map((row) => row.map(_cellText).toList())
          .toList();
      final sourceHeader = rows.first
          .map((value) => value.trim().toLowerCase())
          .toList();
      final header = _mappedHeaders(sourceHeader, headerMapping);
      if (header.isEmpty ||
          !header.contains('date') ||
          !header.contains('title') ||
          !header.contains('category')) {
        notices.add(
          ScheduleImportNotice(
            'Worksheet "$name" was skipped because its first row does not contain the documented date, title and category columns.',
          ),
        );
        continue;
      }
      final sourceIdIndex = header.indexOf('source_id');
      for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
        if (rows[rowIndex].every((value) => value.trim().isEmpty)) continue;
        while (rows[rowIndex].length < header.length) {
          rows[rowIndex].add('');
        }
        if (rows[rowIndex].length > header.length) {
          notices.add(
            ScheduleImportNotice(
              'Worksheet "$name", row ${rowIndex + 1} has extra cells and was skipped.',
            ),
          );
          continue;
        }
        if (sourceIdIndex >= 0 &&
            rows[rowIndex][sourceIdIndex].trim().isNotEmpty) {
          rows[rowIndex][sourceIdIndex] =
              '$name:${rows[rowIndex][sourceIdIndex].trim()}';
        }
      }
      final mappedRows = headerMapping == null
          ? rows
          : [
              [
                for (var i = 0; i < header.length; i++)
                  if (header[i].isNotEmpty) header[i],
              ],
              for (final row in rows.skip(1))
                [
                  for (var i = 0; i < header.length; i++)
                    if (header[i].isNotEmpty) row[i],
                ],
            ];
      final normalizedCsv = mappedRows.map(_csvLine).join('\n');
      final preview = await _csvParser.parse(
        normalizedCsv,
        sourceName: '$sourceName · $name',
        importedAt: importedAt,
      );
      proposals.addAll(preview.proposals);
      notices.addAll(preview.notices);
    }
    if (proposals.isEmpty && notices.isEmpty) {
      notices.add(
        const ScheduleImportNotice('No supported schedule rows were found.'),
      );
    }
    return ScheduleImportPreview(proposals: proposals, notices: notices);
  }

  /// Reads coworker-only worksheets without requiring event titles, times, or
  /// categories. It applies the same ZIP, XML, formula, visibility, and size
  /// checks as calendar imports before matching rows to saved shifts.
  CoworkerRosterPreview parseCoworkerRoster(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('This Excel file is empty or too large.');
    }
    final archive = _inspectZip(bytes);
    final workbookFile = archive.findFile('xl/workbook.xml');
    if (workbookFile == null) {
      throw const FormatException('Choose a valid .xlsx workbook.');
    }
    final workbookXml = _parseXml(
      Uint8List.fromList(workbookFile.content as List<int>),
    );
    final sheets = workbookXml.findAllElements('sheet').toList();
    if (sheets.isEmpty || sheets.length > maxSheets) {
      throw const FormatException('This workbook needs 1 to 8 worksheets.');
    }
    if (sheets.any(
      (sheet) =>
          sheet.getAttribute('state') != null &&
          sheet.getAttribute('state') != 'visible',
    )) {
      throw const FormatException('Unhide all worksheets before importing.');
    }

    var totalRows = 0;
    for (final entry in archive.files.where(
      (file) =>
          file.isFile &&
          file.name.startsWith('xl/worksheets/') &&
          file.name.endsWith('.xml'),
    )) {
      final document = _parseXml(
        Uint8List.fromList(entry.content as List<int>),
      );
      if (document.findAllElements('f').isNotEmpty) {
        throw const FormatException(
          'Remove formulas from the workbook before importing.',
        );
      }
      if (document
              .findAllElements('row')
              .any(
                (row) =>
                    row.getAttribute('hidden') == '1' ||
                    row.getAttribute('hidden') == 'true',
              ) ||
          document
              .findAllElements('col')
              .any(
                (column) =>
                    column.getAttribute('hidden') == '1' ||
                    column.getAttribute('hidden') == 'true',
              )) {
        throw const FormatException(
          'Unhide all rows and columns before importing.',
        );
      }
      final rowNodes = document.findAllElements('row').toList();
      totalRows += rowNodes.length;
      if (rowNodes.length > maxRowsPerSheet ||
          totalRows > CsvScheduleImportParser.maxRows) {
        throw const FormatException(
          'This workbook has too many rows to review at once.',
        );
      }
      for (final row in rowNodes) {
        final rowNumber = int.tryParse(row.getAttribute('r') ?? '');
        if (rowNumber == null || rowNumber > maxRowsPerSheet + 1) {
          throw const FormatException(
            'A worksheet has an unsupported sparse row layout.',
          );
        }
      }
      for (final cell in document.findAllElements('c')) {
        final reference = cell.getAttribute('r') ?? '';
        final match = RegExp(r'^([A-Z]+)([1-9][0-9]*)$').firstMatch(reference);
        if (match == null ||
            _columnNumber(match.group(1)!) > maxColumns ||
            int.parse(match.group(2)!) > maxRowsPerSheet + 1) {
          throw const FormatException(
            'A worksheet cell is outside the supported review area.',
          );
        }
      }
    }

    final decoder = XlsxDecoder(archive);
    final normalizedRows = <String>['date,code,coworkers,employer'];
    final notices = <String>[];
    var recognizedSheetCount = 0;
    for (final sheet in sheets) {
      final sheetName = sheet.getAttribute('name') ?? '';
      final table = decoder.tables[sheetName];
      if (table == null || table.rows.isEmpty) continue;
      if (table.rows.length > maxRowsPerSheet + 1 ||
          table.maxCols > maxColumns) {
        throw const FormatException(
          'A worksheet is larger than its supported review area.',
        );
      }
      final rows = table.rows
          .map((row) => row.map(_cellText).toList())
          .toList();
      final headers = rows.first
          .map((value) => value.trim().toLowerCase().replaceAll(' ', '_'))
          .toList(growable: false);
      final dateIndex = headers.indexWhere(
        const {'date', 'shift_date', 'work_date'}.contains,
      );
      final codeIndex = headers.indexWhere(
        const {'code', 'shift_code', 'roster_code'}.contains,
      );
      final coworkersIndex = headers.indexWhere(
        const {'coworkers', 'coworker', 'colleagues'}.contains,
      );
      final employerIndex = headers.indexOf('employer');
      if (headers.toSet().length != headers.length ||
          headers.any((header) => header.isEmpty)) {
        notices.add(
          'Worksheet "$sheetName" has blank or repeated headings and was skipped.',
        );
        continue;
      }
      if (dateIndex < 0 || codeIndex < 0 || coworkersIndex < 0) {
        notices.add(
          'Worksheet "$sheetName" was skipped because it needs date, code and coworkers columns.',
        );
        continue;
      }
      recognizedSheetCount++;
      for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        if (row.every((value) => value.trim().isEmpty)) continue;
        while (row.length < headers.length) {
          row.add('');
        }
        if (row.length > headers.length) {
          notices.add(
            'Worksheet "$sheetName", row ${rowIndex + 1} has extra cells and was skipped.',
          );
          continue;
        }
        normalizedRows.add(
          _csvLine([
            row[dateIndex],
            row[codeIndex],
            row[coworkersIndex],
            employerIndex < 0 ? '' : row[employerIndex],
          ]),
        );
      }
    }
    if (recognizedSheetCount == 0) {
      throw const FormatException(
        'No worksheet has date, code and coworkers columns.',
      );
    }
    if (normalizedRows.length - 1 > CsvScheduleImportParser.maxRows) {
      throw const FormatException(
        'This workbook has too many coworker rows to review at once.',
      );
    }
    final parsed = _csvParser.parseCoworkerRoster(normalizedRows.join('\n'));
    return CoworkerRosterPreview(
      assignments: parsed.assignments,
      notices: List.unmodifiable([...notices, ...parsed.notices]),
    );
  }

  /// Returns the first visible worksheet's header row for a local mapping step.
  /// Parsing still performs the complete workbook safety checks before use.
  List<String> inspectHeaders(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('This Excel file is empty or too large.');
    }
    final archive = _inspectZip(bytes);
    final workbookFile = archive.findFile('xl/workbook.xml');
    if (workbookFile == null) {
      throw const FormatException('Choose a valid .xlsx workbook.');
    }
    final workbookXml = _parseXml(
      Uint8List.fromList(workbookFile.content as List<int>),
    );
    final sheets = workbookXml.findAllElements('sheet').toList();
    if (sheets.isEmpty ||
        sheets.length > maxSheets ||
        sheets.any(
          (sheet) =>
              sheet.getAttribute('state') != null &&
              sheet.getAttribute('state') != 'visible',
        )) {
      throw const FormatException('This workbook needs visible worksheets.');
    }
    final decoder = XlsxDecoder(archive);
    for (final sheet in sheets) {
      final name = sheet.getAttribute('name') ?? '';
      final table = decoder.tables[name];
      if (table == null || table.rows.isEmpty) continue;
      final headers = table.rows.first
          .map(_cellText)
          .map((value) => value.trim())
          .toList();
      if (headers.isEmpty ||
          headers.any((header) => header.isEmpty) ||
          headers.map((header) => header.toLowerCase()).toSet().length !=
              headers.length) {
        throw const FormatException(
          'The worksheet header contains a blank or repeated column name.',
        );
      }
      return List.unmodifiable(headers);
    }
    throw const FormatException('This workbook has no worksheet rows to map.');
  }

  List<String> _mappedHeaders(
    List<String> sourceHeaders,
    Map<String, String>? headerMapping,
  ) {
    if (headerMapping == null) return sourceHeaders;
    const allowed = {
      'date',
      'end_date',
      'title',
      'category',
      'start',
      'end',
      'time_zone',
      'code',
      'code_meaning',
      'coworkers',
      'employer',
      'department',
      'job_role',
      'location',
      'notes',
      'reporting_instruction',
      'supervisor_name',
      'supervisor_phone',
      'contact_name',
      'contact_phone',
      'source_id',
    };
    final normalized = <String, String>{};
    for (final entry in headerMapping.entries) {
      final source = entry.key.trim().toLowerCase();
      final target = entry.value.trim().toLowerCase();
      if (!sourceHeaders.contains(source) ||
          !allowed.contains(target) ||
          normalized.containsValue(target)) {
        throw const FormatException('The selected column mapping is invalid.');
      }
      normalized[source] = target;
    }
    return sourceHeaders.map((header) => normalized[header] ?? '').toList();
  }

  static Archive _inspectZip(Uint8List bytes) {
    // Read only the central directory first, preventing decompression of
    // encrypted, ZIP64 or oversized entries by the XLSX package.
    final data = ByteData.sublistView(bytes);
    final lowerBound = bytes.length - 22 - 65535;
    var eocd = -1;
    for (
      var offset = bytes.length - 22;
      offset >= lowerBound && offset >= 0;
      offset--
    ) {
      if (data.getUint32(offset, Endian.little) == 0x06054b50) {
        eocd = offset;
        break;
      }
    }
    if (eocd < 0 ||
        data.getUint16(eocd + 4, Endian.little) != 0 ||
        data.getUint16(eocd + 6, Endian.little) != 0) {
      throw const FormatException(
        'This workbook has an unsupported ZIP structure.',
      );
    }
    final count = data.getUint16(eocd + 10, Endian.little);
    final directorySize = data.getUint32(eocd + 12, Endian.little);
    final directoryOffset = data.getUint32(eocd + 16, Endian.little);
    if (count == 0 ||
        count > maxEntries ||
        count == 0xffff ||
        directorySize == 0xffffffff ||
        directoryOffset == 0xffffffff ||
        directoryOffset + directorySize > eocd) {
      throw const FormatException(
        'This workbook has an unsupported or oversized ZIP directory.',
      );
    }
    var offset = directoryOffset;
    var expanded = 0;
    final names = <String>{};
    final dataRanges = <(int, int)>[];
    for (var index = 0; index < count; index++) {
      if (offset + 46 > bytes.length ||
          data.getUint32(offset, Endian.little) != 0x02014b50) {
        throw const FormatException(
          'This workbook has an invalid ZIP directory.',
        );
      }
      final flags = data.getUint16(offset + 8, Endian.little);
      final compressed = data.getUint32(offset + 20, Endian.little);
      final uncompressed = data.getUint32(offset + 24, Endian.little);
      final nameLength = data.getUint16(offset + 28, Endian.little);
      final extraLength = data.getUint16(offset + 30, Endian.little);
      final commentLength = data.getUint16(offset + 32, Endian.little);
      final localOffset = data.getUint32(offset + 42, Endian.little);
      final next = offset + 46 + nameLength + extraLength + commentLength;
      if (next > directoryOffset + directorySize ||
          flags & 1 != 0 ||
          compressed == 0xffffffff ||
          uncompressed == 0xffffffff ||
          uncompressed > 4 * 1024 * 1024 ||
          (data.getUint16(offset + 10, Endian.little) != 0 &&
              data.getUint16(offset + 10, Endian.little) != 8)) {
        throw const FormatException(
          'This workbook contains an unsupported ZIP entry.',
        );
      }
      final name = utf8.decode(
        bytes.sublist(offset + 46, offset + 46 + nameLength),
        allowMalformed: false,
      );
      if (name.startsWith('/') ||
          name.split('/').contains('..') ||
          name.contains('\\') ||
          !names.add(name)) {
        throw const FormatException('This workbook has an unsafe ZIP path.');
      }
      if (localOffset + 30 > directoryOffset ||
          data.getUint32(localOffset, Endian.little) != 0x04034b50) {
        throw const FormatException('This workbook has an invalid ZIP entry.');
      }
      final localFlags = data.getUint16(localOffset + 6, Endian.little);
      final localMethod = data.getUint16(localOffset + 8, Endian.little);
      final localNameLength = data.getUint16(localOffset + 26, Endian.little);
      final localExtraLength = data.getUint16(localOffset + 28, Endian.little);
      final localNameEnd = localOffset + 30 + localNameLength;
      final contentStart = localNameEnd + localExtraLength;
      final contentEnd = contentStart + compressed;
      if (localFlags != flags ||
          localMethod != data.getUint16(offset + 10, Endian.little) ||
          localNameEnd > directoryOffset ||
          utf8.decode(bytes.sublist(localOffset + 30, localNameEnd)) != name ||
          contentStart > directoryOffset ||
          contentEnd > directoryOffset ||
          dataRanges.any(
            (range) => contentStart < range.$2 && range.$1 < contentEnd,
          )) {
        throw const FormatException('This workbook has an invalid ZIP entry.');
      }
      dataRanges.add((contentStart, contentEnd));
      final method = localMethod;
      if (method == 0 && compressed != uncompressed) {
        throw const FormatException(
          'This workbook has an invalid stored entry.',
        );
      }
      if (method == 8) {
        try {
          final inflated = Inflate.buffer(
            InputStream(bytes.sublist(contentStart, contentEnd)),
            uncompressed,
          ).getBytes();
          if (inflated.length != uncompressed) {
            throw const FormatException(
              'This workbook has an invalid compressed entry.',
            );
          }
        } on RangeError {
          throw const FormatException(
            'This workbook expands beyond its declared size.',
          );
        }
      }
      expanded += uncompressed;
      if (expanded > maxExpandedBytes) {
        throw const FormatException(
          'This workbook expands beyond the supported size.',
        );
      }
      offset = next;
    }
    if (offset != directoryOffset + directorySize) {
      throw const FormatException(
        'This workbook has an invalid ZIP directory size.',
      );
    }
    return ZipDecoder().decodeBytes(bytes, verify: true);
  }

  static XmlDocument _parseXml(Uint8List bytes) {
    if (bytes.length > 4 * 1024 * 1024) {
      throw const FormatException('A workbook XML section is too large.');
    }
    final source = utf8.decode(bytes, allowMalformed: false);
    if (source.contains('<!DOCTYPE') || source.contains('<!ENTITY')) {
      throw const FormatException(
        'This workbook contains unsupported XML declarations.',
      );
    }
    try {
      return XmlDocument.parse(source);
    } on XmlException {
      throw const FormatException('This workbook contains invalid XML.');
    }
  }

  static int _columnNumber(String letters) {
    var number = 0;
    for (final rune in letters.runes) {
      number = number * 26 + rune - 64;
    }
    return number;
  }

  static String _cellText(Object? value) {
    if (value == null) return '';
    var text = value.toString();
    final date = RegExp(r'^(\d{4}-\d{2}-\d{2})T00:00:00(?:\.000)?$')
        .firstMatch(text);
    if (date != null) return date.group(1)!;
    final time = RegExp(r'^(\d{2}:\d{2}):00$').firstMatch(text);
    if (time != null) return time.group(1)!;
    return text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  }

  static String _csvLine(List<String> fields) =>
      fields.map((field) => '"${field.replaceAll('"', '""')}"').join(',');
}
