import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;

import '../../domain/schedule.dart';
import '../app_theme.dart';
import '../schedule_format.dart';
import 'schedule_event_tile.dart';

typedef _TimedWeekBlock = ({EventOccurrence occurrence, int start, int end});

double weekDayColumnWidth(double viewportWidth) => viewportWidth < 700
    ? ((viewportWidth - 48) / 2).clamp(156.0, 260.0).toDouble()
    : ((viewportWidth - 48) / 7).clamp(96.0, 132.0).toDouble();

double weekGridHourHeight(double viewportHeight) =>
    viewportHeight < 500 ? 48.0 : 64.0;

double weekGridInitialScrollOffset({
  required int? firstScheduledMinute,
  double hourHeight = 64,
}) {
  // Keep an empty week useful from morning through evening. If there is a
  // scheduled event, show some context before its first interval.
  final minute = firstScheduledMinute ?? 7 * 60;
  return (minute / 60 * hourHeight - hourHeight).clamp(0, double.infinity);
}

class WeekGrid extends StatefulWidget {
  const WeekGrid({
    super.key,
    required this.weekStart,
    required this.focusDate,
    required this.occurrences,
    required this.conflictedIds,
    required this.use24Hour,
    required this.onSelect,
    this.onFocusDateChanged,
  });
  final CivilDate weekStart;
  final CivilDate focusDate;
  final List<EventOccurrence> occurrences;
  final Set<String> conflictedIds;
  final bool use24Hour;
  final ValueChanged<EventOccurrence> onSelect;
  final ValueChanged<CivilDate>? onFocusDateChanged;

  @override
  State<WeekGrid> createState() => _WeekGridState();
}

class _WeekGridState extends State<WeekGrid> {
  final _headerScrollController = ScrollController();
  final _gridScrollController = ScrollController();
  final _timeScrollController = ScrollController();
  bool _syncingScroll = false;

  List<EventOccurrence> _eventsForDay(CivilDate day) {
    final events = widget.occurrences.where((occurrence) {
      if (occurrence.item.hasNoTime) return occurrence.date == day;
      return occurrence.item.intervals.any((interval) {
        final start = occurrence.date.addDays(interval.startDayOffset);
        final end = occurrence.date.addDays(interval.endDayOffset);
        return day.compareTo(start) >= 0 &&
            (day.compareTo(end) < 0 || (day == end && interval.endMinute > 0));
      });
    }).toList();
    int startMinute(EventOccurrence occurrence) {
      if (occurrence.item.hasNoTime) return -1;
      for (final interval in occurrence.item.intervals) {
        final start = occurrence.date.addDays(interval.startDayOffset);
        final end = occurrence.date.addDays(interval.endDayOffset);
        if (day.compareTo(start) >= 0 &&
            (day.compareTo(end) < 0 ||
                (day == end && interval.endMinute > 0))) {
          return day == start ? interval.startMinute : 0;
        }
      }
      return 1440;
    }

    events.sort(
      (first, second) => startMinute(first).compareTo(startMinute(second)),
    );
    return events;
  }

  void _showDayAgenda(BuildContext context, CivilDate day) {
    final onFocusDateChanged = widget.onFocusDateChanged;
    if (onFocusDateChanged != null) {
      onFocusDateChanged(day);
      return;
    }
    final events = _eventsForDay(day);
    final title = MaterialLocalizations.of(context)
        .formatFullDate(DateTime(day.year, day.month, day.day));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .68,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 8),
                Expanded(
                  child: events.isEmpty
                      ? Center(
                          child: Text(
                            'No events on this day',
                            style: Theme.of(sheetContext).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: events.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final occurrence = events[index];
                            return ScheduleEventTile(
                              item: occurrence.item,
                              use24Hour: widget.use24Hour,
                              conflict: widget.conflictedIds.contains(
                                occurrence.item.id,
                              ),
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                widget.onSelect(occurrence);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scheduleInitialPosition();
    _headerScrollController.addListener(_syncHeaderToGrid);
    _gridScrollController.addListener(_syncGridToHeader);
  }

  @override
  void didUpdateWidget(covariant WeekGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusDate != widget.focusDate ||
        oldWidget.occurrences != widget.occurrences) {
      _scheduleInitialPosition();
    }
  }

  void _scheduleInitialPosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_headerScrollController.hasClients &&
          _gridScrollController.hasClients) {
        const labelWidth = 48.0;
        final viewport = _gridScrollController.position.viewportDimension;
        final columnWidth = weekDayColumnWidth(viewport + labelWidth);
        final focusIndex =
            DateTime.utc(
                  widget.focusDate.year,
                  widget.focusDate.month,
                  widget.focusDate.day,
                )
                .difference(
                  DateTime.utc(
                    widget.weekStart.year,
                    widget.weekStart.month,
                    widget.weekStart.day,
                  ),
                )
                .inDays
                .clamp(0, 6);
        final horizontalOffset =
            (focusIndex * columnWidth - (viewport - columnWidth) / 2)
                .clamp(
                  _gridScrollController.position.minScrollExtent,
                  _gridScrollController.position.maxScrollExtent,
                )
                .toDouble();
        _syncingScroll = true;
        _headerScrollController.jumpTo(
          horizontalOffset
              .clamp(
                _headerScrollController.position.minScrollExtent,
                _headerScrollController.position.maxScrollExtent,
              )
              .toDouble(),
        );
        _gridScrollController.jumpTo(horizontalOffset);
        _syncingScroll = false;
      }
      if (!_timeScrollController.hasClients) return;
      final focusDayStarts = <int>[];
      for (final event in widget.occurrences) {
        if (event.item.hasNoTime) continue;
        for (final interval in event.item.intervals) {
          final startDate = event.date.addDays(interval.startDayOffset);
          final endDate = event.date.addDays(interval.endDayOffset);
          if (widget.focusDate.compareTo(startDate) >= 0 &&
              (widget.focusDate.compareTo(endDate) < 0 ||
                  (widget.focusDate == endDate && interval.endMinute > 0))) {
            focusDayStarts.add(
              widget.focusDate == startDate ? interval.startMinute : 0,
            );
          }
        }
      }
      final firstStart = focusDayStarts.isEmpty
          ? null
          : focusDayStarts.reduce((a, b) => a < b ? a : b);
      final hourHeight = weekGridHourHeight(MediaQuery.sizeOf(context).height);
      final position = _timeScrollController.position;
      final offset = weekGridInitialScrollOffset(
        firstScheduledMinute: firstStart,
        hourHeight: hourHeight,
      ).clamp(position.minScrollExtent, position.maxScrollExtent);
      _timeScrollController.jumpTo(offset.toDouble());
    });
  }

  @override
  void dispose() {
    _headerScrollController
      ..removeListener(_syncHeaderToGrid)
      ..dispose();
    _gridScrollController
      ..removeListener(_syncGridToHeader)
      ..dispose();
    _timeScrollController.dispose();
    super.dispose();
  }

  void _syncHeaderToGrid() =>
      _syncScroll(from: _headerScrollController, to: _gridScrollController);

  void _syncGridToHeader() =>
      _syncScroll(from: _gridScrollController, to: _headerScrollController);

  void _syncScroll({
    required ScrollController from,
    required ScrollController to,
  }) {
    if (_syncingScroll || !from.hasClients || !to.hasClients) return;
    final offset = from.offset.clamp(
      to.position.minScrollExtent,
      to.position.maxScrollExtent,
    );
    if ((to.offset - offset).abs() < 0.5) return;
    _syncingScroll = true;
    to.jumpTo(offset);
    _syncingScroll = false;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final labelWidth = MediaQuery.textScalerOf(context)
        .scale(48)
        .clamp(48.0, 104.0);
    final hourHeight = weekGridHourHeight(size.height);
    final dayHeaderHeight = MediaQuery.textScalerOf(context)
        .scale(72)
        .clamp(56.0, double.infinity);
    final days = [for (var i = 0; i < 7; i++) widget.weekStart.addDays(i)];
    final today = CivilDate.fromDateTime(DateTime.now());
    return LayoutBuilder(
      builder: (context, constraints) {
        final selectedDayView = widget.onFocusDateChanged != null;
        final width = selectedDayView
            ? (constraints.maxWidth - labelWidth) / 7
            : weekDayColumnWidth(constraints.maxWidth);
        final selectedDayWidth = constraints.maxWidth - labelWidth;
        final selectedDayEvents = _eventsForDay(widget.focusDate);
        final selectedDayAllDayEvents = selectedDayEvents
            .where((event) => event.item.hasNoTime)
            .toList(growable: false);
        return Column(
          children: [
            SizedBox(
              key: const Key('week-day-header'),
              height: dayHeaderHeight,
              child: Row(
                children: [
                  if (!selectedDayView) SizedBox(width: labelWidth),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      dragStartBehavior: DragStartBehavior.down,
                      physics: selectedDayView
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      controller: selectedDayView
                          ? null
                          : _headerScrollController,
                      key: const Key('week-day-header-scroll'),
                      child: SizedBox(
                        width: selectedDayView
                            ? constraints.maxWidth
                            : width * 7,
                        child: Row(
                          children: [
                            for (final day in days)
                              SizedBox(
                                width: width,
                                child: Semantics(
                                  key: ValueKey(
                                    'week-day-${day.year}-${day.month}-${day.day}',
                                  ),
                                  container: true,
                                  label: MaterialLocalizations.of(context)
                                      .formatFullDate(
                                        DateTime(day.year, day.month, day.day),
                                      ),
                                  selected: day == widget.focusDate,
                                  button: true,
                                  hint: day == today ? 'Today' : null,
                                  onTap: () => _showDayAgenda(context, day),
                                  child: ExcludeSemantics(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            onTap: () =>
                                                _showDayAgenda(context, day),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _dayLabel(
                                                    context,
                                                    day,
                                                    today,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Container(
                                                    constraints:
                                                        const BoxConstraints(
                                                          minWidth: 28,
                                                          minHeight: 28,
                                                        ),
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          day ==
                                                              widget.focusDate
                                                          ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                          : null,
                                                      shape: BoxShape.circle,
                                                      border:
                                                          day == today &&
                                                              day !=
                                                                  widget
                                                                      .focusDate
                                                          ? Border.all(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary,
                                                            )
                                                          : null,
                                                    ),
                                                    child: Text(
                                                      '${day.day}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                day ==
                                                                    widget
                                                                        .focusDate
                                                                ? Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .onPrimary
                                                                : null,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (selectedDayView)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${MaterialLocalizations.of(context).formatFullDate(DateTime(widget.focusDate.year, widget.focusDate.month, widget.focusDate.day))} · ${selectedDayEvents.length} ${selectedDayEvents.length == 1 ? 'event' : 'events'}',
                    key: const Key('week-selected-day-summary'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
            if (selectedDayView && selectedDayAllDayEvents.isNotEmpty)
              Padding(
                key: const Key('week-selected-day-all-day'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All day',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final occurrence in selectedDayAllDayEvents)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth - 32,
                              ),
                              child: Semantics(
                                button: true,
                                label:
                                    '${scheduleKindName(occurrence.item.kind)}: '
                                    '${occurrence.item.title}, '
                                    '${MaterialLocalizations.of(context).formatFullDate(DateTime(widget.focusDate.year, widget.focusDate.month, widget.focusDate.day))}, all day',
                                child: Material(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    key: ValueKey(
                                      'week-all-day-${occurrence.item.id}',
                                    ),
                                    onTap: () => widget.onSelect(occurrence),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        occurrence.item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelLarge,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: _timeScrollController,
                key: const Key('week-grid-time-scroll'),
                child: SizedBox(
                  width: double.infinity,
                  height: hourHeight * 24,
                  child: Row(
                    children: [
                      SizedBox(
                        width: labelWidth,
                        child: Stack(
                          children: [
                            for (var hour = 0; hour < 24; hour++)
                              Positioned(
                                top: hour * hourHeight,
                                left: 0,
                                right: 0,
                                child: Text(
                                  _hourLabel(hour),
                                  style: Theme.of(context).textTheme.labelSmall,
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: selectedDayView
                            ? SizedBox(
                                key: const Key('week-selected-day-timeline'),
                                width: selectedDayWidth,
                                height: hourHeight * 24,
                                child: Stack(
                                  children: [
                                    for (var hour = 0; hour <= 24; hour++)
                                      Positioned(
                                        top: hour * hourHeight - .5,
                                        left: 0,
                                        right: 0,
                                        child: Divider(
                                          height: 1,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outlineVariant,
                                        ),
                                      ),
                                    ..._dayBlocks(
                                      context,
                                      widget.focusDate,
                                      0,
                                      selectedDayWidth,
                                      hourHeight,
                                    ),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                dragStartBehavior: DragStartBehavior.down,
                                controller: _gridScrollController,
                                key: const Key('week-grid-horizontal-scroll'),
                                child: SizedBox(
                                  width: width * 7,
                                  height: hourHeight * 24,
                                  child: Stack(
                                    children: [
                                      for (var hour = 0; hour <= 24; hour++)
                                        Positioned(
                                          top: hour * hourHeight - .5,
                                          left: 0,
                                          right: 0,
                                          child: Divider(
                                            height: 1,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant,
                                          ),
                                        ),
                                      for (
                                        var dayIndex = 0;
                                        dayIndex < days.length;
                                        dayIndex++
                                      )
                                        ..._dayBlocks(
                                          context,
                                          days[dayIndex],
                                          dayIndex,
                                          width,
                                          hourHeight,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dayLabel(BuildContext context, CivilDate day, CivilDate today) {
    final weekday = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][day.weekday - 1];
    return Text(
      weekday,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: day == today ? Theme.of(context).colorScheme.primary : null,
        fontWeight: day == today ? FontWeight.w700 : null,
      ),
    );
  }

  List<Widget> _dayBlocks(
    BuildContext context,
    CivilDate day,
    int dayIndex,
    double columnWidth,
    double hourHeight,
  ) {
    final blocks = <_TimedWeekBlock>[];
    for (final occurrence in widget.occurrences.where(
      (entry) => entry.date.compareTo(day) <= 0,
    )) {
      if (occurrence.item.hasNoTime) continue;
      for (final interval in occurrence.item.intervals) {
        final startDate = occurrence.date.addDays(interval.startDayOffset);
        final endDate = occurrence.date.addDays(interval.endDayOffset);
        if (day.compareTo(startDate) < 0 || day.compareTo(endDate) > 0) {
          continue;
        }
        final start = day == startDate ? interval.startMinute : 0;
        final end = day == endDate ? interval.endMinute : 1440;
        if (end <= start) continue;
        blocks.add((occurrence: occurrence, start: start, end: end));
      }
    }
    blocks.sort((a, b) => a.start.compareTo(b.start));
    final groups = <List<_TimedWeekBlock>>[];
    for (final block in blocks) {
      if (groups.isNotEmpty &&
          block.start <
              groups.last.map((entry) => entry.end).reduce(math.max)) {
        groups.last.add(block);
      } else {
        groups.add([block]);
      }
    }
    return [
      for (final group in groups)
        if (group.length > 1)
          _overlapGroupCard(
            context,
            day,
            dayIndex,
            columnWidth,
            hourHeight,
            group,
          )
        else
          _singleEventBlock(
            context,
            day,
            dayIndex,
            columnWidth,
            hourHeight,
            group.single,
          ),
    ];
  }

  Widget _singleEventBlock(
    BuildContext context,
    CivilDate day,
    int dayIndex,
    double columnWidth,
    double hourHeight,
    _TimedWeekBlock block,
  ) {
    final occurrence = block.occurrence;
    final width = columnWidth - 7;
    final top = block.start / 60 * hourHeight;
    final height = ((block.end - block.start) / 60 * hourHeight).clamp(
      25.0,
      double.infinity,
    );
    final palette = Theme.of(context).extension<SchedulePalette>()!;
    final training = occurrence.item.workCategory == WorkCategory.training;
    final categoryColor = training
        ? palette.training
        : switch (occurrence.item.kind) {
            ScheduleKind.work => palette.work,
            ScheduleKind.classSession => palette.school,
            ScheduleKind.deadline => palette.deadline,
            _ => palette.personal,
          };
    final color = categoryColor.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? .24 : .10,
    );
    final ink = training
        ? palette.onTraining
        : switch (occurrence.item.kind) {
            ScheduleKind.work => palette.onWork,
            ScheduleKind.classSession => palette.onSchool,
            ScheduleKind.deadline => palette.onDeadline,
            _ => palette.onPersonal,
          };
    final dateLabel = MaterialLocalizations.of(context)
        .formatFullDate(DateTime(day.year, day.month, day.day));
    final startLabel = formatMinute(block.start, use24Hour: widget.use24Hour);
    final endLabel = formatMinute(
      block.end % 1440,
      use24Hour: widget.use24Hour,
    );
    return Positioned(
      left: dayIndex * columnWidth + 3,
      top: top + 2,
      width: width,
      height: height - 4,
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label:
            '${scheduleKindName(occurrence.item.kind)}: ${occurrence.item.title}, '
            '$dateLabel, $startLabel – $endLabel',
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => widget.onSelect(occurrence),
            borderRadius: BorderRadius.circular(10),
            child: height < 40
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        occurrence.item.title,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: ink,
                          fontSize: 9,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          occurrence.item.title,
                          maxLines: width < 104 ? 2 : 3,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: ink,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (height > 72)
                          Text(
                            width < 104 || columnWidth <= 124
                                ? '${_compactTime(block.start)}–${_compactTime(block.end % 1440)}'
                                : '$startLabel – $endLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: ink),
                          ),
                        if (widget.conflictedIds.contains(occurrence.item.id))
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: Theme.of(context).colorScheme.error,
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _overlapGroupCard(
    BuildContext context,
    CivilDate day,
    int dayIndex,
    double columnWidth,
    double hourHeight,
    List<_TimedWeekBlock> group,
  ) {
    final start = group
        .map((block) => block.start)
        .reduce((a, b) => a < b ? a : b);
    final end = group.map((block) => block.end).reduce((a, b) => a > b ? a : b);
    final top = start / 60 * hourHeight;
    final height = ((end - start) / 60 * hourHeight).clamp(
      40.0,
      double.infinity,
    );
    final colorScheme = Theme.of(context).colorScheme;
    final titles = group
        .map((block) => block.occurrence.item.title)
        .join(' · ');
    final eventTimes = MaterialLocalizations.of(context)
        .formatFullDate(DateTime(day.year, day.month, day.day));
    return Positioned(
      key: ValueKey('week-overlap-group-$day-${group.length}'),
      left: dayIndex * columnWidth + 3,
      top: top + 2,
      width: columnWidth - 7,
      height: height - 4,
      child: Semantics(
        button: true,
        label: '${group.length} overlapping events: $titles, $eventTimes',
        child: Material(
          color: colorScheme.errorContainer.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: colorScheme.error.withValues(alpha: 0.48)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            onTap: () => _showOverlapDetails(context, group),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${group.length} overlapping events',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (constraints.maxHeight >= 42)
                            Text(
                              titles,
                              maxLines: constraints.maxHeight >= 70 ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: colorScheme.onSurface),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colorScheme.error,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showOverlapDetails(BuildContext context, List<_TimedWeekBlock> group) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * .7;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${group.length} overlapping events',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Select an event to review its details.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: math.min(maxHeight, group.length * 76.0),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: group.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final block = group[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_outlined),
                        title: Text(block.occurrence.item.title),
                        subtitle: Text(
                          '${formatMinute(block.start, use24Hour: widget.use24Hour)} – '
                          '${formatMinute(block.end % 1440, use24Hour: widget.use24Hour)}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) widget.onSelect(block.occurrence);
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _hourLabel(int hour) =>
      '${hour % 12 == 0 ? 12 : hour % 12} ${hour < 12 ? 'AM' : 'PM'}';

  String _compactTime(int minute) {
    final normalized = minute % 1440;
    final hour = normalized ~/ 60;
    final minutes = normalized % 60;
    if (widget.use24Hour) {
      final shortHour = hour.toString().padLeft(2, '0');
      return minutes == 0
          ? shortHour
          : '$shortHour:${minutes.toString().padLeft(2, '0')}';
    }
    final shortHour = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour < 12 ? 'a' : 'p';
    return minutes == 0
        ? '$shortHour$suffix'
        : '$shortHour:${minutes.toString().padLeft(2, '0')}$suffix';
  }
}
