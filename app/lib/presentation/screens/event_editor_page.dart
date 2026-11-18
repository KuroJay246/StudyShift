import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dependencies.dart';
import '../../domain/academic_term.dart';
import '../../domain/civil_time_resolver.dart';
import '../../domain/schedule.dart';
import '../../domain/supervisor_profile.dart';
import '../../domain/work_code_legend.dart';
import '../../data/preferences_repository.dart';
import '../../platform/local_reminders.dart';
import '../schedule_format.dart';
import '../design/studyshift_spacing.dart';
import '../app_theme.dart';
import 'work_code_legend_page.dart';

class EventEditorPage extends ConsumerStatefulWidget {
  const EventEditorPage({
    super.key,
    required this.kind,
    this.existing,
    this.initialDate,
    this.initialTitle,
    this.initialStartMinute,
    this.initialEndMinute,
    this.initialDeadlineType,
  });
  final ScheduleKind kind;
  final ScheduleItem? existing;
  final CivilDate? initialDate;
  final String? initialTitle;
  final int? initialStartMinute;
  final int? initialEndMinute;
  final DeadlineType? initialDeadlineType;
  @override
  ConsumerState<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends ConsumerState<EventEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.existing?.title ?? widget.initialTitle ?? '',
  );
  late final _code = TextEditingController(text: widget.existing?.code ?? '');
  late final _employer = TextEditingController(
    text: widget.existing?.employerName ?? '',
  );
  late final _department = TextEditingController(
    text: widget.existing?.departmentName ?? '',
  );
  late final _jobRole = TextEditingController(
    text: widget.existing?.jobRole ?? '',
  );
  late final _codeMeaning = TextEditingController(
    text: widget.existing?.codeMeaning ?? '',
  );
  late final _location = TextEditingController(
    text: widget.existing?.location ?? '',
  );
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late final _reportingInstruction = TextEditingController(
    text: widget.existing?.reportingInstruction ?? '',
  );
  late final _supervisorName = TextEditingController(
    text: widget.existing?.supervisorName ?? '',
  );
  late final _supervisorPhone = TextEditingController(
    text: widget.existing?.supervisorPhone ?? '',
  );
  late final _contactName = TextEditingController(
    text: widget.existing?.contactName ?? '',
  );
  late final _contactPhone = TextEditingController(
    text: widget.existing?.contactPhone ?? '',
  );
  late final _timeZone = TextEditingController(
    text: widget.existing?.timeZoneId ?? '',
  );
  late CivilDate _date =
      widget.existing?.startDate ??
      widget.initialDate ??
      CivilDate.fromDateTime(DateTime.now());
  late final List<TimeOfDay> _starts = widget.existing == null
      ? [
          _timeFromMinute(
            widget.initialStartMinute ??
                _minute(_defaultStartTime(widget.kind)),
          ),
        ]
      : [
          for (final i in widget.existing!.intervals)
            TimeOfDay(hour: i.startMinute ~/ 60, minute: i.startMinute % 60),
        ];
  late final List<TimeOfDay> _ends = widget.existing == null
      ? [
          _timeFromMinute(
            widget.initialEndMinute ?? _minute(_defaultEndTime(widget.kind)),
          ),
        ]
      : [
          for (final i in widget.existing!.intervals)
            TimeOfDay(hour: i.endMinute ~/ 60, minute: i.endMinute % 60),
        ];
  late WorkCategory _workCategory =
      widget.existing?.workCategory ?? WorkCategory.shift;
  late DeadlineType _deadlineType =
      widget.existing?.deadlineType ??
      widget.initialDeadlineType ??
      DeadlineType.assignment;
  late final Set<int> _weekdays = {...?widget.existing?.recurrence?.weekdays};
  String? _academicTermId;
  CivilDate? _until;
  bool _repeat = false;
  bool _allDay = false;
  int? _reminderMinutesBefore;
  bool _saving = false;
  bool _didSuggestDeviceZone = false;
  bool _meaningManuallyEdited = false;
  bool _timeManuallyEdited = false;
  CivilTimeFoldChoice? _fold;
  String? _error;
  String? _selectedLegendId;
  int _endDayOffset = 0;
  bool _endDateManuallyEdited = false;

  bool get _hasNoTime =>
      (widget.kind == ScheduleKind.work && _workCategory.isAllDay) ||
      (widget.kind == ScheduleKind.deadline &&
          _deadlineType == DeadlineType.assignment) ||
      (widget.kind == ScheduleKind.personal && _allDay);

  @override
  void initState() {
    super.initState();
    _repeat = widget.existing?.recurrence != null;
    _academicTermId = widget.existing?.academicTermId;
    _meaningManuallyEdited = (widget.existing?.codeMeaning ?? '').isNotEmpty;
    _until = widget.existing?.recurrence?.until;
    _allDay = widget.existing?.allDay ?? false;
    _reminderMinutesBefore = widget.existing?.reminderMinutesBefore;
    _endDayOffset = widget.existing?.intervals.isNotEmpty == true
        ? widget.existing!.intervals.last.endDayOffset
        : (!_hasNoTime && _minute(_ends.last) <= _minute(_starts.last))
        ? 1
        : 0;
  }

  @override
  void dispose() {
    _title.dispose();
    _code.dispose();
    _employer.dispose();
    _department.dispose();
    _jobRole.dispose();
    _codeMeaning.dispose();
    _location.dispose();
    _notes.dispose();
    _reportingInstruction.dispose();
    _supervisorName.dispose();
    _supervisorPhone.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    _timeZone.dispose();
    super.dispose();
  }

  void _applyLegendSuggestion(List<WorkCodeLegend> legends) {
    final employer = _employer.text.trim().toLowerCase();
    final code = _code.text.trim().toLowerCase();
    if (code.isEmpty) return;
    final matches = legends
        .where((entry) => entry.code.trim().toLowerCase() == code)
        .toList();
    WorkCodeLegend? suggestion;
    if (employer.isEmpty) {
      if (matches.length == 1 && matches.single.employer.isEmpty) {
        suggestion = matches.single;
      }
    } else {
      final eligible =
          matches.where((entry) {
            final entryEmployer = entry.employer.trim().toLowerCase();
            return entryEmployer == employer || entryEmployer.isEmpty;
          }).toList()..sort((a, b) {
            final aSpecific = a.employer.trim().isNotEmpty;
            final bSpecific = b.employer.trim().isNotEmpty;
            return aSpecific == bSpecific ? 0 : (aSpecific ? -1 : 1);
          });
      if (eligible.isNotEmpty) suggestion = eligible.first;
    }
    if (suggestion == null) return;
    setState(() => _applyLegendEntry(suggestion!));
  }

  void _applyLegendEntry(WorkCodeLegend legend) {
    if (!_meaningManuallyEdited && legend.assignmentDetails.isNotEmpty) {
      _codeMeaning.text = legend.assignmentDetails;
    }
    final windows = legend.timeWindows;
    if (!_timeManuallyEdited && windows.isNotEmpty && windows.length <= 2) {
      _starts
        ..clear()
        ..addAll(
          windows.map(
            (window) => TimeOfDay(
              hour: window.startMinute ~/ 60,
              minute: window.startMinute % 60,
            ),
          ),
        );
      _ends
        ..clear()
        ..addAll(
          windows.map(
            (window) => TimeOfDay(
              hour: window.endMinute ~/ 60,
              minute: window.endMinute % 60,
            ),
          ),
        );
      _endDayOffset = windows.last.endDayOffset;
      _endDateManuallyEdited = false;
    }
  }

  WorkCodeLegend? _legendForCode(List<WorkCodeLegend> legends) {
    if (_selectedLegendId != null) {
      for (final legend in legends) {
        if (legend.id == _selectedLegendId) return legend;
      }
    }
    final code = _code.text.trim().toLowerCase();
    if (code.isEmpty) return null;
    final employer = _employer.text.trim().toLowerCase();
    final matches = legends.where((legend) {
      if (legend.code.trim().toLowerCase() != code) return false;
      final entryEmployer = legend.employer.trim().toLowerCase();
      return employer.isEmpty
          ? legends
                    .where((item) => item.code.trim().toLowerCase() == code)
                    .length ==
                1
          : entryEmployer == employer || entryEmployer.isEmpty;
    }).toList();
    if (matches.length != 1) return null;
    return matches.single;
  }

  List<WorkCodeLegend> _legendOptions(List<WorkCodeLegend> legends) {
    final employer = _employer.text.trim().toLowerCase();
    return legends.where((legend) {
      final entryEmployer = legend.employer.trim().toLowerCase();
      return employer.isEmpty ||
          entryEmployer.isEmpty ||
          entryEmployer == employer;
    }).toList();
  }

  String _legendLabel(WorkCodeLegend legend, bool use24Hour) {
    final employer = legend.employer.trim();
    final timeWindows = legend.timeWindows;
    final time = timeWindows.isEmpty
        ? ''
        : ' · ${timeWindows.map((window) => '${formatMinute(window.startMinute, use24Hour: use24Hour)}–${formatMinute(window.endMinute, use24Hour: use24Hour)}${window.endDayOffset > 0 ? ' (+${window.endDayOffset} day)' : ''}').join(' / ')}';
    return '${employer.isEmpty ? '' : '$employer · '}${legend.code}$time';
  }

  Future<void> _pickDate() async {
    final term = _selectedAcademicTerm(
      ref.read(academicTermsProvider).asData?.value ?? const [],
    );
    final first = term == null
        ? DateTime(2000)
        : DateTime(
            term.startDate.year,
            term.startDate.month,
            term.startDate.day,
          );
    final endDate = _date.addDays(_endDayOffset);
    final last = term == null || endDate.compareTo(term.endDate) > 0
        ? DateTime(endDate.year, endDate.month, endDate.day)
        : DateTime(term.endDate.year, term.endDate.month, term.endDate.day);
    final initial = DateTime(_date.year, _date.month, _date.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first)
          ? first
          : initial.isAfter(last)
          ? last
          : initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() {
        final nextDate = CivilDate.fromDateTime(picked);
        if (_endDateManuallyEdited) {
          final selectedEnd = _date.addDays(_endDayOffset);
          _endDayOffset =
              DateTime.utc(selectedEnd.year, selectedEnd.month, selectedEnd.day)
                  .difference(
                    DateTime.utc(nextDate.year, nextDate.month, nextDate.day),
                  )
                  .inDays;
        }
        _date = nextDate;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final endDate = _date.addDays(_endDayOffset);
    final term = _selectedAcademicTerm(
      ref.read(academicTermsProvider).asData?.value ?? const [],
    );
    final termEnd = term?.endDate;
    final last = termEnd != null && termEnd.compareTo(_date) >= 0
        ? DateTime(termEnd.year, termEnd.month, termEnd.day)
        : DateTime(2100, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(endDate.year, endDate.month, endDate.day),
      firstDate: DateTime(_date.year, _date.month, _date.day),
      lastDate: last,
    );
    if (picked == null) return;
    final selected = CivilDate.fromDateTime(picked);
    setState(() {
      _endDayOffset = DateTime.utc(
        selected.year,
        selected.month,
        selected.day,
      ).difference(DateTime.utc(_date.year, _date.month, _date.day)).inDays;
      _endDateManuallyEdited = true;
    });
  }

  Future<void> _pickUntil() async {
    final term = _selectedAcademicTerm(
      ref.read(academicTermsProvider).asData?.value ?? const [],
    );
    final selectedEnd = _until;
    final initial = selectedEnd != null && selectedEnd.compareTo(_date) >= 0
        ? selectedEnd
        : _date;
    if (term != null && _date.compareTo(term.endDate) > 0) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: term != null && initial.compareTo(term.endDate) > 0
          ? DateTime(term.endDate.year, term.endDate.month, term.endDate.day)
          : DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(_date.year, _date.month, _date.day),
      lastDate: term == null
          ? DateTime(2100, 12, 31)
          : DateTime(term.endDate.year, term.endDate.month, term.endDate.day),
    );
    if (picked != null) setState(() => _until = CivilDate.fromDateTime(picked));
  }

  AcademicTerm? _selectedAcademicTerm(List<AcademicTerm> terms) {
    for (final term in terms) {
      if (term.id == _academicTermId) return term;
    }
    return null;
  }

  Future<void> _pickTime(int index, bool start) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? _starts[index] : _ends[index],
    );
    if (selected != null) {
      setState(() {
        _timeManuallyEdited = true;
        (start ? _starts : _ends)[index] = selected;
        if (!_endDateManuallyEdited && index == _starts.length - 1) {
          _endDayOffset = _minute(_ends[index]) <= _minute(_starts[index])
              ? 1
              : 0;
        }
      });
    }
  }

  int _minute(TimeOfDay time) => time.hour * 60 + time.minute;

  CalendarColorCategory get _colorCategory => switch (widget.kind) {
    ScheduleKind.work =>
      _workCategory == WorkCategory.training
          ? CalendarColorCategory.training
          : CalendarColorCategory.work,
    ScheduleKind.classSession => CalendarColorCategory.school,
    ScheduleKind.deadline => CalendarColorCategory.deadline,
    ScheduleKind.personal => CalendarColorCategory.personal,
  };

  String get _colorCategoryName => switch (_colorCategory) {
    CalendarColorCategory.work => 'Work',
    CalendarColorCategory.training => 'Training',
    CalendarColorCategory.school => 'Study',
    CalendarColorCategory.deadline => 'Deadline',
    CalendarColorCategory.personal => 'Personal',
  };

  Color _currentCategoryColor(AppPreferences? preferences) {
    final stored = switch (_colorCategory) {
      CalendarColorCategory.work => preferences?.workColor,
      CalendarColorCategory.training => preferences?.trainingColor,
      CalendarColorCategory.school => preferences?.schoolColor,
      CalendarColorCategory.deadline => preferences?.deadlineColor,
      CalendarColorCategory.personal => preferences?.personalColor,
    };
    if (stored != null) return Color(stored);
    final theme = Theme.of(context);
    final palette =
        theme.extension<SchedulePalette>() ??
        (theme.brightness == Brightness.dark
                ? AppTheme.dark()
                : AppTheme.light())
            .extension<SchedulePalette>()!;
    return switch (_colorCategory) {
      CalendarColorCategory.work => palette.work,
      CalendarColorCategory.training => palette.training,
      CalendarColorCategory.school => palette.school,
      CalendarColorCategory.deadline => palette.deadline,
      CalendarColorCategory.personal => palette.personal,
    };
  }

  Future<void> _chooseCategoryColor(AppPreferences? preferences) async {
    final picked = await _showCalendarColorPicker(
      context,
      _currentCategoryColor(preferences),
    );
    if (picked == null) return;
    await ref
        .read(preferencesRepositoryProvider)
        .setCalendarColor(_colorCategory, picked.toARGB32());
    ref.invalidate(appPreferencesProvider);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || (_repeat && _weekdays.isEmpty)) {
      setState(
        () => _error = _repeat && _weekdays.isEmpty
            ? 'Choose at least one weekday.'
            : null,
      );
      return;
    }
    if (_repeat && _until != null && _until!.compareTo(_date) < 0) {
      setState(
        () => _error = 'The end date must be on or after the start date.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_reminderMinutesBefore != null) {
        final permission = await ref
            .read(localReminderServiceProvider)
            .requestPermissions();
        if (!permission.notificationsAllowed) {
          throw const FormatException(
            'Allow notifications to save this reminder, or choose No reminder and save the event.',
          );
        }
      }
      final zone = _timeZone.text.trim();
      if (zone.isEmpty) {
        throw const FormatException('Enter a time zone before saving.');
      }
      final zoneCheck = CivilTimeResolver().resolve(_date, 12 * 60, zone);
      if (zoneCheck.status == CivilTimeStatus.invalidTimeZone) {
        throw FormatException('“$zone” is not a recognized time zone.');
      }
      final intervals = <EventInterval>[];
      if (!_hasNoTime) {
        for (var i = 0; i < _starts.length; i++) {
          final start = _minute(_starts[i]), end = _minute(_ends[i]);
          final offset = i == _ends.length - 1
              ? _endDayOffset
              : end <= start
              ? 1
              : 0;
          final interval = EventInterval(
            startDayOffset: 0,
            startMinute: start,
            endDayOffset: offset,
            endMinute: end,
            startFoldChoice: _fold,
            endFoldChoice: _fold,
          );
          if (!interval.isValid) {
            throw const FormatException(
              'Each interval must have a later end time.',
            );
          }
          for (final (day, minute) in [
            (_date, start),
            (_date.addDays(offset), end),
          ]) {
            final result = CivilTimeResolver().resolve(day, minute, zone);
            if (result.status == CivilTimeStatus.nonexistent) {
              throw FormatException(
                '${formatMinute(minute, use24Hour: true)} does not exist on $day because clocks change. Choose a different time.',
              );
            }
            if (result.status == CivilTimeStatus.invalidTimeZone) {
              throw FormatException(
                'The device time zone “$zone” is not recognized.',
              );
            }
            if (result.status == CivilTimeStatus.ambiguous && _fold == null) {
              throw FormatException(
                '${formatMinute(minute, use24Hour: true)} occurs twice on $day. Choose which occurrence below.',
              );
            }
          }
          intervals.add(interval);
        }
      }
      final recurrence = _repeat
          ? WeeklyRecurrence(
              weekdays: _weekdays,
              until: _until,
              exceptionDates:
                  widget.existing?.recurrence?.exceptionDates ?? const {},
            )
          : null;
      final item = ScheduleItem(
        id:
            widget.existing?.id ??
            'evt-${DateTime.now().microsecondsSinceEpoch}',
        kind: widget.kind,
        title: _title.text.trim(),
        startDate: _date,
        intervals: intervals,
        timeZoneId: zone,
        code: _code.text.trim().isEmpty ? null : _code.text.trim(),
        employerName:
            widget.kind == ScheduleKind.work && _employer.text.trim().isNotEmpty
            ? _employer.text.trim()
            : null,
        departmentName:
            widget.kind == ScheduleKind.work &&
                _department.text.trim().isNotEmpty
            ? _department.text.trim()
            : null,
        jobRole:
            widget.kind == ScheduleKind.work && _jobRole.text.trim().isNotEmpty
            ? _jobRole.text.trim()
            : null,
        codeMeaning:
            widget.kind == ScheduleKind.work &&
                _codeMeaning.text.trim().isNotEmpty
            ? _codeMeaning.text.trim()
            : null,
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        reportingInstruction:
            widget.kind == ScheduleKind.work &&
                _reportingInstruction.text.trim().isNotEmpty
            ? _reportingInstruction.text.trim()
            : null,
        supervisorName:
            widget.kind == ScheduleKind.work &&
                _supervisorName.text.trim().isNotEmpty
            ? _supervisorName.text.trim()
            : null,
        supervisorPhone:
            widget.kind == ScheduleKind.work &&
                _supervisorPhone.text.trim().isNotEmpty
            ? _supervisorPhone.text.trim()
            : null,
        contactName:
            widget.kind == ScheduleKind.work &&
                _contactName.text.trim().isNotEmpty
            ? _contactName.text.trim()
            : null,
        contactPhone:
            widget.kind == ScheduleKind.work &&
                _contactPhone.text.trim().isNotEmpty
            ? _contactPhone.text.trim()
            : null,
        academicTermId: _academicTermId,
        recurrence: recurrence,
        workCategory: widget.kind == ScheduleKind.work ? _workCategory : null,
        deadlineType: widget.kind == ScheduleKind.deadline
            ? _deadlineType
            : null,
        allDay: widget.kind == ScheduleKind.personal && _allDay,
        importProvenance: widget.existing?.importProvenance,
        reminderMinutesBefore: _hasNoTime ? null : _reminderMinutesBefore,
      );
      await ref.read(scheduleRepositoryProvider).save(item);
      ref.invalidate(scheduleItemsProvider);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('FormatException: ', '');
          _saving = false;
        });
      }
    }
  }

  Future<void> _openWorkReferences() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const WorkCodeLegendPage()),
    );
    if (!mounted) return;
    ref.invalidate(workCodeLegendsProvider);
    ref.invalidate(supervisorProfilesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(appPreferencesProvider).value;
    final legendsAsync = ref.watch(workCodeLegendsProvider);
    final legends = legendsAsync.asData?.value ?? const [];
    final termsAsync =
        widget.kind == ScheduleKind.classSession ||
            widget.kind == ScheduleKind.deadline
        ? ref.watch(academicTermsProvider)
        : null;
    final terms = termsAsync?.asData?.value ?? const <AcademicTerm>[];
    final selectedTerm = _selectedAcademicTerm(terms);
    final supervisorsAsync = widget.kind == ScheduleKind.work
        ? ref.watch(supervisorProfilesProvider)
        : null;
    final supervisors =
        supervisorsAsync?.asData?.value ?? const <SupervisorProfile>[];
    final selectedSupervisor = supervisors
        .where(
          (profile) =>
              profile.name.trim().toLowerCase() ==
              _supervisorName.text.trim().toLowerCase(),
        )
        .firstOrNull;
    final deviceZone = ref.watch(deviceTimeZoneIdProvider).asData?.value;
    if (!_didSuggestDeviceZone &&
        widget.existing == null &&
        deviceZone != null) {
      _timeZone.text = deviceZone;
      _didSuggestDeviceZone = true;
    }
    final loc = MaterialLocalizations.of(context);
    final title = widget.existing == null
        ? 'Add ${widget.kind == ScheduleKind.deadline
              ? deadlineTypeName(_deadlineType).toLowerCase()
              : widget.kind == ScheduleKind.work
              ? 'shift'
              : widget.kind == ScheduleKind.classSession
              ? 'class'
              : 'event'}'
        : 'Edit ${scheduleKindName(widget.kind).toLowerCase()}';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              StudyShiftSpacing.pageMargin,
              StudyShiftSpacing.x2,
              StudyShiftSpacing.pageMargin,
              28,
            ),
            children: [
              _sectionHeading(
                'Essential details',
                widget.kind == ScheduleKind.work
                    ? Icons.work_outline_rounded
                    : widget.kind == ScheduleKind.classSession
                    ? Icons.school_outlined
                    : Icons.event_outlined,
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const ValueKey('event-title-field'),
                controller: _title,
                autofocus: widget.existing == null,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: switch (widget.kind) {
                    ScheduleKind.work => 'e.g. Ramp shift',
                    ScheduleKind.classSession => 'e.g. Chemistry lecture',
                    ScheduleKind.deadline =>
                      _deadlineType == DeadlineType.assignment
                          ? 'e.g. Research paper'
                          : 'e.g. Final examination',
                    ScheduleKind.personal => 'e.g. Appointment',
                  },
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name.'
                    : null,
              ),
              const SizedBox(height: 14),
              if (widget.kind == ScheduleKind.work)
                DropdownButtonFormField<WorkCategory>(
                  initialValue: _workCategory,
                  decoration: const InputDecoration(labelText: 'Roster entry'),
                  items: [
                    for (final category in WorkCategory.values)
                      DropdownMenuItem(
                        value: category,
                        child: Text(workCategoryName(category)),
                      ),
                  ],
                  onChanged: (category) {
                    if (category != null) {
                      setState(() => _workCategory = category);
                    }
                  },
                ),
              if (widget.kind == ScheduleKind.deadline)
                DropdownButtonFormField<DeadlineType>(
                  initialValue: _deadlineType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'School item'),
                  items: [
                    for (final type in DeadlineType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(deadlineTypeName(type)),
                      ),
                  ],
                  onChanged: (type) {
                    if (type != null) setState(() => _deadlineType = type);
                  },
                ),
              if (widget.kind == ScheduleKind.personal)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All day'),
                  value: _allDay,
                  onChanged: (value) => setState(() => _allDay = value),
                ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.palette_outlined,
                  color: _currentCategoryColor(preferences),
                ),
                title: Text('$_colorCategoryName color'),
                subtitle: Text(
                  'Used for all ${_colorCategoryName.toLowerCase()} items',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Choose $_colorCategoryName color',
                      onPressed: () => _chooseCategoryColor(preferences),
                      icon: CircleAvatar(
                        radius: 12,
                        backgroundColor: _currentCategoryColor(preferences),
                      ),
                    ),
                    if (_hasCustomCategoryColor(preferences))
                      IconButton(
                        tooltip: 'Use theme default color',
                        onPressed: () async {
                          await ref
                              .read(preferencesRepositoryProvider)
                              .clearCalendarColor(_colorCategory);
                          ref.invalidate(appPreferencesProvider);
                        },
                        icon: const Icon(Icons.restart_alt_rounded),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _sectionHeading('Date and time', Icons.schedule_rounded),
              const SizedBox(height: 6),
              if (widget.kind == ScheduleKind.work && _hasNoTime)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '${workCategoryName(_workCategory)} · all day',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              if (widget.kind == ScheduleKind.deadline &&
                  _deadlineType == DeadlineType.assignment)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Assignment · due this day'),
                ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final startDate = _datePickerButton(
                    key: const ValueKey('event-start-date-button'),
                    valueKey: const ValueKey('event-start-date-value'),
                    label: 'Start date',
                    date: _date,
                    onPressed: _pickDate,
                    loc: loc,
                  );
                  if (_hasNoTime) return startDate;
                  final endDate = _datePickerButton(
                    key: const ValueKey('event-end-date-button'),
                    valueKey: const ValueKey('event-end-date-value'),
                    label: 'End date',
                    date: _date.addDays(_endDayOffset),
                    onPressed: _pickEndDate,
                    loc: loc,
                  );
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(14) > 17;
                  if (constraints.maxWidth < 360 || largeText) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [startDate, const SizedBox(height: 8), endDate],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: startDate),
                      const SizedBox(width: 8),
                      Expanded(child: endDate),
                    ],
                  );
                },
              ),
              if (!_hasNoTime) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: _reminderMinutesBefore,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Reminder',
                    helperText: 'Android may delay reminders if exact alarms are not allowed.',
                    helperMaxLines: 2,
                  ),
                  items: [
                    for (final offset in reminderOffsets)
                      DropdownMenuItem<int?>(
                        value: offset,
                        child: Text(reminderOffsetLabel(offset)),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _reminderMinutesBefore = value),
                ),
              ],
              if (!_hasNoTime) ...[
                for (var i = 0; i < _starts.length; i++)
                  Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _starts.length == 1
                                      ? 'Time'
                                      : 'Interval ${i + 1}',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                              if (_starts.length > 1)
                                IconButton(
                                  tooltip: 'Remove interval',
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 32,
                                    height: 32,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => setState(() {
                                    _starts.removeAt(i);
                                    _ends.removeAt(i);
                                    _endDayOffset =
                                        _minute(_ends.last) <=
                                            _minute(_starts.last)
                                        ? 1
                                        : 0;
                                    _endDateManuallyEdited = false;
                                  }),
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _timePickerButton(
                                  label: 'Starts',
                                  value: _starts[i].format(context),
                                  onPressed: () => _pickTime(i, true),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                ),
                              ),
                              Expanded(
                                child: _timePickerButton(
                                  label: 'Ends',
                                  value: _ends[i].format(context),
                                  onPressed: () => _pickTime(i, false),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.kind == ScheduleKind.work && _starts.length < 2)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        _starts.add(const TimeOfDay(hour: 14, minute: 0));
                        _ends.add(const TimeOfDay(hour: 18, minute: 0));
                        _endDayOffset = 0;
                        _endDateManuallyEdited = false;
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('Add split interval'),
                    ),
                  ),
              ],
              if (widget.kind == ScheduleKind.classSession ||
                  widget.kind == ScheduleKind.work) ...[
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeat weekly'),
                  subtitle: const Text('Choose the weekdays for this series.'),
                  value: _repeat,
                  onChanged: (value) => setState(() {
                    _repeat = value;
                    final term = _selectedAcademicTerm(terms);
                    if (value &&
                        term != null &&
                        (_until == null ||
                            _until!.compareTo(_date) < 0 ||
                            _until!.compareTo(term.endDate) > 0)) {
                      _until = term.endDate;
                    }
                  }),
                ),
                if (_repeat) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_repeat_outlined),
                    title: const Text('End date · optional'),
                    subtitle: Text(
                      _until == null
                          ? 'No end date'
                          : loc.formatMediumDate(
                              DateTime(
                                _until!.year,
                                _until!.month,
                                _until!.day,
                              ),
                            ),
                    ),
                    trailing: _until == null
                        ? const Icon(Icons.calendar_month_outlined)
                        : IconButton(
                            tooltip: 'Clear end date',
                            onPressed: () => setState(() => _until = null),
                            icon: const Icon(Icons.close_rounded),
                          ),
                    onTap: _pickUntil,
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var day = 1; day <= 7; day++)
                        FilterChip(
                          label: Text(
                            ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day - 1],
                            semanticsLabel: const [
                              'Monday',
                              'Tuesday',
                              'Wednesday',
                              'Thursday',
                              'Friday',
                              'Saturday',
                              'Sunday',
                            ][day - 1],
                          ),
                          selected: _weekdays.contains(day),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _weekdays.add(day)
                                : _weekdays.remove(day);
                          }),
                        ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 10),
              if (widget.kind == ScheduleKind.work) ...[
                const SizedBox(height: 12),
                ExpansionTile(
                  key: const ValueKey('work-details-section'),
                  title: const Text('Work details'),
                  subtitle: const Text(
                    'Employer, team, roster code and location',
                  ),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  children: [
                    TextFormField(
                      key: const ValueKey('work-employer-field'),
                      controller: _employer,
                      decoration: const InputDecoration(
                        labelText: 'Employer · optional',
                        hintText: 'e.g. Airport operations',
                      ),
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) {
                        _selectedLegendId = null;
                        _applyLegendSuggestion(legends);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const ValueKey('work-department-field'),
                      controller: _department,
                      decoration: const InputDecoration(
                        labelText: 'Department or team · optional',
                        counterText: '',
                      ),
                      textCapitalization: TextCapitalization.words,
                      maxLength: 512,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const ValueKey('work-role-field'),
                      controller: _jobRole,
                      decoration: const InputDecoration(
                        labelText: 'Job role · optional',
                        counterText: '',
                      ),
                      textCapitalization: TextCapitalization.words,
                      maxLength: 512,
                    ),
                    const SizedBox(height: 8),
                    if (legendsAsync.isLoading)
                      _referenceStatus('Loading saved shift codes…')
                    else if (legendsAsync.hasError)
                      TextButton.icon(
                        onPressed: () =>
                            ref.invalidate(workCodeLegendsProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Could not load shift codes · Retry'),
                      )
                    else if (legends.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        key: const ValueKey('work-code-legend-selector'),
                        initialValue: _legendForCode(legends)?.id,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Choose a saved shift code',
                          helperText: 'Selecting a code fills its usual time and duties. You can still edit them.',
                          helperMaxLines: 2,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Choose a code'),
                          ),
                          for (final legend in _legendOptions(legends))
                            DropdownMenuItem<String?>(
                              value: legend.id,
                              child: Text(
                                _legendLabel(
                                  legend,
                                  preferences?.use24HourTime ?? false,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (id) {
                          if (id == null) {
                            setState(() => _selectedLegendId = null);
                            return;
                          }
                          WorkCodeLegend? selected;
                          for (final legend in legends) {
                            if (legend.id == id) {
                              selected = legend;
                              break;
                            }
                          }
                          if (selected == null) return;
                          setState(() {
                            _selectedLegendId = id;
                            if (_employer.text.trim().isEmpty &&
                                selected!.employer.isNotEmpty) {
                              _employer.text = selected.employer;
                            }
                            _code.text = selected!.code;
                            _meaningManuallyEdited = false;
                            _timeManuallyEdited = false;
                            _applyLegendEntry(selected);
                          });
                        },
                      ),
                    if (legends.isEmpty &&
                        !legendsAsync.isLoading &&
                        !legendsAsync.hasError)
                      TextButton.icon(
                        key: const ValueKey('manage-roster-references'),
                        onPressed: _openWorkReferences,
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('Set up shift codes'),
                      ),
                    if (legends.isNotEmpty) const SizedBox(height: 8),
                    TextFormField(
                      key: const ValueKey('work-code-field'),
                      controller: _code,
                      decoration: const InputDecoration(
                        labelText: 'Roster code · optional',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) {
                        _selectedLegendId = null;
                        _applyLegendSuggestion(legends);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const ValueKey('work-location-field'),
                      controller: _location,
                      decoration: const InputDecoration(
                        labelText: 'Location · optional',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const ValueKey('work-code-assignment-field'),
                      controller: _codeMeaning,
                      decoration: const InputDecoration(
                        labelText: 'Code assignment details · optional',
                        hintText:
                            'Flights or duties covered by this roster code',
                        alignLabelWithHint: true,
                        counterText: '',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 2000,
                      minLines: 1,
                      maxLines: 3,
                      onChanged: (_) => _meaningManuallyEdited = true,
                    ),
                  ],
                ),
              ],

              ExpansionTile(
                key: const ValueKey('additional-details-section'),
                title: const Text('Additional details'),
                subtitle: Text(switch (widget.kind) {
                  ScheduleKind.work => 'Notes, supervisor and shift contacts',
                  ScheduleKind.classSession ||
                  ScheduleKind.deadline => 'Course details, location and notes',
                  ScheduleKind.personal => 'Location and notes',
                }),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                  if (widget.kind == ScheduleKind.classSession ||
                      widget.kind == ScheduleKind.deadline) ...[
                    TextFormField(
                      key: const ValueKey('event-code-field'),
                      controller: _code,
                      decoration: const InputDecoration(
                        labelText: 'Course code · optional',
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    if (termsAsync!.hasValue)
                      DropdownButtonFormField<String?>(
                        key: const ValueKey('academic-term-field'),
                        initialValue: _academicTermId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Academic term · optional',
                          helperText: selectedTerm == null
                              ? 'Link this study event to an institution and semester.'
                              : 'Dates are limited to ${selectedTerm.name}.',
                          helperMaxLines: 2,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No term'),
                          ),
                          for (final term in terms)
                            DropdownMenuItem<String?>(
                              value: term.id,
                              child: Text(
                                '${term.institution} · ${term.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _academicTermId = value;
                          final term = _selectedAcademicTerm(terms);
                          if (term != null) {
                            if (_date.compareTo(term.startDate) < 0) {
                              _date = term.startDate;
                            } else if (_date.compareTo(term.endDate) > 0) {
                              _date = term.endDate;
                            }
                            if (_repeat &&
                                (_until == null ||
                                    _until!.compareTo(_date) < 0 ||
                                    _until!.compareTo(term.endDate) > 0)) {
                              _until = term.endDate;
                            }
                          }
                        }),
                      )
                    else if (termsAsync.hasError)
                      TextButton.icon(
                        onPressed: () => ref.invalidate(academicTermsProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text(
                          'Academic terms could not be loaded. Retry',
                        ),
                      )
                    else
                      const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                  if (widget.kind != ScheduleKind.work) ...[
                    TextFormField(
                      key: const ValueKey('personal-location-field'),
                      controller: _location,
                      decoration: const InputDecoration(
                        labelText: 'Location · optional',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    key: const ValueKey('event-notes-field'),
                    controller: _notes,
                    decoration: const InputDecoration(
                      labelText: 'Notes · optional',
                    ),
                    minLines: 2,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  if (widget.kind == ScheduleKind.work) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _reportingInstruction,
                      decoration: const InputDecoration(
                        labelText: 'Reporting instructions · optional',
                        hintText: 'e.g. Where and when to report',
                        alignLabelWithHint: true,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 2000,
                    ),
                    const SizedBox(height: 8),
                    if (supervisorsAsync?.isLoading == true)
                      _referenceStatus('Loading saved supervisors…')
                    else if (supervisorsAsync?.hasError == true)
                      TextButton.icon(
                        onPressed: () =>
                            ref.invalidate(supervisorProfilesProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Could not load supervisors · Retry'),
                      )
                    else if (supervisors.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        key: const ValueKey('saved-supervisor-selector'),
                        initialValue: selectedSupervisor?.id,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Choose a saved supervisor',
                          helperText: 'Selecting a supervisor fills their saved contact number.',
                          helperMaxLines: 2,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Choose a supervisor'),
                          ),
                          for (final profile in supervisors)
                            DropdownMenuItem<String?>(
                              value: profile.id,
                              child: Text(
                                '${profile.name} · ${profile.type == SupervisorType.acting ? 'Acting' : 'Permanent'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (id) {
                          if (id == null) return;
                          final profile = supervisors
                              .where((entry) => entry.id == id)
                              .firstOrNull;
                          if (profile == null) return;
                          setState(() {
                            _supervisorName.text = profile.name;
                            _supervisorPhone.text = profile.phone;
                          });
                        },
                      ),
                    if (supervisors.isEmpty &&
                        supervisorsAsync?.isLoading != true &&
                        supervisorsAsync?.hasError != true)
                      TextButton.icon(
                        onPressed: _openWorkReferences,
                        icon: const Icon(Icons.people_outline_rounded),
                        label: const Text('Set up supervisor list'),
                      ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const ValueKey('supervisor-name-field'),
                      controller: _supervisorName,
                      decoration: const InputDecoration(
                        labelText: 'Supervisor · optional',
                      ),
                      textCapitalization: TextCapitalization.words,
                      maxLength: 512,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('supervisor-phone-field'),
                      controller: _supervisorPhone,
                      decoration: const InputDecoration(
                        labelText: 'Supervisor phone · optional',
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 256,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactName,
                      decoration: const InputDecoration(
                        labelText: 'Shift contact · optional',
                      ),
                      textCapitalization: TextCapitalization.words,
                      maxLength: 512,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactPhone,
                      decoration: const InputDecoration(
                        labelText: 'Contact phone · optional',
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 256,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                key: const ValueKey('advanced-details-section'),
                initiallyExpanded:
                    deviceZone == null ||
                    (widget.existing?.timeZoneId == null &&
                        widget.existing != null),
                title: const Text('Advanced'),
                subtitle: const Text('Time zone and clock changes'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                  TextFormField(
                    controller: _timeZone,
                    decoration: InputDecoration(
                      labelText: 'Time zone',
                      hintText: deviceZone ?? 'e.g. America/Barbados',
                      helperText:
                          widget.existing?.timeZoneId == null &&
                              widget.existing != null
                          ? 'This older event needs a time zone before you save it.'
                          : 'Normally this is set automatically from your device.',
                      helperMaxLines: 2,
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a time zone.'
                        : null,
                  ),
                  if (widget.existing?.timeZoneId == null &&
                      widget.existing != null &&
                      deviceZone != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _timeZone.text = deviceZone),
                        icon: const Icon(Icons.my_location_outlined),
                        label: Text('Use device time zone: $deviceZone'),
                      ),
                    ),
                  if (!_hasNoTime)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: DropdownButtonFormField<CivilTimeFoldChoice?>(
                        initialValue: _fold,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'If the clock time repeats',
                          helperText:
                              'Usually leave this set to ask only if needed.',
                          helperMaxLines: 2,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: null,
                            child: Text('Ask me if needed'),
                          ),
                          DropdownMenuItem(
                            value: CivilTimeFoldChoice.earlier,
                            child: Text('Use the earlier time'),
                          ),
                          DropdownMenuItem(
                            value: CivilTimeFoldChoice.later,
                            child: Text('Use the later time'),
                          ),
                        ],
                        onChanged: (value) => setState(() => _fold = value),
                      ),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_saving ? 'Saving…' : 'Save event'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeading(String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Row(
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    ),
  );

  Widget _datePickerButton({
    required Key key,
    required Key valueKey,
    required String label,
    required CivilDate date,
    required VoidCallback onPressed,
    required MaterialLocalizations loc,
  }) => OutlinedButton(
    key: key,
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      visualDensity: VisualDensity.compact,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(
          key: valueKey,
          loc.formatMediumDate(DateTime(date.year, date.month, date.day)),
          maxLines: 2,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    ),
  );

  Widget _referenceStatus(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );

  Widget _timePickerButton({
    required String label,
    required String value,
    required VoidCallback onPressed,
  }) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      visualDensity: VisualDensity.compact,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    ),
  );

  bool _hasCustomCategoryColor(AppPreferences? preferences) =>
      switch (_colorCategory) {
        CalendarColorCategory.work => preferences?.workColor != null,
        CalendarColorCategory.training => preferences?.trainingColor != null,
        CalendarColorCategory.school => preferences?.schoolColor != null,
        CalendarColorCategory.deadline => preferences?.deadlineColor != null,
        CalendarColorCategory.personal => preferences?.personalColor != null,
      };
}

TimeOfDay _defaultStartTime(ScheduleKind kind) => switch (kind) {
  ScheduleKind.work => const TimeOfDay(hour: 9, minute: 0),
  ScheduleKind.classSession => const TimeOfDay(hour: 10, minute: 0),
  ScheduleKind.deadline => const TimeOfDay(hour: 9, minute: 0),
  ScheduleKind.personal => const TimeOfDay(hour: 9, minute: 0),
};

TimeOfDay _defaultEndTime(ScheduleKind kind) => switch (kind) {
  ScheduleKind.work => const TimeOfDay(hour: 17, minute: 0),
  ScheduleKind.classSession => const TimeOfDay(hour: 11, minute: 30),
  ScheduleKind.deadline => const TimeOfDay(hour: 11, minute: 0),
  ScheduleKind.personal => const TimeOfDay(hour: 10, minute: 0),
};

TimeOfDay _timeFromMinute(int minute) =>
    TimeOfDay(hour: (minute ~/ 60) % 24, minute: minute % 60);

Future<Color?> _showCalendarColorPicker(BuildContext context, Color initial) {
  const colors = <({String name, Color color})>[
    (name: 'Blue', color: Color(0xFF2563EB)),
    (name: 'Teal', color: Color(0xFF0F9D8A)),
    (name: 'Violet', color: Color(0xFF7C4DFF)),
    (name: 'Amber', color: Color(0xFFF59E0B)),
    (name: 'Red', color: Color(0xFFEF4444)),
    (name: 'Green', color: Color(0xFF16A34A)),
    (name: 'Pink', color: Color(0xFFEC4899)),
    (name: 'Orange', color: Color(0xFFEA580C)),
    (name: 'Indigo', color: Color(0xFF4F46E5)),
    (name: 'Cyan', color: Color(0xFF0891B2)),
    (name: 'Rose', color: Color(0xFFE11D48)),
    (name: 'Slate', color: Color(0xFF64748B)),
  ];
  final choices = [
    if (!colors.any((choice) => choice.color.toARGB32() == initial.toARGB32()))
      (name: 'Current', color: initial),
    ...colors,
  ];
  return showDialog<Color>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Choose a calendar color'),
      content: SizedBox(
        width: 320,
        height: (choices.length / 2).ceil() * 48,
        child: GridView.builder(
          itemCount: choices.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 48,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final choice = choices[index];
            final selected = choice.color.toARGB32() == initial.toARGB32();
            return Semantics(
              button: true,
              selected: selected,
              label: '${choice.name} calendar color',
              child: ExcludeSemantics(
                child: InkWell(
                  key: ValueKey('calendar-color-${choice.name.toLowerCase()}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(context, choice.color),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: choice.color,
                          child: selected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: choice.color.computeLuminance() > .45
                                      ? Colors.black
                                      : Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(choice.name)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
