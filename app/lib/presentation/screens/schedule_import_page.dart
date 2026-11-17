import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dependencies.dart';
import '../../data/csv_schedule_import.dart';
import '../../data/ics_schedule_import.dart';
import '../../data/ocr_schedule_import.dart';
import '../../data/xlsx_schedule_import.dart';
import '../../data/schedule_import_models.dart';
import '../../data/schedule_import_history_repository.dart';
import '../../domain/civil_time_resolver.dart';
import '../../domain/schedule.dart';
import '../../domain/work_code_legend.dart';
import '../../platform/schedule_import_file_bridge.dart';
import '../design/studyshift_spacing.dart';
import '../schedule_format.dart';
import 'schedule_import_history_page.dart';

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
  });

  final ScheduleImportProposal proposal;
  final bool included;
  final ScheduleItem? existing;

  _ImportRow copyWith({ScheduleImportProposal? proposal, bool? included}) =>
      _ImportRow(
        proposal: proposal ?? this.proposal,
        included: included ?? this.included,
        existing: existing,
      );
}

class _ScheduleImportPageState extends ConsumerState<ScheduleImportPage> {
  final _parser = const IcsScheduleImportParser();
  final _csvParser = const CsvScheduleImportParser();
  final _xlsxParser = const XlsxScheduleImportParser();
  final _ocrParser = const OcrScheduleImportParser();
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
    'reporting_instruction': 'Reporting instruction',
    'location': 'Location',
    'notes': 'Notes',
    'supervisor_name': 'Supervisor name',
    'supervisor_phone': 'Supervisor phone',
    'contact_name': 'Contact name',
    'contact_phone': 'Contact phone',
  };

  Future<void> _selectFile() async {
    setState(() {
      _loading = true;
      _error = null;
      _rows = const [];
      _notices = const [];
      _sourceName = null;
      _recognizedText = null;
      _sourceType = null;
    });
    try {
      final selected = await _fileBridge.openCalendar();
      if (selected == null) return;
      final zone = await ref.read(deviceTimeZoneIdProvider.future);
      final fileName = selected.name.toLowerCase();
      final ScheduleImportPreview preview;
      final ScheduleImportSourceType sourceType;
      if (fileName.endsWith('.ics')) {
        sourceType = ScheduleImportSourceType.ics;
        final text = utf8.decode(selected.bytes!, allowMalformed: false);
        preview = await _parser.parse(
          text,
          sourceName: selected.name,
          floatingTimeZoneId: zone,
        );
      } else if (fileName.endsWith('.csv')) {
        sourceType = ScheduleImportSourceType.csv;
        final text = utf8.decode(selected.bytes!, allowMalformed: false);
        final headers = _csvParser.inspectHeaders(text);
        if (_needsColumnMapping(headers)) {
          if (!mounted) return;
          setState(() {
            _pendingTableBytes = selected.bytes;
            _pendingTableName = selected.name;
            _pendingTableType = sourceType;
            _tableHeaders = headers;
            _columnSelections = _suggestColumns(headers);
          });
          return;
        }
        preview = await _csvParser.parse(text, sourceName: selected.name);
      } else if (fileName.endsWith('.xlsx')) {
        sourceType = ScheduleImportSourceType.xlsx;
        final headers = _xlsxParser.inspectHeaders(selected.bytes!);
        if (_needsColumnMapping(headers)) {
          if (!mounted) return;
          setState(() {
            _pendingTableBytes = selected.bytes;
            _pendingTableName = selected.name;
            _pendingTableType = sourceType;
            _tableHeaders = headers;
            _columnSelections = _suggestColumns(headers);
          });
          return;
        }
        preview = await _xlsxParser.parse(
          selected.bytes!,
          sourceName: selected.name,
        );
      } else {
        throw const FormatException('Choose an .ics, .csv or .xlsx file.');
      }
      final existingItems = await ref
          .read(scheduleRepositoryProvider)
          .getItems();
      final localLegends = await ref
          .read(workCodeLegendRepositoryProvider)
          .getItems();
      final byId = {for (final item in existingItems) item.id: item};
      final reviewedProposals = [
        for (final proposal in preview.proposals)
          _withLocalLegendMeaning(proposal, localLegends),
      ];
      if (!mounted) return;
      setState(() {
        _sourceName = selected.name;
        _sourceType = sourceType;
        _rows = [
          for (final proposal in reviewedProposals)
            _ImportRow(
              proposal: proposal,
              existing: byId[proposal.item.id],
              included: !byId.containsKey(proposal.item.id),
            ),
        ];
        _notices = preview.notices;
      });
      if (preview.proposals.isEmpty && preview.notices.isEmpty) {
        setState(() => _error = 'This calendar has no events to review.');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyError(error));
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
      if (mounted) setState(() => _error = _friendlyError(error));
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
    final byId = {for (final item in existingItems) item.id: item};
    final reviewedProposals = [
      for (final proposal in preview.proposals)
        _withLocalLegendMeaning(proposal, localLegends),
    ];
    if (!mounted) return;
    setState(() {
      _sourceName = sourceName;
      _sourceType = sourceType;
      _rows = [
        for (final proposal in reviewedProposals)
          _ImportRow(
            proposal: proposal,
            existing: byId[proposal.item.id],
            included: !byId.containsKey(proposal.item.id),
          ),
      ];
      _notices = preview.notices;
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
    if (item.kind != ScheduleKind.work ||
        item.employerName == null ||
        item.code == null ||
        (item.codeMeaning?.trim().isNotEmpty ?? false)) {
      return proposal;
    }
    for (final legend in legends) {
      if (legend.employer.trim().toLowerCase() ==
              item.employerName!.trim().toLowerCase() &&
          legend.code.trim().toLowerCase() == item.code!.trim().toLowerCase()) {
        return ScheduleImportProposal(
          item: item.copyWith(codeMeaning: legend.assignmentDetails),
          sourceText: proposal.sourceText,
        );
      }
    }
    return proposal;
  }

  Future<void> _selectOcrFile({bool examTimetable = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _rows = const [];
      _notices = const [];
      _sourceName = null;
      _recognizedText = null;
      _sourceType = null;
    });
    try {
      final selected = await _fileBridge.openOcrImport();
      if (selected == null) return;
      final zone = await ref.read(deviceTimeZoneIdProvider.future);
      final text = selected.extractedText;
      if (text == null) {
        throw const FormatException(
          'The recognized schedule text is unavailable.',
        );
      }
      final preview = await _ocrParser.parse(
        text: text,
        sourceName: selected.name,
        timeZoneId: zone,
        examTimetable: examTimetable,
      );
      final existingItems = await ref
          .read(scheduleRepositoryProvider)
          .getItems();
      final byId = {for (final item in existingItems) item.id: item};
      final unusedExistingOcrItems = existingItems
          .where((item) => _hasOcrProvenance(item))
          .toList();
      final matchedOcrIds = <String>{};
      if (!mounted) return;
      setState(() {
        _sourceName = selected.name;
        _sourceType = examTimetable
            ? ScheduleImportSourceType.examTimetableOcr
            : selected.name.toLowerCase().endsWith('.pdf')
            ? ScheduleImportSourceType.pdfOcr
            : ScheduleImportSourceType.imageOcr;
        _recognizedText = text;
        _rows = [
          for (final proposal in preview.proposals)
            _ocrReviewRow(
              proposal,
              byId: byId,
              unusedExistingOcrItems: unusedExistingOcrItems,
              matchedOcrIds: matchedOcrIds,
            ),
        ];
        _notices = preview.notices;
        if (preview.proposals.isEmpty) {
          _error = 'No clear event rows were found. Review the extracted text and add uncertain entries manually.';
        }
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _ImportRow _ocrReviewRow(
    ScheduleImportProposal proposal, {
    required Map<String, ScheduleItem> byId,
    required List<ScheduleItem> unusedExistingOcrItems,
    required Set<String> matchedOcrIds,
  }) {
    final exactIdMatch = byId[proposal.item.id];
    final existing =
        exactIdMatch ??
        _takeMatchingOcrEvent(
          proposal.item,
          unusedExistingOcrItems,
          matchedOcrIds,
        );
    if (existing != null) matchedOcrIds.add(existing.id);
    final matchedProposal = existing == null || existing.id == proposal.item.id
        ? proposal
        : ScheduleImportProposal(
            item: _withItemId(proposal.item, existing.id),
            sourceText: proposal.sourceText,
          );
    return _ImportRow(
      proposal: matchedProposal,
      existing: existing,
      included: existing == null,
    );
  }

  ScheduleItem? _takeMatchingOcrEvent(
    ScheduleItem proposed,
    List<ScheduleItem> candidates,
    Set<String> matchedIds,
  ) {
    for (final candidate in candidates) {
      if (!matchedIds.contains(candidate.id) &&
          _sameOcrEvent(candidate, proposed)) {
        return candidate;
      }
    }
    return null;
  }

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
    final selected = _rows.where((row) => row.included).toList();
    if (selected.isEmpty) {
      setState(() => _error = 'Select at least one event to add.');
      return;
    }
    final sourceType = _sourceType;
    if (sourceType == null) {
      setState(() => _error = 'Review an import file before adding events.');
      return;
    }
    final rejectedCount = _rows
        .where((row) => !row.included && row.existing == null)
        .length;
    final skippedDuplicateCount = _rows
        .where((row) => !row.included && row.existing != null)
        .length;
    final duplicateCount = selected.where((row) => row.existing != null).length;
    if (_replaceMatches && duplicateCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: const Text('Replace saved events?'),
          content: Text(
            '$duplicateCount matching event${duplicateCount == 1 ? '' : 's'} will be replaced with the reviewed calendar version. This cannot be undone in the app.',
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
      final result = await ref
          .read(scheduleRepositoryProvider)
          .importItems(
            [for (final row in selected) row.proposal.item],
            replaceExisting: _replaceMatches,
            historyDraft: ScheduleImportHistoryDraft(
              sourceType: sourceType,
              parserVersion: sourceType.parserVersion,
              proposedCount: _rows.length,
              rejectedCount: rejectedCount,
              skippedCount: skippedDuplicateCount,
              warningsCount: _notices.length,
              importedAt: DateTime.now().toUtc(),
            ),
          );
      ref.invalidate(scheduleItemsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${result.inserted}, replaced ${result.replaced}, skipped ${result.skipped}.',
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

  @override
  Widget build(BuildContext context) {
    final duplicateCount = _rows
        .where((row) => row.included && row.existing != null)
        .length;
    final selectedCount = _rows.where((row) => row.included).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import calendar'),
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
          padding: const EdgeInsets.fromLTRB(
            StudyShiftSpacing.pageMargin,
            12,
            StudyShiftSpacing.pageMargin,
            StudyShiftSpacing.pageMargin,
          ),
          children: [
            Text(
              'Review before adding',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose an .ics calendar, StudyShift CSV or supported Excel file. Nothing is saved until you review and confirm.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'If your roster uses different headings, match its columns to StudyShift fields. Import stays on this device, and nothing is saved until you review and confirm.',
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
                      'Required fields: event date, event or shift name, and category. Timed events also need start and end times; use YYYY-MM-DD dates and 24-hour HH:mm times. Optional fields include end_date, source_id, employer, department,job_role, code, code_meaning, reporting_instruction, location, notes, supervisor_name, supervisor_phone, contact_name and contact_phone. These are the StudyShift field names available in the mapping step. Excel imports read visible worksheets; formulas, hidden rows and hidden worksheets are refused. Categories: shift, overtime, training, class, examination, assignment, rest_day, leave, day_off or personal. Work events with an earlier end time continue the next day; other overnight events need an end date. Every proposed event must be reviewed before saving.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    'source_id,date,title,category,start,end,time_zone,employer,department,job_role,code,code_meaning,reporting_instruction,location,notes,supervisor_name,supervisor_phone,contact_name,contact_phone\n'
                    'SYNTH-001,2026-11-07,Sample work shift,shift,21:00,05:00,America/Barbados,Synthetic employer,Synthetic department,Synthetic role,S1,Confirmed sample meaning,Sample reporting text,Sample location,,,,\n'
                    'SYNTH-002,2026-11-08,Sample overtime,overtime,18:00,21:00,America/Barbados,,,,OT,,,,,,,,',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loading || _saving ? null : _selectFile,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_open_outlined),
              label: Text(
                _loading ? 'Reading file…' : 'Choose .ics, .csv or .xlsx file',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loading || _saving ? null : _selectOcrFile,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Read a PDF or schedule image offline'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loading || _saving
                  ? null
                  : () => _selectOcrFile(examTimetable: true),
              icon: const Icon(Icons.school_outlined),
              label: const Text('Read an exam timetable'),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'General OCR drafts only clear ISO date and 24-hour time rows. Exam timetable review can also read a named date, AM/PM start, course code and stated duration. Check every proposal; uncertain roster codes and layouts are never guessed.',
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
              Text(
                'Proposed events · $selectedCount selected',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              for (var i = 0; i < _rows.length; i++)
                _ProposalCard(
                  row: _rows[i],
                  onSelected: (selected) => setState(() {
                    _rows = [
                      for (var j = 0; j < _rows.length; j++)
                        if (j == i)
                          _rows[j].copyWith(included: selected)
                        else
                          _rows[j],
                    ];
                  }),
                  onEdit: () => _editRow(i),
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
      bottomNavigationBar: _rows.isEmpty
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
                    _saving ? 'Adding events…' : 'Add $selectedCount selected',
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: row.included,
              onChanged: (value) => onSelected(value ?? false),
              title: Text(item.title),
              subtitle: Text('$date · $time · $category'),
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
            if (existing != null)
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
