import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dependencies.dart';
import '../../data/schedule_import_history_repository.dart';
import '../design/studyshift_spacing.dart';

class ScheduleImportHistoryPage extends ConsumerWidget {
  const ScheduleImportHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(scheduleImportHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Import history')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(StudyShiftSpacing.pageMargin),
            child: Text('Import history is unavailable: $error'),
          ),
        ),
        data: (entries) => ListView(
          padding: const EdgeInsets.all(StudyShiftSpacing.pageMargin),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(StudyShiftSpacing.cardPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: StudyShiftSpacing.x3),
                    Expanded(
                      child: Text(
                        'This history stores only source type, date, parser version and counts. It does not store the selected file name, path or contents. Only the ${ScheduleImportHistoryRepository.retainedEntryLimit} most recent summaries are kept.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: StudyShiftSpacing.x3),
            if (entries.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(StudyShiftSpacing.x6),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 38,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: StudyShiftSpacing.x3),
                      Text(
                        'No accepted imports yet',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: StudyShiftSpacing.x1),
                      Text(
                        'After you review and confirm an import, its summary will appear here.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Text(
                '${entries.length} recent ${entries.length == 1 ? 'import' : 'imports'}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: StudyShiftSpacing.x2),
              for (final entry in entries) ...[
                _ImportHistoryCard(entry: entry),
                const SizedBox(height: StudyShiftSpacing.x2),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ImportHistoryCard extends StatelessWidget {
  const _ImportHistoryCard({required this.entry});

  final ScheduleImportHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final local = entry.importedAt.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(StudyShiftSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.file_present_outlined, color: colors.primary),
                const SizedBox(width: StudyShiftSpacing.x2),
                Expanded(
                  child: Text(
                    '${entry.sourceType.label} import',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  'Parser ${entry.parserVersion}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: StudyShiftSpacing.x1),
            Text(
              '$date · $time',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: StudyShiftSpacing.x3),
            Wrap(
              spacing: StudyShiftSpacing.x2,
              runSpacing: StudyShiftSpacing.x2,
              children: [
                _ImportCount(label: 'Proposed', count: entry.proposedCount),
                _ImportCount(label: 'Accepted', count: entry.acceptedCount),
                _ImportCount(label: 'Rejected', count: entry.rejectedCount),
                _ImportCount(label: 'Skipped', count: entry.skippedCount),
                _ImportCount(label: 'Warnings', count: entry.warningsCount),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportCount extends StatelessWidget {
  const _ImportCount({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) =>
      Chip(label: Text('$label $count'), visualDensity: VisualDensity.compact);
}
