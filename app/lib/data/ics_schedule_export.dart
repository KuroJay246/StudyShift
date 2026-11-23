import 'dart:convert';
import 'dart:typed_data';

import 'package:firstfloor_calendar/firstfloor_calendar.dart'
    hide EventOccurrence;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/schedule.dart';
import '../domain/schedule_engine.dart';

class IcsScheduleExport {
  const IcsScheduleExport(this._engine);

  static const maxEvents = 500;
  static const maxBytes = 5 * 1024 * 1024;
  static bool _timeZonesInitialized = false;

  final ScheduleEngine _engine;

  Uint8List encode(Iterable<ScheduleItem> items, {required DateTime now}) {
    final stableItems = List<ScheduleItem>.unmodifiable(items);
    _initializeTimeZones();
    final events = <CalendarDocumentComponent>[];
    for (final item in stableItems) {
      if (item.hasNoTime) {
        events.add(_allDayEvent(item, now));
        if (events.length > maxEvents) _throwTooManyEvents();
        continue;
      }
      final occurrence = EventOccurrence(item: item, date: item.startDate);
      final resolved = _engine.resolveOccurrence(occurrence);
      if (resolved.issues.isNotEmpty ||
          resolved.intervals.length != item.intervals.length) {
        throw FormatException(
          '“${item.title}” has a time that needs review before calendar export.',
        );
      }
      for (var index = 0; index < resolved.intervals.length; index++) {
        final interval = resolved.intervals[index];
        events.add(
          _timedEvent(
            item,
            index,
            interval,
            now,
            splitCount: resolved.intervals.length,
          ),
        );
        if (events.length > maxEvents) _throwTooManyEvents();
        if (events.length > maxEvents) {
          throw const FormatException(
            'This schedule is too large for one calendar file. Export a smaller schedule first.',
          );
        }
      }
    }

    final calendar = CalendarDocument(
      properties: const [
        CalendarProperty(name: 'VERSION', value: '2.0'),
        CalendarProperty(name: 'PRODID', value: '-//StudyShift//Android//EN'),
        CalendarProperty(name: 'CALSCALE', value: 'GREGORIAN'),
        CalendarProperty(name: 'X-WR-CALNAME', value: 'StudyShift'),
      ],
      components: events,
    );
    final bytes = Uint8List.fromList(utf8.encode(calendar.toIcsString()));
    if (bytes.length > maxBytes) {
      throw const FormatException(
        'This schedule is too large for one calendar file.',
      );
    }
    return bytes;
  }

  CalendarDocumentComponent _allDayEvent(ScheduleItem item, DateTime now) {
    final nextDay = item.startDate.addDays(1);
    return _event(
      item,
      0,
      now,
      summary: item.title,
      properties: [
        CalendarProperty(
          name: 'DTSTART',
          parameters: const {
            'VALUE': ['DATE'],
          },
          value: _date(item.startDate),
        ),
        CalendarProperty(
          name: 'DTEND',
          parameters: const {
            'VALUE': ['DATE'],
          },
          value: _date(nextDay),
        ),
        ..._recurrenceProperties(item),
      ],
      partCount: 1,
    );
  }

  CalendarDocumentComponent _timedEvent(
    ScheduleItem item,
    int intervalIndex,
    ResolvedInterval interval,
    DateTime now, {
    required int splitCount,
  }) {
    final zoneId = item.timeZoneId;
    if (zoneId == null) {
      throw FormatException('“${item.title}” needs a time zone before export.');
    }
    final zone = tz.getLocation(zoneId);
    final localStart = tz.TZDateTime.from(interval.start, zone);
    final localEnd = tz.TZDateTime.from(interval.end, zone);
    return _event(
      item,
      intervalIndex,
      now,
      summary: item.title,
      properties: [
        CalendarProperty(
          name: 'DTSTART',
          parameters: {
            'TZID': [zoneId],
          },
          value: _localDateTime(localStart),
        ),
        CalendarProperty(
          name: 'DTEND',
          parameters: {
            'TZID': [zoneId],
          },
          value: _localDateTime(localEnd),
        ),
        ..._recurrenceProperties(item, intervalIndex: intervalIndex),
      ],
      partCount: splitCount,
    );
  }

  CalendarDocumentComponent _event(
    ScheduleItem item,
    int intervalIndex,
    DateTime now, {
    required String summary,
    required List<CalendarProperty> properties,
    required int partCount,
  }) {
    final notes = [
      if (item.code?.trim().isNotEmpty ?? false) 'Code: ${item.code!.trim()}',
      if (item.codeMeaning?.trim().isNotEmpty ?? false)
        'Code assignment / flights: ${item.codeMeaning!.trim()}',
      if (item.reportingInstruction?.trim().isNotEmpty ?? false)
        'Reporting instructions: ${item.reportingInstruction!.trim()}',
      if (item.notes?.trim().isNotEmpty ?? false) item.notes!.trim(),
    ].join('\n');
    final uid = base64Url
        .encode(utf8.encode('${item.id}:part:$intervalIndex'))
        .replaceAll('=', '');
    return CalendarDocumentComponent(
      name: 'VEVENT',
      properties: [
        CalendarProperty(name: 'UID', value: '$uid@shiftstudy.local'),
        CalendarProperty(name: 'DTSTAMP', value: _utc(now)),
        ...properties,
        CalendarProperty(name: 'SUMMARY', value: _escape(summary)),
        if (item.location?.trim().isNotEmpty ?? false)
          CalendarProperty(
            name: 'LOCATION',
            value: _escape(item.location!.trim()),
          ),
        if (notes.isNotEmpty)
          CalendarProperty(name: 'DESCRIPTION', value: _escape(notes)),
        CalendarProperty(name: 'CATEGORIES', value: _category(item)),
        CalendarProperty(name: 'X-SHIFT-STUDY-ID', value: _escape(item.id)),
        CalendarProperty(name: 'X-SHIFT-STUDY-EXPORT', value: '2'),
        CalendarProperty(
          name: 'X-SHIFT-STUDY-PART',
          value: '${intervalIndex + 1}',
        ),
        CalendarProperty(name: 'X-SHIFT-STUDY-PARTS', value: '$partCount'),
        if (item.coworkers.isNotEmpty)
          CalendarProperty(
            name: 'X-SHIFT-STUDY-COWORKERS',
            value: base64Url
                .encode(utf8.encode(jsonEncode(item.coworkers)))
                .replaceAll('=', ''),
          ),
        if (item.supportsCompletionTracking && item.isCompleted)
          const CalendarProperty(name: 'X-SHIFT-STUDY-COMPLETED', value: '1'),
        if (item.actualIntervals != null)
          CalendarProperty(
            name: 'X-SHIFT-STUDY-ACTUAL-END',
            value: [
              item.actualIntervals![intervalIndex].endDayOffset,
              item.actualIntervals![intervalIndex].endMinute,
              item.actualIntervals![intervalIndex].endFoldChoice?.name ?? '-',
            ].join(';'),
          ),
        if (!item.hasNoTime && item.timeZoneId != null)
          CalendarProperty(
            name: 'X-SHIFT-STUDY-TZID',
            value: _escape(item.timeZoneId!),
          ),
      ],
    );
  }

  List<CalendarProperty> _recurrenceProperties(
    ScheduleItem item, {
    int? intervalIndex,
  }) {
    final recurrence = item.recurrence;
    if (recurrence == null) return const [];
    final days = <int, String>{
      DateTime.monday: 'MO',
      DateTime.tuesday: 'TU',
      DateTime.wednesday: 'WE',
      DateTime.thursday: 'TH',
      DateTime.friday: 'FR',
      DateTime.saturday: 'SA',
      DateTime.sunday: 'SU',
    };
    final byDay = recurrence.weekdays.toList()..sort();
    final properties = <CalendarProperty>[
      CalendarProperty(
        name: 'RRULE',
        value: [
          'FREQ=WEEKLY',
          'BYDAY=${byDay.map((day) => days[day]!).join(',')}',
          if (recurrence.until != null)
            'UNTIL=${_recurrenceUntil(item, recurrence.until!)}',
        ].join(';'),
      ),
    ];
    for (final date in recurrence.exceptionDates.toList()..sort()) {
      properties.add(
        CalendarProperty(
          name: 'EXDATE',
          parameters: item.hasNoTime || item.timeZoneId == null
              ? const {
                  'VALUE': ['DATE'],
                }
              : {
                  'TZID': [item.timeZoneId!],
                },
          value: item.hasNoTime || item.timeZoneId == null
              ? _date(date)
              : _localDateTime(
                  tz.TZDateTime(
                    tz.getLocation(item.timeZoneId!),
                    date.year,
                    date.month,
                    date.day,
                    item.intervals[intervalIndex ?? 0].startMinute ~/ 60,
                    item.intervals[intervalIndex ?? 0].startMinute % 60,
                  ),
                ),
        ),
      );
    }
    return properties;
  }

  String _recurrenceUntil(ScheduleItem item, CivilDate date) {
    if (item.hasNoTime || item.timeZoneId == null) return _date(date);
    final localEnd = tz.TZDateTime(
      tz.getLocation(item.timeZoneId!),
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
    );
    return _utc(localEnd.toUtc());
  }

  static void _initializeTimeZones() {
    if (_timeZonesInitialized) return;
    tzdata.initializeTimeZones();
    _timeZonesInitialized = true;
  }

  String _localDateTime(DateTime value) =>
      '${_date(CivilDate.fromDateTime(value))}T${value.hour.toString().padLeft(2, '0')}${value.minute.toString().padLeft(2, '0')}${value.second.toString().padLeft(2, '0')}';

  Never _throwTooManyEvents() => throw const FormatException(
    'This schedule is too large for one calendar file. Export a smaller schedule first.',
  );

  String _category(ScheduleItem item) => switch (item.kind) {
    ScheduleKind.work => 'WORK,${item.workCategory!.name.toUpperCase()}',
    ScheduleKind.classSession => 'SCHOOL',
    ScheduleKind.personal => 'PERSONAL',
    ScheduleKind.deadline => item.deadlineType!.name.toUpperCase(),
  };

  String _date(CivilDate date) =>
      '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

  String _utc(DateTime value) {
    final utc = value.toUtc();
    return '${_date(CivilDate.fromDateTime(utc))}T${utc.hour.toString().padLeft(2, '0')}${utc.minute.toString().padLeft(2, '0')}${utc.second.toString().padLeft(2, '0')}Z';
  }

  String _escape(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,')
      .replaceAll('\r\n', r'\n')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\n');
}
