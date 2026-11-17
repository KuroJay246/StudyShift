/// Platform independent scheduling primitives. Times are civil wall-clock
/// values; an interval stores its ending day offset explicitly, so overnight
/// work never depends on date formatting or inference at display time.
enum ScheduleKind { work, classSession, personal, deadline }

enum DeadlineType { assignment, examination }

// Keep existing values in place: Drift stores the enum index in work_category.
enum WorkCategory { shift, training, restDay, leave, dayOff, overtime }

extension WorkCategoryRules on WorkCategory {
  bool get isAllDay => switch (this) {
    WorkCategory.restDay || WorkCategory.leave || WorkCategory.dayOff => true,
    WorkCategory.shift ||
    WorkCategory.training ||
    WorkCategory.overtime => false,
  };
}

enum CivilTimeFoldChoice { earlier, later }

const Object _unchanged = Object();

class ScheduleImportProvenance {
  const ScheduleImportProvenance({
    required this.format,
    required this.uid,
    required this.sourceName,
    required this.sourceText,
    required this.importedAt,
  });

  final String format;
  final String uid;
  final String sourceName;
  final String sourceText;
  final DateTime importedAt;
}

class CivilDate implements Comparable<CivilDate> {
  const CivilDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  factory CivilDate.fromDateTime(DateTime date) =>
      CivilDate(date.year, date.month, date.day);

  /// Midnight in the device's local zone. Use this only when comparing civil
  /// day boundaries with local event DateTimes.
  DateTime toDateTime() => DateTime(year, month, day);

  /// ISO weekday, computed from a timezone-independent civil date.
  int get weekday => DateTime.utc(year, month, day).weekday;

  CivilDate addDays(int days) {
    final next = DateTime.utc(year, month, day).add(Duration(days: days));
    return CivilDate(next.year, next.month, next.day);
  }

  bool get isValid =>
      year >= 1 && month >= 1 && month <= 12 && day >= 1 && day <= daysInMonth;
  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;

  @override
  int compareTo(CivilDate other) {
    final yearOrder = year.compareTo(other.year);
    if (yearOrder != 0) return yearOrder;
    final monthOrder = month.compareTo(other.month);
    return monthOrder != 0 ? monthOrder : day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CivilDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

class EventInterval {
  const EventInterval({
    required this.startDayOffset,
    required this.startMinute,
    required this.endDayOffset,
    required this.endMinute,
    this.startFoldChoice,
    this.endFoldChoice,
  });

  final int startDayOffset;
  final int startMinute;
  final int endDayOffset;
  final int endMinute;
  final CivilTimeFoldChoice? startFoldChoice;
  final CivilTimeFoldChoice? endFoldChoice;

  bool get isValid =>
      startDayOffset >= 0 &&
      endDayOffset >= startDayOffset &&
      startMinute >= 0 &&
      startMinute < 1440 &&
      endMinute >= 0 &&
      endMinute < 1440 &&
      endEpochMinute > startEpochMinute;

  int get startEpochMinute => startDayOffset * 1440 + startMinute;
  int get endEpochMinute => endDayOffset * 1440 + endMinute;

  @override
  bool operator ==(Object other) =>
      other is EventInterval &&
      startDayOffset == other.startDayOffset &&
      startMinute == other.startMinute &&
      endDayOffset == other.endDayOffset &&
      endMinute == other.endMinute &&
      startFoldChoice == other.startFoldChoice &&
      endFoldChoice == other.endFoldChoice;

  @override
  int get hashCode => Object.hash(
    startDayOffset,
    startMinute,
    endDayOffset,
    endMinute,
    startFoldChoice,
    endFoldChoice,
  );

  factory EventInterval.sameDay({
    required int startMinute,
    required int endMinute,
  }) => EventInterval(
    startDayOffset: 0,
    startMinute: startMinute,
    endDayOffset: 0,
    endMinute: endMinute,
  );

  factory EventInterval.overnight({
    required int startMinute,
    required int endMinute,
  }) => EventInterval(
    startDayOffset: 0,
    startMinute: startMinute,
    endDayOffset: 1,
    endMinute: endMinute,
  );
}

/// Extends the last planned work interval to a picked local clock time.
/// A finish time earlier than the scheduled clock time is interpreted as the
/// following local day, preserving overnight shift boundaries explicitly.
List<EventInterval> intervalsWithOvertimeEnd(
  List<EventInterval> planned,
  int actualEndMinute,
) {
  if (planned.isEmpty || actualEndMinute < 0 || actualEndMinute >= 1440) {
    throw ArgumentError('A timed work interval and valid finish time are required.');
  }
  final updated = [...planned];
  final last = updated.last;
  var actualEndDayOffset = last.endDayOffset;
  if (actualEndMinute <= last.endMinute) actualEndDayOffset++;
  updated[updated.length - 1] = EventInterval(
    startDayOffset: last.startDayOffset,
    startMinute: last.startMinute,
    endDayOffset: actualEndDayOffset,
    endMinute: actualEndMinute,
    startFoldChoice: last.startFoldChoice,
    endFoldChoice: last.endFoldChoice,
  );
  return List.unmodifiable(updated);
}

class WeeklyRecurrence {
  WeeklyRecurrence({
    required Set<int> weekdays,
    required this.until,
    Set<CivilDate> exceptionDates = const {},
  }) : weekdays = Set.unmodifiable(weekdays),
       exceptionDates = Set.unmodifiable(exceptionDates) {
    if (this.weekdays.isEmpty ||
        this.weekdays.any(
          (day) => day < DateTime.monday || day > DateTime.sunday,
        )) {
      throw ArgumentError.value(
        weekdays,
        'weekdays',
        'Use one or more ISO weekdays (1-7).',
      );
    }
    if (this.exceptionDates.any((date) => !date.isValid)) {
      throw ArgumentError.value(
        exceptionDates,
        'exceptionDates',
        'Exceptions must be valid civil dates.',
      );
    }
  }

  /// ISO weekday numbers: Monday 1 through Sunday 7.
  final Set<int> weekdays;
  final CivilDate? until;

  /// Individual dates on which a matching weekly occurrence is cancelled.
  final Set<CivilDate> exceptionDates;
}

class ScheduleItem {
  ScheduleItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.startDate,
    required List<EventInterval> intervals,
    this.timeZoneId,
    this.code,
    this.codeMeaning,
    String? employerName,
    String? departmentName,
    String? jobRole,
    this.location,
    this.notes,
    this.reportingInstruction,
    String? supervisorName,
    String? supervisorPhone,
    String? contactName,
    String? contactPhone,
    this.academicTermId,
    this.recurrence,
    WorkCategory? workCategory,
    DeadlineType? deadlineType,
    bool isDayOff = false,
    this.allDay = false,
    this.importProvenance,
    this.reminderMinutesBefore,
    bool isCompleted = false,
    List<EventInterval>? actualIntervals,
  }) : workCategory = kind == ScheduleKind.work
           ? workCategory ??
                 (isDayOff ? WorkCategory.dayOff : WorkCategory.shift)
           : null,
       deadlineType = kind == ScheduleKind.deadline
           ? deadlineType ?? DeadlineType.examination
           : null,
       supervisorName = kind == ScheduleKind.work ? supervisorName : null,
       supervisorPhone = kind == ScheduleKind.work ? supervisorPhone : null,
       contactName = kind == ScheduleKind.work ? contactName : null,
       contactPhone = kind == ScheduleKind.work ? contactPhone : null,
       employerName = kind == ScheduleKind.work ? employerName : null,
       departmentName = kind == ScheduleKind.work ? departmentName : null,
       jobRole = kind == ScheduleKind.work ? jobRole : null,
       isCompleted =
           (kind == ScheduleKind.deadline ||
               (kind == ScheduleKind.work &&
                   (workCategory == null ||
                       workCategory == WorkCategory.shift ||
                       workCategory == WorkCategory.overtime))) &&
           isCompleted,
       actualIntervals = actualIntervals == null
           ? null
           : List.unmodifiable(actualIntervals),
       intervals = List.unmodifiable(intervals) {
    if (id.trim().isEmpty || title.trim().isEmpty) {
      throw ArgumentError('An event requires a non-empty ID and title.');
    }
    if (!startDate.isValid) throw ArgumentError.value(startDate, 'startDate');
    if (allDay && kind != ScheduleKind.personal) {
      throw ArgumentError('Only personal events can use this all-day flag.');
    }
    if (this.actualIntervals != null) {
      final actual = this.actualIntervals!;
      if (!supportsCompletionTracking || !this.isCompleted) {
        throw ArgumentError('Actual intervals require a completed shift or deadline.');
      }
      if (actual.length != this.intervals.length ||
          actual.asMap().entries.any((entry) {
            final planned = this.intervals[entry.key];
            final interval = entry.value;
            return interval.startEpochMinute != planned.startEpochMinute ||
                interval.endEpochMinute < planned.endEpochMinute;
          })) {
        throw ArgumentError('Actual intervals must preserve planned intervals and only extend them.');
      }
    }
    if (timeZoneId != null && timeZoneId!.trim().isEmpty) {
      throw ArgumentError.value(timeZoneId, 'timeZoneId');
    }
    if (academicTermId != null && academicTermId!.trim().isEmpty) {
      throw ArgumentError.value(academicTermId, 'academicTermId');
    }
    if (academicTermId != null &&
        kind != ScheduleKind.classSession &&
        kind != ScheduleKind.deadline) {
      throw ArgumentError('Only study events can belong to an academic term.');
    }
    final provenance = importProvenance;
    if (provenance != null &&
        (provenance.format.trim().isEmpty ||
            provenance.uid.trim().isEmpty ||
            provenance.uid.length > 1024 ||
            provenance.sourceName.length > 512 ||
            provenance.sourceText.length > 10 * 1024 * 1024 ||
            !provenance.importedAt.isUtc)) {
      throw ArgumentError.value(provenance, 'importProvenance');
    }
    if (reminderMinutesBefore != null &&
        !const {0, 5, 15, 30, 60, 1440}.contains(reminderMinutesBefore)) {
      throw ArgumentError.value(
        reminderMinutesBefore,
        'reminderMinutesBefore',
        'Choose a supported reminder time before the event.',
      );
    }
    if (reminderMinutesBefore != null &&
        (allDay ||
            (kind == ScheduleKind.work &&
                (workCategory ?? WorkCategory.shift).isAllDay) ||
            (kind == ScheduleKind.deadline &&
                (deadlineType ?? DeadlineType.examination) ==
                    DeadlineType.assignment))) {
      throw ArgumentError('Reminders need a timed event.');
    }
    final recurrenceEnd = recurrence?.until;
    if (recurrenceEnd != null && !recurrenceEnd.isValid) {
      throw ArgumentError.value(
        recurrenceEnd,
        'recurrence.until',
        'Recurrence end must be a valid civil date.',
      );
    }
    if (recurrenceEnd != null && recurrenceEnd.compareTo(startDate) < 0) {
      throw ArgumentError.value(
        recurrenceEnd,
        'recurrence.until',
        'Recurrence cannot end before it starts.',
      );
    }
    for (final exceptionDate
        in recurrence?.exceptionDates ?? const <CivilDate>{}) {
      if (exceptionDate.compareTo(startDate) < 0 ||
          (recurrenceEnd != null &&
              exceptionDate.compareTo(recurrenceEnd) > 0) ||
          !recurrence!.weekdays.contains(exceptionDate.weekday)) {
        throw ArgumentError.value(
          exceptionDate,
          'recurrence.exceptionDates',
          'An exception must be a scheduled weekday within the recurrence term.',
        );
      }
    }
    if (hasNoTime && this.intervals.isNotEmpty) {
      throw ArgumentError('All-day entries cannot contain time intervals.');
    }
    if (!hasNoTime &&
        (this.intervals.isEmpty ||
            this.intervals.any((part) => !part.isValid))) {
      throw ArgumentError(
        'Timed events need valid, positive-duration intervals.',
      );
    }
    if (this.intervals.length > 1) {
      final sorted = [...this.intervals]
        ..sort((a, b) => a.startEpochMinute.compareTo(b.startEpochMinute));
      for (var i = 1; i < sorted.length; i++) {
        if (sorted[i].startEpochMinute < sorted[i - 1].endEpochMinute) {
          throw ArgumentError('Intervals in one split event cannot overlap.');
        }
      }
    }
  }

  final String id;
  final ScheduleKind kind;
  final String title;
  final CivilDate startDate;
  final List<EventInterval> intervals;

  /// IANA zone captured when the event was entered. Null is reserved for
  /// records created before zone persistence was introduced.
  final String? timeZoneId;
  final String? code;
  final String? codeMeaning;
  final String? employerName;
  final String? departmentName;
  final String? jobRole;
  final String? location;
  final String? notes;
  final String? reportingInstruction;
  final String? supervisorName;
  final String? supervisorPhone;
  final String? contactName;
  final String? contactPhone;
  final String? academicTermId;
  final WeeklyRecurrence? recurrence;
  final WorkCategory? workCategory;
  final DeadlineType? deadlineType;
  final bool isCompleted;
  final List<EventInterval>? actualIntervals;

  bool get supportsCompletionTracking =>
      kind == ScheduleKind.deadline ||
      (kind == ScheduleKind.work &&
          (workCategory == WorkCategory.shift ||
              workCategory == WorkCategory.overtime));
  final bool allDay;
  final ScheduleImportProvenance? importProvenance;
  final int? reminderMinutesBefore;

  bool get isDayOff => workCategory == WorkCategory.dayOff;
  bool get hasNoTime =>
      allDay ||
      (workCategory?.isAllDay ??
          (kind == ScheduleKind.deadline &&
              deadlineType == DeadlineType.assignment));

  ScheduleItem copyWith({
    String? title,
    Object? code = _unchanged,
    Object? codeMeaning = _unchanged,
    Object? employerName = _unchanged,
    Object? departmentName = _unchanged,
    Object? jobRole = _unchanged,
    Object? location = _unchanged,
    Object? notes = _unchanged,
    Object? reportingInstruction = _unchanged,
    Object? supervisorName = _unchanged,
    Object? supervisorPhone = _unchanged,
    Object? contactName = _unchanged,
    Object? contactPhone = _unchanged,
    Object? academicTermId = _unchanged,
    Object? reminderMinutesBefore = _unchanged,
    bool? isCompleted,
    Object? actualIntervals = _unchanged,
  }) => ScheduleItem(
    id: id,
    kind: kind,
    title: title ?? this.title,
    startDate: startDate,
    intervals: intervals,
    timeZoneId: timeZoneId,
    code: _optionalValue(code, this.code),
    codeMeaning: _optionalValue(codeMeaning, this.codeMeaning),
    employerName: _optionalValue(employerName, this.employerName),
    departmentName: _optionalValue(departmentName, this.departmentName),
    jobRole: _optionalValue(jobRole, this.jobRole),
    location: _optionalValue(location, this.location),
    notes: _optionalValue(notes, this.notes),
    reportingInstruction: _optionalValue(
      reportingInstruction,
      this.reportingInstruction,
    ),
    supervisorName: _optionalValue(supervisorName, this.supervisorName),
    supervisorPhone: _optionalValue(supervisorPhone, this.supervisorPhone),
    contactName: _optionalValue(contactName, this.contactName),
    contactPhone: _optionalValue(contactPhone, this.contactPhone),
    academicTermId: _optionalValue(academicTermId, this.academicTermId),
    recurrence: recurrence,
    workCategory: workCategory,
    deadlineType: deadlineType,
    isCompleted: isCompleted ?? this.isCompleted,
    actualIntervals: identical(actualIntervals, _unchanged)
        ? this.actualIntervals
        : actualIntervals as List<EventInterval>?,
    allDay: allDay,
    importProvenance: importProvenance,
    reminderMinutesBefore: identical(reminderMinutesBefore, _unchanged)
        ? this.reminderMinutesBefore
        : reminderMinutesBefore as int?,
  );
}

String? _optionalValue(Object? requested, String? existing) =>
    identical(requested, _unchanged) ? existing : requested as String?;

class EventOccurrence {
  const EventOccurrence({required this.item, required this.date});

  final ScheduleItem item;
  final CivilDate date;

  List<ResolvedInterval> get intervals => item.intervals
      .map(
        (part) => ResolvedInterval(
          start: _civilMinute(
            date.addDays(part.startDayOffset),
            part.startMinute,
          ),
          end: _civilMinute(date.addDays(part.endDayOffset), part.endMinute),
        ),
      )
      .toList(growable: false);
}

class ResolvedInterval {
  const ResolvedInterval({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}

DateTime _civilMinute(CivilDate date, int minute) =>
    DateTime(date.year, date.month, date.day, minute ~/ 60, minute % 60);
