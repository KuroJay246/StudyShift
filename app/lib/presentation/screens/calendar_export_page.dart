import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ics_schedule_export.dart';
import '../../domain/schedule_engine.dart';
import '../../application/dependencies.dart';
import '../../platform/schedule_export_file_bridge.dart';
import '../design/studyshift_spacing.dart';

class CalendarExportPage extends ConsumerStatefulWidget {
  const CalendarExportPage({super.key});

  @override
  ConsumerState<CalendarExportPage> createState() => _CalendarExportPageState();
}

class _CalendarExportPageState extends ConsumerState<CalendarExportPage> {
  bool _working = false;

  Future<void> _export() async {
    setState(() => _working = true);
    try {
      final items = await ref.read(scheduleRepositoryProvider).getItems();
      final now = DateTime.now();
      final bytes = const IcsScheduleExport(ScheduleEngine())
          .encode(items, now: now);
      final saved = await const ScheduleExportFileBridge().save(
        bytes,
        fileName:
            'shift-study-${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.ics',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved ? 'Calendar file saved.' : 'Calendar export cancelled.',
            ),
          ),
        );
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message.toString())));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calendar export could not be completed.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Export calendar')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(
        StudyShiftSpacing.pageMargin,
        StudyShiftSpacing.pageMargin,
        StudyShiftSpacing.pageMargin,
        StudyShiftSpacing.x8,
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(StudyShiftSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.event_available_outlined,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Take your schedule with you',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Save a standard .ics calendar file to a location you choose. One-time events are included; weekly series are expanded from today through the next 12 months. Split shifts are exported as separate labelled intervals.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Timed entries use their saved time-zone rules to preserve the exact event instant. Entries with unresolved times must be corrected before export.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _working ? null : _export,
          icon: _working
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_download_outlined),
          label: Text(_working ? 'Preparing calendar…' : 'Save .ics file'),
        ),
      ],
    ),
  );
}
