import 'package:flutter/material.dart';

import '../../domain/schedule.dart';
import '../app_theme.dart';
import '../motion.dart';
import '../schedule_format.dart';
import 'shift_icon.dart';

class ScheduleEventTile extends StatefulWidget {
  const ScheduleEventTile({
    super.key,
    required this.item,
    required this.use24Hour,
    required this.onTap,
    this.conflict = false,
    this.reviewTime = false,
    this.dateLabel,
    this.countdownLabel,
    this.statusLabel,
    this.workHoursLabel,
    this.staggerIndex = 0,
    this.showExtendedWorkDetails = false,
  });

  final ScheduleItem item;
  final bool use24Hour;
  final bool conflict;
  final bool reviewTime;
  final String? dateLabel;
  final String? countdownLabel;
  final String? statusLabel;
  final String? workHoursLabel;
  final int staggerIndex;
  final bool showExtendedWorkDetails;
  final VoidCallback onTap;

  @override
  State<ScheduleEventTile> createState() => _ScheduleEventTileState();
}

class _ScheduleEventTileState extends State<ScheduleEventTile> {
  bool _pressed = false;
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    if (widget.staggerIndex == 0) {
      _entered = true;
    } else {
      final stagger = widget.staggerIndex < AppMotion.maxStaggerRows
          ? widget.staggerIndex
          : AppMotion.maxStaggerRows;
      Future<void>.delayed(AppMotion.staggerStep * stagger, () {
        if (mounted) setState(() => _entered = true);
      });
    }
  }

  Color _categoryColor(BuildContext context) {
    final palette = Theme.of(context).extension<SchedulePalette>()!;
    if (widget.item.workCategory == WorkCategory.training) {
      return palette.training;
    }
    return switch (widget.item.kind) {
      ScheduleKind.work => palette.work,
      ScheduleKind.classSession => palette.school,
      ScheduleKind.deadline => palette.deadline,
      ScheduleKind.personal => palette.personal,
    };
  }

  Color _categoryInk(BuildContext context) {
    final palette = Theme.of(context).extension<SchedulePalette>()!;
    if (widget.item.workCategory == WorkCategory.training) {
      return palette.onTraining;
    }
    return switch (widget.item.kind) {
      ScheduleKind.work => palette.onWork,
      ScheduleKind.classSession => palette.onSchool,
      ScheduleKind.deadline => palette.onDeadline,
      ScheduleKind.personal => palette.onPersonal,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = _categoryColor(context);
    final categoryInk = _categoryInk(context);
    final contextLabel = scheduleItemContextLabel(widget.item);
    final code = widget.item.code?.trim();
    final reportingInstruction = widget.item.kind == ScheduleKind.work
        ? widget.item.reportingInstruction?.trim()
        : null;
    final codeLabel = switch (widget.item.kind) {
      ScheduleKind.work => 'roster code',
      ScheduleKind.classSession || ScheduleKind.deadline => 'course code',
      ScheduleKind.personal => 'code',
    };
    final codeDisplay = switch (widget.item.kind) {
      ScheduleKind.classSession ||
      ScheduleKind.deadline => 'Course code: $code',
      _ => code,
    };
    final codeMeaning = widget.item.kind == ScheduleKind.work
        ? widget.item.codeMeaning?.trim()
        : null;
    final compactWork =
        widget.item.kind == ScheduleKind.work &&
        !widget.showExtendedWorkDetails;
    final timeText = widget.item.hasNoTime
        ? widget.item.workCategory != null
              ? '${workCategoryName(widget.item.workCategory!)} · all day'
              : '${deadlineTypeName(widget.item.deadlineType!)} · due this day'
        : widget.reviewTime
        ? 'Time needs review'
        : widget.item.intervals
              .map(
                (interval) =>
                    formatInterval(interval, use24Hour: widget.use24Hour),
              )
              .join(' · ');
    final semanticsLabel = <String>[
      '${scheduleKindName(widget.item.kind)}: ${widget.item.title}',
      if (widget.statusLabel != null) widget.statusLabel!,
      contextLabel,
      if (code?.isNotEmpty == true) '$codeLabel $code',
      if (codeMeaning?.isNotEmpty == true) 'code assignment $codeMeaning',
      timeText,
      if (widget.workHoursLabel != null) widget.workHoursLabel!,
      if (widget.item.kind == ScheduleKind.deadline)
        widget.item.isCompleted ? 'Completed' : 'Not completed',
      if (widget.countdownLabel != null) widget.countdownLabel!,
      if (widget.item.location?.isNotEmpty == true) widget.item.location!,
      if (reportingInstruction?.isNotEmpty == true)
        'reporting instructions: $reportingInstruction',
      if (widget.conflict) 'Schedule conflict',
      if (widget.dateLabel != null) widget.dateLabel!,
    ].join(', ');
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedOpacity(
      opacity: _entered || reduceMotion ? 1 : 0,
      duration: AppMotion.duration(context, AppMotion.entrance),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _entered || reduceMotion ? Offset.zero : const Offset(0, .04),
        duration: AppMotion.duration(context, AppMotion.entrance),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: _pressed && !MediaQuery.disableAnimationsOf(context) ? .97 : 1,
          duration: Duration(milliseconds: _pressed ? 110 : 150),
          curve: Curves.easeOutCubic,
          child: Card(
            color: theme.colorScheme.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              button: true,
              label: semanticsLabel,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: categoryColor, width: 4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            alignment: Alignment.center,
                            child: IconTheme(
                              data: IconThemeData(color: categoryInk),
                              child: ShiftIcon(
                                scheduleKindIconAsset(widget.item.kind),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.statusLabel != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    widget.statusLabel!,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.item.title,
                                      maxLines: compactWork ? 1 : 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: categoryInk,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  if (widget.conflict) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: theme.colorScheme.error,
                                      semanticLabel: 'Schedule conflict',
                                    ),
                                  ],
                                ],
                              ),
                              if (widget.item.kind ==
                                  ScheduleKind.deadline) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(
                                      widget.item.isCompleted
                                          ? Icons.check_circle_rounded
                                          : Icons
                                                .radio_button_unchecked_rounded,
                                      size: 16,
                                      color: widget.item.isCompleted
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      widget.item.isCompleted
                                          ? 'Completed'
                                          : 'Not completed',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                              if (widget.countdownLabel != null) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.hourglass_bottom_rounded,
                                      size: 15,
                                      color: categoryInk,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      widget.countdownLabel!,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: categoryInk,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                              if (compactWork) ...[
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (code?.isNotEmpty == true &&
                                        !widget.item.title
                                            .toLowerCase()
                                            .contains(code!.toLowerCase()))
                                      code,
                                    if (widget.dateLabel != null)
                                      widget.dateLabel!,
                                    timeText,
                                  ].join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                if (widget.workHoursLabel != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.workHoursLabel!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ] else if (code?.isNotEmpty == true) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: categoryColor.withValues(
                                          alpha: .10,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        contextLabel,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: categoryInk,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        codeDisplay!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                const SizedBox(height: 4),
                                Text(
                                  contextLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: categoryInk,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (!compactWork) ...[
                                const SizedBox(height: 5),
                                Text(
                                  timeText,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                if (widget.workHoursLabel != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.workHoursLabel!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                              if (!compactWork &&
                                  (widget.item.location?.isNotEmpty ??
                                      false)) ...[
                                const SizedBox(height: 3),
                                Text(
                                  widget.item.location!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (widget.showExtendedWorkDetails &&
                                  reportingInstruction?.isNotEmpty == true) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Report: $reportingInstruction',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (widget.showExtendedWorkDetails &&
                                  codeMeaning?.isNotEmpty == true) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Code assignment: $codeMeaning',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (!compactWork && widget.dateLabel != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.dateLabel!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: categoryInk),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
