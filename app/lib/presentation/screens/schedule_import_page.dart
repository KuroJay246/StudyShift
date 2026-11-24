import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dependencies.dart';
import '../../data/csv_schedule_import.dart';
import '../../data/ics_schedule_import.dart';
import '../../data/ocr_schedule_import.dart';
import '../../data/roster_grid_import.dart';
import '../../data/roster_grid_selection_resolver.dart';
import '../../data/roster_legend_import.dart';
import '../../data/xlsx_schedule_import.dart';
import '../../data/schedule_import_models.dart';
import '../../data/schedule_import_history_repository.dart';
import '../../domain/civil_time_resolver.dart';
import '../../domain/schedule.dart';
import '../../domain/supervisor_profile.dart';
import '../../domain/supervisor_roster_parser.dart';
import '../../domain/work_occurrence_coworkers.dart';
import '../../domain/work_code_legend.dart';
import '../../platform/schedule_import_file_bridge.dart';
import '../design/studyshift_spacing.dart';
import '../schedule_format.dart';
import 'schedule_import_history_page.dart';
import 'work_code_legend_page.dart';

enum _ImportCategory {
  personal,
  shift,
  overtime,
  training,
  classSession,
  examination,
  assignment,
  restDay,
  leave,
  dayOff,
}

String _rosterEventTitle(WorkCodeLegend legend) {
  var title = legend.assignmentDetails;
  for (final flightId in legend.flightIds) {
    title = title.replaceAll(
      RegExp(RegExp.escape(flightId), caseSensitive: false),
      ' ',
    );
  }
  title = title.replaceAll(
    RegExp(r'\b[A-Z]{1,3}\s*\d{2,5}(?:/\d{1,4})?\b', caseSensitive: false),
    ' ',
  );
  if (legend.code.trim().isNotEmpty) {
    title = title.replaceAll(
      RegExp(
        '\\b${RegExp.escape(legend.code.trim())}\\b',
        caseSensitive: false,
      ),
      ' ',
    );
  }
  title = title.replaceAll(RegExp(r'[\s,;|/·–—-]+'), ' ').trim();
  return title.isEmpty ? 'Work shift' : title;
}

class ScheduleImportPage extends ConsumerStatefulWidget {
  const ScheduleImportPage({super.key});

  @override
  ConsumerState<ScheduleImportPage> createState() => _ScheduleImportPageState();
}

class _ImportRow {
  const _ImportRow({
    required this.proposal,
    required this.included,
    this.existing,
    this.ambiguousMatch = false,
    this.coworkerOnly = false,
    this.rosterOccurrenceDate,
    this.sourceName,
  });

  final ScheduleImportProposal proposal;
  final bool included;
  final ScheduleItem? existing;
  final bool ambiguousMatch;
  final bool coworkerOnly;
  final CivilDate? rosterOccurrenceDate;
  final String? sourceName;

  String? get effectiveSourceName =>
      sourceName ?? proposal.item.importProvenance?.sourceName;

  _ImportRow copyWith({
    ScheduleImportProposal? proposal,
    bool? included,
    bool? coworkerOnly,
    CivilDate? rosterOccurrenceDate,
    String? sourceName,
  }) => _ImportRow(
    proposal: proposal ?? this.proposal,
    included: included ?? this.included,
    existing: existing,
    ambiguousMatch: ambiguousMatch,
    coworkerOnly: coworkerOnly ?? this.coworkerOnly,
    rosterOccurrenceDate: rosterOccurrenceDate ?? this.rosterOccurrenceDate,
    sourceName: sourceName ?? this.sourceName,
  );
}

class _OcrMatchResult {
  const _OcrMatchResult({this.item, this.ambiguous = false});

  final ScheduleItem? item;
  final bool ambiguous;
}

class _ScheduleImportPageState extends ConsumerState<ScheduleImportPage> {
  final _parser = const IcsScheduleImportParser();
  final _csvParser = const CsvScheduleImportParser();
  final _xlsxParser = const XlsxScheduleImportParser();
  final _ocrParser = const OcrScheduleImportParser();
  final _rosterLegendParser = const RosterLegendImportParser();
  final _supervisorRosterParser = const SupervisorRosterParser();
  final _fileBridge = const ScheduleImportFileBridge();
  List<_ImportRow> _rows = const [];
  List<ScheduleImportNotice> _notices = const [];
  String? _sourceName;
  String? _recognizedText;
  bool _loading = false;
  bool _saving = false;
  bool _replaceMatches = false;
  ScheduleImportSourceType? _sourceType;
  String? _error;
  Uint8List? _pendingTableBytes;
  String? _pendingTableName;
  ScheduleImportSourceType? _pendingTableType;
  List<String> _tableHeaders = const [];
  Map<String, String> _columnSelections = const {};
  RosterGridDetection? _rosterDetection;
  RosterLegendDetection? _rosterLegendDetection;
  List<WorkCodeLegend> _rosterLegendProposals = const [];
  List<WorkCodeLegend> _rosterLegendConflicts = const [];
  Set<String> _selectedRosterLegendIds = const {};
  List<SupervisorProfile> _supervisorProposals = const [];
  Set<String> _selectedSupervisorIds = const {};
  final Map<String, SupervisorProfile> _manualRosterSupervisorProfiles = {};
  String? _selectedRosterSupervisorName;
  SupervisorType? _selectedRosterSupervisorType;
  int _selectedRosterTable = 0;
  int? _selectedRosterRow;
  DateTime? _rosterFirstDate;
  Map<int, DateTime> _rosterDateOverrides = const {};
  bool _rosterDatesConfirmed = false;
  bool _appendIncoming = false;
  bool _coworkerRosterDetected = false;
  RosterCoworkerScope _rosterCoworkerScope = RosterCoworkerScope.sameRosterCode;
  String? _rosterTimeZoneId;
  int _rosterTimeZoneRevision = 0;
  List<String> _unresolvedRosterCells = const [];

  Future<void> _reviewRosterLegend(WorkCodeLegend definition) async {
    final corrected = await showDialog<WorkCodeLegend>(
      context: context,
      builder: (_) => WorkCodeLegendEditorDialog(
        suggestion: definition,
        persistOnSave: false,
      ),
    );
    if (!mounted || corrected == null) return;
    setState(() {
      _rosterLegendProposals = [
        for (final proposal in _rosterLegendProposals)
          if (proposal.id == definition.id) corrected else proposal,
      ];
      _selectedRosterLegendIds = {..._selectedRosterLegendIds, corrected.id};
      _rows = [
        for (final row in _rows)
          if (row.effectiveSourceName == _sourceName &&
              row.proposal.item.kind == ScheduleKind.work &&
              row.proposal.item.code?.trim().toUpperCase() ==
                  corrected.code.trim().toUpperCase())
            row.copyWith(
              proposal: ScheduleImportProposal(
                item: row.proposal.item.copyWith(
                  title: _rosterEventTitle(corrected),
                  codeMeaning: corrected.assignmentDetails,
                ),
                sourceText: row.proposal.sourceText,
              ),
            )
          else
            row,
      ];
    });
  }

  static const _tableFields = <String, String>{
    'date': 'Event date *',
    'title': 'Event or shift name *',
    'category': 'Category *',
    'start': 'Start time',
    'end': 'End time',
    'end_date': 'End date',
    'time_zone': 'Time zone',
    'source_id': 'Source ID',
    'employer': 'Employer',
    'department': 'Department or team',
    'job_role': 'Job role',
    'code': 'Roster code',
    'code_meaning': 'Code meaning',
    'coworkers': 'Coworkers (semicolon-separated)',
    'reporting_instruction': 'Reporting instruction',
    'location': 'Location',
    'notes': 'Notes',
    'supervisor_name': 'Supervisor name',
    'supervisor_phone': 'Supervisor phone',
    'contact_name': 'Contact name',
    'contact_phone': 'Contact phone',
  };

  Future<void> _selectFile({bool appendToBatch = false}) async {
    final append = appendToBatch && _rows.isNotEmpty;
    setState(() {
      _loading = true;
      _error = null;
      _appendIncoming = append;
      if (!append) {
        _rows = const [];
        _notices = const [];
        _sourceName = null;
        _recognizedText = null;
        _sourceType = null;
        _rosterDetection = null;
        _rosterLegendDetection = null;
        _rosterLegendProposals = const [];
        _rosterLegendConflicts = const [];
        _selectedRosterLegendIds = const {};
        _supervisorProposals = const [];
        _selectedSupervisorIds = const {};
        _manualRosterSupervisorProfiles.clear();
        _selectedRosterSupervisorName = null;
        _selectedRosterSupervisorType = null;
        _selectedRosterTable = 0;
        _selectedRosterRow = null;
        _rosterFirstDate = null;
        _rosterTimeZoneId = null;
        _rosterTimeZoneRevision++;
        _rosterDateOverrides = const {};
        _rosterDatesConfirmed = false;
        _unresolvedRosterCells = const [];
        _coworkerRosterDetected = false;
        _rosterCoworkerScope = RosterCoworkerScope.sameRosterCode;
      }
    });
    try {
      var selected = await _fileBridge.openImport();
      if (selected == null) {
        if (mounted) setState(() => _appendIncoming = false);
        return;
      }
      if (selected.requiresOcr) {
        if (!await _confirmOcrMetrics()) {
          await _fileBridge.discardSelectedOcr();
          if (mounted) setState(() => _appendIncoming = false);
          return;
        }
        if (selected.extractedText == null) {
          selected = await _fileBridge.extractSelectedOcr();
        }
      }
      final sourceName = _batchSourceName(selected.name, append: append);
      final zone = await ref.read(deviceTimeZoneIdProvider.future);
      final fileName = selected.name.toLowerCase();
      if (selected.extractedText case final extractedText?) {
        final sourceType = _isExamTimetable(selected.name, extractedText)
            ? ScheduleImportSourceType.examTimetableOcr
            : fileName.endsWith('.pdf')
            ? ScheduleImportSourceType.pdfOcr
            : ScheduleImportSourceType.imageOcr;
        final detection = const RosterGridImportParser().detect(
          selected.ocrTokens,
        );
        final legendDetection = _rosterLegendParser.detect(selected.ocrTokens);
        final supervisorProposals = _mergeSupervisorProposals(
          await _newSupervisorProfiles(extractedText),
          append: append,
        );
        if (detection.candidates.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _sourceName = sourceName;
            _sourceType = append ? ScheduleImportSourceType.batch : sourceType;
            _recognizedText = extractedText;
            _rosterDetection = detection;
            _rosterLegendDetection = legendDetection;
            _rosterLegendProposals = const [];
            _rosterLegendConflicts = const [];
            _selectedRosterLegendIds = const {};
            _supervisorProposals = supervisorProposals;
            _selectedSupervisorIds = {
              for (final profile in supervisorProposals) profile.id,
            };
            _selectedRosterTable = 0;
            _selectedRosterRow = null;
            _rosterFirstDate = _inferredRosterFirstDate(
              detection.candidates.first,
            );
            _rosterDateOverrides = const {};
            _rosterDatesConfirmed = false;
            _unresolvedRosterCells = const [];
          });
          return;
        }
        final preview = await _ocrParser.parse(
          text: extractedText,
          sourceName: sourceName,
          timeZoneId: zone,
          examTimetable:
              sourceType == ScheduleImportSourceType.examTimetableOcr,
        );
        final existingItems = await ref
            .read(scheduleRepositoryProvider)
            .getItems();
        final byId = {for (final item in existingItems) item.id: item};
        final unusedExistingOcrItems = existingItems
            .where(_hasOcrProvenance)
            .toList();
        final matchedOcrIds = <String>{};
        final incoming = [
          for (final proposal in preview.proposals)
            _ocrReviewRow(
              proposal,
              byId: byId,
              unusedExistingOcrItems: unusedExistingOcrItems,
              matchedOcrIds: matchedOcrIds,
            ),
        ];
        _mergeBatchRows(incoming, preview.notices);
        if (mounted) {
          setState(() {
            _sourceName = sourceName;
            _sourceType = append ? ScheduleImportSourceType.batch : sourceType;
            _recognizedText = extractedText;
            _supervisorProposals = supervisorProposals;
            _selectedSupervisorIds = {
              for (final profile in supervisorProposals) profile.id,
            };
            if (preview.proposals.isEmpty && supervisorProposals.isEmpty) {
              _error = 'No clear schedule rows were found. Review the recognized text and correct uncertain entries manually.';
            }
          });
        }
        return;
      }
      final ScheduleImportPreview preview;
      final ScheduleImportSourceType sourceType;
      if (fileName.endsWith('.ics')) {
        sourceType = ScheduleImportSourceType.ics;
        final text = utf8.decode(selected.bytes!, allowMalformed: false);
        preview = await _parser.parse(
          text,
          sourceName: sourceName,
          floatingTimeZoneId: zone,
        );
      } else if (fileName.endsWith('.csv')) {
        sourceType = ScheduleImportSourceType.csv;
        final text = utf8.decode(selected.bytes!, allowMalformed: false);
        final matrix = _csvParser.detectRosterGrid(text);
        if (matrix.candidates.isNotEmpty) {
          _stageRosterGrid(
            matrix,
            sourceName: sourceName,
            sourceType: sourceType,
            append: append,
          );
          return;
        }
        final headers = _csvParser.inspectHeaders(text);
        if (_isCoworkerRosterHeaders(headers)) {
          final preview = _csvParser.parseCoworkerRoster(text);
          await _stageCoworkerRoster(
            preview,
            sourceName: sourceName,
            sourceType: sourceType,
            append: append,
          );
          return;
        }
        if (_needsColumnMapping(headers)) {
          if (!mounted) return;
          setState(() {
            _pendingTableBytes = selected?.bytes;
            _pendingTableName = sourceName;
            _pendingTableType = sourceType;
            _tableHeaders = headers;
            _columnSelections = _suggestColumns(headers);
          });
          return;
        }
        preview = await _csvParser.parse(text, sourceName: sourceName);
      } else if (fileName.endsWith('.xlsx')) {
        sourceType = ScheduleImportSourceType.xlsx;
        final matrix = _xlsxParser.detectRosterGrid(selected.bytes!);
        if (matrix.candidates.isNotEmpty) {
          _stageRosterGrid(
            matrix,
            sourceName: sourceName,
            sourceType: sourceType,
            append: append,
          );
          return;
        }
        final headers = _xlsxParser.inspectHeaders(selected.bytes!);
        if (_isCoworkerRosterHeaders(headers)) {
          final preview = _xlsxParser.parseCoworkerRoster(selected.bytes!);
          await _stageCoworkerRoster(
            preview,
            sourceName: sourceName,
            sourceType: sourceType,
            append: append,
          );
          return;
        }
        if (_needsColumnMapping(headers)) {
          if (!mounted) return;
          setState(() {
            _pendingTableBytes = selected?.bytes;
            _pendingTableName = sourceName;
            _pendingTableType = sourceType;
            _tableHeaders = headers;
            _columnSelections = _suggestColumns(headers);
          });
          return;
        }
        preview = await _xlsxParser.parse(
          selected.bytes!,
          sourceName: sourceName,
        );
      } else {
        throw const FormatException(
          'Choose an ICS, CSV, Excel (.xlsx), PDF, or supported image file.',
        );
      }
      final existingItems = await ref
          .read(scheduleRepositoryProvider)
          .getItems();
      final localLegends = await ref
          .read(workCodeLegendRepositoryProvider)
          .getItems();
      final reviewedProposals = [
        for (final proposal in preview.proposals)
          _withLocalLegendMeaning(proposal, localLegends),
      ];
      if (!mounted) return;
      final incoming = _matchExistingRows(reviewedProposals, existingItems);
      _mergeBatchRows(incoming, preview.notices);
      if (mounted) {
        setState(() {
          _sourceName = sourceName;
          _sourceType = append ? ScheduleImportSourceType.batch : sourceType;
        });
      }
      if (preview.proposals.isEmpty && preview.notices.isEmpty) {
        setState(() => _error = 'This calendar has no events to review.');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _needsColumnMapping(List<String> headers) {
    const canonical = {
      'date',
      'end_date',
      'title',
      'category',
      'start',
      'end',
      'time_zone',
      'source_id',
      'employer',
      'department',
      'job_role',
      'code',
      'code_meaning',
      'coworkers',
      'coworker_codes',
      'reporting_instruction',
      'location',
      'notes',
      'supervisor_name',
      'supervisor_phone',
      'contact_name',
      'contact_phone',
    };
    final normalized = headers
        .map((header) => header.trim().toLowerCase())
        .toSet();
    return !{'date', 'title', 'category'}.every(normalized.contains) ||
        normalized.any((header) => !canonical.contains(header));
  }

  bool _isCoworkerRosterHeaders(List<String> headers) {
    final normalized = headers
        .map((header) => header.trim().toLowerCase().replaceAll(' ', '_'))
        .toSet();
    const dateFields = {'date', 'shift_date', 'work_date'};
    const codeFields = {'code', 'shift_code', 'roster_code'};
    const coworkerFields = {'coworkers', 'coworker', 'colleagues'};
    return normalized.any(dateFields.contains) &&
        normalized.any(codeFields.contains) &&
        normalized.any(coworkerFields.contains) &&
        !normalized.contains('title') &&
        !normalized.contains('category') &&
        !normalized.contains('start') &&
        !normalized.contains('end');
  }

  Future<List<SupervisorProfile>> _newSupervisorProfiles(String text) async {
    final entries = _supervisorRosterParser.parse(text);
    if (entries.isEmpty) return const [];
    final existing = await ref.read(supervisorRepositoryProvider).getItems();
    final existingNames = {
      for (final profile in existing) _normalizeStaffName(profile.name),
    };
    return [
      for (final entry in entries)
        if (existingNames.add(_normalizeStaffName(entry.name)))
          SupervisorProfile(
            id: 'roster-supervisor-${sha256.convert(utf8.encode(_normalizeStaffName(entry.name))).toString().substring(0, 24)}',
            name: entry.name,
            type: entry.type,
          ),
    ];
  }

  List<SupervisorProfile> _mergeSupervisorProposals(
    List<SupervisorProfile> incoming, {
    required bool append,
  }) {
    if (!append) return incoming;
    final merged = [..._supervisorProposals];
    final names = {
      for (final profile in merged) _normalizeStaffName(profile.name),
    };
    for (final profile in incoming) {
      if (names.add(_normalizeStaffName(profile.name))) merged.add(profile);
    }
    return List.unmodifiable(merged);
  }

  String _normalizeStaffName(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  List<String> _availableRosterStaffNames() {
    final detection = _rosterDetection;
    if (detection == null ||
        _selectedRosterTable < 0 ||
        _selectedRosterTable >= detection.candidates.length) {
      return const [];
    }
    final knownNames = {
      for (final profile in _supervisorProposals)
        _normalizeStaffName(profile.name),
      ..._manualRosterSupervisorProfiles.keys,
    };
    final namesByKey = <String, String>{};
    for (final row in detection.candidates[_selectedRosterTable].rows) {
      final name = row.label.trim().replaceAll(RegExp(r'\s+'), ' ');
      final key = _normalizeStaffName(name);
      if (name.isNotEmpty && !knownNames.contains(key)) {
        namesByKey.putIfAbsent(key, () => name);
      }
    }
    return List.unmodifiable(namesByKey.values);
  }

  Future<void> _chooseRosterStaffRow(RosterGridCandidate table) async {
    var query = '';
    final selectedRow = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final normalizedQuery = query.trim().toLowerCase();
          final matchingRows = [
            for (var index = 0; index < table.rows.length; index++)
              if (normalizedQuery.isEmpty ||
                  table.rows[index].label.toLowerCase().contains(
                    normalizedQuery,
                  ))
                index,
          ];
          final maxDialogHeight = MediaQuery.sizeOf(context).height * .62;
          return AlertDialog(
            title: const Text('Which person are you?'),
            content: SizedBox(
              width: 480,
              height: maxDialogHeight,
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('roster-staff-row-search'),
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Search roster names',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setDialogState(() => query = value),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: matchingRows.isEmpty
                        ? const Center(child: Text('No matching roster names'))
                        : ListView.builder(
                            itemCount: matchingRows.length,
                            itemBuilder: (context, resultIndex) {
                              final rowIndex = matchingRows[resultIndex];
                              return ListTile(
                                key: ValueKey('roster-staff-option-$rowIndex'),
                                title: Text(
                                  table.rows[rowIndex].label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text('Roster row ${rowIndex + 1}'),
                                onTap: () =>
                                    Navigator.of(dialogContext).pop(rowIndex),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
    if (selectedRow == null || !mounted) return;
    setState(() {
      _selectedRosterRow = selectedRow;
      if (!_appendIncoming) _rows = const [];
      _unresolvedRosterCells = const [];
    });
  }

  List<SupervisorProfile> _selectedManualRosterSupervisors() =>
      List.unmodifiable(_manualRosterSupervisorProfiles.values);

  Future<void> _addRosterSupervisor() async {
    final name = _selectedRosterSupervisorName?.trim();
    final type = _selectedRosterSupervisorType;
    if (name == null || name.isEmpty || type == null) return;
    final normalizedName = _normalizeStaffName(name);
    final existingProfiles = await ref
        .read(supervisorRepositoryProvider)
        .getItems();
    if (existingProfiles.any(
      (profile) => _normalizeStaffName(profile.name) == normalizedName,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name is already in Shift Legend.')),
        );
      }
      return;
    }
    final id =
        'roster-supervisor-${sha256.convert(utf8.encode(normalizedName)).toString().substring(0, 24)}';
    setState(() {
      _manualRosterSupervisorProfiles[normalizedName] = SupervisorProfile(
        id: id,
        name: name,
        type: type,
      );
      _selectedRosterSupervisorName = null;
      _selectedRosterSupervisorType = null;
    });
  }

  void _removeRosterSupervisor(String normalizedName) {
    setState(() => _manualRosterSupervisorProfiles.remove(normalizedName));
  }

  void _stageRosterGrid(
    RosterGridDetection detection, {
    required String sourceName,
    required ScheduleImportSourceType sourceType,
    required bool append,
  }) {
    if (!mounted) return;
    setState(() {
      _sourceName = sourceName;
      _sourceType = append ? ScheduleImportSourceType.batch : sourceType;
      _recognizedText = null;
      _rosterDetection = detection;
      _selectedRosterTable = 0;
      _selectedRosterRow = null;
      _rosterFirstDate = _inferredRosterFirstDate(detection.candidates.first);
      _rosterDateOverrides = const {};
      _rosterDatesConfirmed = false;
      _unresolvedRosterCells = const [];
      _coworkerRosterDetected = false;
    });
  }

  Future<void> _stageCoworkerRoster(
    CoworkerRosterPreview preview, {
    required String sourceName,
    required ScheduleImportSourceType sourceType,
    required bool append,
  }) async {
    final savedItems = await ref.read(scheduleRepositoryProvider).getItems();
    final occurrenceRows = await ref
        .read(workOccurrenceCoworkerRepositoryProvider)
        .getAll();
    final occurrenceCoworkersByKey = {
      for (final row in occurrenceRows)
        '${row.shiftItemId}|${row.occurrenceDate}': row,
    };
    final byId = {for (final item in savedItems) item.id: item};
    final candidates = savedItems.where(_canMatchOcrProposal).toList();
    final matchedIds = <String>{};
    final incoming = <_ImportRow>[];
    final notices = [
      for (final notice in preview.notices) ScheduleImportNotice(notice),
    ];
    for (final assignment in preview.assignments) {
      final sourceText =
          'Coworker roster · ${assignment.date} · ${assignment.code}';
      final matches = candidates
          .where((item) => _matchesRosterIdentity(item, assignment))
          .toList(growable: false);
      if (matches.isEmpty) {
        notices.add(
          ScheduleImportNotice(
            'No saved shift matches ${assignment.code} on ${assignment.date}; coworkers were not added.',
          ),
        );
        continue;
      }
      for (final savedShift in matches) {
        final proposal = ScheduleImportProposal(
          item: savedShift.copyWith(coworkers: assignment.coworkers),
          sourceText: sourceText,
        );
        final row = _ocrReviewRow(
          proposal,
          byId: byId,
          unusedExistingOcrItems: candidates,
          matchedOcrIds: matchedIds,
          rosterProposal: true,
          occurrenceCoworkersByKey: occurrenceCoworkersByKey,
          sourceName: sourceName,
        );
        if (row.existing != null && row.coworkerOnly) {
          incoming.add(
            assignment.sameRosterCodeVerified
                ? row
                : row.copyWith(included: false),
          );
        }
      }
    }
    _mergeBatchRows(incoming, notices);
    if (!mounted) return;
    setState(() {
      _sourceName = sourceName;
      _sourceType = append ? ScheduleImportSourceType.batch : sourceType;
      _coworkerRosterDetected = true;
      _error = incoming.isEmpty && notices.isEmpty
          ? 'No coworker rows matched saved shifts. Your schedule was not changed.'
          : null;
    });
  }

  void _mergeBatchRows(
    List<_ImportRow> incoming,
    List<ScheduleImportNotice> notices,
  ) {
    final append = _appendIncoming;
    final combinedRows = _mergeCoworkerOnlyRows(
      append ? [..._rows, ...incoming] : incoming,
    );
    final duplicates = _duplicateBatchGroups(combinedRows);
    final duplicateIndexes = duplicates.values
        .expand((indexes) => indexes)
        .toSet();
    setState(() {
      _rows = [
        for (var index = 0; index < combinedRows.length; index++)
          duplicateIndexes.contains(index)
              ? combinedRows[index].copyWith(included: false)
              : combinedRows[index],
      ];
      _notices = [
        if (append) ..._notices,
        ...notices,
        if (duplicates.isNotEmpty)
          const ScheduleImportNotice(
            'Some shifts use the same date and code in more than one file, even when the times differ. They are unchecked until you choose the correct version.',
          ),
      ];
      _appendIncoming = false;
    });
  }

  List<_ImportRow> _mergeCoworkerOnlyRows(List<_ImportRow> rows) {
    final merged = <_ImportRow>[];
    final indexesByOccurrence = <String, int>{};
    for (final row in rows) {
      if (!row.coworkerOnly) {
        merged.add(row);
        continue;
      }
      final key =
          '${row.proposal.item.id}|${row.rosterOccurrenceDate ?? row.proposal.item.startDate}';
      final priorIndex = indexesByOccurrence[key];
      if (priorIndex == null) {
        indexesByOccurrence[key] = merged.length;
        merged.add(row);
        continue;
      }
      final prior = merged[priorIndex];
      final names = [...prior.proposal.item.coworkers];
      for (final name in row.proposal.item.coworkers) {
        if (!names.any(
          (existing) =>
              existing.trim().toLowerCase() == name.trim().toLowerCase(),
        )) {
          names.add(name);
        }
      }
      merged[priorIndex] = prior.copyWith(
        proposal: ScheduleImportProposal(
          item: prior.proposal.item.copyWith(coworkers: names),
          sourceText:
              '${prior.proposal.sourceText}\n${row.proposal.sourceText}',
        ),
      );
    }
    return merged;
  }

  String _batchSourceName(String sourceName, {required bool append}) {
    if (!append) return sourceName;
    final existing = {
      for (final name
          in _rows.map((row) => row.effectiveSourceName).whereType<String>())
        name,
    };
    if (!existing.contains(sourceName)) return sourceName;
    final extensionIndex = sourceName.lastIndexOf('.');
    final hasExtension = extensionIndex > 0;
    final stem = hasExtension
        ? sourceName.substring(0, extensionIndex)
        : sourceName;
    final extension = hasExtension ? sourceName.substring(extensionIndex) : '';
    var copy = 2;
    var candidate = '$stem ($copy)$extension';
    while (existing.contains(candidate)) {
      copy++;
      candidate = '$stem ($copy)$extension';
    }
    return candidate;
  }

  Map<String, String> _suggestColumns(List<String> headers) {
    final byNormalized = {
      for (final header in headers) header.trim().toLowerCase(): header,
    };
    return {
      for (final field in _tableFields.keys)
        if (byNormalized.containsKey(field)) field: byNormalized[field]!,
    };
  }

  Future<void> _continueMappedImport() async {
    final sourceName = _pendingTableName;
    final sourceType = _pendingTableType;
    final bytes = _pendingTableBytes;
    if (sourceName == null || sourceType == null || bytes == null) return;
    final mapping = <String, String>{};
    for (final entry in _columnSelections.entries) {
      if (entry.value.isNotEmpty) mapping[entry.value] = entry.key;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preview = sourceType == ScheduleImportSourceType.csv
          ? await _csvParser.parse(
              utf8.decode(bytes, allowMalformed: false),
              sourceName: sourceName,
              headerMapping: mapping,
            )
          : await _xlsxParser.parse(
              bytes,
              sourceName: sourceName,
              headerMapping: mapping,
            );
      await _showPreview(preview, sourceName, sourceType);
      if (mounted) {
        setState(() {
          _pendingTableBytes = null;
          _pendingTableName = null;
          _pendingTableType = null;
          _tableHeaders = const [];
          _columnSelections = const {};
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showPreview(
    ScheduleImportPreview preview,
    String sourceName,
    ScheduleImportSourceType sourceType,
  ) async {
    final existingItems = await ref.read(scheduleRepositoryProvider).getItems();
    final localLegends = await ref
        .read(workCodeLegendRepositoryProvider)
        .getItems();
    final reviewedProposals = [
      for (final proposal in preview.proposals)
        _withLocalLegendMeaning(proposal, localLegends),
    ];
    if (!mounted) return;
    final append = _appendIncoming;
    _mergeBatchRows(
      _matchExistingRows(reviewedProposals, existingItems),
      preview.notices,
    );
    setState(() {
      _sourceName = sourceName;
      _sourceType = append ? ScheduleImportSourceType.batch : sourceType;
      _error = preview.proposals.isEmpty && preview.notices.isEmpty
          ? 'This calendar has no events to review.'
          : null;
    });
  }

  ScheduleImportProposal _withLocalLegendMeaning(
    ScheduleImportProposal proposal,
    List<WorkCodeLegend> legends,
  ) {
    final item = proposal.item;
    if (item.kind != ScheduleKind.work || item.code == null) {
      return proposal;
    }
    final normalizedCode = item.code!.trim().toLowerCase();
    final normalizedEmployer = item.employerName?.trim().toLowerCase() ?? '';
    final matchingLegends = legends.where((legend) {
      final legendEmployer = legend.employer.trim().toLowerCase();
      return legend.code.trim().toLowerCase() == normalizedCode &&
          legend.appliesOn(item.startDate) &&
          (legendEmployer.isEmpty ||
              normalizedEmployer.isEmpty ||
              legendEmployer == normalizedEmployer);
    }).toList();
    final matchedLegend = matchingLegends.length == 1
        ? matchingLegends.single
        : null;
    final existingMeaning = item.codeMeaning?.trim() ?? '';
    final legendMeaning = matchedLegend?.assignmentDetails.trim() ?? '';
    final meaning = existingMeaning.isNotEmpty
        ? existingMeaning
        : legendMeaning;
    final titleIsOnlyCode = item.title.trim().toLowerCase() == normalizedCode;
    final codePrefix = RegExp(
      '^\\s*${RegExp.escape(item.code!.trim())}(?:\\s*[-–—:·|]\\s*|\\s+)(.+)\$',
      caseSensitive: false,
    ).firstMatch(item.title);
    final titleWithoutCode = codePrefix?.group(1)?.trim();
    final titleHasCodePrefix = titleWithoutCode?.isNotEmpty == true;
    if (!titleIsOnlyCode && !titleHasCodePrefix && meaning == existingMeaning) {
      return proposal;
    }

    final titleDefinition = WorkCodeLegend(
      id: matchedLegend?.id ?? 'imported-code-title',
      employer: matchedLegend?.employer ?? item.employerName ?? '',
      code: item.code!,
      assignmentDetails: meaning,
      flightIds: matchedLegend?.flightIds ?? const [],
    );
    final title = titleIsOnlyCode
        ? meaning.isEmpty
              ? 'Work shift'
              : _rosterEventTitle(titleDefinition)
        : titleHasCodePrefix
        ? titleWithoutCode!
        : item.title;
    return ScheduleImportProposal(
      item: item.copyWith(title: title, codeMeaning: meaning),
      sourceText: proposal.sourceText,
      studyShiftSeriesId: proposal.studyShiftSeriesId,
      studyShiftExpandedThrough: proposal.studyShiftExpandedThrough,
    );
  }

  List<_ImportRow> _matchExistingRows(
    List<ScheduleImportProposal> proposals,
    List<ScheduleItem> existingItems,
  ) {
    final byId = {for (final item in existingItems) item.id: item};
    final matchedIds = <String>{};
    return [
      for (final proposal in proposals)
        _matchExistingRow(proposal, existingItems, byId, matchedIds),
    ];
  }

  _ImportRow _matchExistingRow(
    ScheduleImportProposal proposal,
    List<ScheduleItem> existingItems,
    Map<String, ScheduleItem> byId,
    Set<String> matchedIds,
  ) {
    final proposed = proposal.item;
    final exactIdMatch = byId[proposed.id];
    final semanticMatch = exactIdMatch == null
        ? _takeMatchingSavedShift(proposed, existingItems, matchedIds)
        : const _OcrMatchResult();
    final existing =
        exactIdMatch ??
        semanticMatch.item ??
        (semanticMatch.ambiguous
            ? null
            : _takeMatchingSavedDayMarker(proposed, existingItems, matchedIds));
    if (existing != null) matchedIds.add(existing.id);
    final matchedProposal = existing == null || existing.id == proposed.id
        ? proposal
        : ScheduleImportProposal(
            item: _withItemId(proposed, existing.id),
            sourceText: proposal.sourceText,
          );
    return _ImportRow(
      proposal: matchedProposal,
      existing: existing,
      included: existing == null && !semanticMatch.ambiguous,
      ambiguousMatch: semanticMatch.ambiguous,
    );
  }

  _OcrMatchResult _takeMatchingSavedShift(
    ScheduleItem proposed,
    List<ScheduleItem> candidates,
    Set<String> matchedIds,
  ) {
    if (!_isTimedCodedShift(proposed)) return const _OcrMatchResult();
    final matches = candidates
        .where((candidate) => _sameImportedShift(candidate, proposed))
        .toList(growable: false);
    if (matches.length != 1 || matchedIds.contains(matches.single.id)) {
      return _OcrMatchResult(ambiguous: matches.isNotEmpty);
    }
    return _OcrMatchResult(item: matches.single);
  }

  bool _isTimedCodedShift(ScheduleItem item) =>
      item.kind == ScheduleKind.work &&
      item.workCategory == WorkCategory.shift &&
      !item.hasNoTime &&
      (item.code?.trim().isNotEmpty ?? false);

  bool _sameImportedShift(ScheduleItem saved, ScheduleItem proposed) {
    String normalizeCode(String? value) =>
        value?.replaceAll(RegExp(r'\s+'), '').toUpperCase() ?? '';
    String normalizeEmployer(String? value) =>
        value?.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase() ?? '';

    final savedEmployer = normalizeEmployer(saved.employerName);
    final proposedEmployer = normalizeEmployer(proposed.employerName);
    return _isTimedCodedShift(saved) &&
        _occursOn(saved, proposed.startDate) &&
        normalizeCode(saved.code) == normalizeCode(proposed.code) &&
        (savedEmployer.isEmpty ||
            proposedEmployer.isEmpty ||
            savedEmployer == proposedEmployer) &&
        saved.intervals.length == proposed.intervals.length &&
        List.generate(
          saved.intervals.length,
          (index) => saved.intervals[index] == proposed.intervals[index],
        ).every((matches) => matches);
  }

  ScheduleItem? _takeMatchingSavedDayMarker(
    ScheduleItem proposed,
    List<ScheduleItem> candidates,
    Set<String> matchedIds,
  ) {
    if (!_isSavedDayMarker(proposed)) return null;
    for (final candidate in candidates) {
      if (!matchedIds.contains(candidate.id) &&
          _sameSavedDayMarker(candidate, proposed)) {
        return candidate;
      }
    }
    return null;
  }

  bool _isSavedDayMarker(ScheduleItem item) =>
      item.kind == ScheduleKind.work &&
      (item.isDayOff ||
          item.workCategory == WorkCategory.dayOff ||
          item.workCategory == WorkCategory.restDay) &&
      item.intervals.isEmpty &&
      (item.code?.trim().isNotEmpty ?? false);

  bool _sameSavedDayMarker(ScheduleItem saved, ScheduleItem proposed) {
    if (!_isSavedDayMarker(saved) ||
        saved.startDate != proposed.startDate ||
        saved.workCategory != proposed.workCategory ||
        saved.code?.trim().toLowerCase() !=
            proposed.code?.trim().toLowerCase()) {
      return false;
    }

    String normalize(String value) =>
        value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    final savedEmployer = normalize(saved.employerName ?? '');
    final proposedEmployer = normalize(proposed.employerName ?? '');
    if (savedEmployer.isNotEmpty &&
        proposedEmployer.isNotEmpty &&
        savedEmployer != proposedEmployer) {
      return false;
    }
    final sameTitle = normalize(saved.title) == normalize(proposed.title);
    return sameTitle ||
        (savedEmployer.isNotEmpty && savedEmployer == proposedEmployer);
  }

  Future<bool> _confirmOcrMetrics() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Before using OCR'),
        content: const Text(
          'The selected file and recognized text stay on this device. '
          'Google ML Kit may send technical diagnostics and usage or '
          'performance metrics, such as device and app details or processing '
          'sizes. This applies only to this OCR import. Continue only if you '
          'are comfortable with that.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue once'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  DateTime? _inferredRosterFirstDate(RosterGridCandidate candidate) {
    if (candidate.columns.isEmpty) return null;
    final first = candidate.columns.first;
    final month = first.month;
    final year = first.year;
    if (month == null || year == null) return null;
    final date = DateTime(year, month, first.dayNumber);
    if (date.year != year ||
        date.month != month ||
        date.day != first.dayNumber) {
      return null;
    }
    return date;
  }

  Future<void> _chooseRosterFirstDate() async {
    final initial = _rosterFirstDate ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 2),
      lastDate: DateTime(initial.year + 5),
      helpText: 'Confirm the first roster date',
    );
    if (selected != null && mounted) {
      setState(() {
        _rosterFirstDate = DateTime(
          selected.year,
          selected.month,
          selected.day,
        );
        _rosterDateOverrides = const {};
        _rosterDatesConfirmed = false;
      });
    }
  }

  Future<void> _chooseRosterColumnDate(
    int columnIndex,
    DateTime current,
  ) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 2),
      lastDate: DateTime(current.year + 5),
      helpText: 'Confirm roster date ${columnIndex + 1}',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _rosterDateOverrides = {
        ..._rosterDateOverrides,
        columnIndex: DateTime(selected.year, selected.month, selected.day),
      };
      if (columnIndex == 0) _rosterFirstDate = _rosterDateOverrides[0];
      _rosterDatesConfirmed = false;
    });
  }

  Future<void> _buildRosterGridDrafts() async {
    final detection = _rosterDetection;
    final firstDate = _rosterFirstDate;
    final selectedRow = _selectedRosterRow;
    if (detection == null ||
        firstDate == null ||
        selectedRow == null ||
        !_rosterDatesConfirmed) {
      return;
    }
    final localizations = MaterialLocalizations.of(context);
    final table = detection.candidates[_selectedRosterTable];
    if (selectedRow < 0 || selectedRow >= table.rows.length) return;
    final lowerSourceName = _sourceName?.toLowerCase() ?? '';
    final importFormat = lowerSourceName.endsWith('.pdf')
        ? 'pdf-ocr'
        : lowerSourceName.endsWith('.csv')
        ? 'csv-roster-table'
        : lowerSourceName.endsWith('.xlsx')
        ? 'xlsx-roster-table'
        : 'image-ocr';
    try {
      final selection = const RosterGridSelectionResolver().resolve(
        detection: detection,
        candidateIndex: _selectedRosterTable,
        selectedRowIndex: selectedRow,
        firstDate: firstDate,
        dateOverrides: _rosterDateOverrides,
      );
      final dates = selection.cells.map((cell) => cell.date).toList();
      final deviceZone = await ref.read(deviceTimeZoneIdProvider.future);
      final rosterZone = _rosterTimeZoneId?.trim().isNotEmpty == true
          ? _rosterTimeZoneId!.trim()
          : deviceZone;
      final zoneCheck = CivilTimeResolver().resolve(
        CivilDate(firstDate.year, firstDate.month, firstDate.day),
        12 * 60,
        rosterZone,
      );
      if (zoneCheck.status == CivilTimeStatus.invalidTimeZone) {
        throw const FormatException(
          'Enter a recognized IANA time zone, such as America/Barbados.',
        );
      }
      final legends = await ref
          .read(workCodeLegendRepositoryProvider)
          .getItems();
      final proposedDefinitions = <WorkCodeLegend>[];
      final definitionConflicts = <WorkCodeLegend>[];
      if (_rosterDatesConfirmed && dates.isNotEmpty) {
        final orderedDates = [...dates]..sort((a, b) => a.compareTo(b));
        final first = orderedDates.first;
        final last = orderedDates.last;
        final parsedByCode = <String, List<WorkCodeLegend>>{};
        for (final parsed
            in _rosterLegendDetection?.definitions ??
                const <WorkCodeLegend>[]) {
          parsedByCode
              .putIfAbsent(parsed.code.trim().toUpperCase(), () => [])
              .add(parsed);
        }
        for (final codeEntries in parsedByCode.values) {
          if (codeEntries.length > 1) {
            // Multiple incompatible definitions for one code cannot share
            // an effective period. Leave them for manual review.
            definitionConflicts.addAll(codeEntries);
            continue;
          }
          final parsed = codeEntries.single;
          final imported = parsed.copyWith(
            effectiveStartDate: CivilDate(first.year, first.month, first.day),
            effectiveEndDate: CivilDate(last.year, last.month, last.day),
          );
          final sameCode = legends.where(
            (saved) =>
                saved.code.trim().toUpperCase() ==
                imported.code.trim().toUpperCase(),
          );
          final overlaps = sameCode
              .where((saved) => saved.overlapsEffectivePeriod(imported))
              .toList();
          if (overlaps.isNotEmpty) {
            final identical = overlaps.any(
              (saved) =>
                  _sameLegendWindows(saved.timeWindows, imported.timeWindows) &&
                  saved.assignmentDetails.trim().toLowerCase() ==
                      imported.assignmentDetails.trim().toLowerCase() &&
                  _sameLegendFlights(saved.flightIds, imported.flightIds),
            );
            if (!identical) definitionConflicts.add(imported);
            continue;
          }
          final idSeed = [
            _sourceName ?? '',
            imported.code,
            imported.effectiveStartDate,
            imported.effectiveEndDate,
            imported.timeWindows,
            imported.assignmentDetails,
            imported.flightIds,
          ].join('|');
          proposedDefinitions.add(
            WorkCodeLegend(
              id: 'roster-legend-${sha256.convert(utf8.encode(idSeed))}',
              employer: imported.employer,
              code: imported.code,
              assignmentDetails: imported.assignmentDetails,
              flightIds: imported.flightIds,
              timeWindows: imported.timeWindows,
              effectiveStartDate: imported.effectiveStartDate,
              effectiveEndDate: imported.effectiveEndDate,
            ),
          );
        }
      }
      final legendsForDrafts = [...legends, ...proposedDefinitions];
      final existingItems = await ref
          .read(scheduleRepositoryProvider)
          .getItems();
      final existingOccurrenceCoworkers = await ref
          .read(workOccurrenceCoworkerRepositoryProvider)
          .getAll();
      final occurrenceCoworkersByKey = {
        for (final assignment in existingOccurrenceCoworkers)
          '${assignment.shiftItemId}|${assignment.occurrenceDate}': assignment,
      };
      final byId = {for (final item in existingItems) item.id: item};
      final existingOcrItems = existingItems
          .where(_canMatchOcrProposal)
          .toList();
      final matchedIds = <String>{};
      final proposals = <_ImportRow>[];
      final unresolved = <String>[];
      for (
        var columnIndex = 0;
        columnIndex < selection.cells.length;
        columnIndex++
      ) {
        final cell = selection.cells[columnIndex];
        if (cell.rawCode.isEmpty) continue;
        if (cell.needsReview) {
          unresolved.add(
            '${localizations.formatMediumDate(dates[columnIndex])} · ${cell.rawCode}',
          );
          continue;
        }
        final normalizedCell = cell.rawCode.trim().toUpperCase();
        if (_isOffMarker(normalizedCell)) {
          final sourceText = 'Roster cell ${cell.rawCode}';
          final key = sha256
              .convert(
                utf8.encode(
                  '$_sourceName\n${table.page}\n$selectedRow\n$columnIndex\n$sourceText',
                ),
              )
              .toString();
          final item = ScheduleItem(
            id: 'roster-ocr-$key',
            kind: ScheduleKind.work,
            title: 'Day off',
            startDate: CivilDate(
              dates[columnIndex].year,
              dates[columnIndex].month,
              dates[columnIndex].day,
            ),
            intervals: const [],
            code: normalizedCell,
            codeMeaning: 'Day off',
            workCategory: WorkCategory.dayOff,
            importProvenance: ScheduleImportProvenance(
              format: importFormat,
              uid: 'roster-cell-$key',
              sourceName: _sourceName ?? 'schedule.pdf',
              sourceText: sourceText,
              importedAt: DateTime.now().toUtc(),
            ),
          );
          final proposal = ScheduleImportProposal(
            item: item,
            sourceText: sourceText,
          );
          final reviewRow = _ocrReviewRow(
            proposal,
            byId: byId,
            unusedExistingOcrItems: existingOcrItems,
            matchedOcrIds: matchedIds,
            rosterProposal: true,
          );
          proposals.add(
            reviewRow.copyWith(
              included:
                  (reviewRow.existing == null || reviewRow.coworkerOnly) &&
                  !reviewRow.ambiguousMatch,
            ),
          );
          continue;
        }
        final matches = cell.needsReview
            ? const <WorkCodeLegend>[]
            : legendsForDrafts.where((legend) {
                return legend.code.trim().toUpperCase() == normalizedCell &&
                    legend.appliesOn(
                      CivilDate(
                        dates[columnIndex].year,
                        dates[columnIndex].month,
                        dates[columnIndex].day,
                      ),
                    );
              }).toList();
        final legend =
            matches.length == 1 && matches.single.timeWindows.isNotEmpty
            ? matches.single
            : null;
        if (legend == null) {
          unresolved.add(
            '${localizations.formatMediumDate(dates[columnIndex])} · ${cell.rawCode}',
          );
          continue;
        }
        final intervals = legend.timeWindows
            .map(
              (window) => EventInterval(
                startDayOffset: 0,
                startMinute: window.startMinute,
                endDayOffset: window.endDayOffset,
                endMinute: window.endMinute,
              ),
            )
            .toList(growable: false);
        final sourceText = 'Roster cell ${cell.rawCode}';
        final coworkers = const RosterGridImportParser().coworkersForCell(
          table,
          selectedRow: selectedRow,
          columnIndex: columnIndex,
          code: normalizedCell,
          date: CivilDate(
            dates[columnIndex].year,
            dates[columnIndex].month,
            dates[columnIndex].day,
          ),
          legends: legendsForDrafts,
          coworkerScope: _rosterCoworkerScope,
        );
        final key = sha256
            .convert(
              utf8.encode(
                '$_sourceName\n${table.page}\n$selectedRow\n$columnIndex\n$sourceText',
              ),
            )
            .toString();
        final title = _rosterEventTitle(legend);
        final item = ScheduleItem(
          id: 'roster-ocr-$key',
          kind: ScheduleKind.work,
          title: title,
          startDate: CivilDate(
            dates[columnIndex].year,
            dates[columnIndex].month,
            dates[columnIndex].day,
          ),
          intervals: intervals,
          timeZoneId: rosterZone,
          code: legend.code,
          codeMeaning: legend.assignmentDetails,
          coworkers: coworkers,
          employerName: legend.employer,
          workCategory: WorkCategory.shift,
          importProvenance: ScheduleImportProvenance(
            format: importFormat,
            uid: 'roster-cell-$key',
            sourceName: _sourceName ?? 'schedule.pdf',
            sourceText: sourceText,
            importedAt: DateTime.now().toUtc(),
          ),
        );
        final proposal = ScheduleImportProposal(
          item: item,
          sourceText: sourceText,
        );
        final reviewRow = _ocrReviewRow(
          proposal,
          byId: byId,
          unusedExistingOcrItems: existingOcrItems,
          matchedOcrIds: matchedIds,
          rosterProposal: true,
          occurrenceCoworkersByKey: occurrenceCoworkersByKey,
        );
        proposals.add(
          reviewRow.copyWith(
            included:
                (reviewRow.existing == null || reviewRow.coworkerOnly) &&
                !reviewRow.ambiguousMatch,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        final currentSource = _sourceName;
        final retainedRows = [
          for (final row in _rows)
            if (row.effectiveSourceName != currentSource) row,
        ];
        final combinedRows = [...retainedRows, ...proposals];
        final duplicates = _duplicateBatchGroups(combinedRows);
        final duplicateIndexes = duplicates.values
            .expand((indexes) => indexes)
            .toSet();
        _rows = [
          for (var index = 0; index < combinedRows.length; index++)
            if (duplicateIndexes.contains(index))
              combinedRows[index].copyWith(included: false)
            else
              combinedRows[index],
        ];
        if (_appendIncoming) _sourceType = ScheduleImportSourceType.batch;
        _appendIncoming = false;
        _unresolvedRosterCells = unresolved;
        _rosterLegendProposals = proposedDefinitions;
        _rosterLegendConflicts = definitionConflicts;
        _selectedRosterLegendIds = proposedDefinitions
            .where(_rosterLegendParser.isSafeToPreselect)
            .map((entry) => entry.id)
            .toSet();
        _notices = [
          ScheduleImportNotice(
            'Drafts use only the selected staff row and confirmed date columns. Unmatched or ambiguous cells are kept for manual review and never converted into shifts.',
          ),
          if (duplicates.isNotEmpty)
            ScheduleImportNotice(
              'Matching date and code entries from multiple roster files start unchecked, even if the times differ. Review the row details and select only the correct version.',
            ),
        ];
        _error = proposals.isEmpty && unresolved.isEmpty
            ? 'No shift codes were found in the selected row. Check the row choice and date columns.'
            : null;
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  bool _isOffMarker(String raw) => const {
    'X',
    'OFF',
    'REST',
    'DAY OFF',
    'D/O',
    'DO',
  }.contains(raw.trim().toUpperCase());

  String _formatLegendWindow(BuildContext context, WorkCodeTimeWindow window) {
    final start = TimeOfDay(
      hour: window.startMinute ~/ 60,
      minute: window.startMinute % 60,
    ).format(context);
    final end = TimeOfDay(
      hour: window.endMinute ~/ 60,
      minute: window.endMinute % 60,
    ).format(context);
    return '$start–$end${window.endDayOffset > 0 ? ' (+1 day)' : ''}';
  }

  bool _sameLegendWindows(
    List<WorkCodeTimeWindow> left,
    List<WorkCodeTimeWindow> right,
  ) =>
      left.length == right.length &&
      List.generate(
        left.length,
        (index) => index,
      ).every((index) => left[index] == right[index]);

  bool _sameLegendFlights(List<String> left, List<String> right) =>
      left.length == right.length &&
      List.generate(left.length, (index) => index).every(
        (index) => left[index].toUpperCase() == right[index].toUpperCase(),
      );

  bool _isImportedWorkRow(_ImportRow row) {
    final item = row.proposal.item;
    final sourceName = row.effectiveSourceName?.trim() ?? '';
    return item.kind == ScheduleKind.work && sourceName.isNotEmpty;
  }

  int _batchSourceCount(List<_ImportRow> rows) => {
    for (final row in rows)
      if (_isImportedWorkRow(row)) row.effectiveSourceName!,
  }.length;

  Map<String, List<int>> _duplicateBatchGroups(List<_ImportRow> rows) {
    final grouped = <String, List<int>>{};
    if (_batchSourceCount(rows) < 2) return const {};
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      if (!_isImportedWorkRow(row) || row.coworkerOnly) continue;
      final item = row.proposal.item;
      final codeKey = item.workCategory == WorkCategory.dayOff
          ? 'day-off'
          : item.code?.trim().toUpperCase() ?? '';
      if (codeKey.isEmpty) continue;
      final employerKey = item.employerName?.trim().toUpperCase() ?? '';
      // Revised rosters can change a shift's hours while retaining its date
      // and code. Treat that as a version conflict too, and let the owner
      // choose which row to keep instead of silently importing both shifts.
      // Keep different employers and work categories independent.
      final key =
          '${item.startDate}|$employerKey|${item.workCategory}|$codeKey';
      grouped.putIfAbsent(key, () => []).add(index);
    }
    return {
      for (final entry in grouped.entries)
        if (entry.value
                .map((index) => rows[index].effectiveSourceName!)
                .toSet()
                .length >
            1)
          entry.key: entry.value,
    };
  }

  _ImportRow _ocrReviewRow(
    ScheduleImportProposal proposal, {
    required Map<String, ScheduleItem> byId,
    required List<ScheduleItem> unusedExistingOcrItems,
    required Set<String> matchedOcrIds,
    bool rosterProposal = false,
    Map<String, WorkOccurrenceCoworkers> occurrenceCoworkersByKey = const {},
    String? sourceName,
  }) {
    final exactIdMatch = byId[proposal.item.id];
    final match = exactIdMatch == null
        ? _takeMatchingOcrEvent(
            proposal.item,
            unusedExistingOcrItems,
            matchedOcrIds,
            rosterProposal: rosterProposal,
          )
        : _OcrMatchResult(item: exactIdMatch);
    final existing = match.item;
    if (existing != null) matchedOcrIds.add(existing.id);
    var matchedProposal = existing == null || existing.id == proposal.item.id
        ? proposal
        : ScheduleImportProposal(
            item: _withItemId(proposal.item, existing.id),
            sourceText: proposal.sourceText,
          );
    var coworkerOnly = false;
    CivilDate? rosterOccurrenceDate;
    if (existing != null && rosterProposal && !match.ambiguous) {
      final isRecurring = existing.recurrence != null;
      final occurrenceDate = proposal.item.startDate;
      final priorCoworkers = isRecurring
          ? occurrenceCoworkersByKey['${existing.id}|$occurrenceDate']
                    ?.coworkers ??
                const <String>[]
          : existing.coworkers;
      final mergedCoworkers = [...priorCoworkers];
      for (final name in proposal.item.coworkers) {
        if (!mergedCoworkers.any(
          (saved) => saved.trim().toLowerCase() == name.trim().toLowerCase(),
        )) {
          mergedCoworkers.add(name);
        }
      }
      coworkerOnly = mergedCoworkers.length != existing.coworkers.length;
      if (isRecurring) {
        coworkerOnly = mergedCoworkers.length != priorCoworkers.length;
        rosterOccurrenceDate = occurrenceDate;
      }
      if (coworkerOnly) {
        matchedProposal = ScheduleImportProposal(
          item: existing.copyWith(coworkers: mergedCoworkers),
          sourceText: proposal.sourceText,
        );
      }
    }
    return _ImportRow(
      proposal: matchedProposal,
      existing: existing,
      included: (existing == null || coworkerOnly) && !match.ambiguous,
      ambiguousMatch: match.ambiguous,
      coworkerOnly: coworkerOnly,
      rosterOccurrenceDate: rosterOccurrenceDate,
      sourceName: sourceName ?? proposal.item.importProvenance?.sourceName,
    );
  }

  _OcrMatchResult _takeMatchingOcrEvent(
    ScheduleItem proposed,
    List<ScheduleItem> candidates,
    Set<String> matchedIds, {
    required bool rosterProposal,
  }) {
    final matches = candidates
        .where(
          (candidate) =>
              !matchedIds.contains(candidate.id) ||
              (rosterProposal && candidate.recurrence != null),
        )
        .where(
          (candidate) =>
              _sameOcrEvent(candidate, proposed) ||
              (rosterProposal && _sameRosterShift(candidate, proposed)),
        )
        .toList(growable: false);
    if (matches.length == 1) return _OcrMatchResult(item: matches.single);
    return _OcrMatchResult(ambiguous: matches.length > 1);
  }

  bool _canMatchOcrProposal(ScheduleItem item) =>
      _hasOcrProvenance(item) ||
      (item.kind == ScheduleKind.work &&
          item.workCategory == WorkCategory.shift &&
          !item.hasNoTime);

  bool _isExamTimetable(String fileName, String text) => RegExp(
    r'\b(exam(?:ination)?s?|midterms?|finals?|assessment timetable)\b',
    caseSensitive: false,
  ).hasMatch('$fileName\n$text');

  bool _hasOcrProvenance(ScheduleItem item) =>
      switch (item.importProvenance?.format) {
        'pdf-ocr' || 'image-ocr' || 'exam-timetable-ocr' => true,
        _ => false,
      };

  bool _sameOcrEvent(ScheduleItem saved, ScheduleItem proposed) {
    String normalize(String value) =>
        value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

    return saved.kind == proposed.kind &&
        saved.deadlineType == proposed.deadlineType &&
        normalize(saved.title) == normalize(proposed.title) &&
        normalize(saved.code ?? '') == normalize(proposed.code ?? '') &&
        saved.startDate == proposed.startDate &&
        saved.timeZoneId == proposed.timeZoneId &&
        saved.intervals.length == proposed.intervals.length &&
        List.generate(
          saved.intervals.length,
          (index) => saved.intervals[index] == proposed.intervals[index],
        ).every((matches) => matches);
  }

  bool _occursOn(ScheduleItem item, CivilDate date) {
    final recurrence = item.recurrence;
    if (recurrence == null) return item.startDate == date;
    return date.compareTo(item.startDate) >= 0 &&
        (recurrence.until == null || date.compareTo(recurrence.until!) <= 0) &&
        recurrence.weekdays.contains(date.weekday) &&
        !recurrence.exceptionDates.contains(date);
  }

  bool _sameRosterShift(ScheduleItem saved, ScheduleItem proposed) {
    return _matchesRosterIdentity(
      saved,
      CoworkerRosterAssignment(
        date: proposed.startDate,
        code: proposed.code ?? '',
        employer: proposed.employerName,
        coworkers: proposed.coworkers,
        sourceRows: const [],
      ),
    );
  }

  bool _matchesRosterIdentity(
    ScheduleItem saved,
    CoworkerRosterAssignment assignment,
  ) {
    String normalizeEmployer(String? value) =>
        value?.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase() ?? '';
    String normalizeCode(String? value) =>
        value?.replaceAll(RegExp(r'\s+'), '').toUpperCase() ?? '';

    final savedEmployer = normalizeEmployer(saved.employerName);
    final proposedEmployer = normalizeEmployer(assignment.employer);
    return saved.kind == ScheduleKind.work &&
        saved.workCategory == WorkCategory.shift &&
        !saved.hasNoTime &&
        _occursOn(saved, assignment.date) &&
        normalizeCode(saved.code).isNotEmpty &&
        normalizeCode(saved.code) == normalizeCode(assignment.code) &&
        (savedEmployer.isEmpty ||
            proposedEmployer.isEmpty ||
            savedEmployer == proposedEmployer);
  }

  ScheduleItem _withItemId(ScheduleItem item, String id) => ScheduleItem(
    id: id,
    kind: item.kind,
    title: item.title,
    startDate: item.startDate,
    intervals: item.intervals,
    timeZoneId: item.timeZoneId,
    code: item.code,
    codeMeaning: item.codeMeaning,
    employerName: item.employerName,
    departmentName: item.departmentName,
    jobRole: item.jobRole,
    location: item.location,
    notes: item.notes,
    reportingInstruction: item.reportingInstruction,
    supervisorName: item.supervisorName,
    supervisorPhone: item.supervisorPhone,
    contactName: item.contactName,
    contactPhone: item.contactPhone,
    coworkers: item.coworkers,
    academicTermId: item.academicTermId,
    recurrence: item.recurrence,
    workCategory: item.workCategory,
    deadlineType: item.deadlineType,
    isDayOff: item.isDayOff,
    allDay: item.allDay,
    isCompleted: item.isCompleted,
    importProvenance: item.importProvenance,
    reminderMinutesBefore: item.reminderMinutesBefore,
  );

  Future<void> _editRow(int index) async {
    final row = _rows[index];
    final deviceZone = await ref.read(deviceTimeZoneIdProvider.future);
    if (!mounted) return;
    final item = await showDialog<ScheduleItem>(
      context: context,
      builder: (_) => _ImportProposalEditor(
        item: row.proposal.item,
        deviceZone: deviceZone,
      ),
    );
    if (item != null && mounted) {
      setState(() {
        _rows = [
          for (var i = 0; i < _rows.length; i++)
            if (i == index)
              _rows[i].copyWith(
                proposal: ScheduleImportProposal(
                  item: item,
                  sourceText: row.proposal.sourceText,
                ),
              )
            else
              _rows[i],
        ];
      });
    }
  }

  Future<void> _importSelected() async {
    final selected = _rows
        .where((row) => row.included && !row.ambiguousMatch)
        .toList();
    final selectedCodeDefinitions = _rosterLegendProposals
        .where((entry) => _selectedRosterLegendIds.contains(entry.id))
        .toList(growable: false);
    final selectedSupervisors = [
      ..._supervisorProposals.where(
        (profile) => _selectedSupervisorIds.contains(profile.id),
      ),
      ..._selectedManualRosterSupervisors(),
    ];
    if (selected.isEmpty &&
        selectedCodeDefinitions.isEmpty &&
        selectedSupervisors.isEmpty) {
      setState(() => _error = 'Select at least one change to apply.');
      return;
    }
    final sourceType = _sourceType;
    if (sourceType == null) {
      setState(() => _error = 'Review an import file before adding events.');
      return;
    }
    final duplicateGroups = _duplicateBatchGroups(_rows);
    final selectedDuplicate = duplicateGroups.values.any(
      (indexes) =>
          indexes
              .where(
                (index) =>
                    _rows[index].included && !_rows[index].ambiguousMatch,
              )
              .length >
          1,
    );
    if (selectedDuplicate) {
      setState(
        () => _error = 'Two roster files contain the same shift date, code and time. Select only the correct version before adding.',
      );
      return;
    }
    final rejectedCount = _rows
        .where((row) => !row.included && row.existing == null)
        .length;
    final skippedDuplicateCount = _rows
        .where((row) => !row.included && row.existing != null)
        .length;
    final eventDuplicateCount = selected
        .where((row) => row.existing != null && !row.coworkerOnly)
        .length;
    if (_replaceMatches && eventDuplicateCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: const Text('Replace saved events?'),
          content: Text(
            '$eventDuplicateCount matching event${eventDuplicateCount == 1 ? '' : 's'} will be replaced with the reviewed calendar version. This cannot be undone in the app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep saved events'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace matching'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final coworkerUpdates = selected
          .where((row) => row.coworkerOnly && row.rosterOccurrenceDate == null)
          .map((row) => row.proposal.item)
          .toList(growable: false);
      final occurrenceCoworkerUpdates = selected
          .where((row) => row.coworkerOnly && row.rosterOccurrenceDate != null)
          .map((row) {
            final item = row.proposal.item;
            return WorkOccurrenceCoworkers(
              shiftItemId: item.id,
              occurrenceDate: row.rosterOccurrenceDate!,
              rosterCode: item.code!,
              employerName: item.employerName,
              coworkers: item.coworkers,
            );
          })
          .toList(growable: false);
      final coworkerEntriesUpdated =
          coworkerUpdates.length + occurrenceCoworkerUpdates.length;
      final savedSupervisorNames = {
        for (final profile
            in await ref.read(supervisorRepositoryProvider).getItems())
          _normalizeStaffName(profile.name),
      };
      final supervisorsToSave = selectedSupervisors
          .where(
            (profile) =>
                savedSupervisorNames.add(_normalizeStaffName(profile.name)),
          )
          .toList(growable: false);
      final result = await ref
          .read(scheduleRepositoryProvider)
          .applyRosterImport(
            eventItems: [
              for (final row in selected)
                if (!row.coworkerOnly) row.proposal.item,
            ],
            coworkerUpdates: coworkerUpdates,
            occurrenceCoworkerUpdates: occurrenceCoworkerUpdates,
            codeDefinitions: selectedCodeDefinitions,
            supervisorProfiles: supervisorsToSave,
            replaceExisting: _replaceMatches,
            historyDraft: ScheduleImportHistoryDraft(
              sourceType: sourceType,
              parserVersion: sourceType.parserVersion,
              proposedCount:
                  _rows.length +
                  _rosterLegendProposals.length +
                  _supervisorProposals.length +
                  _manualRosterSupervisorProfiles.length,
              rejectedCount: rejectedCount,
              skippedCount: skippedDuplicateCount,
              warningsCount: _notices.length,
              importedAt: DateTime.now().toUtc(),
            ),
          );
      ref.invalidate(scheduleItemsProvider);
      ref.invalidate(workOccurrenceCoworkersProvider);
      ref.invalidate(supervisorProfilesProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${result.inserted}, replaced ${result.replaced}, skipped ${result.skipped}.${selectedCodeDefinitions.isEmpty ? '' : ' Added ${selectedCodeDefinitions.length} shift-code definitions.'}${result.supervisorsAdded == 0 ? '' : ' Added ${result.supervisorsAdded} supervisor ${result.supervisorsAdded == 1 ? 'profile' : 'profiles'}.'}${coworkerEntriesUpdated == 0 ? '' : ' Updated coworkers for $coworkerEntriesUpdated ${coworkerEntriesUpdated == 1 ? 'saved shift entry' : 'saved shift entries'}.'}',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _detectedImportType() {
    if (_sourceType == ScheduleImportSourceType.batch) {
      return 'Multiple timetable files';
    }
    if (_rows.isEmpty && _supervisorProposals.isNotEmpty) {
      return 'Supervisor roster';
    }
    if (_rosterDetection?.candidates.isNotEmpty == true) {
      return 'Employee roster';
    }
    if (_coworkerRosterDetected) return 'Employee roster';
    return switch (_sourceType) {
      ScheduleImportSourceType.ics => 'ICS calendar',
      ScheduleImportSourceType.csv => 'CSV schedule or roster',
      ScheduleImportSourceType.xlsx => 'Excel schedule or roster',
      ScheduleImportSourceType.pdfOcr => 'PDF timetable',
      ScheduleImportSourceType.imageOcr => 'Schedule image',
      ScheduleImportSourceType.examTimetableOcr => 'Exam timetable',
      ScheduleImportSourceType.batch => 'Multiple timetable files',
      null => 'Timetable information',
    };
  }

  String _importDestination() {
    final destinations = <String>{};
    if (_rosterLegendProposals.any(
      (entry) => _selectedRosterLegendIds.contains(entry.id),
    )) {
      destinations.add('Shift Legend · Codes');
    }
    if (_supervisorProposals.any(
      (profile) => _selectedSupervisorIds.contains(profile.id),
    )) {
      destinations.add('Shift Legend · Supervisors');
    }
    for (final row in _rows) {
      if (row.coworkerOnly) {
        destinations.add('Shift Legend · Coworkers');
        continue;
      }
      final item = row.proposal.item;
      destinations.add(switch (item.kind) {
        ScheduleKind.work => 'My Work Schedule',
        ScheduleKind.classSession => 'Classes',
        ScheduleKind.deadline =>
          item.deadlineType == DeadlineType.examination
              ? 'Exams'
              : 'Assignments',
        ScheduleKind.personal => 'Calendar',
      });
    }
    return destinations.join(' · ');
  }

  String _importAction() {
    final coworkerUpdates = _rows.where((row) => row.coworkerOnly).length;
    final newEntries = _rows
        .where((row) => row.existing == null && !row.ambiguousMatch)
        .length;
    final selectedSupervisors =
        _supervisorProposals
            .where((profile) => _selectedSupervisorIds.contains(profile.id))
            .length +
        _manualRosterSupervisorProfiles.length;
    if (selectedSupervisors > 0 && newEntries == 0 && coworkerUpdates == 0) {
      return 'Add reviewed supervisor profiles';
    }
    if (selectedSupervisors > 0) return 'Add schedule and supervisor details';
    if (coworkerUpdates > 0 && newEntries > 0) {
      return 'Add new entries and update matched coworkers';
    }
    if (coworkerUpdates > 0) {
      return 'Update coworkers on matched shifts';
    }
    if (newEntries > 0) return 'Add reviewed schedule entries';
    return 'Review existing and uncertain matches';
  }

  @override
  Widget build(BuildContext context) {
    final availableRosterStaffNames = _availableRosterStaffNames();
    final manualSupervisorProfiles = _selectedManualRosterSupervisors();
    final duplicateCount = _rows
        .where((row) => row.included && row.existing != null)
        .length;
    final selectedCount = _rows
        .where((row) => row.included && !row.ambiguousMatch)
        .length;
    final selectedCodeCount = _rosterLegendProposals
        .where((entry) => _selectedRosterLegendIds.contains(entry.id))
        .length;
    final selectedSupervisorCount =
        _supervisorProposals
            .where((profile) => _selectedSupervisorIds.contains(profile.id))
            .length +
        manualSupervisorProfiles.length;
    final hasAmbiguousOcrTime = _rosterLegendProposals.any(
      (entry) => !_rosterLegendParser.isSafeToPreselect(entry),
    );
    final selectedChangeCount =
        selectedCount + selectedCodeCount + selectedSupervisorCount;
    final rosterBatchCount = _batchSourceCount(_rows);
    final hasCoworkerUpdates = _rows.any((row) => row.coworkerOnly);
    final reviewHeading = _pendingTableName != null
        ? 'Match your roster columns'
        : _rosterDetection != null
        ? 'Review detected roster'
        : _coworkerRosterDetected
        ? 'Review coworker matches'
        : _rows.isEmpty && _supervisorProposals.isNotEmpty
        ? 'Review supervisor profiles'
        : _rows.isEmpty
        ? 'Choose a file to get started'
        : 'Review before adding';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Import'),
        actions: [
          IconButton(
            tooltip: 'Import history',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ScheduleImportHistoryPage(),
              ),
            ),
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('smart-import-list'),
          padding: const EdgeInsets.fromLTRB(
            StudyShiftSpacing.pageMargin,
            12,
            StudyShiftSpacing.pageMargin,
            StudyShiftSpacing.pageMargin,
          ),
          children: [
            Text(
              reviewHeading,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Import schedules, rosters, exams, or other timetable information. Smart Import detects the file type and content, then previews proposed changes here.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a supported file. Add other timetable files to the same review when needed. StudyShift reads rows, columns, dates, times, codes, and names where available. Nothing is saved until you review and confirm.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.table_view_outlined),
                title: const Text('CSV and Excel file format'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Required fields: date, title and category. Timed events also need start, end and a time_zone value to preserve the event clock correctly. Use YYYY-MM-DD dates, 24-hour HH:mm times, and an IANA zone such as America/Barbados. Optional fields: end_date, source_id, employer, department, job_role, code, code_meaning, coworkers, coworker_codes, reporting_instruction, location, notes, supervisor_name, supervisor_phone, contact_name and contact_phone. Separate coworker names with semicolons; for work rows, coworker_codes must list one roster code per name in the same order. Names with a different code are excluded, and names without verifiable codes are not attached. Use end_date for overnight events; for a split shift, use one row per interval and the same source_id. Excel imports read visible worksheets; formulas, hidden rows and hidden worksheets are refused. Categories: shift, overtime, training, class, examination, assignment, rest_day, leave, day_off or personal. Review every proposed event before saving.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'For a coworker-only roster table, add a coworker_codes column with one code per name in the same semicolon-separated order. Names with a different code are excluded. Without individual codes, the update stays unchecked until you verify it.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    'source_id,date,end_date,title,category,start,end,time_zone,employer,department,job_role,code,code_meaning,coworkers,coworker_codes,reporting_instruction,location,notes,supervisor_name,supervisor_phone,contact_name,contact_phone\n'
                    'SYNTH-001,2026-11-07,2026-11-08,Sample overnight shift,shift,21:00,05:00,America/Barbados,Synthetic employer,Synthetic department,Synthetic role,S1,Confirmed sample meaning,Synthetic coworker,S1,Sample reporting text,Sample location,,,,,\n'
                    'SYNTH-002,2026-11-08,2026-11-08,Sample split shift,shift,06:00,09:00,America/Barbados,Synthetic employer,Synthetic department,Synthetic role,A1,Sample duties,Synthetic coworker,A1,Sample reporting text,Sample location,,Synthetic supervisor,+1 246 555 0100,Synthetic contact,+1 246 555 0101\n'
                    'SYNTH-002,2026-11-08,2026-11-08,Sample split shift,shift,12:00,16:00,America/Barbados,Synthetic employer,Synthetic department,Synthetic role,A1,Sample duties,Synthetic coworker,A1,Sample reporting text,Sample location,,Synthetic supervisor,+1 246 555 0100,Synthetic contact,+1 246 555 0101',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('smart-import-choose-file'),
              onPressed: _loading || _saving ? null : _selectFile,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_open_outlined),
              label: Text(_loading ? 'Reading file…' : 'Choose a file'),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Supported files: ICS, PDF, images, CSV and Excel (.xlsx). Dates or roster layouts that cannot be identified confidently are flagged for review instead of guessed.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (_pendingTableName != null) ...[
              const SizedBox(height: 12),
              _buildColumnMapper(),
            ],
            if (_sourceName != null) ...[
              const SizedBox(height: 8),
              _NoticeCard(
                icon: Icons.description_outlined,
                message: 'Source: $_sourceName',
              ),
            ],
            if (_rows.isNotEmpty || _supervisorProposals.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(StudyShiftSpacing.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Document recognized',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _ImportSummaryLine(
                        label: 'Detected type',
                        value: _detectedImportType(),
                      ),
                      _ImportSummaryLine(
                        label: 'Destination',
                        value: _importDestination(),
                      ),
                      _ImportSummaryLine(
                        label: 'Action',
                        value: _importAction(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_rosterDetection case final detection?
                when detection.candidates.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildRosterGridSetup(detection),
            ],
            if (_rosterLegendProposals.isNotEmpty ||
                _rosterLegendConflicts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(StudyShiftSpacing.x3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shift code definitions · ${_rosterLegendProposals.length}',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Review these roster references. They are saved only when you apply the reviewed import.',
                      ),
                      if (hasAmbiguousOcrTime) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Some code definitions have ambiguous OCR time text and start unchecked. Verify them against the document before selecting.',
                        ),
                      ],
                      for (final definition in _rosterLegendProposals)
                        CheckboxListTile(
                          key: ValueKey('roster-legend-${definition.id}'),
                          contentPadding: EdgeInsets.zero,
                          value: _selectedRosterLegendIds.contains(
                            definition.id,
                          ),
                          onChanged: _saving || _loading
                              ? null
                              : (selected) => setState(() {
                                  final ids = {..._selectedRosterLegendIds};
                                  if (selected == true) {
                                    ids.add(definition.id);
                                  } else {
                                    ids.remove(definition.id);
                                  }
                                  _selectedRosterLegendIds = ids;
                                }),
                          title: Text(
                            '${definition.code} · ${definition.timeWindows.map((window) => _formatLegendWindow(context, window)).join(' / ')}',
                          ),
                          subtitle: Text(
                            [
                              if (definition.assignmentDetails.isNotEmpty)
                                definition.assignmentDetails,
                              if (definition.flightIds.isNotEmpty)
                                'Possible flights: ${definition.flightIds.join(', ')}',
                              'Applies ${definition.effectiveStartDate} – ${definition.effectiveEndDate}',
                            ].join('\n'),
                          ),
                          secondary: IconButton(
                            tooltip: 'Review or correct ${definition.code}',
                            onPressed: _saving || _loading
                                ? null
                                : () => _reviewRosterLegend(definition),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                      if (_rosterLegendConflicts.isNotEmpty) ...[
                        const Divider(),
                        Text(
                          '${_rosterLegendConflicts.length} code definition${_rosterLegendConflicts.length == 1 ? '' : 's'} not added because a saved code overlaps the roster dates. Existing legend data was preserved.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (_rosterDetection != null) ...[
              const SizedBox(height: 12),
              Card(
                child: ExpansionTile(
                  key: const ValueKey('roster-supervisor-role-review'),
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Assign supervisor roles from this roster'),
                  subtitle: Text(
                    '${availableRosterStaffNames.length} staff names available · no roles inferred',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'This roster does not identify every supervisor. Choose a name and role only when you can confirm it; profiles are saved after Apply.',
                      ),
                    ),
                    if (availableRosterStaffNames.isEmpty &&
                        manualSupervisorProfiles.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'No unassigned staff names are available.',
                          ),
                        ),
                      ),
                    if (availableRosterStaffNames.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('roster-supervisor-staff'),
                        initialValue: _selectedRosterSupervisorName,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Staff name',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final name in availableRosterStaffNames)
                            DropdownMenuItem(value: name, child: Text(name)),
                        ],
                        onChanged: (value) => setState(() {
                          _selectedRosterSupervisorName = value;
                          _selectedRosterSupervisorType = null;
                        }),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<SupervisorType>(
                        key: const ValueKey('roster-supervisor-role'),
                        initialValue: _selectedRosterSupervisorType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirmed supervisor role',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: SupervisorType.permanent,
                            child: Text('Permanent supervisor'),
                          ),
                          DropdownMenuItem(
                            value: SupervisorType.acting,
                            child: Text('Acting supervisor'),
                          ),
                        ],
                        onChanged: (value) => setState(
                          () => _selectedRosterSupervisorType = value,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey('add-roster-supervisor'),
                          onPressed:
                              _selectedRosterSupervisorName == null ||
                                  _selectedRosterSupervisorType == null
                              ? null
                              : _addRosterSupervisor,
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: const Text('Add supervisor profile'),
                        ),
                      ),
                    ],
                    for (final profile in manualSupervisorProfiles)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(profile.name),
                        subtitle: Text(
                          profile.type == SupervisorType.permanent
                              ? 'Permanent supervisor · manually confirmed'
                              : 'Acting supervisor · manually confirmed',
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove ${profile.name}',
                          onPressed: _saving || _loading
                              ? null
                              : () => _removeRosterSupervisor(
                                  _normalizeStaffName(profile.name),
                                ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (_supervisorProposals.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(StudyShiftSpacing.x3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supervisor profiles · ${_supervisorProposals.length}',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Only names under explicit supervisor headings are suggested. Review before adding them to Shift Legend.',
                      ),
                      for (final profile in _supervisorProposals)
                        CheckboxListTile(
                          key: ValueKey('supervisor-profile-${profile.id}'),
                          contentPadding: EdgeInsets.zero,
                          value: _selectedSupervisorIds.contains(profile.id),
                          onChanged: _saving || _loading
                              ? null
                              : (selected) => setState(() {
                                  final ids = {..._selectedSupervisorIds};
                                  if (selected == true) {
                                    ids.add(profile.id);
                                  } else {
                                    ids.remove(profile.id);
                                  }
                                  _selectedSupervisorIds = ids;
                                }),
                          title: Text(profile.name),
                          subtitle: Text(
                            profile.type == SupervisorType.permanent
                                ? 'Permanent supervisor'
                                : 'Acting supervisor',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (_recognizedText != null) ...[
              const SizedBox(height: 8),
              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.text_snippet_outlined),
                  title: const Text('Recognized text'),
                  subtitle: const Text('Local review · not saved as a file'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    SelectableText(
                      _recognizedText!,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              _NoticeCard(error: true, message: _error!),
            ],
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 16),
              if (rosterBatchCount > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '$rosterBatchCount rosters · one combined review and save',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              Text(
                '${hasCoworkerUpdates ? 'Proposed changes' : 'Proposed events'} · $selectedCount selected',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              for (var i = 0; i < _rows.length; i++)
                _ProposalCard(
                  row: _rows[i],
                  onSelected: (selected) {
                    if (_rows[i].ambiguousMatch) return;
                    setState(() {
                      _rows = [
                        for (var j = 0; j < _rows.length; j++)
                          if (j == i)
                            _rows[j].copyWith(included: selected)
                          else
                            _rows[j],
                      ];
                    });
                  },
                  onEdit: () => _editRow(i),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading || _saving
                    ? null
                    : () => _selectFile(appendToBatch: true),
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('Add another file to this import'),
              ),
              if (rosterBatchCount > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$rosterBatchCount files are staged for one review and save.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              if (duplicateCount > 0)
                Card(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.sync_problem_outlined),
                    title: const Text('Replace matching saved events'),
                    subtitle: const Text(
                      'Off by default. Existing events stay unchanged unless you turn this on and confirm.',
                    ),
                    value: _replaceMatches,
                    onChanged: (value) =>
                        setState(() => _replaceMatches = value),
                  ),
                ),
            ],
            if (_unresolvedRosterCells.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(StudyShiftSpacing.x3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Codes to review · ${_unresolvedRosterCells.length}',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'These cells were not added as shifts. Add or correct a matching shift-code definition, then review the roster again.',
                      ),
                      for (final cell in _unresolvedRosterCells)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(cell),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (_notices.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Needs attention · ${_notices.length}',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              for (final notice in _notices)
                _NoticeCard(
                  error: true,
                  message:
                      '${notice.uid == null ? '' : '${notice.uid}: '}${notice.message}',
                ),
            ],
          ],
        ),
      ),
      bottomNavigationBar:
          _rows.isEmpty &&
              selectedCodeCount == 0 &&
              selectedSupervisorCount == 0
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  StudyShiftSpacing.pageMargin,
                  StudyShiftSpacing.x2,
                  StudyShiftSpacing.pageMargin,
                  StudyShiftSpacing.x3,
                ),
                child: FilledButton.icon(
                  onPressed: _saving || _loading ? null : _importSelected,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.playlist_add_check_rounded),
                  label: Text(
                    _saving
                        ? hasCoworkerUpdates
                              ? 'Applying changes…'
                              : 'Adding events…'
                        : hasCoworkerUpdates ||
                              selectedCodeCount > 0 ||
                              selectedSupervisorCount > 0
                        ? 'Apply $selectedChangeCount selected'
                        : 'Add $selectedCount selected',
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildColumnMapper() {
    final requiredFields = ['date', 'title', 'category'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(StudyShiftSpacing.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match your roster columns',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose which heading in ${_pendingTableName ?? 'this file'} contains each StudyShift field. Unmapped columns are ignored.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final field in requiredFields)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _columnDropdown(field, requiredField: true),
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Optional fields'),
              subtitle: const Text(
                'Roster code, supervisor, contact and other details',
              ),
              children: [
                for (final field in _tableFields.keys.where(
                  (field) => !requiredFields.contains(field),
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _columnDropdown(field),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _loading ||
                        _saving ||
                        requiredFields.any(
                          (field) => (_columnSelections[field] ?? '').isEmpty,
                        )
                    ? null
                    : _continueMappedImport,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: Text(
                  _loading ? 'Reading columns…' : 'Match columns and preview',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRosterGridSetup(RosterGridDetection detection) {
    final deviceZone = ref.watch(deviceTimeZoneIdProvider).asData?.value;
    final selectedTable = detection.candidates[_selectedRosterTable];
    final dateLabel = _rosterFirstDate == null
        ? 'Choose first date'
        : MaterialLocalizations.of(context).formatMediumDate(_rosterFirstDate!);
    final localizations = MaterialLocalizations.of(context);
    List<DateTime> mappedDates = const [];
    String? dateMappingError;
    if (_rosterFirstDate != null) {
      try {
        mappedDates = const RosterGridImportParser().mapDates(
          selectedTable,
          _rosterFirstDate!,
          dateOverrides: _rosterDateOverrides,
          allowWeekdayMismatch: true,
        );
      } on FormatException catch (error) {
        dateMappingError = error.message;
      }
    }
    final columnCorrectionDates = mappedDates.isNotEmpty
        ? mappedDates
        : dateMappingError != null && _rosterFirstDate != null
        ? List.generate(
            selectedTable.columns.length,
            (index) =>
                _rosterDateOverrides[index] ??
                _rosterFirstDate!.add(Duration(days: index)),
          )
        : const <DateTime>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(StudyShiftSpacing.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match your roster table',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Confirm the date headings and select your own staff row. Only that row becomes shift drafts.',
            ),
            if (detection.candidates.length > 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: const ValueKey('roster-table-choice'),
                initialValue: _selectedRosterTable,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Detected date row',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (
                    var index = 0;
                    index < detection.candidates.length;
                    index++
                  )
                    DropdownMenuItem(
                      value: index,
                      child: Text(
                        'Page ${detection.candidates[index].page + 1}: ${detection.candidates[index].columns.map((column) => column.dayNumber).join(' · ')}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _selectedRosterTable = value ?? 0;
                  _rosterDateOverrides = const {};
                  _rosterDatesConfirmed = false;
                  _rosterFirstDate = _inferredRosterFirstDate(
                    detection.candidates[_selectedRosterTable],
                  );
                  _selectedRosterRow = null;
                  if (!_appendIncoming) _rows = const [];
                  _unresolvedRosterCells = const [];
                }),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('roster-first-date'),
              onPressed: _loading || _saving ? null : _chooseRosterFirstDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('First roster date · $dateLabel'),
            ),
            if (dateMappingError != null) ...[
              const SizedBox(height: 8),
              Text(
                dateMappingError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (columnCorrectionDates.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                dateMappingError == null
                    ? 'Detected dates · tap any date to correct it, then confirm the full sequence'
                    : 'Date sequence needs correction · choose the correct date for each affected column',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [
                  for (
                    var index = 0;
                    index < columnCorrectionDates.length;
                    index++
                  )
                    ActionChip(
                      key: ValueKey('roster-date-column-$index'),
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        _rosterDateOverrides.containsKey(index)
                            ? Icons.edit_calendar_outlined
                            : Icons.calendar_today_outlined,
                        size: 16,
                      ),
                      label: Text(
                        dateMappingError == null
                            ? localizations.formatMediumDate(
                                columnCorrectionDates[index],
                              )
                            : _rosterDateOverrides.containsKey(index)
                            ? 'Column ${index + 1} · ${localizations.formatMediumDate(columnCorrectionDates[index])}'
                            : 'Column ${index + 1} · day ${selectedTable.columns[index].dayNumber}',
                      ),
                      onPressed: _loading || _saving
                          ? null
                          : () => _chooseRosterColumnDate(
                              index,
                              columnCorrectionDates[index],
                            ),
                    ),
                ],
              ),
              if (dateMappingError == null) ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  key: const ValueKey('confirm-roster-dates'),
                  onPressed: _loading || _saving || _rosterDatesConfirmed
                      ? null
                      : () => setState(() => _rosterDatesConfirmed = true),
                  icon: Icon(
                    _rosterDatesConfirmed
                        ? Icons.check_circle_outline
                        : Icons.fact_check_outlined,
                  ),
                  label: Text(
                    _rosterDatesConfirmed
                        ? 'Dates confirmed'
                        : 'Confirm roster dates',
                  ),
                ),
              ],
            ],
            if (deviceZone != null) ...[
              const SizedBox(height: 12),
              KeyedSubtree(
                key: ValueKey('roster-time-zone-$_rosterTimeZoneRevision'),
                child: TextFormField(
                  key: const ValueKey('roster-time-zone'),
                  initialValue: _rosterTimeZoneId ?? deviceZone,
                  keyboardType: TextInputType.text,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Roster time zone',
                    hintText: 'America/Barbados',
                    helperText:
                        'Default: $deviceZone. Confirm the zone used by the roster.',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => _rosterTimeZoneId = value,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: ValueKey('roster-staff-row-$_selectedRosterTable'),
                onPressed: _loading || _saving
                    ? null
                    : () => _chooseRosterStaffRow(selectedTable),
                icon: const Icon(Icons.person_search_outlined),
                label: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedRosterRow == null
                            ? 'Select your name in the roster'
                            : selectedTable.rows[_selectedRosterRow!].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _selectedRosterRow == null
                            ? 'Search and choose one staff row'
                            : 'Tap to change your row',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<RosterCoworkerScope>(
              key: const ValueKey('roster-coworker-scope'),
              initialValue: _rosterCoworkerScope,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Coworkers to include',
                border: OutlineInputBorder(),
                helperText: 'Choose how coworkers are matched to your shift.',
              ),
              items: const [
                DropdownMenuItem(
                  value: RosterCoworkerScope.sameRosterCode,
                  child: Text('Same roster code'),
                ),
                DropdownMenuItem(
                  value: RosterCoworkerScope.overlappingShiftTimes,
                  child: Text('Overlapping shift times'),
                ),
              ],
              onChanged: (value) => setState(() {
                _rosterCoworkerScope =
                    value ?? RosterCoworkerScope.sameRosterCode;
              }),
            ),
            const SizedBox(height: 10),
            Text(
              'Date columns detected: ${selectedTable.columns.length}. Possible staff rows: ${selectedTable.rows.length}. Saved shift-code definitions fill times where they match; unclear codes remain unchecked.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _loading ||
                        _saving ||
                        _rosterFirstDate == null ||
                        dateMappingError != null ||
                        _selectedRosterRow == null ||
                        !_rosterDatesConfirmed
                    ? null
                    : _buildRosterGridDrafts,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Build shift review'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _columnDropdown(String field, {bool requiredField = false}) {
    final current = _columnSelections[field] ?? '';
    final usedByOthers = {
      for (final entry in _columnSelections.entries)
        if (entry.key != field && entry.value.isNotEmpty) entry.value,
    };
    return DropdownButtonFormField<String>(
      key: ValueKey('column-map-$field'),
      initialValue: current.isEmpty && requiredField ? null : current,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: _tableFields[field],
        border: const OutlineInputBorder(),
        helperText: requiredField ? 'Required' : null,
      ),
      items: [
        if (!requiredField)
          const DropdownMenuItem(value: '', child: Text('Do not import')),
        for (final header in _tableHeaders)
          if (!usedByOthers.contains(header) || header == current)
            DropdownMenuItem(
              value: header,
              child: Text(header, overflow: TextOverflow.ellipsis),
            ),
      ],
      onChanged: (value) => setState(() {
        _columnSelections = {..._columnSelections, field: value ?? ''};
      }),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.row,
    required this.onSelected,
    required this.onEdit,
  });

  final _ImportRow row;
  final ValueChanged<bool> onSelected;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final item = row.proposal.item;
    final date = MaterialLocalizations.of(context).formatMediumDate(
      DateTime(item.startDate.year, item.startDate.month, item.startDate.day),
    );
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final time = item.hasNoTime
        ? 'All day'
        : item.intervals
              .map((part) => formatInterval(part, use24Hour: use24Hour))
              .join(' · ');
    final category = item.kind == ScheduleKind.deadline
        ? deadlineTypeName(item.deadlineType!)
        : scheduleKindName(item.kind);
    final codeLabel = item.kind == ScheduleKind.work
        ? 'Shift code'
        : item.kind == ScheduleKind.personal
        ? 'Code'
        : 'Course code';
    final existing = row.existing;
    final changedFields = existing == null
        ? const <String>[]
        : _importedScheduleChanges(existing, item);
    final coworkersToAdd = row.coworkerOnly && existing != null
        ? item.coworkers
              .where(
                (name) => !existing.coworkers.any(
                  (saved) =>
                      saved.trim().toLowerCase() == name.trim().toLowerCase(),
                ),
              )
              .toSet()
              .toList(growable: false)
        : const <String>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: row.included,
              onChanged: row.ambiguousMatch
                  ? null
                  : (value) => onSelected(value ?? false),
              title: Text(item.title),
              subtitle: Text('$date · $time · $category'),
            ),
            if (row.ambiguousMatch)
              Padding(
                padding: const EdgeInsets.only(left: 44, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                      semanticLabel: 'Ambiguous saved match',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ambiguous match: multiple saved events match this import. Review before adding.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (item.code != null)
              Padding(
                padding: const EdgeInsets.only(left: 44, bottom: 4),
                child: Text('$codeLabel: ${item.code}'),
              ),
            if (item.codeMeaning != null)
              Padding(
                padding: const EdgeInsets.only(left: 44, bottom: 4),
                child: Text('Code assignment: ${item.codeMeaning}'),
              ),
            if (item.location != null)
              Padding(
                padding: const EdgeInsets.only(left: 44, bottom: 4),
                child: Text('Location: ${item.location}'),
              ),
            if (item.recurrence != null)
              Padding(
                padding: const EdgeInsets.only(left: 44, bottom: 4),
                child: Text(_recurrenceDescription(context, item.recurrence!)),
              ),
            if (row.coworkerOnly && existing != null)
              Padding(
                padding: const EdgeInsets.only(left: 44, bottom: 4),
                child: ExpansionTile(
                  key: ValueKey('import-coworkers-${item.id}'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(
                    left: 8,
                    right: 8,
                    bottom: 8,
                  ),
                  title: Text(
                    '${coworkersToAdd.length} ${coworkersToAdd.length == 1 ? 'coworker' : 'coworkers'} to add',
                  ),
                  subtitle: const Text('Saved shift details stay unchanged.'),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final name in coworkersToAdd)
                            Chip(label: Text(name)),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else if (existing != null)
              Padding(
                padding: const EdgeInsets.only(left: 44, bottom: 4),
                child: Text(
                  changedFields.isEmpty
                      ? 'Already saved with no schedule changes. Leave unchecked to keep it.'
                      : 'Changed since saved: ${changedFields.join(', ')}. Leave unchecked to keep the saved event.',
                  style: TextStyle(
                    color: changedFields.isEmpty
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Review or correct'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _recurrenceDescription(
  BuildContext context,
  WeeklyRecurrence recurrence,
) {
  const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final weekdays = [
    for (var day = DateTime.monday; day <= DateTime.sunday; day++)
      if (recurrence.weekdays.contains(day)) weekdayNames[day - 1],
  ];
  final end = recurrence.until;
  final ending = end == null
      ? ''
      : ' through ${MaterialLocalizations.of(context).formatMediumDate(DateTime(end.year, end.month, end.day))}';
  final exceptions = recurrence.exceptionDates.length;
  final skipped = exceptions == 0
      ? ''
      : '; $exceptions ${exceptions == 1 ? 'date' : 'dates'} skipped';
  return 'Repeats weekly on ${weekdays.join(', ')}$ending$skipped';
}

List<String> _importedScheduleChanges(
  ScheduleItem saved,
  ScheduleItem proposed,
) {
  final changes = <String>[];
  if (saved.title != proposed.title) changes.add('title');
  if (saved.startDate.compareTo(proposed.startDate) != 0) {
    changes.add('date');
  }
  if (saved.kind != proposed.kind ||
      saved.workCategory != proposed.workCategory ||
      saved.deadlineType != proposed.deadlineType ||
      saved.allDay != proposed.allDay) {
    changes.add('category');
  }
  if (saved.intervals.length != proposed.intervals.length ||
      saved.intervals.indexed.any(
        (entry) => proposed.intervals[entry.$1] != entry.$2,
      )) {
    changes.add('time');
  }
  if (saved.timeZoneId != proposed.timeZoneId) changes.add('time zone');
  if (saved.code != proposed.code) changes.add('code');
  if (saved.employerName != proposed.employerName) changes.add('employer');
  if (saved.coworkers.length != proposed.coworkers.length ||
      saved.coworkers.indexed.any(
        (entry) =>
            entry.$1 >= proposed.coworkers.length ||
            proposed.coworkers[entry.$1] != entry.$2,
      )) {
    changes.add('coworkers');
  }
  if (saved.location != proposed.location) changes.add('location');
  if (saved.notes != proposed.notes) changes.add('notes');
  if (!_sameRecurrence(saved.recurrence, proposed.recurrence)) {
    changes.add('recurrence');
  }
  if (saved.reminderMinutesBefore != proposed.reminderMinutesBefore) {
    changes.add('reminder');
  }
  return changes;
}

bool _sameRecurrence(WeeklyRecurrence? first, WeeklyRecurrence? second) {
  if (first == null || second == null) return first == second;
  final sameUntil = first.until == null
      ? second.until == null
      : second.until != null && first.until!.compareTo(second.until!) == 0;
  return sameUntil &&
      _sameSet(first.weekdays, second.weekdays) &&
      _sameSet(first.exceptionDates, second.exceptionDates);
}

bool _sameSet<T>(Set<T> first, Set<T> second) =>
    first.length == second.length && first.containsAll(second);

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.message, this.error = false, this.icon});

  final String message;
  final bool error;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Card(
    color: error ? Theme.of(context).colorScheme.errorContainer : null,
    child: ListTile(
      leading: Icon(
        icon ?? (error ? Icons.warning_amber_rounded : Icons.info_outline),
      ),
      title: Text(message),
    ),
  );
}

class _ImportSummaryLine extends StatelessWidget {
  const _ImportSummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: StudyShiftSpacing.x1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _ImportProposalEditor extends StatefulWidget {
  const _ImportProposalEditor({required this.item, required this.deviceZone});

  final ScheduleItem item;
  final String deviceZone;

  @override
  State<_ImportProposalEditor> createState() => _ImportProposalEditorState();
}

class _ImportProposalEditorState extends State<_ImportProposalEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.item.title);
  late final _code = TextEditingController(text: widget.item.code ?? '');
  late final _codeMeaning = TextEditingController(
    text: widget.item.codeMeaning ?? '',
  );
  late final _reportingInstruction = TextEditingController(
    text: widget.item.reportingInstruction ?? '',
  );
  late final _supervisorName = TextEditingController(
    text: widget.item.supervisorName ?? '',
  );
  late final _supervisorPhone = TextEditingController(
    text: widget.item.supervisorPhone ?? '',
  );
  late final _contactName = TextEditingController(
    text: widget.item.contactName ?? '',
  );
  late final _coworkers = TextEditingController(
    text: widget.item.coworkers.join('\n'),
  );
  late final _contactPhone = TextEditingController(
    text: widget.item.contactPhone ?? '',
  );
  late final _location = TextEditingController(
    text: widget.item.location ?? '',
  );
  late final _notes = TextEditingController(text: widget.item.notes ?? '');
  late final _zone = TextEditingController(
    text: widget.item.timeZoneId ?? widget.deviceZone,
  );
  late CivilDate _date = widget.item.startDate;
  late bool _allDay =
      widget.item.allDay ||
      widget.item.workCategory?.isAllDay == true ||
      widget.item.deadlineType == DeadlineType.assignment;
  late TimeOfDay _start = widget.item.intervals.isEmpty
      ? const TimeOfDay(hour: 9, minute: 0)
      : _time(widget.item.intervals.single.startMinute);
  late TimeOfDay _end = widget.item.intervals.isEmpty
      ? const TimeOfDay(hour: 10, minute: 0)
      : _time(widget.item.intervals.single.endMinute);
  late bool _overnight =
      widget.item.intervals.isNotEmpty &&
      widget.item.intervals.single.endDayOffset == 1;
  late _ImportCategory _category = _categoryFor(widget.item);
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _code.dispose();
    _codeMeaning.dispose();
    _reportingInstruction.dispose();
    _supervisorName.dispose();
    _supervisorPhone.dispose();
    _contactName.dispose();
    _coworkers.dispose();
    _contactPhone.dispose();
    _location.dispose();
    _notes.dispose();
    _zone.dispose();
    super.dispose();
  }

  static TimeOfDay _time(int minute) =>
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60);

  static _ImportCategory _categoryFor(ScheduleItem item) {
    if (item.kind == ScheduleKind.work) {
      return switch (item.workCategory!) {
        WorkCategory.shift => _ImportCategory.shift,
        WorkCategory.overtime => _ImportCategory.overtime,
        WorkCategory.training => _ImportCategory.training,
        WorkCategory.restDay => _ImportCategory.restDay,
        WorkCategory.leave => _ImportCategory.leave,
        WorkCategory.dayOff => _ImportCategory.dayOff,
      };
    }
    if (item.kind == ScheduleKind.classSession) {
      return _ImportCategory.classSession;
    }
    if (item.kind == ScheduleKind.deadline) {
      return item.deadlineType == DeadlineType.assignment
          ? _ImportCategory.assignment
          : _ImportCategory.examination;
    }
    return _ImportCategory.personal;
  }

  List<_ImportCategory> get _categories => _allDay
      ? const [
          _ImportCategory.personal,
          _ImportCategory.assignment,
          _ImportCategory.restDay,
          _ImportCategory.leave,
          _ImportCategory.dayOff,
        ]
      : const [
          _ImportCategory.personal,
          _ImportCategory.shift,
          _ImportCategory.overtime,
          _ImportCategory.training,
          _ImportCategory.classSession,
          _ImportCategory.examination,
        ];

  String _categoryLabel(_ImportCategory category) => switch (category) {
    _ImportCategory.personal => 'Personal event',
    _ImportCategory.shift => 'Work shift',
    _ImportCategory.overtime => 'Overtime',
    _ImportCategory.training => 'Training',
    _ImportCategory.classSession => 'Class',
    _ImportCategory.examination => 'Examination',
    _ImportCategory.assignment => 'Assignment',
    _ImportCategory.restDay => 'Rest day',
    _ImportCategory.leave => 'Leave',
    _ImportCategory.dayOff => 'Day off',
  };

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) setState(() => _date = CivilDate.fromDateTime(value));
  }

  Future<void> _pickTime({required bool start}) async {
    final value = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (value != null) setState(() => start ? _start = value : _end = value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final zone = _zone.text.trim();
    final resolver = CivilTimeResolver();
    final interval = _allDay
        ? null
        : EventInterval(
            startDayOffset: 0,
            startMinute: _start.hour * 60 + _start.minute,
            endDayOffset: _overnight ? 1 : 0,
            endMinute: _end.hour * 60 + _end.minute,
          );
    if (interval != null) {
      if (!interval.isValid) {
        setState(() => _error = 'Choose an end time after the start.');
        return;
      }
      for (final (day, minute) in [
        (_date, interval.startMinute),
        (_date.addDays(interval.endDayOffset), interval.endMinute),
      ]) {
        final time = resolver.resolve(day, minute, zone);
        if (time.status != CivilTimeStatus.unique) {
          setState(
            () => _error =
                'Choose a time that is valid and unambiguous in $zone.',
          );
          return;
        }
      }
    } else {
      _category = switch (_category) {
        _ImportCategory.shift ||
        _ImportCategory.overtime ||
        _ImportCategory.training => _ImportCategory.restDay,
        _ImportCategory.classSession ||
        _ImportCategory.examination => _ImportCategory.assignment,
        _ => _category,
      };
    }

    final kind = switch (_category) {
      _ImportCategory.personal => ScheduleKind.personal,
      _ImportCategory.shift ||
      _ImportCategory.overtime ||
      _ImportCategory.training ||
      _ImportCategory.restDay ||
      _ImportCategory.leave ||
      _ImportCategory.dayOff => ScheduleKind.work,
      _ImportCategory.classSession => ScheduleKind.classSession,
      _ImportCategory.examination ||
      _ImportCategory.assignment => ScheduleKind.deadline,
    };
    final workCategory = switch (_category) {
      _ImportCategory.shift => WorkCategory.shift,
      _ImportCategory.overtime => WorkCategory.overtime,
      _ImportCategory.training => WorkCategory.training,
      _ImportCategory.restDay => WorkCategory.restDay,
      _ImportCategory.leave => WorkCategory.leave,
      _ImportCategory.dayOff => WorkCategory.dayOff,
      _ => null,
    };
    final deadlineType = switch (_category) {
      _ImportCategory.assignment => DeadlineType.assignment,
      _ImportCategory.examination => DeadlineType.examination,
      _ => null,
    };
    try {
      Navigator.pop(
        context,
        ScheduleItem(
          id: widget.item.id,
          kind: kind,
          title: _title.text.trim(),
          startDate: _date,
          intervals: interval == null ? const [] : [interval],
          timeZoneId: interval == null ? widget.item.timeZoneId : zone,
          code: _optional(_code.text),
          codeMeaning: kind == ScheduleKind.work
              ? _optional(_codeMeaning.text)
              : null,
          reportingInstruction: kind == ScheduleKind.work
              ? _optional(_reportingInstruction.text)
              : null,
          supervisorName: kind == ScheduleKind.work
              ? _optional(_supervisorName.text)
              : null,
          supervisorPhone: kind == ScheduleKind.work
              ? _optional(_supervisorPhone.text)
              : null,
          contactName: kind == ScheduleKind.work
              ? _optional(_contactName.text)
              : null,
          contactPhone: kind == ScheduleKind.work
              ? _optional(_contactPhone.text)
              : null,
          coworkers: kind == ScheduleKind.work
              ? _coworkers.text
                    .split(RegExp(r'[\n;]'))
                    .map((name) => name.trim())
                    .where((name) => name.isNotEmpty)
                    .toList(growable: false)
              : const [],
          location: _optional(_location.text),
          notes: _optional(_notes.text),
          recurrence: widget.item.recurrence,
          workCategory: workCategory,
          deadlineType: deadlineType,
          allDay: kind == ScheduleKind.personal && _allDay,
          importProvenance: widget.item.importProvenance,
        ),
      );
    } on Object catch (error) {
      setState(() => _error = error.toString());
    }
  }

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Review event'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter an event name.'
                    : null,
              ),
              if (widget.item.recurrence != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.repeat_rounded),
                  title: const Text('Repeat pattern'),
                  subtitle: Text(
                    '${_recurrenceDescription(context, widget.item.recurrence!)}. Kept as imported.',
                  ),
                ),
              TextFormField(
                key: const ValueKey('import-event-code'),
                controller: _code,
                decoration: const InputDecoration(labelText: 'Code · optional'),
                textCapitalization: TextCapitalization.characters,
              ),
              DropdownButtonFormField<_ImportCategory>(
                initialValue: _categories.contains(_category)
                    ? _category
                    : _ImportCategory.personal,
                decoration: const InputDecoration(labelText: 'Add as'),
                items: [
                  for (final category in _categories)
                    DropdownMenuItem(
                      value: category,
                      child: Text(_categoryLabel(category)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('All day'),
                value: _allDay,
                onChanged: (value) => setState(() {
                  _allDay = value;
                  if (!_categories.contains(_category)) {
                    _category = _ImportCategory.personal;
                  }
                }),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(
                  MaterialLocalizations.of(context).formatMediumDate(
                    DateTime(_date.year, _date.month, _date.day),
                  ),
                ),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickDate,
              ),
              if (!_allDay) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Starts'),
                  subtitle: Text(_start.format(context)),
                  onTap: () => _pickTime(start: true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ends'),
                  subtitle: Text(_end.format(context)),
                  onTap: () => _pickTime(start: false),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ends the next day'),
                  value: _overnight,
                  onChanged: (value) => setState(() => _overnight = value),
                ),
                TextFormField(
                  controller: _zone,
                  decoration: const InputDecoration(labelText: 'Time zone'),
                  autocorrect: false,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Choose a time zone.'
                      : null,
                ),
              ],
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Location · optional',
                ),
              ),
              if (_category == _ImportCategory.shift ||
                  _category == _ImportCategory.overtime ||
                  _category == _ImportCategory.training ||
                  _category == _ImportCategory.restDay ||
                  _category == _ImportCategory.leave ||
                  _category == _ImportCategory.dayOff) ...[
                TextFormField(
                  key: const ValueKey('import-code-meaning'),
                  controller: _codeMeaning,
                  decoration: const InputDecoration(
                    labelText: 'Code assignment details · optional',
                    helperText:
                        'Use only the meaning confirmed by your source.',
                  ),
                  maxLines: 2,
                  maxLength: 2000,
                ),
                TextFormField(
                  key: const ValueKey('import-reporting-instruction'),
                  controller: _reportingInstruction,
                  decoration: const InputDecoration(
                    labelText: 'Reporting instructions · optional',
                  ),
                  maxLines: 2,
                  maxLength: 2000,
                ),
                TextFormField(
                  key: const ValueKey('import-supervisor-name'),
                  controller: _supervisorName,
                  decoration: const InputDecoration(
                    labelText: 'Supervisor · optional',
                  ),
                  maxLength: 512,
                ),
                TextFormField(
                  key: const ValueKey('import-supervisor-phone'),
                  controller: _supervisorPhone,
                  decoration: const InputDecoration(
                    labelText: 'Supervisor phone · optional',
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 256,
                ),
                TextFormField(
                  key: const ValueKey('import-contact-name'),
                  controller: _contactName,
                  decoration: const InputDecoration(
                    labelText: 'Shift contact · optional',
                  ),
                  maxLength: 512,
                ),
                TextFormField(
                  key: const ValueKey('import-contact-phone'),
                  controller: _contactPhone,
                  decoration: const InputDecoration(
                    labelText: 'Contact phone · optional',
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 256,
                ),
                TextFormField(
                  key: const ValueKey('import-coworkers'),
                  controller: _coworkers,
                  decoration: const InputDecoration(
                    labelText: 'Coworkers · optional',
                    hintText: 'One name per line',
                    helperText: 'Matching roster rows are added automatically.',
                    alignLabelWithHint: true,
                  ),
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 6000,
                ),
              ],
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Notes · optional',
                ),
                minLines: 2,
                maxLines: 4,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.check_rounded),
        label: const Text('Save review'),
      ),
    ],
  );
}

String _friendlyError(Object error) => error is FormatException
    ? error.message.toString()
    : 'Could not prepare the calendar import. Check the file and try again.';
