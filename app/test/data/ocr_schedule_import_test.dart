import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/ocr_schedule_import.dart';
import 'package:shift_study/domain/schedule.dart';

void main() {
  const parser = OcrScheduleImportParser();

  test('drafts only clear ISO date and 24-hour time rows', () async {
    final preview = await parser.parse(
      text: '''2026-11-09 Operations Management 10:00 11:30 Room B204
2026-11-10 Ramp shift 21:00 05:00
Nov 11, 2026 unclear roster line
2026-02-30 Invalid date 09:00 10:00
2026-11-12 Two classes 09:00 10:00 and 13:00 14:00''',
      sourceName: 'synthetic.pdf',
      timeZoneId: 'America/Barbados',
      clock: () => DateTime.utc(2026, 11, 8),
    );

    expect(preview.proposals, hasLength(2));
    expect(
      preview.proposals.first.item.title,
      'Operations Management Room B204',
    );
    expect(preview.proposals.first.item.kind, ScheduleKind.personal);
    expect(preview.proposals.first.item.importProvenance!.format, 'pdf-ocr');
    expect(
      preview.proposals.first.item.importProvenance!.sourceText,
      contains('10:00'),
    );
    expect(preview.proposals[1].item.intervals.single.endDayOffset, 1);
    expect(preview.notices, hasLength(1));
    expect(
      preview.notices.single.message,
      contains('3 lines need manual review'),
    );
  });

  test(
    'does not create proposals without an unambiguous date and time pair',
    () async {
      final preview = await parser.parse(
        text:
            '11/09/2026 Shift A 08:00 16:00\n2026-11-09 Class 8:00 AM 9:00 AM',
        sourceName: 'synthetic.png',
        timeZoneId: 'America/Barbados',
      );

      expect(preview.proposals, isEmpty);
      expect(preview.notices, hasLength(1));
    },
  );

  test('reviews named-month AM/PM exam rows with stated duration', () async {
    final preview = await parser.parse(
      text: '''4/Dec/26 9:00 A.M. BIOL1100 Introductory Biology 2 HRS
31/Feb/26 1:00 P.M. MATH1200 Calculus 1 HRS
5/Dec/26 9:00 A.M. CHEM1100 Chemistry 2 HRS additional 10:00 AM''',
      sourceName: 'synthetic-exams.pdf',
      timeZoneId: 'America/Barbados',
      examTimetable: true,
      clock: () => DateTime.utc(2026, 11, 8),
    );

    expect(preview.proposals, hasLength(1));
    final exam = preview.proposals.single.item;
    expect(exam.kind, ScheduleKind.deadline);
    expect(exam.deadlineType, DeadlineType.examination);
    expect(exam.title, 'Introductory Biology');
    expect(exam.code, 'BIOL1100');
    expect(exam.startDate, const CivilDate(2026, 12, 4));
    expect(exam.intervals.single.startMinute, 9 * 60);
    expect(exam.intervals.single.endMinute, 11 * 60);
    expect(exam.importProvenance!.format, 'exam-timetable-ocr');
    expect(
      preview.notices.single.message,
      contains('2 lines need manual review'),
    );
  });

  test('does not reinterpret generic OCR as an exam timetable', () async {
    final preview = await parser.parse(
      text: '4/Dec/26 9:00 A.M. BIOL1100 Introductory Biology 2 HRS',
      sourceName: 'synthetic-exams.pdf',
      timeZoneId: 'America/Barbados',
    );

    expect(preview.proposals, isEmpty);
    expect(preview.notices, hasLength(1));
  });

  test('recognizes a full-year hyphenated exam date from a PDF line', () async {
    final preview = await parser.parse(
      text: '19-Nov-2026 1:30 PM COMP1170 Computing systems 2 HOURS',
      sourceName: 'StudyShift_Synthetic_Import.pdf',
      timeZoneId: 'America/Barbados',
      examTimetable: true,
      clock: () => DateTime.utc(2026, 11, 15),
    );

    expect(preview.proposals, hasLength(1));
    final exam = preview.proposals.single.item;
    expect(exam.title, 'Computing systems');
    expect(exam.code, 'COMP1170');
    expect(exam.startDate, const CivilDate(2026, 11, 19));
    expect(exam.intervals.single.startMinute, 13 * 60 + 30);
    expect(exam.intervals.single.endMinute, 15 * 60 + 30);
  });

  test(
    'keeps OCR event identity across filenames and separates repeated rows',
    () async {
      const repeatedExam =
          '4/Dec/26 9:00 A.M. BIOL1100 Introductory Biology 2 HRS';
      const text = '$repeatedExam\n$repeatedExam';
      final firstImport = await parser.parse(
        text: text,
        sourceName: 'first-name.pdf',
        timeZoneId: 'America/Barbados',
        examTimetable: true,
      );
      final renamedImport = await parser.parse(
        text: text,
        sourceName: 'renamed-copy.pdf',
        timeZoneId: 'America/Barbados',
        examTimetable: true,
      );

      expect(firstImport.proposals, hasLength(2));
      expect(renamedImport.proposals, hasLength(2));
      final firstIds = firstImport.proposals
          .map((proposal) => proposal.item.id)
          .toList();
      final renamedIds = renamedImport.proposals
          .map((proposal) => proposal.item.id)
          .toList();
      expect(firstIds.toSet(), hasLength(2));
      expect(renamedIds, firstIds);
    },
  );

  test(
    'caps OCR proposals and reports the remaining rows for manual review',
    () async {
      final text = List.generate(
        301,
        (index) => '2026-11-09 Sample event $index 09:00 10:00',
      ).join('\n');
      final preview = await parser.parse(
        text: text,
        sourceName: 'synthetic.pdf',
        timeZoneId: 'America/Barbados',
      );

      expect(preview.proposals, hasLength(300));
      expect(
        preview.notices.single.message,
        contains('1 additional clear row'),
      );
    },
  );
}
