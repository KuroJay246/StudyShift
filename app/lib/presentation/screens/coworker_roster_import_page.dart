import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dependencies.dart';
import '../../data/csv_schedule_import.dart';
import '../../data/coworker_roster_matcher.dart';
import '../../data/xlsx_schedule_import.dart';
import '../../domain/schedule.dart';
import '../../domain/work_occurrence_coworkers.dart';
import '../../platform/schedule_import_file_bridge.dart';

class CoworkerRosterImportPage extends ConsumerStatefulWidget {
  const CoworkerRosterImportPage({super.key});

  @override
  ConsumerState<CoworkerRosterImportPage> createState() =>
      _CoworkerRosterImportPageState();
}

class _CoworkerRosterImportPageState
    extends ConsumerState<CoworkerRosterImportPage> {
  final _fileBridge = const ScheduleImportFileBridge();
  final _parser = const CsvScheduleImportParser();
  final _matcher = const CoworkerRosterMatcher();
  final _xlsxParser = const XlsxScheduleImportParser();
  List<CoworkerRosterMatch> _matches = const [];
  List<String> _notices = const [];
  String? _fileName;
  String? _error;
  bool _loading = false;
  bool _saving = false;

  Future<void> _selectFile() async {
    setState(() {
      _loading = true;
      _error = null;
      _matches = const [];
      _notices = const [];
      _fileName = null;
    });
    try {
      final selected = await _fileBridge.openCalendar();
      if (selected == null) return;
      final name = selected.name.toLowerCase();
      final parsed = name.endsWith('.csv')
          ? _parser.parseCoworkerRoster(
              utf8.decode(selected.bytes!, allowMalformed: false),
            )
          : name.endsWith('.xlsx')
          ? _xlsxParser.parseCoworkerRoster(selected.bytes!)
          : throw const FormatException(
              'Choose a .csv or .xlsx coworker roster file.',
            );
      final saved = await ref.read(scheduleRepositoryProvider).getItems();
      final matches = parsed.assignments
          .map((assignment) => _matcher.match(assignment, saved))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _fileName = selected.name;
        _matches = matches;
        _notices = parsed.notices;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final eligible = _matches
        .where(
          (match) =>
              match.status == CoworkerRosterMatchStatus.matched &&
              match.assignment.sameRosterCodeVerified,
        )
        .toList(growable: false);
    if (eligible.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update coworkers on saved shifts?'),
        content: Text(
          'Add coworker names to ${eligible.length} matching saved ${eligible.length == 1 ? 'shift' : 'shifts'}. Dates, times, codes and all other schedule details stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Review again'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update coworkers'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(scheduleRepositoryProvider);
      final occurrenceUpdates = <WorkOccurrenceCoworkers>[];
      final eventUpdates = <ScheduleItem>[];
      for (final match in eligible) {
        final updatedShift = match.updatedShift;
        if (updatedShift != null) {
          eventUpdates.add(updatedShift);
          continue;
        }
        final shift = match.existingShift;
        final date = match.occurrenceDate;
        final code = shift?.code;
        if (shift == null || date == null || code == null) continue;
        occurrenceUpdates.add(
          WorkOccurrenceCoworkers(
            shiftItemId: shift.id,
            occurrenceDate: date,
            rosterCode: code,
            employerName: shift.employerName,
            coworkers: match.updatedCoworkers,
          ),
        );
      }
      await repository.updateCoworkersAtomically(
        eventUpdates,
        occurrenceUpdates: occurrenceUpdates,
      );
      ref.invalidate(scheduleItemsProvider);
      ref.invalidate(workOccurrenceCoworkersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated coworkers on ${eligible.length} shifts.'),
          ),
        );
        Navigator.pop(context);
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendlyError(Object error) => error is FormatException
      ? error.message.toString()
      : 'Could not read this roster. Check the CSV and try again.';

  @override
  Widget build(BuildContext context) {
    final matched = _matches
        .where((match) => match.status == CoworkerRosterMatchStatus.matched)
        .length;
    final unmatched = _matches
        .where((match) => match.status == CoworkerRosterMatchStatus.unmatched)
        .length;
    final ambiguous = _matches
        .where((match) => match.status == CoworkerRosterMatchStatus.ambiguous)
        .length;
    final verifiedMatched = _matches
        .where(
          (match) =>
              match.status == CoworkerRosterMatchStatus.matched &&
              match.assignment.sameRosterCodeVerified,
        )
        .length;
    final hasUnverifiedMatches = _matches.any(
      (match) =>
          match.status == CoworkerRosterMatchStatus.matched &&
          !match.assignment.sameRosterCodeVerified,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Import coworkers')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Match coworkers to saved shifts',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use a CSV or Excel sheet with date, code and coworkers columns. StudyShift matches the date and roster code to existing shifts. This flow never creates shifts.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Optional employer column can distinguish employers with the same code. Unmatched and duplicate matches are shown for review and are never saved.',
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
                _loading ? 'Reading roster…' : 'Choose coworker roster file',
              ),
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 8),
              Text('Source: $_fileName'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              _MessageCard(
                icon: Icons.error_outline,
                text: _error!,
                warning: true,
              ),
            ],
            for (final notice in _notices) ...[
              const SizedBox(height: 8),
              _MessageCard(
                icon: Icons.info_outline,
                text: notice,
                warning: true,
              ),
            ],
            if (_matches.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '$matched matched · $unmatched unmatched · $ambiguous ambiguous',
              ),
              for (final match in _matches) ...[
                const SizedBox(height: 10),
                _MatchCard(match: match),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: verifiedMatched == 0 || _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.group_add_outlined),
                label: Text(
                  _saving
                      ? 'Saving…'
                      : verifiedMatched > 0
                      ? 'Update coworkers on $verifiedMatched ${verifiedMatched == 1 ? 'shift' : 'shifts'}'
                      : hasUnverifiedMatches
                      ? 'Verify coworker codes first'
                      : 'No verified shift matches',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final CoworkerRosterMatch match;

  @override
  Widget build(BuildContext context) {
    final status = switch (match.status) {
      CoworkerRosterMatchStatus.matched => 'Match found',
      CoworkerRosterMatchStatus.unmatched => 'No saved shift matches',
      CoworkerRosterMatchStatus.ambiguous =>
        'More than one saved shift matches',
    };
    final icon = switch (match.status) {
      CoworkerRosterMatchStatus.matched => Icons.check_circle_outline,
      CoworkerRosterMatchStatus.unmatched => Icons.help_outline,
      CoworkerRosterMatchStatus.ambiguous => Icons.warning_amber_rounded,
    };
    final item = match.existingShift;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${match.assignment.code} · ${match.assignment.date}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(status, style: Theme.of(context).textTheme.titleSmall),
            if (item != null) ...[
              const SizedBox(height: 4),
              Text(item.title),
              if (match.assignment.employer != null)
                Text('Employer: ${match.assignment.employer}'),
              Text('Coworkers: ${match.updatedCoworkers.join(', ')}'),
            ],
            if (match.status == CoworkerRosterMatchStatus.matched &&
                !match.assignment.sameRosterCodeVerified) ...[
              const SizedBox(height: 6),
              const Text(
                'Coworker codes are missing. Add one code per name in Smart Import before applying this roster.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.text,
    this.warning = false,
  });

  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: warning ? Theme.of(context).colorScheme.error : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}
