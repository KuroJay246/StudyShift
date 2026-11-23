import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dependencies.dart';
import '../../domain/schedule.dart';
import '../../domain/schedule_engine.dart';
import '../../domain/work_overtime.dart';
import '../../platform/clock_alarm_bridge.dart';
import '../../platform/local_reminders.dart';
import '../schedule_format.dart';
import '../screens/event_editor_page.dart';
import 'device_calendar_action.dart';
import 'clock_alarm_action.dart';
import 'shift_icon.dart';

Future<void> showScheduleDetails(
  BuildContext context,
  WidgetRef ref,
  ScheduleItem item, {
  CivilDate? occurrenceDate,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) =>
      _ScheduleDetailsSheet(item: item, occurrenceDate: occurrenceDate),
);

class _ScheduleDetailsSheet extends ConsumerWidget {
  const _ScheduleDetailsSheet({required this.item, this.occurrenceDate});
  final ScheduleItem item;
  final CivilDate? occurrenceDate;

  Future<void> _editOvertimeHours(
    BuildContext context,
    WidgetRef ref,
    ScheduleItem shift,
    CivilDate date,
    int currentMinutes,
  ) async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) =>
          _OvertimeHoursDialog(initialMinutes: currentMinutes),
    );
    if (minutes == null || !context.mounted) return;
    try {
      final repository = ref.read(workOvertimeRepositoryProvider);
      if (minutes == 0) {
        await repository.clearForOccurrence(shift.id, date);
      } else {
        await repository.setForOccurrence(shift, date, minutes);
      }
      ref.invalidate(workOvertimeAdjustmentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              minutes == 0
                  ? 'Overtime hours cleared'
                  : 'Overtime hours saved for this shift',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save overtime hours: $error')),
        );
      }
    }
  }

  Future<void> _setOccurrenceCancelled(
    BuildContext context,
    WidgetRef ref,
    ScheduleItem sourceItem,
    CivilDate date,
    bool cancelled,
  ) async {
    final recurrence = sourceItem.recurrence;
    if (recurrence == null) return;
    final exceptions = {...recurrence.exceptionDates};
    final changed = cancelled ? exceptions.add(date) : exceptions.remove(date);
    if (!changed) return;
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .save(
            ScheduleItem(
              id: sourceItem.id,
              kind: sourceItem.kind,
              title: sourceItem.title,
              startDate: sourceItem.startDate,
              intervals: sourceItem.intervals,
              timeZoneId: sourceItem.timeZoneId,
              code: sourceItem.code,
              employerName: sourceItem.employerName,
              codeMeaning: sourceItem.codeMeaning,
              location: sourceItem.location,
              notes: sourceItem.notes,
              reportingInstruction: sourceItem.reportingInstruction,
              supervisorName: sourceItem.supervisorName,
              supervisorPhone: sourceItem.supervisorPhone,
              contactName: sourceItem.contactName,
              contactPhone: sourceItem.contactPhone,
              coworkers: sourceItem.coworkers,
              workCategory: sourceItem.workCategory,
              deadlineType: sourceItem.deadlineType,
              allDay: sourceItem.allDay,
              importProvenance: sourceItem.importProvenance,
              recurrence: WeeklyRecurrence(
                weekdays: recurrence.weekdays,
                until: recurrence.until,
                exceptionDates: exceptions,
              ),
            ),
          );
      ref.invalidate(scheduleItemsProvider);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cancelled ? 'Occurrence skipped' : 'Occurrence restored',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update occurrence: $error')),
        );
      }
    }
  }

  Future<void> _toggleOccurrence(
    BuildContext context,
    WidgetRef ref,
    ScheduleItem sourceItem,
  ) async {
    final date = occurrenceDate;
    if (date == null || sourceItem.recurrence == null) return;
    await _setOccurrenceCancelled(
      context,
      ref,
      sourceItem,
      date,
      !sourceItem.recurrence!.exceptionDates.contains(date),
    );
  }

  Future<void> _toggleCompletion(
    BuildContext context,
    WidgetRef ref,
    ScheduleItem sourceItem,
  ) async {
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .save(sourceItem.copyWith(isCompleted: !sourceItem.isCompleted));
      ref.invalidate(scheduleItemsProvider);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sourceItem.isCompleted
                  ? 'Marked not completed'
                  : 'Deadline completed',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update completion: $error')),
        );
      }
    }
  }

  Future<void> _finishShift(
    BuildContext context,
    WidgetRef ref,
    ScheduleItem sourceItem,
  ) async {
    final overtime = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shift wrap-up'),
        content: const Text('Did you work overtime on this shift?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No overtime'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Overtime'),
          ),
        ],
      ),
    );
    if (!context.mounted || overtime == null) return;
    List<EventInterval> actualIntervals = sourceItem.intervals;
    if (overtime) {
      final plannedEnd = sourceItem.intervals.last;
      final selectedEnd = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: (plannedEnd.endMinute ~/ 60) % 24,
          minute: plannedEnd.endMinute % 60,
        ),
        helpText: 'Enter your actual shift finish time',
      );
      if (!context.mounted) return;
      if (selectedEnd == null) return;
      actualIntervals = intervalsWithOvertimeEnd(
        sourceItem.intervals,
        selectedEnd.hour * 60 + selectedEnd.minute,
      );
    }
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .save(
            sourceItem.copyWith(
              isCompleted: true,
              actualIntervals: actualIntervals,
            ),
          );
      ref.invalidate(scheduleItemsProvider);
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            overtime ? 'Shift and overtime saved' : 'Shift completed',
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save shift wrap-up: $error')),
        );
      }
    }
  }

  Future<void> _undoShiftWrapUp(
    BuildContext context,
    WidgetRef ref,
    ScheduleItem sourceItem,
  ) async {
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .save(sourceItem.copyWith(isCompleted: false, actualIntervals: null));
      ref.invalidate(scheduleItemsProvider);
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Shift wrap-up cleared')));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not clear shift wrap-up: $error')),
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ScheduleItem sourceItem,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: Text(
          sourceItem.recurrence == null
              ? 'Delete this event?'
              : 'Delete this repeating event?',
        ),
        content: Text(
          sourceItem.recurrence == null
              ? '“${sourceItem.title}” will be removed from your schedule.'
              : '“${sourceItem.title}” and all of its weekly occurrences will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep event'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(scheduleRepositoryProvider).delete(sourceItem.id);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Event deleted')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete event: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedItems = ref.watch(scheduleItemsProvider).asData?.value;
    var detailItem = item;
    for (final savedItem in savedItems ?? const <ScheduleItem>[]) {
      if (savedItem.id == item.id) {
        detailItem = savedItem;
        break;
      }
    }
    final preferences = ref.watch(appPreferencesProvider).value;
    final use24Hour = preferenceUses24Hour(preferences, context);
    final localizations = MaterialLocalizations.of(context);
    final actualFinish = detailItem.actualIntervals?.last;
    final actualFinishDate = actualFinish == null
        ? null
        : detailItem.startDate.addDays(actualFinish.endDayOffset);
    final actualFinishDateLabel =
        actualFinishDate == null || actualFinishDate == detailItem.startDate
        ? ''
        : ' · ${localizations.formatMediumDate(DateTime(actualFinishDate.year, actualFinishDate.month, actualFinishDate.day))}';
    final recurrence = detailItem.recurrence;
    final detailDate = recurrence == null
        ? detailItem.startDate
        : occurrenceDate ?? detailItem.startDate;
    final overtimeAdjustments =
        ref.watch(workOvertimeAdjustmentsProvider).asData?.value ??
        const <WorkOvertimeAdjustment>[];
    WorkOvertimeAdjustment? overtimeAdjustment;
    for (final adjustment in overtimeAdjustments) {
      if (adjustment.shiftItemId == detailItem.id &&
          adjustment.occurrenceDate == detailDate) {
        overtimeAdjustment = adjustment;
        break;
      }
    }
    final overtimeMinutes = overtimeAdjustment?.minutes ?? 0;
    final hoursSummary = detailItem.workCategory == WorkCategory.shift
        ? WorkHoursSummary.forIntervals(
            intervals: overtimeMinutes > 0
                ? detailItem.intervals
                : detailItem.actualIntervals ?? detailItem.intervals,
            overtimeMinutes: overtimeMinutes,
          )
        : null;
    final startDate = DateTime(
      detailDate.year,
      detailDate.month,
      detailDate.day,
    );
    final timeResolution = ref
        .read(scheduleQueriesProvider)
        .resolveOccurrence(EventOccurrence(item: detailItem, date: detailDate));
    final timeIssues = timeResolution.issues
        .where((issue) => issue.kind != ScheduleTimeIssueKind.missingTimeZone)
        .toList(growable: false);
    final canFinishShift =
        detailItem.isCompleted ||
        (timeResolution.intervals.isNotEmpty &&
            !timeResolution.intervals.first.start.isAfter(DateTime.now()));
    final canAddToDeviceCalendar =
        detailItem.hasNoTime ||
        (detailItem.timeZoneId != null &&
            timeResolution.issues.isEmpty &&
            timeResolution.intervals.length == detailItem.intervals.length);
    ResolvedInterval? nextClockAlarm;
    if (!detailItem.hasNoTime) {
      for (final interval in timeResolution.intervals) {
        if (canOfferClockAlarm(interval.start)) {
          nextClockAlarm = interval;
          break;
        }
      }
    }
    final occurrenceSkipped =
        occurrenceDate != null &&
        (recurrence?.exceptionDates.contains(occurrenceDate) ?? false);
    final weekdays = recurrence == null
        ? null
        : (recurrence.weekdays.toList()..sort());
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          4,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                detailItem.title,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ShiftIcon(scheduleKindIconAsset(detailItem.kind), size: 18),
                  const SizedBox(width: 8),
                  Text(scheduleKindName(detailItem.kind)),
                ],
              ),
              if (detailItem.workCategory != null)
                _DetailRow(
                  icon: Icons.badge_outlined,
                  text: workCategoryName(detailItem.workCategory!),
                ),
              if (detailItem.employerName?.isNotEmpty ?? false)
                _DetailRow(
                  icon: Icons.business_outlined,
                  text: detailItem.employerName!,
                ),
              if (detailItem.deadlineType != null)
                _DetailRow(
                  icon: Icons.flag_outlined,
                  text: deadlineTypeName(detailItem.deadlineType!),
                ),
              if (detailItem.supportsCompletionTracking)
                _DetailRow(
                  icon: detailItem.isCompleted
                      ? Icons.check_circle_outline_rounded
                      : Icons.radio_button_unchecked_rounded,
                  text: detailItem.isCompleted ? 'Completed' : 'Not completed',
                ),
              if (detailItem.isCompleted &&
                  actualFinish != null &&
                  detailItem.kind == ScheduleKind.work)
                _DetailRow(
                  icon: Icons.more_time_rounded,
                  text:
                      'Actual finish: ${formatMinute(actualFinish.endMinute, use24Hour: use24Hour)}$actualFinishDateLabel',
                ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                text: localizations.formatMediumDate(startDate),
              ),
              if (detailItem.timeZoneId == null)
                const _DetailRow(
                  icon: Icons.public_off_outlined,
                  text: 'Time zone not saved. Edit this event to review or set one.',
                ),
              if (timeIssues.isNotEmpty) ...[
                const SizedBox(height: 10),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Time needs review',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (final issue in timeIssues)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              _timeIssueMessage(issue),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                            ),
                          ),
                        if (recurrence != null && occurrenceDate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Change the series time for every week, or skip this date to leave the other occurrences unchanged.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              if (detailItem.hasNoTime)
                _DetailRow(icon: Icons.weekend_outlined, text: 'All day')
              else
                for (var i = 0; i < detailItem.intervals.length; i++)
                  _DetailRow(
                    icon: Icons.schedule_rounded,
                    text:
                        '${detailItem.intervals.length > 1 ? 'Part ${i + 1}: ' : ''}${formatInterval(detailItem.intervals[i], use24Hour: use24Hour)}',
                  ),
              if (detailItem.supportsCompletionTracking) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: detailItem.kind == ScheduleKind.deadline
                            ? () => _toggleCompletion(context, ref, detailItem)
                            : detailItem.isCompleted
                            ? () => _undoShiftWrapUp(context, ref, detailItem)
                            : canFinishShift
                            ? () => _finishShift(context, ref, detailItem)
                            : null,
                        icon: Icon(
                          detailItem.isCompleted
                              ? Icons.undo_rounded
                              : Icons.check_rounded,
                        ),
                        label: Text(
                          detailItem.isCompleted
                              ? 'Undo'
                              : detailItem.kind == ScheduleKind.deadline
                              ? 'Complete'
                              : 'Finish shift',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _delete(context, ref, detailItem),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
                if (detailItem.kind == ScheduleKind.work &&
                    !detailItem.isCompleted &&
                    !canFinishShift) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Available after the shift starts.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ] else ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _delete(context, ref, detailItem),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
                ),
              ],
              if (hoursSummary != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shift hours',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scheduled ${_hoursText(hoursSummary.scheduledMinutes)}'
                          '  ·  Extra ${_hoursText(hoursSummary.overtimeMinutes)}'
                          '  ·  Total ${_hoursText(hoursSummary.totalMinutes)}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Premium-eligible after 8h: '
                          '${_hoursText(hoursSummary.premiumEligibleMinutes)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _editOvertimeHours(
                              context,
                              ref,
                              detailItem,
                              detailDate,
                              overtimeMinutes,
                            ),
                            icon: const Icon(Icons.more_time_rounded),
                            label: Text(
                              overtimeMinutes == 0
                                  ? 'Add overtime hours'
                                  : 'Edit overtime hours',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => EventEditorPage(
                        kind: detailItem.kind,
                        existing: detailItem,
                      ),
                    ),
                  ),
                  icon: const ShiftIcon('square-pen'),
                  label: Text(
                    recurrence == null ? 'Edit event' : 'Edit series',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (defaultTargetPlatform == TargetPlatform.android &&
                  canAddToDeviceCalendar &&
                  !occurrenceSkipped) ...[
                const SizedBox(height: 14),
                DeviceCalendarAction(
                  item: detailItem,
                  occurrenceDate: detailDate,
                  resolvedIntervals: timeResolution.intervals,
                  use24Hour: use24Hour,
                ),
              ],
              if (defaultTargetPlatform == TargetPlatform.android &&
                  nextClockAlarm != null) ...[
                const SizedBox(height: 10),
                ClockAlarmAction(
                  eventStart: nextClockAlarm.start,
                  label: detailItem.title,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Opens a one-time alarm draft for the next 24 hours. Confirm it in your Clock app.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              if (detailItem.reminderMinutesBefore case final minutes?)
                _DetailRow(
                  icon: Icons.notifications_active_outlined,
                  text: reminderOffsetLabel(minutes),
                ),
              if (detailItem.code?.isNotEmpty ?? false)
                _DetailRow(
                  icon: Icons.sell_outlined,
                  text: switch (detailItem.kind) {
                    ScheduleKind.work => 'Roster code: ${detailItem.code!}',
                    ScheduleKind.classSession ||
                    ScheduleKind.deadline => 'Course code: ${detailItem.code!}',
                    ScheduleKind.personal => 'Code: ${detailItem.code!}',
                  },
                ),
              if (detailItem.codeMeaning?.isNotEmpty ?? false)
                _DetailRow(
                  icon: Icons.menu_book_outlined,
                  text: detailItem.codeMeaning!,
                ),
              if (detailItem.location?.isNotEmpty ?? false)
                _DetailRow(
                  icon: Icons.place_outlined,
                  text: detailItem.location!,
                ),
              if (detailItem.timeZoneId?.isNotEmpty ?? false)
                _DetailRow(
                  icon: Icons.public_rounded,
                  text: detailItem.timeZoneId!,
                ),
              if (recurrence != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                _DetailRow(
                  icon: Icons.repeat_rounded,
                  text:
                      'Repeats ${weekdays!.map((day) => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1]).join(', ')}${recurrence.until == null ? '' : ' until ${localizations.formatMediumDate(DateTime(recurrence.until!.year, recurrence.until!.month, recurrence.until!.day))}'}',
                ),
                if (recurrence.exceptionDates.isNotEmpty)
                  _DetailRow(
                    icon: Icons.event_busy_outlined,
                    text:
                        '${recurrence.exceptionDates.length} cancelled ${recurrence.exceptionDates.length == 1 ? 'date' : 'dates'}',
                  ),
                if (recurrence.exceptionDates.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 4),
                    child: Text(
                      (recurrence.exceptionDates.toList()..sort())
                          .map(
                            (date) => localizations.formatShortDate(
                              DateTime(date.year, date.month, date.day),
                            ),
                          )
                          .join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                for (final cancelledDate
                    in (recurrence.exceptionDates.toList()..sort()))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _setOccurrenceCancelled(
                        context,
                        ref,
                        detailItem,
                        cancelledDate,
                        false,
                      ),
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(
                        'Restore ${localizations.formatShortDate(DateTime(cancelledDate.year, cancelledDate.month, cancelledDate.day))}',
                      ),
                    ),
                  ),
              ],
              if (detailItem.notes?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                const Divider(),
                Text(
                  'Notes',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(detailItem.notes!),
              ],
              if (detailItem.codeMeaning?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                const Divider(),
                Text(
                  'Code assignment / flights',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(detailItem.codeMeaning!),
              ],
              if (detailItem.reportingInstruction?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                const Divider(),
                Text(
                  'Reporting instructions',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(detailItem.reportingInstruction!),
              ],
              if (detailItem.departmentName?.isNotEmpty ?? false)
                _DetailRow(
                  icon: Icons.apartment_outlined,
                  text: 'Department or team: ${detailItem.departmentName}',
                ),
              if (detailItem.jobRole?.isNotEmpty ?? false)
                _DetailRow(
                  icon: Icons.work_outline_rounded,
                  text: 'Job role: ${detailItem.jobRole}',
                ),
              if (detailItem.supervisorName?.isNotEmpty ?? false)
                _DetailRow(
                  icon: Icons.badge_outlined,
                  text: 'Supervisor: ${detailItem.supervisorName}',
                ),
              if (detailItem.supervisorPhone?.isNotEmpty ?? false)
                _DetailRow(
                  icon: Icons.phone_outlined,
                  text: 'Supervisor phone: ${detailItem.supervisorPhone}',
                ),
              if (detailItem.contactName?.isNotEmpty ?? false)
                _DetailRow(
                  icon: Icons.support_agent_outlined,
                  text: 'Shift contact: ${detailItem.contactName}',
                ),
              if (detailItem.contactPhone?.isNotEmpty ?? false)
                _DetailRow(
                  icon: Icons.phone_outlined,
                  text: 'Contact phone: ${detailItem.contactPhone}',
                ),
              if (detailItem.coworkers.isNotEmpty)
                _DetailRow(
                  icon: Icons.groups_outlined,
                  text: 'Working with: ${detailItem.coworkers.join(', ')}',
                ),
              if (detailItem.importProvenance case final provenance?) ...[
                const SizedBox(height: 12),
                const Divider(),
                _DetailRow(
                  icon: Icons.file_open_outlined,
                  text: 'Imported from ${provenance.sourceName}',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Original calendar entry'),
                        content: SizedBox(
                          width: 520,
                          child: SingleChildScrollView(
                            child: SelectableText(provenance.sourceText),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('View original source'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (recurrence != null && occurrenceDate != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _toggleOccurrence(context, ref, detailItem),
                    icon: Icon(
                      occurrenceSkipped
                          ? Icons.event_available_outlined
                          : Icons.event_busy_outlined,
                    ),
                    label: Text(
                      occurrenceSkipped
                          ? 'Restore this occurrence'
                          : 'Skip this occurrence',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _timeIssueMessage(ScheduleTimeIssue issue) {
  final part = issue.intervalIndex < 0
      ? ''
      : 'Part ${issue.intervalIndex + 1}: ';
  return switch (issue.kind) {
    ScheduleTimeIssueKind.ambiguousStart =>
      '${part}the start time occurs twice on this date. Choose earlier or later in the event editor.',
    ScheduleTimeIssueKind.ambiguousEnd =>
      '${part}the end time occurs twice on this date. Choose earlier or later in the event editor.',
    ScheduleTimeIssueKind.nonexistentStart =>
      '${part}the start time falls in a daylight-saving clock gap on this date.',
    ScheduleTimeIssueKind.nonexistentEnd =>
      '${part}the end time falls in a daylight-saving clock gap on this date.',
    ScheduleTimeIssueKind.invalidTimeZone => 'The saved time zone is not recognized. Edit this event and choose a valid time zone.',
    ScheduleTimeIssueKind.invalidResolvedInterval =>
      '${part}the resolved end is not after the start. Edit the event times.',
    ScheduleTimeIssueKind.missingTimeZone => 'This older event has no saved time zone. Edit it and choose a time zone.',
  };
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _OvertimeHoursDialog extends StatefulWidget {
  const _OvertimeHoursDialog({required this.initialMinutes});

  final int initialMinutes;

  @override
  State<_OvertimeHoursDialog> createState() => _OvertimeHoursDialogState();
}

class _OvertimeHoursDialogState extends State<_OvertimeHoursDialog> {
  late final _controller = TextEditingController(
    text: widget.initialMinutes == 0
        ? ''
        : (widget.initialMinutes / 60).toStringAsFixed(
            widget.initialMinutes % 60 == 0 ? 0 : 2,
          ),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null || parsed <= 0 || parsed > 24) {
      setState(() => _error = 'Enter a total from 0.01 to 24 hours.');
      return;
    }
    final minutes = (parsed * 60).round();
    if (minutes < 1 || minutes > 24 * 60) {
      setState(() => _error = 'Enter a total from 0.01 to 24 hours.');
      return;
    }
    Navigator.pop(context, minutes);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Log overtime hours'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Total extra hours for this shift'),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: 'hours',
            hintText: 'e.g. 1.5',
            errorText: _error,
          ),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 8),
        Text(
          'Count all extra time for the shift, including time worked during a split gap. This does not change the shift times.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      if (widget.initialMinutes > 0)
        TextButton(
          onPressed: () => Navigator.pop(context, 0),
          child: const Text('Clear'),
        ),
      FilledButton(onPressed: _save, child: const Text('Save hours')),
    ],
  );
}

String _hoursText(int minutes) =>
    '${(minutes / 60).toStringAsFixed(minutes % 60 == 0 ? 0 : 1)}h';
