import 'package:flutter/material.dart';

import '../../domain/schedule.dart';
import '../../platform/device_calendar_bridge.dart';
import '../schedule_format.dart';

class DeviceCalendarAction extends StatelessWidget {
  const DeviceCalendarAction({
    super.key,
    required this.item,
    required this.occurrenceDate,
    required this.resolvedIntervals,
    required this.use24Hour,
  });

  final ScheduleItem item;
  final CivilDate occurrenceDate;
  final List<ResolvedInterval> resolvedIntervals;
  final bool use24Hour;

  Future<void> _add(BuildContext context) async {
    var intervalIndex = 0;
    if (!item.hasNoTime && item.intervals.length > 1) {
      final selected = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text(
                  'Choose a shift interval',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (var index = 0; index < item.intervals.length; index++)
                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: Text('Part ${index + 1}'),
                  subtitle: Text(
                    formatInterval(item.intervals[index], use24Hour: use24Hour),
                  ),
                  onTap: () => Navigator.pop(context, index),
                ),
            ],
          ),
        ),
      );
      if (selected == null || !context.mounted) return;
      intervalIndex = selected;
    }

    final allDay = item.hasNoTime;
    final start = allDay
        ? DateTime.utc(
            occurrenceDate.year,
            occurrenceDate.month,
            occurrenceDate.day,
          )
        : resolvedIntervals[intervalIndex].start;
    final end = allDay
        ? DateTime.utc(
            occurrenceDate.year,
            occurrenceDate.month,
            occurrenceDate.day + 1,
          )
        : resolvedIntervals[intervalIndex].end;

    final details = <String>[
      'Added from StudyShift (${_categoryLabel(item)}).',
      if (item.code?.trim().isNotEmpty ?? false) 'Code: ${item.code!.trim()}',
      if (item.recurrence != null) 'This is one occurrence of a repeating schedule item; the full series was not copied.',
      if (item.notes?.trim().isNotEmpty ?? false) item.notes!.trim(),
    ].join('\n\n');

    try {
      final opened = await const DeviceCalendarBridge().openDraft(
        title: item.title,
        startMillis: start.millisecondsSinceEpoch,
        endMillis: end.millisecondsSinceEpoch,
        allDay: allDay,
        location: item.location,
        description: details,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened ? 'Review and save this draft in your calendar app.' : 'No calendar app can create an event. Use Export calendar to save an .ics file.',
          ),
        ),
      );
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open a calendar app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () => _add(context),
      icon: const Icon(Icons.event_available_outlined),
      label: const Text('Add to device calendar'),
    ),
  );
}

String _categoryLabel(ScheduleItem item) => switch (item.kind) {
  ScheduleKind.work => workCategoryName(item.workCategory!),
  ScheduleKind.classSession => 'Class',
  ScheduleKind.personal => 'Personal event',
  ScheduleKind.deadline => deadlineTypeName(item.deadlineType!),
};
