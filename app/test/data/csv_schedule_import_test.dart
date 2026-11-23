import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/csv_schedule_import.dart';
import 'package:shift_study/domain/schedule.dart';

void main() {
  const parser = CsvScheduleImportParser();

  test(
    'reads quoted CSV fields and keeps overnight work on the next day',
    () async {
      final preview = await parser.parse(
        'date,title,category,start,end,time_zone,employer,department,job_role,code,code_meaning,coworkers,location,notes,reporting_instruction,supervisor_name,supervisor_phone,contact_name,contact_phone\r\n'
        '2026-11-07,"Ramp, east",shift,21:00,05:00,America/Barbados,Synthetic Air,Synthetic ramp operations,Ramp agent,R1,"Synthetic ramp duty","Synthetic teammate A; Synthetic teammate B",Airport,"Use stand ""B""","Synthetic report at gate 2",Synthetic supervisor,+1 246 555 0100,Synthetic ops desk,+1 246 555 0101\r\n',
        sourceName: 'roster.csv',
        importedAt: DateTime.utc(2026, 11, 6),
      );

      expect(
        preview.notices,
        isEmpty,
        reason: preview.notices.map((notice) => notice.message).join('; '),
      );
      final item = preview.proposals.single.item;
      expect(item.kind, ScheduleKind.work);
      expect(item.workCategory, WorkCategory.shift);
      expect(item.title, 'Ramp, east');
      expect(item.startDate, const CivilDate(2026, 11, 7));
      expect(item.intervals.single.startMinute, 21 * 60);
      expect(item.intervals.single.endDayOffset, 1);
      expect(item.intervals.single.endMinute, 5 * 60);
      expect(item.timeZoneId, 'America/Barbados');
      expect(item.employerName, 'Synthetic Air');
      expect(item.departmentName, 'Synthetic ramp operations');
      expect(item.jobRole, 'Ramp agent');
      expect(item.location, 'Airport');
      expect(item.notes, 'Use stand "B"');
      expect(item.reportingInstruction, 'Synthetic report at gate 2');
      expect(item.codeMeaning, 'Synthetic ramp duty');
      expect(item.coworkers, ['Synthetic teammate A', 'Synthetic teammate B']);
      expect(item.supervisorName, 'Synthetic supervisor');
      expect(item.supervisorPhone, '+1 246 555 0100');
      expect(item.contactName, 'Synthetic ops desk');
      expect(item.contactPhone, '+1 246 555 0101');
      expect(item.importProvenance!.format, 'Shift & Study CSV v1');
      expect(item.importProvenance!.sourceName, 'roster.csv');
      expect(item.importProvenance!.sourceText, contains('"Ramp, east"'));
      expect(item.importProvenance!.importedAt, DateTime.utc(2026, 11, 6));
    },
  );

  test(
    'maps all-day work and school deadlines without invented times',
    () async {
      final preview = await parser.parse(
        'date,title,category\n'
        '2026-11-08,Rest day,rest_day\n'
        '2026-11-09,Essay due,assignment\n',
        sourceName: 'term.csv',
      );

      expect(
        preview.notices,
        isEmpty,
        reason: preview.notices.map((notice) => notice.message).join('; '),
      );
      expect(preview.proposals[0].item.workCategory, WorkCategory.restDay);
      expect(preview.proposals[0].item.intervals, isEmpty);
      expect(preview.proposals[1].item.kind, ScheduleKind.deadline);
      expect(preview.proposals[1].item.deadlineType, DeadlineType.assignment);
      expect(preview.proposals[1].item.hasNoTime, isTrue);
    },
  );

  test('imports overtime as a timed work duty', () async {
    final preview = await parser.parse(
      'date,title,category,start,end,time_zone,code\n'
      '2026-11-09,Overtime cover,overtime,18:00,21:30,America/Barbados,OT\n',
      sourceName: 'overtime.csv',
    );

    expect(preview.notices, isEmpty);
    final item = preview.proposals.single.item;
    expect(item.kind, ScheduleKind.work);
    expect(item.workCategory, WorkCategory.overtime);
    expect(item.intervals.single.startMinute, 18 * 60);
    expect(item.intervals.single.endMinute, 21 * 60 + 30);
  });

  test('reports bad rows and clock-change ambiguity for review', () async {
    final preview = await parser.parse(
      'date,title,category,start,end,time_zone\n'
      '2026-11-01,Repeated clock,class,01:30,02:30,America/Halifax\n'
      '2026-11-02,Missing end,class,09:00,,America/Halifax\n'
      '2026-11-03,Unknown code,airport duty,09:00,17:00,America/Halifax\n',
      sourceName: 'classes.csv',
    );

    expect(preview.proposals, isEmpty);
    expect(preview.notices, hasLength(3));
    expect(preview.notices[0].message, contains('repeated clock hour'));
    expect(preview.notices[0].uid, 'Row 2');
    expect(preview.notices[1].message, contains('both start and end'));
    expect(preview.notices[2].message, contains('not supported'));
  });

  test(
    'rejects unsupported columns, malformed quoting and oversized files',
    () async {
      await expectLater(
        parser.parse('date,title,category,roster_code\n', sourceName: 'x.csv'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Unsupported CSV columns'),
          ),
        ),
      );
      await expectLater(
        parser.parse(
          'date,title,category\n2026-11-07,"open,shift\n',
          sourceName: 'x.csv',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('not closed'),
          ),
        ),
      );
      await expectLater(
        parser.parse(
          List.filled(CsvScheduleImportParser.maxBytes + 1, 'x').join(),
          sourceName: 'x.csv',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('too large'),
          ),
        ),
      );
    },
  );

  test('skips an exact duplicate row in the same file', () async {
    const row = '2026-11-07,Mathematics,class,09:00,10:00,America/Barbados';
    final preview = await parser.parse(
      'date,title,category,start,end,time_zone\n$row\n$row\n',
      sourceName: 'classes.csv',
    );

    expect(preview.proposals, hasLength(1));
    expect(preview.notices.single.message, contains('duplicates another row'));
  });

  test('repeated imports keep the same event identity', () async {
    const source =
        'date,title,category,start,end,time_zone\n'
        '2026-11-10,Chemistry,class,09:00,10:00,America/Barbados\n';
    final first = await parser.parse(source, sourceName: 'classes.csv');
    final repeated = await parser.parse(
      source,
      sourceName: 'classes.csv',
      importedAt: DateTime.utc(2026, 11, 7),
    );

    expect(repeated.proposals.single.item.id, first.proposals.single.item.id);
    expect(
      repeated.proposals.single.item.importProvenance!.uid,
      first.proposals.single.item.importProvenance!.uid,
    );
  });

  test('source_id keeps identity when a roster row changes', () async {
    const header = 'source_id,date,title,category,start,end,time_zone\n';
    final original = await parser.parse(
      '${header}WORK-001,2026-11-10,Sample work shift,shift,09:00,17:00,America/Barbados\n',
      sourceName: 'roster.csv',
    );
    final revised = await parser.parse(
      '${header}WORK-001,2026-11-11,Sample work shift revised,shift,10:00,18:00,America/Barbados\n',
      sourceName: 'roster.csv',
    );

    expect(revised.notices, isEmpty);
    expect(revised.proposals.single.item.id, original.proposals.single.item.id);
    expect(
      revised.proposals.single.item.importProvenance!.uid,
      original.proposals.single.item.importProvenance!.uid,
    );
    expect(revised.proposals.single.item.startDate, CivilDate(2026, 11, 11));
    expect(revised.proposals.single.item.intervals.single.startMinute, 600);
  });

  test(
    'duplicate source IDs with different contents are rejected clearly',
    () async {
      final preview = await parser.parse(
        'source_id,date,title,category,start,end,time_zone\n'
        'same-id,2026-11-10,First,shift,09:00,17:00,America/Barbados\n'
        'same-id,2026-11-11,Changed,shift,10:00,18:00,America/Barbados\n',
        sourceName: 'roster.csv',
      );

      expect(preview.proposals, isEmpty);
      expect(preview.notices, hasLength(1));
      expect(
        preview.notices.single.message,
        contains('different event details'),
      );
    },
  );

  test('combines same-source shift rows into a split event', () async {
    final preview = await parser.parse(
      'source_id,date,title,category,start,end,time_zone,location\n'
      'CAH-SPLIT-7,2026-11-10,Ramp shift,shift,09:00,12:00,America/Barbados,Airport\n'
      'CAH-SPLIT-7,2026-11-10,Ramp shift,shift,14:00,18:00,America/Barbados,Airport\n',
      sourceName: 'roster.csv',
    );

    expect(preview.notices, isEmpty);
    expect(preview.proposals, hasLength(1));
    final item = preview.proposals.single.item;
    expect(item.intervals, hasLength(2));
    expect(item.intervals[0].startMinute, 9 * 60);
    expect(item.intervals[0].endMinute, 12 * 60);
    expect(item.intervals[1].startMinute, 14 * 60);
    expect(item.intervals[1].endMinute, 18 * 60);
    expect(item.importProvenance!.sourceText, contains('09:00,12:00'));
    expect(item.importProvenance!.sourceText, contains('14:00,18:00'));
  });

  test('skips an entire split shift when its intervals overlap', () async {
    final preview = await parser.parse(
      'source_id,date,title,category,start,end,time_zone\n'
      'CAH-SPLIT-8,2026-11-10,Ramp shift,shift,09:00,13:00,America/Barbados\n'
      'CAH-SPLIT-8,2026-11-10,Ramp shift,shift,12:30,18:00,America/Barbados\n',
      sourceName: 'roster.csv',
    );

    expect(preview.proposals, isEmpty);
    expect(preview.notices, hasLength(1));
    expect(preview.notices.single.message, contains('cannot overlap'));
  });
}
