import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/schedule.dart';
import 'schedule_import_models.dart';

/// Makes only conservative draft proposals from OCR. Unknown codes, dates and
/// layouts remain in the text review instead of being guessed as schedule data.
class OcrScheduleImportParser {
  const OcrScheduleImportParser();

  static const _maxProposals = 300;
  static const _maxLines = 5000;
  static final _datePattern = RegExp(r'(?<!\d)(\d{4}-\d{2}-\d{2})(?!\d)');
  static final _timePattern = RegExp(
    r'(?<!\d)((?:[01]\d|2[0-3])):([0-5]\d)(?!\d)',
  );
  static final _examDatePattern = RegExp(
    r'(?<!\d)(\d{1,2})\s*[/ -]\s*([A-Za-z]{3,9})\s*[/ -]\s*(\d{2}|20\d{2})(?!\d)',
  );
  static final _examTimePattern = RegExp(
    r'(?<!\d)(\d{1,2}):([0-5]\d)\s*([AP])\.?\s*M\.?',
    caseSensitive: false,
  );
  static final _courseCodePattern = RegExp(r'\b[A-Z]{2,5}\s?\d{3,5}\b');
  static final _durationPattern = RegExp(
    r'\b(\d{1,2})\s*(?:HRS?|HOURS?)\b',
    caseSensitive: false,
  );

  Future<ScheduleImportPreview> parse({
    required String text,
    required String sourceName,
    required String timeZoneId,
    bool examTimetable = false,
    DateTime Function()? clock,
  }) async {
    if (text.length > 500_000) {
      throw const FormatException(
        'Recognized text is larger than the review limit.',
      );
    }
    final lines = text.split(RegExp(r'\r?\n'));
    final truncatedLines = lines.length > _maxLines;
    final proposals = <ScheduleImportProposal>[];
    final identityOccurrences = <String, int>{};
    var uncertainLines = 0;
    var overflowLines = 0;
    final importedAt = (clock?.call() ?? DateTime.now()).toUtc();
    for (var index = 0; index < lines.length && index < _maxLines; index++) {
      final line = lines[index].trim().replaceAll(RegExp(r'\s+'), ' ');
      if (line.isEmpty || line.startsWith('--- Page ')) continue;
      if (examTimetable) {
        final examProposal = _examProposal(
          line: line,
          sourceName: sourceName,
          sourceLineIndex: index,
          timeZoneId: timeZoneId,
          importedAt: importedAt,
        );
        if (examProposal != null) {
          if (proposals.length >= _maxProposals) {
            overflowLines++;
          } else {
            proposals.add(
              _withStableIdentity(examProposal, identityOccurrences),
            );
          }
          continue;
        }
      }
      final dates = _datePattern.allMatches(line).toList();
      final times = _timePattern.allMatches(line).toList();
      if (dates.length != 1 ||
          times.length != 2 ||
          RegExp(r'\b(?:AM|PM)\b', caseSensitive: false).hasMatch(line)) {
        uncertainLines++;
        continue;
      }
      final dateText = dates.single.group(1)!;
      final date = DateTime.tryParse(dateText);
      final startMinute = _minute(times[0]);
      final endMinute = _minute(times[1]);
      final title = line
          .replaceRange(dates.single.start, dates.single.end, ' ')
          .replaceAll(_timePattern, ' ')
          .replaceAll(RegExp(r'^[\s,;|–—-]+|[\s,;|–—-]+$'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (date == null ||
          date.year.toString().padLeft(4, '0') != dateText.substring(0, 4) ||
          date.month != int.parse(dateText.substring(5, 7)) ||
          date.day != int.parse(dateText.substring(8, 10)) ||
          title.length < 2 ||
          startMinute == endMinute) {
        uncertainLines++;
        continue;
      }
      if (proposals.length >= _maxProposals) {
        overflowLines++;
        continue;
      }
      final sourceLine = lines[index].trim();
      final key = sha256
          .convert(utf8.encode('$sourceName\n$index\n$sourceLine'))
          .toString();
      final proposal = ScheduleImportProposal(
        item: ScheduleItem(
          id: 'ocr-$key',
          kind: ScheduleKind.personal,
          title: title,
          startDate: CivilDate(date.year, date.month, date.day),
          intervals: [
            startMinute < endMinute
                ? EventInterval.sameDay(
                    startMinute: startMinute,
                    endMinute: endMinute,
                  )
                : EventInterval.overnight(
                    startMinute: startMinute,
                    endMinute: endMinute,
                  ),
          ],
          timeZoneId: timeZoneId,
          importProvenance: ScheduleImportProvenance(
            format: sourceName.toLowerCase().endsWith('.pdf')
                ? 'pdf-ocr'
                : 'image-ocr',
            uid: 'line-$index-$key',
            sourceName: sourceName,
            sourceText: sourceLine,
            importedAt: importedAt,
          ),
        ),
        sourceText: sourceLine,
      );
      proposals.add(_withStableIdentity(proposal, identityOccurrences));
    }
    return ScheduleImportPreview(
      proposals: proposals,
      notices: uncertainLines == 0 && overflowLines == 0 && !truncatedLines
          ? const []
          : [
              ScheduleImportNotice(
                [
                  if (uncertainLines > 0)
                    '$uncertainLines line${uncertainLines == 1 ? '' : 's'} need manual review. Only lines with one ISO date and exactly two clear 24-hour times were drafted.',
                  if (overflowLines > 0)
                    '$overflowLines additional clear row${overflowLines == 1 ? '' : 's'} exceeded the 300-event review limit and were not drafted.',
                  if (truncatedLines) 'OCR reached the 5,000-line review limit. Remaining text was not checked; review the rest manually.',
                ].join(' '),
              ),
            ],
    );
  }

  int _minute(RegExpMatch match) =>
      int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);

  ScheduleImportProposal _withStableIdentity(
    ScheduleImportProposal proposal,
    Map<String, int> identityOccurrences,
  ) {
    final item = proposal.item;
    final canonicalTitle = item.title
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    final canonicalCode = item.code
        ?.replaceAll(RegExp(r'\s+'), '')
        .toUpperCase();
    final identity = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              item.kind.name,
              item.deadlineType?.name,
              item.startDate.year,
              item.startDate.month,
              item.startDate.day,
              canonicalTitle,
              canonicalCode,
              item.timeZoneId,
              [
                for (final interval in item.intervals)
                  [
                    interval.startDayOffset,
                    interval.startMinute,
                    interval.endDayOffset,
                    interval.endMinute,
                  ],
              ],
            ]),
          ),
        )
        .toString();
    final occurrence = identityOccurrences.update(
      identity,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    final stableUid = 'event-$identity-$occurrence';
    final provenance = item.importProvenance!;
    return ScheduleImportProposal(
      item: ScheduleItem(
        id: 'ocr-$identity-$occurrence',
        kind: item.kind,
        title: item.title,
        startDate: item.startDate,
        intervals: item.intervals,
        timeZoneId: item.timeZoneId,
        code: item.code,
        codeMeaning: item.codeMeaning,
        employerName: item.employerName,
        departmentName: item.departmentName,
        jobRole: item.jobRole,
        location: item.location,
        notes: item.notes,
        reportingInstruction: item.reportingInstruction,
        supervisorName: item.supervisorName,
        supervisorPhone: item.supervisorPhone,
        contactName: item.contactName,
        contactPhone: item.contactPhone,
        coworkers: item.coworkers,
        academicTermId: item.academicTermId,
        recurrence: item.recurrence,
        workCategory: item.workCategory,
        deadlineType: item.deadlineType,
        isDayOff: item.isDayOff,
        allDay: item.allDay,
        isCompleted: item.isCompleted,
        reminderMinutesBefore: item.reminderMinutesBefore,
        importProvenance: ScheduleImportProvenance(
          format: provenance.format,
          uid: stableUid,
          sourceName: provenance.sourceName,
          sourceText: provenance.sourceText,
          importedAt: provenance.importedAt,
        ),
      ),
      sourceText: proposal.sourceText,
    );
  }

  ScheduleImportProposal? _examProposal({
    required String line,
    required String sourceName,
    required int sourceLineIndex,
    required String timeZoneId,
    required DateTime importedAt,
  }) {
    final dates = _examDatePattern.allMatches(line).toList();
    final times = _examTimePattern.allMatches(line).toList();
    final codes = _courseCodePattern.allMatches(line).toList();
    final durations = _durationPattern.allMatches(line).toList();
    if (dates.length != 1 ||
        times.length != 1 ||
        codes.length != 1 ||
        durations.length != 1) {
      return null;
    }

    final dateMatch = dates.single;
    final month = _monthNumber(dateMatch.group(2)!);
    final day = int.parse(dateMatch.group(1)!);
    final yearText = dateMatch.group(3)!;
    final year = yearText.length == 2
        ? 2000 + int.parse(yearText)
        : int.parse(yearText);
    if (month == null) return null;
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    final time = times.single;
    final hour12 = int.parse(time.group(1)!);
    if (hour12 < 1 || hour12 > 12) return null;
    final isPm = time.group(3)!.toUpperCase() == 'P';
    final startMinute =
        ((hour12 % 12) + (isPm ? 12 : 0)) * 60 + int.parse(time.group(2)!);
    final durationMinutes = int.parse(durations.single.group(1)!) * 60;
    if (durationMinutes < 30 || durationMinutes > 12 * 60) return null;
    final endEpochMinute = startMinute + durationMinutes;

    final codeMatch = codes.single;
    final code = codeMatch
        .group(0)!
        .replaceAll(RegExp(r'\s+'), '')
        .toUpperCase();
    final title = line
        .replaceAll(dateMatch.group(0)!, ' ')
        .replaceAll(time.group(0)!, ' ')
        .replaceAll(codeMatch.group(0)!, ' ')
        .replaceAll(durations.single.group(0)!, ' ')
        .replaceAll(RegExp(r'^[\s,;|–—-]+|[\s,;|–—-]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (title.length < 2) return null;

    final sourceText = line;
    final key = sha256
        .convert(utf8.encode('$sourceName\n$sourceLineIndex\n$sourceText'))
        .toString();
    return ScheduleImportProposal(
      item: ScheduleItem(
        id: 'ocr-exam-$key',
        kind: ScheduleKind.deadline,
        deadlineType: DeadlineType.examination,
        title: title,
        code: code,
        startDate: CivilDate(year, month, day),
        intervals: [
          endEpochMinute < 1440
              ? EventInterval.sameDay(
                  startMinute: startMinute,
                  endMinute: endEpochMinute,
                )
              : EventInterval.overnight(
                  startMinute: startMinute,
                  endMinute: endEpochMinute - 1440,
                ),
        ],
        timeZoneId: timeZoneId,
        importProvenance: ScheduleImportProvenance(
          format: 'exam-timetable-ocr',
          uid: 'line-$sourceLineIndex-$key',
          sourceName: sourceName,
          sourceText: sourceText,
          importedAt: importedAt,
        ),
      ),
      sourceText: sourceText,
    );
  }

  int? _monthNumber(String value) =>
      switch (value.toLowerCase().substring(0, 3)) {
        'jan' => 1,
        'feb' => 2,
        'mar' => 3,
        'apr' => 4,
        'may' => 5,
        'jun' => 6,
        'jul' => 7,
        'aug' => 8,
        'sep' => 9,
        'oct' => 10,
        'nov' => 11,
        'dec' => 12,
        _ => null,
      };
}
