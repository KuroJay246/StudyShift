import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dependencies.dart';
import '../../application/work_code_references.dart';
import '../../domain/schedule.dart';
import '../../domain/supervisor_profile.dart';
import '../../domain/work_code_legend.dart';
import '../design/studyshift_spacing.dart';

class WorkCodeLegendPage extends ConsumerStatefulWidget {
  const WorkCodeLegendPage({super.key});

  @override
  ConsumerState<WorkCodeLegendPage> createState() => _WorkCodeLegendPageState();
}

enum _LegendSection { codes, supervisors }

class _WorkCodeLegendPageState extends ConsumerState<WorkCodeLegendPage> {
  final _search = TextEditingController();
  _LegendSection _section = _LegendSection.codes;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit([WorkCodeLegend? current]) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _WorkCodeLegendDialog(current: current),
    );
  }

  Future<void> _editSupervisor([SupervisorProfile? current]) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SupervisorProfileDialog(current: current),
    );
  }

  Future<void> _deleteSupervisor(SupervisorProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove supervisor?'),
        content: Text(
          '${profile.name} will be removed from the supervisor list. Saved shifts keep their existing supervisor details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(supervisorRepositoryProvider).delete(profile.id);
    }
  }

  Future<void> _delete(WorkCodeLegend item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove shift code?'),
        content: Text(
          '${item.code} will be removed from your shift legend. Saved shifts will keep their saved details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(workCodeLegendRepositoryProvider).delete(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final legend = ref.watch(workCodeLegendsProvider);
    final schedules = ref.watch(scheduleItemsProvider);
    final supervisors = ref.watch(supervisorProfilesProvider);
    final query = _search.text.trim().toLowerCase();
    return Scaffold(
      appBar: AppBar(title: const Text('Shift legend')),
      floatingActionButton: FloatingActionButton(
        tooltip: _section == _LegendSection.codes
            ? 'Add shift code'
            : 'Add supervisor',
        onPressed: _section == _LegendSection.codes ? _edit : _editSupervisor,
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<_LegendSection>(
              segments: const [
                ButtonSegment(
                  value: _LegendSection.codes,
                  icon: Icon(Icons.schedule_rounded),
                  label: Text('Codes'),
                ),
                ButtonSegment(
                  value: _LegendSection.supervisors,
                  icon: Icon(Icons.badge_outlined),
                  label: Text('Supervisors'),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (selection) => setState(() {
                _section = selection.first;
                _search.clear();
              }),
            ),
          ),
          Expanded(
            child: _section == _LegendSection.codes
                ? legend.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => _loadFailure(
                      'Your shift codes could not be loaded.',
                      () => ref.invalidate(workCodeLegendsProvider),
                    ),
                    data: (items) => schedules.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => _loadFailure(
                        'Saved work shifts could not be loaded.',
                        () => ref.invalidate(scheduleItemsProvider),
                      ),
                      data: (scheduleItems) => _buildLegendContent(
                        context,
                        items,
                        observedWorkCodeReferences(scheduleItems),
                        query,
                      ),
                    ),
                  )
                : supervisors.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => _loadFailure(
                      'Supervisor contacts could not be loaded.',
                      () => ref.invalidate(supervisorProfilesProvider),
                    ),
                    data: (items) => _buildSupervisorContent(items, query),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _loadFailure(String message, VoidCallback retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 40),
          const SizedBox(height: 12),
          Text(message),
          TextButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );

  Widget _buildSupervisorContent(
    List<SupervisorProfile> profiles,
    String query,
  ) {
    final filtered = profiles
        .where(
          (profile) =>
              query.isEmpty ||
              '${profile.name} ${profile.phone} ${profile.notes} ${profile.type.name}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList(growable: false);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Search supervisors or contact details',
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
            children: [
              Text(
                '${filtered.length} ${filtered.length == 1 ? 'supervisor' : 'supervisors'}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              if (profiles.isEmpty)
                _emptySupervisorsCard()
              else if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No matching supervisors. Try another search.'),
                  ),
                )
              else
                for (final profile in filtered) _supervisorCard(profile),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptySupervisorsCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.badge_outlined, size: 40),
          const SizedBox(height: 12),
          Text(
            'No supervisors saved',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'Save supervisor names and optional contact details to choose them on a shift.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _editSupervisor,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add supervisor'),
          ),
        ],
      ),
    ),
  );

  Widget _supervisorCard(SupervisorProfile profile) => Card(
    child: ListTile(
      leading: CircleAvatar(
        child: Text(profile.name.characters.first.toUpperCase()),
      ),
      title: Text(profile.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.type == SupervisorType.acting
                ? 'Acting supervisor'
                : 'Permanent supervisor',
          ),
          if (profile.phone.isNotEmpty) Text(profile.phone),
          if (profile.notes.isNotEmpty)
            Text(profile.notes, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
      isThreeLine: profile.phone.isNotEmpty || profile.notes.isNotEmpty,
      trailing: PopupMenuButton<String>(
        tooltip: 'Actions for ${profile.name}',
        onSelected: (action) => action == 'edit'
            ? _editSupervisor(profile)
            : _deleteSupervisor(profile),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Remove')),
        ],
      ),
    ),
  );

  static String _formatMinute(BuildContext context, int minute) =>
      MaterialLocalizations.of(context)
          .formatTimeOfDay(TimeOfDay(hour: minute ~/ 60, minute: minute % 60));

  static String _formatInterval(BuildContext context, EventInterval interval) {
    final start = _formatMinute(context, interval.startMinute);
    final end = _formatMinute(context, interval.endMinute);
    final dayOffset = interval.endDayOffset - interval.startDayOffset;
    final overnight =
        dayOffset > 0 || interval.endMinute <= interval.startMinute;
    return '$start – $end${overnight ? ' (+${dayOffset > 0 ? dayOffset : 1} day)' : ''}';
  }

  Widget _buildLegendContent(
    BuildContext context,
    List<WorkCodeLegend> definitions,
    List<ObservedWorkCodeReference> observed,
    String query,
  ) {
    final byEmployerAndCode = <String, _CodeCardData>{};
    _CodeCardData dataFor(String code, String? employerName) {
      final employer = employerName?.trim() ?? '';
      final key = '${employer.toLowerCase()}\u0000${code.toLowerCase()}';
      return byEmployerAndCode.putIfAbsent(
        key,
        () => _CodeCardData(code, employer.isEmpty ? null : employer),
      );
    }

    for (final definition in definitions) {
      final data = dataFor(definition.code, definition.employer);
      data.definitions.add(definition);
      final detail = definition.assignmentDetails.trim();
      if (detail.isNotEmpty) data.details.add(detail);
      data.flightIds.addAll(
        definition.flightIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty),
      );
      for (final window in definition.timeWindows) {
        final overnight = window.endDayOffset > 0;
        final label =
            '${_formatMinute(context, window.startMinute)} – ${_formatMinute(context, window.endMinute)}${overnight ? ' (+${window.endDayOffset} day)' : ''}';
        data.addWindow(label, window.startMinute);
      }
    }
    for (final reference in observed) {
      final data = dataFor(reference.code, reference.employerName);
      data.hasRosterObservation = true;
      data.details.addAll(
        reference.assignmentDetails
            .map((detail) => detail.trim())
            .where((detail) => detail.isNotEmpty),
      );
      for (final pattern in reference.patterns) {
        final window = pattern.intervals
            .map((interval) => _formatInterval(context, interval))
            .join(' / ');
        if (window.isNotEmpty) {
          data.addWindow(
            window,
            pattern.intervals.isEmpty ? 0 : pattern.intervals.first.startMinute,
          );
        }
      }
    }

    final cards = <_CodeCardData>[];
    for (final data in byEmployerAndCode.values) {
      final searchable = [
        data.code,
        if (data.employerName != null) data.employerName!,
        ...data.details,
        ...data.windows.keys,
        ...data.flightIds,
      ].join(' ').toLowerCase();
      if (query.isEmpty || searchable.contains(query)) cards.add(data);
    }
    cards.sort((a, b) {
      final byCode = a.code.toLowerCase().compareTo(b.code.toLowerCase());
      return byCode != 0
          ? byCode
          : (a.employerName ?? '').toLowerCase().compareTo(
              (b.employerName ?? '').toLowerCase(),
            );
    });
    final codeCounts = <String, int>{};
    for (final card in cards) {
      final key = card.code.toLowerCase();
      codeCounts.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Search code or description',
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
            children: [
              if (query.isNotEmpty)
                Text(
                  '${cards.length} ${cards.length == 1 ? 'result' : 'results'}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              if (cards.isNotEmpty) ...[
                if (query.isNotEmpty) const SizedBox(height: 12),
                Text(
                  cards.any((card) => card.hasRosterObservation)
                      ? 'From your work roster'
                      : 'Saved shift codes',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (cards.isEmpty && definitions.isEmpty && observed.isEmpty)
                _emptyReferenceCard(context)
              else if (cards.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No matching codes. Try another search.'),
                  ),
                )
              else
                for (final data in cards)
                  _codeCard(
                    context,
                    data,
                    showEmployer: codeCounts[data.code.toLowerCase()]! > 1,
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _codeCard(
    BuildContext context,
    _CodeCardData data, {
    required bool showEmployer,
  }) {
    final details = data.details.toList()..sort();
    final windows = data.sortedWindows;
    final flights = data.flightIds.toList()..sort();
    final summary = _groupSummary(details);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showCodeDetails(context, data),
        child: Padding(
          padding: const EdgeInsets.all(StudyShiftSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(label: Text(data.code)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (data.definitions.isNotEmpty)
                    PopupMenuButton<String>(
                      tooltip: 'Actions for ${data.code}',
                      onSelected: (action) => action == 'edit'
                          ? _edit(data.definitions.first)
                          : _delete(data.definitions.first),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Remove')),
                      ],
                    )
                  else
                    const Icon(Icons.chevron_right_rounded),
                ],
              ),
              if (showEmployer && data.employerName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    data.employerName!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (windows.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 0,
                  children: [
                    for (final window in windows)
                      Chip(
                        avatar: const Icon(Icons.schedule_rounded, size: 17),
                        label: Text(window.label),
                      ),
                  ],
                ),
              ],
              if (flights.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${flights.length} possible ${flights.length == 1 ? 'flight' : 'flights'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCodeDetails(
    BuildContext context,
    _CodeCardData data,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final windows = data.sortedWindows;
      final flights = data.flightIds.toList()..sort();
      final details = data.details.toList()..sort();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${data.code} · ${_groupSummary(details)}',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                if (data.employerName != null) ...[
                  const SizedBox(height: 4),
                  Text(data.employerName!),
                ],
                const SizedBox(height: 16),
                if (windows.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final window in windows)
                        Chip(
                          avatar: const Icon(Icons.schedule_rounded, size: 18),
                          label: Text(window.label),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                Text(
                  'Possible flights',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (flights.isEmpty)
                  const Text('No flight references saved for this code.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final flight in flights) Chip(label: Text(flight)),
                    ],
                  ),
                const Divider(height: 28),
                if (details.isNotEmpty) Text(details.join('\n')),
                const SizedBox(height: 8),
                Text(
                  'Typical roster details · not live flight assignments',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  static String _shortDetail(String detail) {
    final separator = detail.indexOf(' · ');
    return separator < 0 ? detail : detail.substring(0, separator);
  }

  static String _groupSummary(List<String> details) {
    if (details.isEmpty) return 'Shift code reference';
    final summaries = details.map(_shortDetail).toSet().toList()..sort();
    if (summaries.length == 1) return summaries.first;

    var commonPrefix = summaries.first;
    for (final summary in summaries.skip(1)) {
      var length = 0;
      while (length < commonPrefix.length &&
          length < summary.length &&
          commonPrefix[length] == summary[length]) {
        length++;
      }
      commonPrefix = commonPrefix.substring(0, length);
    }
    final sharedMeaning = commonPrefix
        .replaceFirst(RegExp(r'[\s·-]+$'), '')
        .trim();
    return sharedMeaning.length > 2 ? sharedMeaning : summaries.first;
  }

  Widget _emptyReferenceCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(StudyShiftSpacing.cardPadding),
      child: Column(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'No work references saved',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Add a shift code with its usual hours and flight or duty details.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add first code'),
          ),
        ],
      ),
    ),
  );
}

class _CodeCardData {
  _CodeCardData(this.code, this.employerName);

  final String code;
  final String? employerName;
  final definitions = <WorkCodeLegend>[];
  final details = <String>{};
  final windows = <String, int>{};
  final flightIds = <String>{};
  bool hasRosterObservation = false;

  List<({String label, int startMinute})> get sortedWindows {
    final result = [
      for (final entry in windows.entries)
        (label: entry.key, startMinute: entry.value),
    ];
    result.sort((a, b) {
      final byStart = a.startMinute.compareTo(b.startMinute);
      return byStart != 0 ? byStart : a.label.compareTo(b.label);
    });
    return result;
  }

  void addWindow(String label, int startMinute) {
    final previous = windows[label];
    if (previous == null || startMinute < previous) {
      windows[label] = startMinute;
    }
  }
}

class _WorkCodeLegendDialog extends ConsumerStatefulWidget {
  const _WorkCodeLegendDialog({this.current});

  final WorkCodeLegend? current;

  @override
  ConsumerState<_WorkCodeLegendDialog> createState() =>
      _WorkCodeLegendDialogState();
}

class _WorkCodeLegendDialogState extends ConsumerState<_WorkCodeLegendDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.current?.code ?? '');
  late final _employer = TextEditingController(
    text: widget.current?.employer ?? '',
  );
  late final _meaning = TextEditingController(
    text: widget.current?.assignmentDetails ?? '',
  );
  late final _flightIds = TextEditingController(
    text: widget.current?.flightIds.join(', ') ?? '',
  );
  late final List<TimeOfDay?> _starts =
      widget.current?.timeWindows.isNotEmpty == true
      ? widget.current!.timeWindows
            .map((window) => _toTime(window.startMinute))
            .toList()
      : [null];
  late final List<TimeOfDay?> _ends =
      widget.current?.timeWindows.isNotEmpty == true
      ? widget.current!.timeWindows
            .map((window) => _toTime(window.endMinute))
            .toList()
      : [null];
  late final List<int> _endDayOffsets =
      widget.current?.timeWindows.isNotEmpty == true
      ? widget.current!.timeWindows
            .map((window) => window.endDayOffset)
            .toList()
      : [0];
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _employer.dispose();
    _meaning.dispose();
    _flightIds.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (List.generate(
      _starts.length,
      (index) => index,
    ).any((index) => (_starts[index] == null) != (_ends[index] == null))) {
      setState(
        () => _error =
            'Choose both times for each interval, or clear the window.',
      );
      return;
    }
    final windows = [
      for (var index = 0; index < _starts.length; index++)
        if (_starts[index] != null && _ends[index] != null)
          WorkCodeTimeWindow(
            startMinute: _starts[index]!.hour * 60 + _starts[index]!.minute,
            endMinute: _ends[index]!.hour * 60 + _ends[index]!.minute,
            endDayOffset: _endDayOffsets[index],
          ),
    ];
    if (windows.any((window) => !window.isValid)) {
      setState(() => _error = 'Each interval must end after its start.');
      return;
    }
    if (windows.isEmpty && _meaning.text.trim().isEmpty) {
      setState(
        () => _error = 'Add the flight or duty details, or enter a time range.',
      );
      return;
    }
    try {
      await ref
          .read(workCodeLegendRepositoryProvider)
          .save(
            WorkCodeLegend(
              id:
                  widget.current?.id ??
                  'legend-${DateTime.now().microsecondsSinceEpoch}',
              employer: _employer.text,
              code: _code.text,
              assignmentDetails: _meaning.text,
              timeWindows: windows,
              flightIds: _flightIds.text
                  .split(',')
                  .map((flight) => flight.trim())
                  .where((flight) => flight.isNotEmpty)
                  .toSet()
                  .toList(),
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      if (!mounted) return;
      setState(
        () =>
            _error = exception.toString().replaceFirst('FormatException: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.current == null ? 'Add shift code' : 'Edit shift code'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Shift code'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a code.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _employer,
              decoration: const InputDecoration(
                labelText: 'Employer (optional)',
                helperText: 'Use this only when a code differs by employer.',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Typical time windows',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 4),
            for (var index = 0; index < _starts.length; index++) ...[
              Card(
                margin: const EdgeInsets.only(top: 6),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Interval ${index + 1}')),
                          if (_starts.length > 1)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Remove interval ${index + 1}',
                              onPressed: () => setState(() {
                                _starts.removeAt(index);
                                _ends.removeAt(index);
                                _endDayOffsets.removeAt(index);
                              }),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          if (_starts.length == 1 &&
                              (_starts[index] != null || _ends[index] != null))
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Clear code times',
                              onPressed: () => setState(() {
                                _starts[index] = null;
                                _ends[index] = null;
                                _endDayOffsets[index] = 0;
                              }),
                              icon: const Icon(Icons.close_rounded),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _pickTime(index: index, start: true),
                              icon: const Icon(Icons.schedule_rounded),
                              label: Text(
                                _timeLabel(context, _starts[index], 'Starts'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _pickTime(index: index, start: false),
                              icon: const Icon(Icons.schedule_rounded),
                              label: Text(
                                _timeLabel(context, _ends[index], 'Ends'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_starts.length < 2)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _starts.add(null);
                    _ends.add(null);
                    _endDayOffsets.add(0);
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('Add split interval'),
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _meaning,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Flights or assignment details',
                hintText: 'Arrivals, departures, or flight references',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _flightIds,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Associated flight codes',
                hintText: 'AA2725, LI681, B6361',
                helperText: 'Typical references only; not live flight data.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save shift code')),
    ],
  );

  Future<void> _pickTime({required int index, required bool start}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime:
          (start ? _starts[index] : _ends[index]) ??
          TimeOfDay(hour: start ? 6 : 14, minute: 0),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _starts[index] = selected;
      } else {
        _ends[index] = selected;
      }
      if (_starts[index] != null && _ends[index] != null) {
        _endDayOffsets[index] =
            _ends[index]!.hour * 60 + _ends[index]!.minute <=
                _starts[index]!.hour * 60 + _starts[index]!.minute
            ? 1
            : 0;
      }
      _error = null;
    });
  }

  static TimeOfDay? _toTime(int? minute) => minute == null
      ? null
      : TimeOfDay(hour: minute ~/ 60, minute: minute % 60);

  static String _timeLabel(
    BuildContext context,
    TimeOfDay? time,
    String empty,
  ) => time == null
      ? empty
      : MaterialLocalizations.of(context).formatTimeOfDay(time);
}

class _SupervisorProfileDialog extends ConsumerStatefulWidget {
  const _SupervisorProfileDialog({this.current});

  final SupervisorProfile? current;

  @override
  ConsumerState<_SupervisorProfileDialog> createState() =>
      _SupervisorProfileDialogState();
}

class _SupervisorProfileDialogState
    extends ConsumerState<_SupervisorProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.current?.name ?? '');
  late final _phone = TextEditingController(text: widget.current?.phone ?? '');
  late final _notes = TextEditingController(text: widget.current?.notes ?? '');
  late SupervisorType _type = widget.current?.type ?? SupervisorType.permanent;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref
          .read(supervisorRepositoryProvider)
          .save(
            SupervisorProfile(
              id:
                  widget.current?.id ??
                  'supervisor-${DateTime.now().microsecondsSinceEpoch}',
              name: _name.text,
              type: _type,
              phone: _phone.text,
              notes: _notes.text,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      if (!mounted) return;
      setState(
        () =>
            _error = exception.toString().replaceFirst('FormatException: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.current == null ? 'Add supervisor' : 'Edit supervisor'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a name.'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SupervisorType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
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
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone or contact number (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save supervisor')),
    ],
  );
}
