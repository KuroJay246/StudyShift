import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import '../domain/civil_time_resolver.dart';
import '../domain/schedule.dart';
import 'roster_grid_import.dart';
import 'schedule_import_models.dart';

/// Imports the documented Shift & Study CSV v1 format. Unknown fields and
/// ambiguous wall times are reported for correction instead of inferred.
class CsvScheduleImportParser {
  const CsvScheduleImportParser();

  static const maxBytes = 5 * 1024 * 1024;
  static const maxRows = 500;
  static final _sha256 = Sha256();
  static bool _timeZonesInitialized = false;

  /// Detects date-across-columns rosters using the same offline table parser
  /// as scanned roster documents. Empty detection means normal row parsing
  /// should continue.
  RosterGridDetection detectRosterGrid(String source) {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException('This CSV file is too large.');
    }
    if (source.trim().isEmpty) {
      throw const FormatException('The selected CSV file is empty.');
    }
    final records = _parseRecords(source);
    if (records.length > maxRows + 1) {
      throw const FormatException(
        'This CSV file has too many rows to review at once.',
      );
    }
    final rows = records.map((record) => record.fields).toList();
    final columns = rows.fold<int>(
      0,
      (maximum, row) => row.length > maximum ? row.length : maximum,
    );
    if (columns < 4 || columns > 32) {
      return const RosterGridDetection([]);
    }
    return const RosterGridImportParser().detectMatrix(rows);
  }

  /// Reads a coworker-only roster CSV. Unlike [parse], this input never
  /// proposes new schedule events; rows are grouped for matching to saved
  /// work shifts by civil date and roster code.
  CoworkerRosterPreview parseCoworkerRoster(String source) {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException('This CSV file is too large.');
    }
    if (source.trim().isEmpty) {
      throw const FormatException('The selected CSV file is empty.');
    }
    final records = _parseRecords(source);
    if (records.isEmpty) {
      throw const FormatException('This CSV file has no header row.');
    }
    final headers = records.first.fields
        .map((field) => field.trim().toLowerCase().replaceAll(' ', '_'))
        .toList();
    if (headers.isNotEmpty && headers.first.startsWith('\uFEFF')) {
      headers[0] = headers[0].replaceFirst('\uFEFF', '');
    }
    const dateAliases = {'date', 'shift_date', 'work_date'};
    const codeAliases = {'code', 'shift_code', 'roster_code'};
    const coworkerAliases = {'coworkers', 'coworker', 'colleagues'};
    const coworkerCodeAliases = {
      'coworker_code',
      'coworker_codes',
      'colleague_code',
      'colleague_codes',
    };
    final dateIndex = headers.indexWhere(dateAliases.contains);
    final codeIndex = headers.indexWhere(codeAliases.contains);
    final coworkerIndex = headers.indexWhere(coworkerAliases.contains);
    final coworkerCodesIndex = headers.indexWhere(coworkerCodeAliases.contains);
    final employerIndex = headers.indexOf('employer');
    if (headers.toSet().length != headers.length ||
        headers.any((header) => header.isEmpty)) {
      throw const FormatException(
        'The CSV header contains a blank or repeated column name.',
      );
    }
    if (dateIndex < 0 || codeIndex < 0 || coworkerIndex < 0) {
      throw const FormatException(
        'A coworker roster needs date, code, and coworkers columns.',
      );
    }
    if (records.length - 1 > maxRows) {
      throw const FormatException(
        'This CSV file has too many rows to review at once.',
      );
    }
    final grouped = <String, _CoworkerRosterBuilder>{};
    final notices = <String>[];
    for (final record in records.skip(1)) {
      if (record.fields.every((field) => field.trim().isEmpty)) continue;
      if (record.fields.length != headers.length) {
        notices.add(
          'Row ${record.line} has a different number of fields than the header.',
        );
        continue;
      }
      try {
        final date = _date(record.fields[dateIndex], 'date');
        final code = record.fields[codeIndex].trim();
        if (code.isEmpty) throw const FormatException('The code is blank.');
        final employer = employerIndex < 0
            ? null
            : _optional(record.fields[employerIndex]);
        final names = _coworkerValues(record.fields[coworkerIndex]);
        if (names.isEmpty) {
          throw const FormatException('No coworker names were supplied.');
        }
        final rawCoworkerCodes = coworkerCodesIndex < 0
            ? ''
            : record.fields[coworkerCodesIndex].trim();
        final coworkerCodes = rawCoworkerCodes.isEmpty
            ? null
            : _coworkerValues(rawCoworkerCodes);
        if (coworkerCodes != null && coworkerCodes.length != names.length) {
          throw const FormatException(
            'A coworker-code row needs the same number of names and codes.',
          );
        }
        final key =
            '${date.toString()}|${_normalizeCode(code)}|${employer?.toLowerCase() ?? ''}';
        final builder = grouped.putIfAbsent(
          key,
          () => _CoworkerRosterBuilder(
            date: date,
            code: code,
            employer: employer,
          ),
        );
        final sameCodeNames = coworkerCodes == null
            ? names
            : [
                for (var index = 0; index < names.length; index++)
                  if (_normalizeCode(coworkerCodes[index]) ==
                      _normalizeCode(code))
                    names[index],
              ];
        final excludedCount = names.length - sameCodeNames.length;
        builder.add(
          sameCodeNames,
          record.line,
          sameRosterCodeVerified: coworkerCodes != null,
        );
        if (excludedCount > 0) {
          final excludedMessage = excludedCount == 1
              ? '1 coworker with a different roster code was excluded.'
              : '$excludedCount coworkers with different roster codes were excluded.';
          notices.add('Row ${record.line}: $excludedMessage');
        }
      } on FormatException catch (error) {
        notices.add('Row ${record.line}: ${error.message}');
      }
    }
    final assignments = grouped.values
        .map((row) => row.build())
        .toList(growable: false);
    for (final assignment in assignments) {
      if (!assignment.sameRosterCodeVerified) {
        notices.add(
          '${assignment.date} · ${assignment.code}: coworker codes are missing, so this name list must be checked manually and will start unchecked.',
        );
      }
    }
    return CoworkerRosterPreview(
      assignments: assignments,
      notices: List.unmodifiable(notices),
    );
  }

  Future<ScheduleImportPreview> parse(
    String source, {
    required String sourceName,
    Map<String, String>? headerMapping,
    DateTime? importedAt,
  }) async {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException('This CSV file is too large.');
    }
    if (source.trim().isEmpty) {
      throw const FormatException('The selected CSV file is empty.');
    }
    _initializeTimeZones();
    final records = _parseRecords(source);
    if (records.isEmpty) {
      throw const FormatException('This CSV file has no header row.');
    }
    final sourceHeaders = records.first.fields
        .map((field) => field.trim().toLowerCase())
        .toList();
    if (sourceHeaders.isNotEmpty && sourceHeaders[0].startsWith('\uFEFF')) {
      sourceHeaders[0] = sourceHeaders[0].replaceFirst('\uFEFF', '');
    }
    if (sourceHeaders.toSet().length != sourceHeaders.length ||
        sourceHeaders.any((header) => header.isEmpty)) {
      throw const FormatException(
        'The CSV header contains a blank or repeated column name.',
      );
    }
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
      'coworker_codes',
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
    final headers = _mappedHeaders(sourceHeaders, allowed, headerMapping);
    final unknown = sourceHeaders.where(
      (header) => headerMapping == null && !allowed.contains(header),
    );
    if (unknown.isNotEmpty) {
      throw FormatException(
        'Unsupported CSV columns: ${unknown.join(', ')}. Rename or remove them before importing.',
      );
    }
    for (final required in ['date', 'title', 'category']) {
      if (!headers.contains(required)) {
        throw FormatException('This CSV file needs a "$required" column.');
      }
    }
    if (records.length - 1 > maxRows) {
      throw const FormatException(
        'This CSV file has too many rows to review at once.',
      );
    }
    final timestamp = (importedAt ?? DateTime.now()).toUtc();
    final proposals = <String, ScheduleImportProposal>{};
    final notices = <ScheduleImportNotice>[];
    final seenRowFingerprints = <String, Set<String>>{};
    final sourceItemIds = <String, String>{};
    final sourceSignatures = <String, String>{};
    final invalidSourceIds = <String>{};

    for (var index = 1; index < records.length; index++) {
      final record = records[index];
      final rowLabel = 'Row ${record.line}';
      if (record.fields.every((field) => field.trim().isEmpty)) continue;
      final sourceIdIndex = headers.indexOf('source_id');
      final sourceId =
          sourceIdIndex >= 0 && record.fields.length > sourceIdIndex
          ? record.fields[sourceIdIndex].trim()
          : '';
      if (record.fields.length != headers.length) {
        if (sourceId.isNotEmpty) {
          invalidSourceIds.add(sourceId);
          final priorId = sourceItemIds.remove(sourceId);
          if (priorId != null) proposals.remove(priorId);
        }
        notices.add(
          ScheduleImportNotice(
            'This row has ${record.fields.length} fields; the header has ${headers.length}.',
            uid: rowLabel,
          ),
        );
        continue;
      }
      final values = <String, String>{
        for (var i = 0; i < headers.length; i++)
          if (headers[i].isNotEmpty) headers[i]: record.fields[i].trim(),
      };
      if (sourceId.isNotEmpty && invalidSourceIds.contains(sourceId)) {
        notices.add(
          ScheduleImportNotice(
            'Another row with this source_id is invalid; the complete event was skipped.',
            uid: rowLabel,
          ),
        );
        continue;
      }
      try {
        final rowFingerprint = await _rowFingerprint(values);
        final coworkerReview = _reviewEventCoworkers(values);
        if (coworkerReview.notice != null) {
          notices.add(
            ScheduleImportNotice(coworkerReview.notice!, uid: rowLabel),
          );
        }
        final item = await _item(
          coworkerReview.values,
          sourceName: sourceName,
          sourceText: record.source,
          importedAt: timestamp,
        );
        final groupKey = sourceId.isEmpty ? item.id : 'source:$sourceId';
        final fingerprints = seenRowFingerprints.putIfAbsent(
          groupKey,
          () => <String>{},
        );
        if (!fingerprints.add(rowFingerprint)) {
          notices.add(
            ScheduleImportNotice(
              'This duplicates another row in the selected file and was skipped.',
              uid: rowLabel,
            ),
          );
          continue;
        }
        final existingId = sourceId.isEmpty ? null : sourceItemIds[sourceId];
        if (existingId == null) {
          proposals[item.id] = ScheduleImportProposal(
            item: item,
            sourceText: record.source,
          );
          if (sourceId.isNotEmpty) {
            sourceItemIds[sourceId] = item.id;
            sourceSignatures[sourceId] = _eventGroupSignature(values);
          }
          continue;
        }

        final existingProposal = proposals[existingId];
        final signature = _eventGroupSignature(values);
        if (existingProposal == null ||
            sourceSignatures[sourceId] != signature ||
            !_isSplitWorkEvent(item) ||
            !_isSplitWorkEvent(existingProposal.item)) {
          proposals.remove(existingId);
          sourceItemIds.remove(sourceId);
          invalidSourceIds.add(sourceId);
          notices.add(
            ScheduleImportNotice(
              'This source_id appears with different event details. Repeated IDs may group only intervals of the same shift or training event; the complete event was skipped.',
              uid: rowLabel,
            ),
          );
          continue;
        }

        try {
          final merged = _mergeSplitItems(
            existingProposal.item,
            item,
            sourceText: '${existingProposal.sourceText}\n${record.source}',
            sourceName: sourceName,
            importedAt: timestamp,
          );
          proposals[existingId] = ScheduleImportProposal(
            item: merged,
            sourceText: '${existingProposal.sourceText}\n${record.source}',
          );
        } on ArgumentError catch (error) {
          proposals.remove(existingId);
          sourceItemIds.remove(sourceId);
          invalidSourceIds.add(sourceId);
          notices.add(
            ScheduleImportNotice(
              error.message?.toString() ?? 'Intervals for this source_id overlap and cannot form one shift.',
              uid: rowLabel,
            ),
          );
        }
      } on FormatException catch (error) {
        if (sourceId.isNotEmpty) {
          invalidSourceIds.add(sourceId);
          final priorId = sourceItemIds.remove(sourceId);
          if (priorId != null) proposals.remove(priorId);
        }
        notices.add(
          ScheduleImportNotice(error.message.toString(), uid: rowLabel),
        );
      } on ArgumentError catch (error) {
        if (sourceId.isNotEmpty) {
          invalidSourceIds.add(sourceId);
          final priorId = sourceItemIds.remove(sourceId);
          if (priorId != null) proposals.remove(priorId);
        }
        notices.add(
          ScheduleImportNotice(
            error.message?.toString() ?? 'This row is incomplete.',
            uid: rowLabel,
          ),
        );
      }
    }
    return ScheduleImportPreview(
      proposals: List.unmodifiable(proposals.values),
      notices: List.unmodifiable(notices),
    );
  }

  /// Reads the first row using the same bounded CSV tokenizer as [parse].
  List<String> inspectHeaders(String source) {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException('This CSV file is too large.');
    }
    if (source.trim().isEmpty) {
      throw const FormatException('The selected CSV file is empty.');
    }
    final records = _parseRecords(source);
    if (records.isEmpty) {
      throw const FormatException('This CSV file has no header row.');
    }
    final headers = records.first.fields.map((field) => field.trim()).toList();
    if (headers.isNotEmpty && headers[0].startsWith('\uFEFF')) {
      headers[0] = headers[0].replaceFirst('\uFEFF', '');
    }
    if (headers.isEmpty ||
        headers.any((header) => header.isEmpty) ||
        headers.map((header) => header.toLowerCase()).toSet().length !=
            headers.length) {
      throw const FormatException(
        'The CSV header contains a blank or repeated column name.',
      );
    }
    return List.unmodifiable(headers);
  }

  List<String> _mappedHeaders(
    List<String> sourceHeaders,
    Set<String> allowed,
    Map<String, String>? headerMapping,
  ) {
    if (headerMapping == null) return sourceHeaders;
    final normalizedMapping = <String, String>{};
    for (final entry in headerMapping.entries) {
      final source = entry.key.trim().toLowerCase();
      final target = entry.value.trim().toLowerCase();
      if (!sourceHeaders.contains(source) || !allowed.contains(target)) {
        throw const FormatException('The selected column mapping is invalid.');
      }
      if (normalizedMapping.containsValue(target)) {
        throw const FormatException(
          'A destination field can only be mapped once.',
        );
      }
      normalizedMapping[source] = target;
    }
    return sourceHeaders
        .map((header) => normalizedMapping[header] ?? '')
        .toList();
  }

  static bool _isSplitWorkEvent(ScheduleItem item) =>
      item.kind == ScheduleKind.work &&
      !item.hasNoTime &&
      (item.workCategory == WorkCategory.shift ||
          item.workCategory == WorkCategory.training ||
          item.workCategory == WorkCategory.overtime);

  static ({Map<String, String> values, String? notice})
  _reviewEventCoworkers(Map<String, String> values) {
    final category = values['category']?.trim().toLowerCase();
    if (category != 'shift' && category != 'overtime' && category != 'training') {
      return (values: values, notice: null);
    }

    final names = _coworkerValues(values['coworkers']);
    if (names.isEmpty) return (values: values, notice: null);

    final codes = _coworkerValues(values['coworker_codes']);
    final shiftCode = values['code']?.trim() ?? '';
    final reviewedValues = Map<String, String>.of(values)
      ..['coworkers'] = '';
    if (shiftCode.isEmpty || codes.isEmpty || codes.length != names.length) {
      return (
        values: reviewedValues,
        notice: codes.isEmpty
            ? 'Coworker roster codes are missing, so the names were not attached to this shift.'
            : 'Coworker names and codes could not be paired, so no names were attached to this shift.',
      );
    }

    final sameCodeNames = <String>[];
    var excludedCount = 0;
    for (var index = 0; index < names.length; index++) {
      if (_normalizeCode(codes[index]) == _normalizeCode(shiftCode)) {
        if (!sameCodeNames.any(
          (existing) => existing.toLowerCase() == names[index].toLowerCase(),
        )) {
          sameCodeNames.add(names[index]);
        }
      } else {
        excludedCount++;
      }
    }
    reviewedValues['coworkers'] = sameCodeNames.join(';');
    if (excludedCount == 0) return (values: reviewedValues, notice: null);
    final excludedLabel = excludedCount == 1
        ? '1 coworker with a different roster code was excluded.'
        : '$excludedCount coworkers with different roster codes were excluded.';
    return (values: reviewedValues, notice: excludedLabel);
  }

  String _eventGroupSignature(Map<String, String> values) {
    final fields =
        values.entries
            .where(
              (entry) =>
                  entry.key != 'source_id' &&
                  entry.key != 'start' &&
                  entry.key != 'end' &&
                  entry.key != 'end_date',
            )
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return jsonEncode({
      for (final entry in fields)
        entry.key: entry.key == 'category'
            ? entry.value.toLowerCase()
            : entry.value,
    });
  }

  ScheduleItem _mergeSplitItems(
    ScheduleItem first,
    ScheduleItem second, {
    required String sourceText,
    required String sourceName,
    required DateTime importedAt,
  }) {
    final intervals = [...first.intervals, ...second.intervals]
      ..sort((a, b) => a.startEpochMinute.compareTo(b.startEpochMinute));
    final provenance = first.importProvenance!;
    return ScheduleItem(
      id: first.id,
      kind: first.kind,
      title: first.title,
      startDate: first.startDate,
      intervals: intervals,
      timeZoneId: first.timeZoneId,
      code: first.code,
      codeMeaning: first.codeMeaning,
      coworkers: first.coworkers,
      location: first.location,
      notes: first.notes,
      reportingInstruction: first.reportingInstruction,
      workCategory: first.workCategory,
      deadlineType: first.deadlineType,
      allDay: first.allDay,
      importProvenance: ScheduleImportProvenance(
        format: provenance.format,
        uid: provenance.uid,
        sourceName: sourceName,
        sourceText: sourceText,
        importedAt: importedAt,
      ),
      reminderMinutesBefore: first.reminderMinutesBefore,
    );
  }

  Future<ScheduleItem> _item(
    Map<String, String> values, {
    required String sourceName,
    required String sourceText,
    required DateTime importedAt,
  }) async {
    final title = values['title']!.trim();
    if (title.isEmpty) throw const FormatException('Add a title in this row.');
    final date = _date(values['date']!, 'date');
    final category = values['category']!.trim().toLowerCase();
    final sourceId = values['source_id']?.trim() ?? '';
    if (sourceId.length > 256 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(sourceId)) {
      throw const FormatException(
        'The source_id must be 256 characters or fewer and contain no control characters.',
      );
    }
    final canonicalFields =
        values.entries
            .where((entry) => entry.key != 'source_id' || sourceId.isNotEmpty)
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    final uidDigest = await _sha256.hash(
      utf8.encode(
        sourceId.isNotEmpty
            ? 'Shift & Study CSV source ID v1\u0000$sourceId'
            : jsonEncode({
                for (final entry in canonicalFields)
                  entry.key: entry.value.trim(),
              }),
      ),
    );
    final uid = base64Url.encode(uidDigest.bytes).replaceAll('=', '');
    final id = 'csv-$uid';
    final provenance = ScheduleImportProvenance(
      format: 'Shift & Study CSV v1',
      uid: uid,
      sourceName: sourceName,
      sourceText: sourceText,
      importedAt: importedAt,
    );
    final note = _optional(values['notes']);
    final reportingInstruction = _optional(values['reporting_instruction']);
    final location = _optional(values['location']);
    final code = _optional(values['code']);
    final codeMeaning = _optional(values['code_meaning']);
    final coworkers = _coworkerNames(values['coworkers']);
    final employerName = _optional(values['employer']);
    final departmentName = _optional(values['department']);
    final jobRole = _optional(values['job_role']);
    final supervisorName = _optional(values['supervisor_name']);
    final supervisorPhone = _optional(values['supervisor_phone']);
    final contactName = _optional(values['contact_name']);
    final contactPhone = _optional(values['contact_phone']);

    switch (category) {
      case 'rest_day':
      case 'leave':
      case 'day_off':
        _requireNoTimes(values);
        final workCategory = switch (category) {
          'rest_day' => WorkCategory.restDay,
          'leave' => WorkCategory.leave,
          _ => WorkCategory.dayOff,
        };
        return ScheduleItem(
          id: id,
          kind: ScheduleKind.work,
          title: title,
          startDate: date,
          intervals: const [],
          code: code,
          codeMeaning: codeMeaning,
          employerName: employerName,
          departmentName: departmentName,
          jobRole: jobRole,
          location: location,
          notes: note,
          reportingInstruction: reportingInstruction,
          supervisorName: supervisorName,
          supervisorPhone: supervisorPhone,
          contactName: contactName,
          contactPhone: contactPhone,
          coworkers: coworkers,
          workCategory: workCategory,
          importProvenance: provenance,
        );
      case 'assignment':
        _requireNoTimes(values);
        return ScheduleItem(
          id: id,
          kind: ScheduleKind.deadline,
          title: title,
          startDate: date,
          intervals: const [],
          code: code,
          location: location,
          notes: note,
          deadlineType: DeadlineType.assignment,
          importProvenance: provenance,
        );
      case 'shift':
      case 'overtime':
      case 'training':
      case 'class':
      case 'examination':
      case 'personal':
        if ((values['start']?.trim().isNotEmpty ?? false) == false &&
            (values['end']?.trim().isNotEmpty ?? false) == false) {
          if (category != 'personal') {
            throw const FormatException(
              'This category needs start and end times.',
            );
          }
          _requireNoTimes(values);
          return ScheduleItem(
            id: id,
            kind: ScheduleKind.personal,
            title: title,
            startDate: date,
            intervals: const [],
            code: code,
            location: location,
            notes: note,
            allDay: true,
            importProvenance: provenance,
          );
        }
        return _timedItem(
          values,
          category: category,
          title: title,
          date: date,
          code: code,
          codeMeaning: codeMeaning,
          coworkers: coworkers,
          location: location,
          notes: note,
          reportingInstruction: reportingInstruction,
          supervisorName: supervisorName,
          supervisorPhone: supervisorPhone,
          contactName: contactName,
          contactPhone: contactPhone,
          employerName: employerName,
          departmentName: departmentName,
          jobRole: jobRole,
          provenance: provenance,
          id: id,
        );
      default:
        throw FormatException(
          'Category "$category" is not supported. Use shift, overtime, training, class, examination, assignment, rest_day, leave, day_off or personal.',
        );
    }
  }

  Future<String> _rowFingerprint(Map<String, String> values) async {
    final canonical =
        values.entries.where((entry) => entry.key != 'source_id').toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    final digest = await _sha256.hash(
      utf8.encode(
        jsonEncode({for (final entry in canonical) entry.key: entry.value}),
      ),
    );
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  ScheduleItem _timedItem(
    Map<String, String> values, {
    required String category,
    required String title,
    required CivilDate date,
    required String? code,
    required String? codeMeaning,
    required List<String> coworkers,
    required String? location,
    required String? notes,
    required String? reportingInstruction,
    required String? supervisorName,
    required String? supervisorPhone,
    required String? contactName,
    required String? contactPhone,
    required String? employerName,
    required String? departmentName,
    required String? jobRole,
    required ScheduleImportProvenance provenance,
    required String id,
  }) {
    final startText = values['start']?.trim() ?? '';
    final endText = values['end']?.trim() ?? '';
    if (startText.isEmpty || endText.isEmpty) {
      throw const FormatException(
        'Enter both start and end times, or leave both blank for an all-day personal event.',
      );
    }
    final start = _minute(startText, 'start');
    final end = _minute(endText, 'end');
    final zone = _optional(values['time_zone']);
    if (zone == null) {
      throw const FormatException(
        'Add a time_zone value to preserve the event clock time correctly.',
      );
    }
    final endDateText = values['end_date']?.trim() ?? '';
    final endDate = endDateText.isEmpty ? date : _date(endDateText, 'end_date');
    final dayOffset = _daysBetween(date, endDate);
    if (dayOffset < 0 || dayOffset > 1) {
      throw const FormatException(
        'The end date must be the same day or the next day.',
      );
    }
    if (dayOffset == 0 &&
        end <= start &&
        endDateText.isEmpty &&
        (category == 'shift' ||
            category == 'training' ||
            category == 'overtime')) {
      final overnight = EventInterval(
        startDayOffset: 0,
        startMinute: start,
        endDayOffset: 1,
        endMinute: end,
      );
      if (!overnight.isValid) {
        throw const FormatException('The event end must be after its start.');
      }
      _validateTimes(date, date.addDays(1), start, end, zone);
      return _makeTimedEvent(
        category,
        title,
        date,
        overnight,
        zone,
        code,
        codeMeaning,
        coworkers,
        location,
        notes,
        provenance,
        id,
        reportingInstruction,
        supervisorName,
        supervisorPhone,
        contactName,
        contactPhone,
        employerName,
        departmentName,
        jobRole,
      );
    }
    if (dayOffset == 0 && end <= start) {
      throw const FormatException(
        'The end time must be later than the start time. Add the next-day end_date if this crosses midnight.',
      );
    }
    if (dayOffset == 1 && endDateText.isEmpty) {
      throw const FormatException(
        'Add an explicit end_date for an overnight non-work event.',
      );
    }
    final interval = EventInterval(
      startDayOffset: 0,
      startMinute: start,
      endDayOffset: dayOffset,
      endMinute: end,
    );
    if (!interval.isValid) {
      throw const FormatException('The event end must be after its start.');
    }
    _validateTimes(date, endDate, start, end, zone);
    return _makeTimedEvent(
      category,
      title,
      date,
      interval,
      zone,
      code,
      codeMeaning,
      coworkers,
      location,
      notes,
      provenance,
      id,
      reportingInstruction,
      supervisorName,
      supervisorPhone,
      contactName,
      contactPhone,
      employerName,
      departmentName,
      jobRole,
    );
  }

  void _validateTimes(
    CivilDate startDate,
    CivilDate endDate,
    int start,
    int end,
    String zone,
  ) {
    for (final entry in [(startDate, start, 'start'), (endDate, end, 'end')]) {
      final resolution = CivilTimeResolver().resolve(entry.$1, entry.$2, zone);
      if (resolution.status == CivilTimeStatus.invalidTimeZone) {
        throw FormatException('"$zone" is not a supported time zone.');
      }
      if (resolution.status == CivilTimeStatus.ambiguous) {
        throw FormatException(
          'The ${entry.$3} time falls in a repeated clock hour; correct it manually in review.',
        );
      }
      if (resolution.status == CivilTimeStatus.nonexistent) {
        throw FormatException(
          'The ${entry.$3} time falls in a clock-change gap; correct it manually in review.',
        );
      }
    }
  }

  ScheduleItem _makeTimedEvent(
    String category,
    String title,
    CivilDate date,
    EventInterval interval,
    String zone,
    String? code,
    String? codeMeaning,
    List<String> coworkers,
    String? location,
    String? notes,
    ScheduleImportProvenance provenance,
    String id,
    String? reportingInstruction,
    String? supervisorName,
    String? supervisorPhone,
    String? contactName,
    String? contactPhone,
    String? employerName,
    String? departmentName,
    String? jobRole,
  ) {
    final kind = switch (category) {
      'shift' || 'overtime' || 'training' => ScheduleKind.work,
      'class' => ScheduleKind.classSession,
      'examination' => ScheduleKind.deadline,
      _ => ScheduleKind.personal,
    };
    return ScheduleItem(
      id: id,
      kind: kind,
      title: title,
      startDate: date,
      intervals: [interval],
      timeZoneId: zone,
      code: code,
      employerName: kind == ScheduleKind.work ? employerName : null,
      departmentName: kind == ScheduleKind.work ? departmentName : null,
      jobRole: kind == ScheduleKind.work ? jobRole : null,
      codeMeaning: kind == ScheduleKind.work ? codeMeaning : null,
      coworkers: kind == ScheduleKind.work ? coworkers : const [],
      location: location,
      notes: notes,
      reportingInstruction: kind == ScheduleKind.work
          ? reportingInstruction
          : null,
      supervisorName: kind == ScheduleKind.work ? supervisorName : null,
      supervisorPhone: kind == ScheduleKind.work ? supervisorPhone : null,
      contactName: kind == ScheduleKind.work ? contactName : null,
      contactPhone: kind == ScheduleKind.work ? contactPhone : null,
      workCategory: switch (category) {
        'shift' => WorkCategory.shift,
        'overtime' => WorkCategory.overtime,
        'training' => WorkCategory.training,
        _ => null,
      },
      deadlineType: category == 'examination' ? DeadlineType.examination : null,
      importProvenance: provenance,
    );
  }

  static List<String> _coworkerNames(String? value) => value == null
      ? const []
      : value
            .split(';')
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .fold(<String>[], (names, name) {
              if (!names.any(
                (existing) => existing.toLowerCase() == name.toLowerCase(),
              )) {
                names.add(name);
              }
              return names;
            });

  static List<String> _coworkerValues(String? value) => value == null
      ? const []
      : value
            .split(';')
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false);

  static String _normalizeCode(String code) =>
      code.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();

  static void _requireNoTimes(Map<String, String> values) {
    if ((values['start']?.trim().isNotEmpty ?? false) ||
        (values['end']?.trim().isNotEmpty ?? false) ||
        (values['end_date']?.trim().isNotEmpty ?? false)) {
      throw const FormatException(
        'This all-day category cannot contain times.',
      );
    }
  }

  static CivilDate _date(String value, String field) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
    if (match == null) {
      throw FormatException('Use YYYY-MM-DD in the $field column.');
    }
    final date = CivilDate(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
    if (!date.isValid) {
      throw FormatException('The $field value is not a valid date.');
    }
    return date;
  }

  static int _minute(String value, String field) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) {
      throw FormatException('Use 24-hour HH:mm in the $field column.');
    }
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (hour > 23 || minute > 59) {
      throw FormatException('The $field time is not valid.');
    }
    return hour * 60 + minute;
  }

  static int _daysBetween(CivilDate from, CivilDate to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static void _initializeTimeZones() {
    if (_timeZonesInitialized) return;
    tzdata.initializeTimeZones();
    _timeZonesInitialized = true;
  }

  static List<_CsvRecord> _parseRecords(String source) {
    final records = <_CsvRecord>[];
    final fields = <String>[];
    final field = StringBuffer();
    var quoted = false;
    var afterQuote = false;
    var rowStart = 0;
    var line = 1;
    var rowLine = 1;
    var index = source.startsWith('\uFEFF') ? 1 : 0;
    while (index < source.length) {
      final char = source[index];
      if (quoted) {
        if (char == '"') {
          if (index + 1 < source.length && source[index + 1] == '"') {
            field.write('"');
            index++;
          } else {
            quoted = false;
            afterQuote = true;
          }
        } else {
          field.write(char);
          if (char == '\n') line++;
        }
      } else if (char == ',') {
        fields.add(field.toString());
        field.clear();
        afterQuote = false;
      } else if (char == '\r' || char == '\n') {
        fields.add(field.toString());
        field.clear();
        final row = List<String>.unmodifiable(fields);
        fields.clear();
        final rowEnd = index;
        final end =
            char == '\r' &&
                index + 1 < source.length &&
                source[index + 1] == '\n'
            ? index + 2
            : index + 1;
        if (row.any((value) => value.trim().isNotEmpty)) {
          records.add(
            _CsvRecord(
              row,
              line: rowLine,
              source: source.substring(rowStart, rowEnd),
            ),
          );
        }
        if (char == '\r' && end == index + 2) index++;
        index = end - 1;
        rowStart = end;
        line++;
        rowLine = line;
        afterQuote = false;
      } else if (char == '"') {
        if (field.isEmpty && !afterQuote) {
          quoted = true;
        } else {
          throw FormatException('Unexpected quote on CSV line $line.');
        }
      } else {
        if (afterQuote && char.trim().isNotEmpty) {
          throw FormatException(
            'Unexpected text after a quoted value on CSV line $line.',
          );
        }
        if (!afterQuote) field.write(char);
      }
      index++;
    }
    if (quoted) {
      throw const FormatException('A quoted CSV field is not closed.');
    }
    if (fields.isNotEmpty || field.isNotEmpty) {
      fields.add(field.toString());
      final row = List<String>.unmodifiable(fields);
      if (row.any((value) => value.trim().isNotEmpty)) {
        records.add(
          _CsvRecord(row, line: rowLine, source: source.substring(rowStart)),
        );
      }
    }
    return records;
  }
}

class _CsvRecord {
  const _CsvRecord(this.fields, {required this.line, required this.source});
  final List<String> fields;
  final int line;
  final String source;
}

class CoworkerRosterPreview {
  const CoworkerRosterPreview({
    required this.assignments,
    required this.notices,
  });

  final List<CoworkerRosterAssignment> assignments;
  final List<String> notices;
}

class CoworkerRosterAssignment {
  const CoworkerRosterAssignment({
    required this.date,
    required this.code,
    required this.coworkers,
    required this.sourceRows,
    this.employer,
    this.sameRosterCodeVerified = false,
  });

  final CivilDate date;
  final String code;
  final String? employer;
  final List<String> coworkers;
  final List<int> sourceRows;
  final bool sameRosterCodeVerified;
}

class _CoworkerRosterBuilder {
  _CoworkerRosterBuilder({
    required this.date,
    required this.code,
    this.employer,
  });

  final CivilDate date;
  final String code;
  final String? employer;
  final List<String> coworkers = [];
  final Set<String> _normalized = {};
  final List<int> sourceRows = [];
  bool sameRosterCodeVerified = true;

  void add(
    List<String> names,
    int sourceRow, {
    required bool sameRosterCodeVerified,
  }) {
    sourceRows.add(sourceRow);
    this.sameRosterCodeVerified &= sameRosterCodeVerified;
    for (final name in names) {
      if (_normalized.add(name.toLowerCase())) coworkers.add(name);
    }
  }

  CoworkerRosterAssignment build() => CoworkerRosterAssignment(
    date: date,
    code: code,
    employer: employer,
    coworkers: List.unmodifiable(coworkers),
    sourceRows: List.unmodifiable(sourceRows),
    sameRosterCodeVerified: sameRosterCodeVerified,
  );
}
