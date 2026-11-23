import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:firstfloor_calendar/firstfloor_calendar.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/civil_time_resolver.dart';
import '../domain/schedule.dart';
import 'schedule_import_models.dart';

typedef IcsImportNotice = ScheduleImportNotice;
typedef IcsImportProposal = ScheduleImportProposal;
typedef IcsImportPreview = ScheduleImportPreview;

class _IcsEventCategory {
  const _IcsEventCategory(this.kind, {this.workCategory, this.deadlineType});

  final ScheduleKind kind;
  final WorkCategory? workCategory;
  final DeadlineType? deadlineType;
}

/// A conservative RFC 5545 import adapter. Weekly rules the schedule model can
/// preserve are retained as recurrence; other patterns are reported for review.
class IcsScheduleImportParser {
  const IcsScheduleImportParser();

  static const maxBytes = 5 * 1024 * 1024;
  static const maxEvents = 500;
  static const maxCountedOccurrences = 500;
  static bool _timeZonesInitialized = false;
  static final _sha256 = Sha256();

  Future<ScheduleImportPreview> parse(
    String source, {
    required String sourceName,
    required String floatingTimeZoneId,
    DateTime? importedAt,
  }) async {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException('This calendar file is too large.');
    }
    if (source.trim().isEmpty) {
      throw const FormatException('The selected calendar file is empty.');
    }
    _initializeTimeZones();
    _requireZone(floatingTimeZoneId);

    final Calendar calendar;
    try {
      calendar = CalendarParser().parseFromString(source);
    } on Object {
      throw const FormatException(
        'This file is not a supported iCalendar file.',
      );
    }
    if (calendar.version != '2.0') {
      throw const FormatException('Only iCalendar version 2.0 is supported.');
    }
    if (calendar.events.length > maxEvents) {
      throw const FormatException(
        'This calendar contains too many events to review at once.',
      );
    }

    final sourceBlocks = _eventSourceBlocks(source);
    final proposals = <ScheduleImportProposal>[];
    final notices = <ScheduleImportNotice>[];
    final selfExportByIndex = <int, _SelfExportPart>{};
    final selfExportGroups = <String, List<_SelfExportPart>>{};
    final invalidSelfExportIndexes = <int>{};
    final invalidSelfExportGroups = <String>{};
    for (var index = 0; index < calendar.events.length; index++) {
      final event = calendar.events[index];
      final exportVersion = event.valueOrNull<String>('X-SHIFT-STUDY-EXPORT');
      if (exportVersion == null) continue;
      final uid = event.uid.trim();
      try {
        final sourceId = event.valueOrNull<String>('X-SHIFT-STUDY-ID')?.trim();
        final part = int.parse(
          event.valueOrNull<String>('X-SHIFT-STUDY-PART') ?? '',
        );
        final partCount = int.parse(
          event.valueOrNull<String>('X-SHIFT-STUDY-PARTS') ?? '',
        );
        final completionValue = event
            .valueOrNull<String>('X-SHIFT-STUDY-COMPLETED')
            ?.toLowerCase();
        final completed = switch (completionValue) {
          null || '0' || 'false' => false,
          '1' || 'true' => true,
          _ => throw const FormatException(
            'Invalid StudyShift completion metadata.',
          ),
        };
        final actualEnd = _parseSelfExportActualEnd(
          event.valueOrNull<String>('X-SHIFT-STUDY-ACTUAL-END'),
        );
        if (exportVersion != '2' ||
            sourceId == null ||
            sourceId.isEmpty ||
            sourceId.length > 512 ||
            sourceId.contains(RegExp(r'[\x00-\x1f\x7f]')) ||
            partCount < 1 ||
            partCount > maxEvents ||
            part < 1 ||
            part > partCount ||
            (actualEnd != null && !completed)) {
          throw const FormatException('Invalid StudyShift export metadata.');
        }
        final metadata = _SelfExportPart(
          sourceId: sourceId,
          part: part,
          partCount: partCount,
          uid: uid,
          completed: completed,
          actualEnd: actualEnd,
        );
        selfExportByIndex[index] = metadata;
        selfExportGroups.putIfAbsent(sourceId, () => []).add(metadata);
      } on Object {
        invalidSelfExportIndexes.add(index);
        notices.add(
          ScheduleImportNotice(
            'StudyShift export details are incomplete or invalid; this record was skipped.',
            uid: uid.isEmpty ? null : uid,
          ),
        );
      }
    }
    for (final entry in selfExportGroups.entries) {
      final parts = entry.value;
      final expected = parts.first.partCount;
      final valid =
          parts.length == expected &&
          parts.every((part) => part.partCount == expected) &&
          parts.map((part) => part.part).toSet().length == expected;
      if (!valid) {
        invalidSelfExportGroups.add(entry.key);
        notices.add(
          ScheduleImportNotice(
            'A StudyShift split or recurring entry is incomplete; the whole entry was skipped for review.',
            uid: parts.first.uid,
          ),
        );
      }
    }
    final selfExportProposals = <String, List<_ImportedSelfExportPart>>{};
    final uidCounts = <String, int>{};
    for (final event in calendar.events) {
      final uid = event.uid.trim();
      if (uid.isNotEmpty) {
        uidCounts.update(uid, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final duplicateUids = uidCounts.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toSet();
    final reportedDuplicateUids = <String>{};
    final timestamp = (importedAt ?? DateTime.now()).toUtc();
    for (var index = 0; index < calendar.events.length; index++) {
      final event = calendar.events[index];
      final selfExport = selfExportByIndex[index];
      String? uid;
      try {
        uid = event.uid.trim();
        if (invalidSelfExportIndexes.contains(index) ||
            (selfExport != null &&
                invalidSelfExportGroups.contains(selfExport.sourceId))) {
          continue;
        }
        if (uid.isEmpty || uid.length > 1024) {
          throw const FormatException('This event has an invalid identifier.');
        }
        if (duplicateUids.contains(uid)) {
          if (reportedDuplicateUids.add(uid)) {
            notices.add(
              ScheduleImportNotice(
                'This event has multiple calendar records or exceptions and needs review; all matching records were skipped.',
                uid: uid,
              ),
            );
          }
          continue;
        }
        if (event.statusName?.toUpperCase() == 'CANCELLED') {
          notices.add(
            ScheduleImportNotice('Cancelled event was skipped.', uid: uid),
          );
          continue;
        }
        if (event.recurrenceId != null) {
          notices.add(
            ScheduleImportNotice(
              'This calendar exception needs manual review and was skipped.',
              uid: uid,
            ),
          );
          continue;
        }
        final title = event.summary?.trim();
        if (title == null || title.isEmpty) {
          throw const FormatException('This event has no name to review.');
        }
        final start = event.dtstart;
        if (start == null) {
          throw const FormatException('This event has no start date.');
        }
        final sourceText = index < sourceBlocks.length
            ? sourceBlocks[index]
            : event.toIcsString();
        final expandedSeries = _expandedStudyShiftSeries(event);
        final id = selfExport?.sourceId ?? await _stableId(uid);

        final eventZone = start.isDate
            ? floatingTimeZoneId
            : _eventZone(event, start, floatingTimeZoneId);
        final category = _eventCategory(event);
        final recurrence = _recurrenceFor(
          event,
          start,
          eventZone,
          floatingTimeZoneId,
        );

        if (start.isDate) {
          if (category.kind == ScheduleKind.classSession ||
              (category.kind == ScheduleKind.deadline &&
                  category.deadlineType == DeadlineType.examination) ||
              (category.workCategory != null &&
                  !category.workCategory!.isAllDay)) {
            throw const FormatException(
              'This category needs a timed event and cannot use an all-day calendar entry.',
            );
          }
          final end = event.effectiveEnd;
          if (end != null && !end.isDate) {
            throw const FormatException(
              'This all-day event has an incompatible end value.',
            );
          }
          final days = end == null
              ? 1
              : _daysBetween(
                  CivilDate(start.year, start.month, start.day),
                  CivilDate(end.year, end.month, end.day),
                );
          if (days != 1) {
            throw const FormatException(
              'Only single-day calendar entries can be imported currently.',
            );
          }
          final proposal = ScheduleImportProposal(
            item: ScheduleItem(
              id: id,
              kind: category.kind,
              title: title,
              startDate: CivilDate(start.year, start.month, start.day),
              intervals: const [],
              workCategory: category.workCategory,
              deadlineType: category.deadlineType,
              recurrence: recurrence,
              coworkers: _readCoworkers(event),
              location: _cleanOptional(event.location),
              notes: _cleanOptional(event.description),
              allDay: category.kind == ScheduleKind.personal,
              importProvenance: _provenance(
                uid,
                sourceName,
                sourceText,
                timestamp,
              ),
            ),
            sourceText: sourceText,
            studyShiftSeriesId: selfExport == null
                ? expandedSeries?.sourceId
                : null,
            studyShiftExpandedThrough: selfExport == null
                ? expandedSeries?.expandedThrough
                : null,
          );
          if (selfExport == null) {
            proposals.add(proposal);
          } else {
            selfExportProposals
                .putIfAbsent(selfExport.sourceId, () => [])
                .add(_ImportedSelfExportPart(selfExport, proposal));
          }
          continue;
        }

        final startTime = start.time!;
        if (startTime.second != 0) {
          throw const FormatException(
            'This event uses seconds, which the schedule editor cannot preserve.',
          );
        }
        final end = event.effectiveEnd;
        if (end == null || end.isDate || end.time == null) {
          throw const FormatException(
            'This event has no usable end time. Add one in the source calendar and try again.',
          );
        }
        if (end.time!.second != 0) {
          throw const FormatException(
            'This event uses seconds, which the schedule editor cannot preserve.',
          );
        }
        final startLocal = _resolveIntoZone(
          start,
          eventZone,
          floatingTimeZoneId,
        );
        final endLocal = _resolveIntoZone(end, eventZone, floatingTimeZoneId);
        final startDate = CivilDate(
          startLocal.year,
          startLocal.month,
          startLocal.day,
        );
        final endDate = CivilDate(endLocal.year, endLocal.month, endLocal.day);
        final startMinute = startLocal.hour * 60 + startLocal.minute;
        final endMinute = endLocal.hour * 60 + endLocal.minute;
        final dayOffset = _daysBetween(startDate, endDate);
        if (dayOffset < 0 || dayOffset > 1 || !endLocal.isAfter(startLocal)) {
          throw const FormatException(
            'Multi-day or reversed events need manual correction before import.',
          );
        }
        final startFold = _foldChoice(
          startDate,
          startMinute,
          eventZone,
          startLocal,
        );
        final endFold = _foldChoice(endDate, endMinute, eventZone, endLocal);
        final interval = EventInterval(
          startDayOffset: 0,
          startMinute: startMinute,
          endDayOffset: dayOffset,
          endMinute: endMinute,
          startFoldChoice: startFold,
          endFoldChoice: endFold,
        );
        if (!interval.isValid) {
          throw const FormatException(
            'The event end must be later than its start.',
          );
        }
        if ((category.workCategory?.isAllDay ?? false) ||
            (category.kind == ScheduleKind.deadline &&
                category.deadlineType == DeadlineType.assignment)) {
          throw const FormatException(
            'This category needs an all-day calendar entry and cannot use a time range.',
          );
        }
        final proposal = ScheduleImportProposal(
          item: ScheduleItem(
            id: id,
            kind: category.kind,
            title: title,
            startDate: startDate,
            intervals: [interval],
            timeZoneId: eventZone,
            workCategory: category.workCategory,
            deadlineType: category.deadlineType,
            recurrence: recurrence,
            coworkers: _readCoworkers(event),
            location: _cleanOptional(event.location),
            notes: _cleanOptional(event.description),
            importProvenance: _provenance(
              uid,
              sourceName,
              sourceText,
              timestamp,
            ),
          ),
          sourceText: sourceText,
          studyShiftSeriesId: selfExport == null
              ? expandedSeries?.sourceId
              : null,
          studyShiftExpandedThrough: selfExport == null
              ? expandedSeries?.expandedThrough
              : null,
        );
        if (selfExport == null) {
          proposals.add(proposal);
        } else {
          selfExportProposals
              .putIfAbsent(selfExport.sourceId, () => [])
              .add(_ImportedSelfExportPart(selfExport, proposal));
        }
      } on Object catch (error) {
        notices.add(
          ScheduleImportNotice(
            error is FormatException
                ? error.message.toString()
                : 'This event could not be safely interpreted.',
            uid: uid,
          ),
        );
      }
    }
    for (final entry in selfExportGroups.entries) {
      final parts = selfExportProposals[entry.key] ?? const [];
      final expected = entry.value.first.partCount;
      if (invalidSelfExportGroups.contains(entry.key)) continue;
      if (parts.length != expected) {
        notices.add(
          ScheduleImportNotice(
            'A StudyShift split or recurring entry could not be fully read; the whole entry was skipped.',
            uid: entry.value.first.uid,
          ),
        );
        continue;
      }
      try {
        proposals.add(_combineSelfExportParts(parts));
      } on FormatException catch (error) {
        notices.add(
          ScheduleImportNotice(
            error.message.toString(),
            uid: entry.value.first.uid,
          ),
        );
      }
    }
    final groupedProposals = _combineExpandedStudyShiftSeries(
      proposals,
      notices,
    );
    return ScheduleImportPreview(
      proposals: List.unmodifiable(groupedProposals),
      notices: List.unmodifiable(notices),
    );
  }

  static _ExpandedStudyShiftSeries? _expandedStudyShiftSeries(
    EventComponent event,
  ) {
    final sourceId = event.valueOrNull<String>('X-SHIFT-STUDY-ID')?.trim();
    final description = event.description ?? '';
    final match = RegExp(
      r'(?:^|\n)Expanded from a weekly series through (\d{4})-(\d{2})-(\d{2})\.?$',
    ).firstMatch(description);
    if (sourceId == null ||
        sourceId.isEmpty ||
        sourceId.length > 512 ||
        sourceId.contains(RegExp(r'[\x00-\x1f\x7f]')) ||
        match == null) {
      return null;
    }
    final through = CivilDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
    return through.isValid
        ? _ExpandedStudyShiftSeries(sourceId, through)
        : null;
  }

  static List<ScheduleImportProposal> _combineExpandedStudyShiftSeries(
    List<ScheduleImportProposal> input,
    List<ScheduleImportNotice> notices,
  ) {
    final groups = <String, List<ScheduleImportProposal>>{};
    final result = <ScheduleImportProposal>[];
    for (final proposal in input) {
      final sourceId = proposal.studyShiftSeriesId;
      if (sourceId == null) {
        result.add(proposal);
      } else {
        groups.putIfAbsent(sourceId, () => []).add(proposal);
      }
    }
    for (final entry in groups.entries) {
      try {
        result.add(_combineExpandedStudyShiftSeriesGroup(entry.value));
      } on FormatException catch (error) {
        notices.add(
          ScheduleImportNotice(
            error.message.toString(),
            uid: entry.value.first.item.importProvenance?.uid,
          ),
        );
      }
    }
    return result;
  }

  static ScheduleImportProposal _combineExpandedStudyShiftSeriesGroup(
    List<ScheduleImportProposal> group,
  ) {
    final first = group.first.item;
    final through = group.first.studyShiftExpandedThrough!;
    final partPattern = RegExp(r'^(.*?) \(Part ([1-9]\d*)\)$');
    final partMatches = group
        .map((proposal) => partPattern.firstMatch(proposal.item.title))
        .toList();
    final hasParts = partMatches.any((match) => match != null);
    if (group.any(
          (proposal) =>
              proposal.studyShiftExpandedThrough != through ||
              proposal.item.kind != first.kind ||
              proposal.item.timeZoneId != first.timeZoneId ||
              proposal.item.workCategory != first.workCategory ||
              proposal.item.deadlineType != first.deadlineType ||
              proposal.item.location != first.location ||
              proposal.item.allDay != first.allDay ||
              proposal.item.recurrence != null,
        ) ||
        (hasParts && partMatches.any((match) => match == null))) {
      throw const FormatException(
        'Expanded StudyShift occurrences disagree about their details; the whole series was skipped for review.',
      );
    }

    final title = hasParts
        ? partMatches.firstWhere((match) => match != null)!.group(1)!
        : first.title;
    final byDate = <CivilDate, List<(int, ScheduleImportProposal)>>{};
    for (var index = 0; index < group.length; index++) {
      final proposal = group[index];
      final item = proposal.item;
      final date = item.startDate;
      final part = hasParts ? int.parse(partMatches[index]!.group(2)!) : 1;
      if ((hasParts ? partMatches[index]!.group(1) : item.title) != title ||
          item.intervals.length != 1 && !item.hasNoTime) {
        throw const FormatException(
          'Expanded StudyShift occurrence parts are invalid; the whole series was skipped for review.',
        );
      }
      byDate.putIfAbsent(date, () => []).add((part, proposal));
    }
    final dates = byDate.keys.toList()..sort();
    if (dates.isEmpty || dates.last.compareTo(through) > 0) {
      throw const FormatException(
        'Expanded StudyShift occurrence dates are invalid; the whole series was skipped for review.',
      );
    }
    final weekday = dates.first.weekday;
    if (dates.any((date) => date.weekday != weekday)) {
      throw const FormatException(
        'Expanded StudyShift occurrences do not follow one weekly pattern; the series was skipped for review.',
      );
    }
    List<EventInterval>? seriesIntervals;
    for (final date in dates) {
      final entries = byDate[date]!
        ..sort((left, right) => left.$1.compareTo(right.$1));
      if ((!hasParts && entries.length != 1) ||
          entries.map((entry) => entry.$1).toSet().length != entries.length ||
          (hasParts &&
              entries.asMap().entries.any(
                (entry) => entry.value.$1 != entry.key + 1,
              ))) {
        throw const FormatException(
          'Expanded StudyShift split intervals are incomplete or duplicated; the whole series was skipped for review.',
        );
      }
      for (final entry in entries) {
        final item = entry.$2.item;
        if (item.kind != first.kind ||
            item.timeZoneId != first.timeZoneId ||
            item.workCategory != first.workCategory ||
            item.deadlineType != first.deadlineType ||
            item.location != first.location ||
            item.allDay != first.allDay) {
          throw const FormatException(
            'Expanded StudyShift split intervals disagree; the whole series was skipped for review.',
          );
        }
      }
      final dateIntervals = [
        for (final entry in entries) ...entry.$2.item.intervals,
      ];
      if (seriesIntervals != null &&
          (seriesIntervals.length != dateIntervals.length ||
              seriesIntervals.asMap().entries.any(
                (entry) => entry.value != dateIntervals[entry.key],
              ))) {
        throw const FormatException(
          'Expanded StudyShift split intervals change between occurrences; the whole series was skipped for review.',
        );
      }
      seriesIntervals ??= dateIntervals;
    }
    final exceptionDates = <CivilDate>{};
    for (
      var candidate = dates.first.addDays(7);
      candidate.compareTo(dates.last) < 0;
      candidate = candidate.addDays(7)
    ) {
      if (!byDate.containsKey(candidate)) exceptionDates.add(candidate);
    }
    final recurrence = WeeklyRecurrence(
      weekdays: {weekday},
      until: dates.last,
      exceptionDates: exceptionDates,
    );
    final sourceText = group
        .map((proposal) => proposal.sourceText)
        .join('\r\n');
    final provenance = first.importProvenance!;
    return ScheduleImportProposal(
      item: ScheduleItem(
        id: group.first.studyShiftSeriesId!,
        kind: first.kind,
        title: title,
        startDate: dates.first,
        intervals: seriesIntervals ?? const [],
        timeZoneId: first.timeZoneId,
        workCategory: first.workCategory,
        deadlineType: first.deadlineType,
        location: first.location,
        notes: _withoutExpansionMarker(first.notes),
        allDay: first.allDay,
        recurrence: recurrence,
        coworkers: first.coworkers,
        importProvenance: ScheduleImportProvenance(
          format: provenance.format,
          uid: provenance.uid,
          sourceName: provenance.sourceName,
          sourceText: sourceText,
          importedAt: provenance.importedAt,
        ),
      ),
      sourceText: sourceText,
    );
  }

  static String? _withoutExpansionMarker(String? notes) {
    if (notes == null) return null;
    final cleaned = notes
        .split(RegExp(r'\r?\n'))
        .where(
          (line) => !RegExp(
            r'^Expanded from a weekly series through \d{4}-\d{2}-\d{2}\.?$',
          ).hasMatch(line.trim()),
        )
        .join('\n')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static ScheduleImportProposal _combineSelfExportParts(
    List<_ImportedSelfExportPart> input,
  ) {
    final parts = input.toList()
      ..sort(
        (left, right) => left.metadata.part.compareTo(right.metadata.part),
      );
    final metadata = parts.first.metadata;
    if (parts.length != metadata.partCount ||
        parts.asMap().entries.any(
          (entry) =>
              entry.value.metadata.sourceId != metadata.sourceId ||
              entry.value.metadata.partCount != metadata.partCount ||
              entry.value.metadata.part != entry.key + 1,
        )) {
      throw const FormatException(
        'StudyShift split-part details do not match; the entry was skipped.',
      );
    }
    final first = parts.first.proposal.item;
    if (parts.any((part) {
      final item = part.proposal.item;
      return item.kind != first.kind ||
          item.title != first.title ||
          item.startDate != first.startDate ||
          item.timeZoneId != first.timeZoneId ||
          item.workCategory != first.workCategory ||
          item.deadlineType != first.deadlineType ||
          !_sameRecurrence(item.recurrence, first.recurrence) ||
          item.location != first.location ||
          item.notes != first.notes ||
          item.allDay != first.allDay;
    })) {
      throw const FormatException(
        'StudyShift split parts disagree about their event details; the entry was skipped.',
      );
    }
    final intervals = [
      for (final part in parts) ...part.proposal.item.intervals,
    ];
    if (first.hasNoTime && (parts.length != 1 || intervals.isNotEmpty) ||
        !first.hasNoTime && intervals.length != parts.length ||
        intervals.toSet().length != intervals.length) {
      throw const FormatException(
        'StudyShift split intervals are incomplete or duplicated; the entry was skipped.',
      );
    }
    final hasActualIntervals = parts.any(
      (part) => part.metadata.actualEnd != null,
    );
    if (parts.any(
          (part) =>
              part.metadata.completed != metadata.completed ||
              (hasActualIntervals && part.metadata.actualEnd == null),
        ) ||
        (metadata.completed && !first.supportsCompletionTracking) ||
        (hasActualIntervals && !metadata.completed)) {
      throw const FormatException(
        'StudyShift completion details do not match; the entry was skipped.',
      );
    }
    final actualIntervals = hasActualIntervals
        ? [
            for (final part in parts)
              _intervalWithActualEnd(
                part.proposal.item.intervals.single,
                part.metadata.actualEnd!,
              ),
          ]
        : null;
    final sourceText = parts
        .map((part) => part.proposal.sourceText)
        .join('\r\n');
    final provenance = first.importProvenance!;
    return ScheduleImportProposal(
      item: ScheduleItem(
        id: metadata.sourceId,
        kind: first.kind,
        title: first.title,
        startDate: first.startDate,
        intervals: intervals,
        timeZoneId: first.timeZoneId,
        workCategory: first.workCategory,
        deadlineType: first.deadlineType,
        recurrence: first.recurrence,
        coworkers: first.coworkers,
        location: first.location,
        notes: first.notes,
        allDay: first.allDay,
        isCompleted: metadata.completed,
        actualIntervals: actualIntervals,
        importProvenance: ScheduleImportProvenance(
          format: provenance.format,
          uid: provenance.uid,
          sourceName: provenance.sourceName,
          sourceText: sourceText,
          importedAt: provenance.importedAt,
        ),
      ),
      sourceText: sourceText,
    );
  }

  static bool _sameRecurrence(WeeklyRecurrence? left, WeeklyRecurrence? right) {
    if (left == null || right == null) return left == right;
    return left.until == right.until &&
        left.weekdays.length == right.weekdays.length &&
        left.weekdays.containsAll(right.weekdays) &&
        left.exceptionDates.length == right.exceptionDates.length &&
        left.exceptionDates.containsAll(right.exceptionDates);
  }

  static _SelfExportActualEnd? _parseSelfExportActualEnd(String? value) {
    if (value == null) return null;
    final fields = value.split(';');
    if (fields.length != 3) {
      throw const FormatException('Invalid StudyShift actual-time metadata.');
    }
    final dayOffset = int.tryParse(fields[0]);
    final minute = int.tryParse(fields[1]);
    final foldChoice = switch (fields[2]) {
      '-' => null,
      'earlier' => CivilTimeFoldChoice.earlier,
      'later' => CivilTimeFoldChoice.later,
      _ => throw const FormatException(
        'Invalid StudyShift actual-time metadata.',
      ),
    };
    if (dayOffset == null ||
        dayOffset < 0 ||
        minute == null ||
        minute < 0 ||
        minute >= 1440) {
      throw const FormatException('Invalid StudyShift actual-time metadata.');
    }
    return _SelfExportActualEnd(dayOffset, minute, foldChoice);
  }

  static List<String> _readCoworkers(EventComponent event) {
    final value = event.valueOrNull<String>('X-SHIFT-STUDY-COWORKERS');
    if (value == null || value.isEmpty) return const [];
    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(value))),
      );
      if (decoded is! List ||
          decoded.length > 100 ||
          decoded.any((name) => name is! String || name.length > 512)) {
        throw const FormatException('Invalid coworker metadata.');
      }
      return decoded.cast<String>();
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('Invalid coworker metadata.');
    }
  }

  static EventInterval _intervalWithActualEnd(
    EventInterval planned,
    _SelfExportActualEnd actualEnd,
  ) {
    final actual = EventInterval(
      startDayOffset: planned.startDayOffset,
      startMinute: planned.startMinute,
      endDayOffset: actualEnd.dayOffset,
      endMinute: actualEnd.minute,
      startFoldChoice: planned.startFoldChoice,
      endFoldChoice: actualEnd.foldChoice,
    );
    if (!actual.isValid || actual.endEpochMinute < planned.endEpochMinute) {
      throw const FormatException(
        'StudyShift actual finish time cannot shorten its scheduled interval.',
      );
    }
    return actual;
  }

  static void _initializeTimeZones() {
    if (_timeZonesInitialized) return;
    tzdata.initializeTimeZones();
    _timeZonesInitialized = true;
  }

  static String _normalizeZone(String value) =>
      value.startsWith('/') ? value.substring(1) : value;

  static String _eventZone(
    EventComponent event,
    CalDateTime start,
    String floatingTimeZoneId,
  ) {
    final startTime = start.time!;
    final exportedZone = event.valueOrNull<String>('X-SHIFT-STUDY-TZID');
    final zone = startTime.isUtc
        ? _normalizeZone(exportedZone ?? floatingTimeZoneId)
        : _normalizeZone(startTime.tzid ?? floatingTimeZoneId);
    _requireZone(zone);
    return zone;
  }

  static _IcsEventCategory _eventCategory(EventComponent event) {
    final categories = event.categories
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    const families = {
      'WORK',
      'SCHOOL',
      'PERSONAL',
      'ASSIGNMENT',
      'EXAMINATION',
    };
    final selectedFamilies = categories.intersection(families);
    if (selectedFamilies.length > 1) {
      throw const FormatException(
        'This event has conflicting schedule categories and needs review.',
      );
    }
    if (selectedFamilies.contains('WORK')) {
      final workCategories = WorkCategory.values
          .where((value) => categories.contains(value.name.toUpperCase()))
          .toList();
      if (workCategories.length != 1) {
        throw const FormatException(
          'This work event has no single recognized work category and needs review.',
        );
      }
      return _IcsEventCategory(
        ScheduleKind.work,
        workCategory: workCategories.single,
      );
    }
    if (selectedFamilies.contains('SCHOOL')) {
      return const _IcsEventCategory(ScheduleKind.classSession);
    }
    if (selectedFamilies.contains('ASSIGNMENT')) {
      return const _IcsEventCategory(
        ScheduleKind.deadline,
        deadlineType: DeadlineType.assignment,
      );
    }
    if (selectedFamilies.contains('EXAMINATION')) {
      return const _IcsEventCategory(
        ScheduleKind.deadline,
        deadlineType: DeadlineType.examination,
      );
    }
    return const _IcsEventCategory(ScheduleKind.personal);
  }

  static WeeklyRecurrence? _recurrenceFor(
    EventComponent event,
    CalDateTime start,
    String eventZone,
    String floatingTimeZoneId,
  ) {
    final rule = event.rrule;
    if (rule == null && event.rdates.isEmpty && event.exdates.isEmpty) {
      return null;
    }
    if (rule == null || event.rdates.isNotEmpty || event.recurrenceId != null) {
      throw const FormatException(
        'This recurrence pattern needs manual review and was skipped.',
      );
    }
    if (rule.freq != RecurrenceFrequency.weekly || rule.interval != 1) {
      throw const FormatException(
        'Only weekly calendar patterns can be imported safely; this event was skipped.',
      );
    }
    if (rule.count != null && rule.until != null) {
      throw const FormatException(
        'This recurrence has conflicting end rules and was skipped.',
      );
    }
    if ((rule.count ?? 0) > maxCountedOccurrences ||
        (rule.count != null && rule.count! < 1)) {
      throw const FormatException(
        'This recurrence is too long to review safely and was skipped.',
      );
    }
    if (rule.bySecond != null ||
        rule.byMinute != null ||
        rule.byHour != null ||
        rule.byMonthDay != null ||
        rule.byYearDay != null ||
        rule.byWeekNo != null ||
        rule.byMonth != null ||
        rule.bySetPos != null) {
      throw const FormatException(
        'This recurrence uses calendar rules that need manual review and was skipped.',
      );
    }

    final startDate = CivilDate(start.year, start.month, start.day);
    final weekdays = (rule.byDay ?? <ByDay>{}).map((byDay) {
      if (byDay.ordinal != null) {
        throw const FormatException(
          'Ordinal weekday patterns need manual review and were skipped.',
        );
      }
      return switch (byDay.weekday) {
        Weekday.mo => DateTime.monday,
        Weekday.tu => DateTime.tuesday,
        Weekday.we => DateTime.wednesday,
        Weekday.th => DateTime.thursday,
        Weekday.fr => DateTime.friday,
        Weekday.sa => DateTime.saturday,
        Weekday.su => DateTime.sunday,
      };
    }).toSet();
    if (weekdays.isEmpty) weekdays.add(startDate.weekday);
    if (!weekdays.contains(startDate.weekday)) {
      throw const FormatException(
        'The first date does not match the weekly pattern and needs manual review.',
      );
    }

    CivilDate? until;
    if (rule.until != null) {
      final untilValue = rule.until!;
      if (untilValue.isDate) {
        until = CivilDate(untilValue.year, untilValue.month, untilValue.day);
      } else {
        final localUntil = _resolveIntoZone(
          untilValue,
          eventZone,
          floatingTimeZoneId,
        );
        final localStart = _resolveIntoZone(
          start,
          eventZone,
          floatingTimeZoneId,
        );
        final untilDate = CivilDate(
          localUntil.year,
          localUntil.month,
          localUntil.day,
        );
        final localStartMinute = localStart.hour * 60 + localStart.minute;
        final localUntilMinute = localUntil.hour * 60 + localUntil.minute;
        until = localUntilMinute < localStartMinute
            ? untilDate.addDays(-1)
            : untilDate;
      }
    } else if (rule.count != null) {
      final occurrences = RecurrenceIterator(
        dtstart: start,
        rrule: rule,
        maxIterations: maxCountedOccurrences * 8,
      ).occurrences().take(rule.count!).toList(growable: false);
      if (occurrences.length != rule.count) {
        throw const FormatException(
          'The recurrence end could not be resolved and needs manual review.',
        );
      }
      final last = occurrences.last;
      until = CivilDate(last.year, last.month, last.day);
    }
    if (until != null && until.compareTo(startDate) < 0) {
      throw const FormatException(
        'This recurrence ends before it starts and was skipped.',
      );
    }

    final exceptions = <CivilDate>{};
    for (final excluded in event.exdates) {
      if (start.isDate != excluded.isDate) {
        throw const FormatException(
          'This recurrence mixes timed and all-day exclusions and needs review.',
        );
      }
      final date = excluded.isDate
          ? CivilDate(excluded.year, excluded.month, excluded.day)
          : () {
              final local = _resolveIntoZone(
                excluded,
                eventZone,
                floatingTimeZoneId,
              );
              return CivilDate(local.year, local.month, local.day);
            }();
      if (date.compareTo(startDate) >= 0 &&
          (until == null || date.compareTo(until) <= 0) &&
          weekdays.contains(date.weekday)) {
        exceptions.add(date);
      }
    }
    return WeeklyRecurrence(
      weekdays: weekdays,
      until: until,
      exceptionDates: exceptions,
    );
  }

  static void _requireZone(String zoneId) {
    try {
      tz.getLocation(zoneId);
    } on Object {
      throw FormatException('“$zoneId” is not a supported IANA time zone.');
    }
  }

  static tz.TZDateTime _resolveIntoZone(
    CalDateTime value,
    String targetZone,
    String floatingZone,
  ) {
    final time = value.time;
    if (time == null) throw const FormatException('A time value is missing.');
    if (time.isUtc) {
      return tz.TZDateTime.from(value.native, tz.getLocation(targetZone));
    }
    final sourceZone = _normalizeZone(time.tzid ?? floatingZone);
    _requireZone(sourceZone);
    final date = CivilDate(value.year, value.month, value.day);
    final resolution = CivilTimeResolver().resolve(
      date,
      time.hour * 60 + time.minute,
      sourceZone,
    );
    switch (resolution.status) {
      case CivilTimeStatus.unique:
        return tz.TZDateTime.from(
          resolution.candidates.single,
          tz.getLocation(targetZone),
        );
      case CivilTimeStatus.ambiguous:
        throw const FormatException(
          'This event falls during a repeated clock time and needs manual time-zone review.',
        );
      case CivilTimeStatus.nonexistent:
        throw const FormatException(
          'This event falls during a clock-change gap and needs manual time review.',
        );
      case CivilTimeStatus.invalidTimeZone:
        throw FormatException('“$sourceZone” is not a supported time zone.');
    }
  }

  static int _daysBetween(CivilDate start, CivilDate end) => DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;

  static CivilTimeFoldChoice? _foldChoice(
    CivilDate date,
    int minute,
    String zoneId,
    tz.TZDateTime instant,
  ) {
    final resolution = CivilTimeResolver().resolve(date, minute, zoneId);
    if (resolution.status == CivilTimeStatus.unique) return null;
    if (resolution.status != CivilTimeStatus.ambiguous) {
      throw const FormatException(
        'This event cannot be represented at that local time.',
      );
    }
    final index = resolution.candidates.indexWhere(
      (candidate) =>
          candidate.millisecondsSinceEpoch == instant.millisecondsSinceEpoch,
    );
    return switch (index) {
      0 => CivilTimeFoldChoice.earlier,
      1 => CivilTimeFoldChoice.later,
      _ => throw const FormatException(
        'This event time does not match its time-zone definition.',
      ),
    };
  }

  static String? _cleanOptional(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static ScheduleImportProvenance _provenance(
    String uid,
    String sourceName,
    String sourceText,
    DateTime importedAt,
  ) => ScheduleImportProvenance(
    format: 'iCalendar 2.0',
    uid: uid,
    sourceName: sourceName,
    sourceText: sourceText,
    importedAt: importedAt,
  );

  static Future<String> _stableId(String uid) async {
    final digest = await _sha256.hash(utf8.encode(uid));
    return 'ics-${base64Url.encode(digest.bytes).replaceAll('=', '')}';
  }

  static List<String> _eventSourceBlocks(String source) {
    final lines = source.split(RegExp(r'\r\n|\n|\r'));
    final blocks = <String>[];
    final current = <String>[];
    var depth = 0;
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (depth == 0 && upper == 'BEGIN:VEVENT') {
        depth = 1;
        current
          ..clear()
          ..add(line);
      } else if (depth > 0) {
        current.add(line);
        if (upper.startsWith('BEGIN:')) depth++;
        if (upper.startsWith('END:')) depth--;
        if (depth == 0) blocks.add(current.join('\r\n'));
      }
    }
    return blocks;
  }
}

class _SelfExportPart {
  const _SelfExportPart({
    required this.sourceId,
    required this.part,
    required this.partCount,
    required this.uid,
    required this.completed,
    required this.actualEnd,
  });

  final String sourceId;
  final int part;
  final int partCount;
  final String uid;
  final bool completed;
  final _SelfExportActualEnd? actualEnd;
}

class _SelfExportActualEnd {
  const _SelfExportActualEnd(this.dayOffset, this.minute, this.foldChoice);

  final int dayOffset;
  final int minute;
  final CivilTimeFoldChoice? foldChoice;
}

class _ImportedSelfExportPart {
  const _ImportedSelfExportPart(this.metadata, this.proposal);

  final _SelfExportPart metadata;
  final ScheduleImportProposal proposal;
}

class _ExpandedStudyShiftSeries {
  const _ExpandedStudyShiftSeries(this.sourceId, this.expandedThrough);

  final String sourceId;
  final CivilDate expandedThrough;
}
