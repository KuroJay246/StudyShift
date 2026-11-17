import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/schedule_backup.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/domain/academic_term.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/supervisor_profile.dart';
import 'package:shift_study/domain/work_code_legend.dart';

void main() {
  const codec = ScheduleBackupCodec();
  const passphrase = 'synthetic-backup-passphrase';

  test(
    'encrypted backup round-trips split, overnight, recurrence and deadlines',
    () async {
      final source = [
        ScheduleItem(
          id: 'synthetic-overnight',
          kind: ScheduleKind.work,
          title: 'Synthetic split night shift',
          startDate: CivilDate(2026, 11, 6),
          timeZoneId: 'America/Halifax',
          intervals: [
            EventInterval(
              startDayOffset: 0,
              startMinute: 1320,
              endDayOffset: 1,
              endMinute: 120,
            ),
            EventInterval(
              startDayOffset: 1,
              startMinute: 600,
              endDayOffset: 1,
              endMinute: 720,
            ),
          ],
          workCategory: WorkCategory.shift,
          code: 'QX',
          employerName: 'Synthetic Air',
          departmentName: 'Synthetic ramp operations',
          jobRole: 'Ramp agent',
          codeMeaning: 'Synthetic ramp duty',
          reminderMinutesBefore: 30,
          reportingInstruction: 'Synthetic report at service desk',
          supervisorName: 'Synthetic supervisor',
          supervisorPhone: '+1 246 555 0100 ext 3',
          contactName: 'Synthetic operations desk',
          contactPhone: '+1 246 555 0101',
        ),
        ScheduleItem(
          id: 'synthetic-recurring-class',
          kind: ScheduleKind.classSession,
          title: 'Synthetic recurring class',
          academicTermId: 'synthetic-term-1',
          startDate: CivilDate(2026, 11, 2),
          timeZoneId: 'America/Halifax',
          intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 600)],
          code: 'SYN1000',
          location: 'Room 100',
          notes: 'Bring notes',
          recurrence: WeeklyRecurrence(
            weekdays: {DateTime.monday, DateTime.wednesday},
            until: CivilDate(2026, 12, 1),
            exceptionDates: {CivilDate(2026, 11, 4)},
          ),
        ),
        ScheduleItem(
          id: 'synthetic-assignment',
          kind: ScheduleKind.deadline,
          title: 'Synthetic assignment due',
          startDate: CivilDate(2026, 11, 12),
          intervals: const [],
          deadlineType: DeadlineType.assignment,
          isCompleted: true,
        ),
        ScheduleItem(
          id: 'synthetic-exam',
          kind: ScheduleKind.deadline,
          title: 'Synthetic examination',
          startDate: CivilDate(2026, 11, 20),
          intervals: [EventInterval.sameDay(startMinute: 540, endMinute: 660)],
          deadlineType: DeadlineType.examination,
        ),
        ScheduleItem(
          id: 'synthetic-imported-all-day',
          kind: ScheduleKind.personal,
          title: 'Synthetic imported day',
          startDate: CivilDate(2026, 11, 21),
          intervals: const [],
          allDay: true,
          importProvenance: ScheduleImportProvenance(
            format: 'iCalendar 2.0',
            uid: 'qa-day@example.test',
            sourceName: 'synthetic.ics',
            sourceText:
                'BEGIN:VEVENT\\r\\nUID:qa-day@example.test\\r\\nEND:VEVENT',
            importedAt: DateTime.utc(2026, 11, 6, 12),
          ),
        ),
        ScheduleItem(
          id: 'synthetic-overtime',
          kind: ScheduleKind.work,
          title: 'Synthetic overtime cover',
          startDate: CivilDate(2026, 11, 22),
          timeZoneId: 'America/Barbados',
          intervals: [
            EventInterval.sameDay(startMinute: 1080, endMinute: 1260),
          ],
          workCategory: WorkCategory.overtime,
          isCompleted: true,
          actualIntervals: [
            EventInterval.sameDay(startMinute: 1080, endMinute: 1350),
          ],
        ),
      ];
      final createdAt = DateTime.utc(2026, 11, 6, 12);
      final bytes = await codec.encode(
        source,
        passphrase: passphrase,
        createdAt: createdAt,
        workCodeLegends: const [
          WorkCodeLegend(
            id: 'synthetic-legend-qx',
            employer: 'Synthetic Air',
            code: 'QX',
            meaning: 'Synthetic ramp duty',
            timeWindows: [
              WorkCodeTimeWindow(startMinute: 360, endMinute: 540),
              WorkCodeTimeWindow(startMinute: 720, endMinute: 960),
            ],
            flightIds: ['AA100', 'LI200'],
          ),
        ],
        academicTerms: [
          AcademicTerm(
            id: 'synthetic-term-1',
            institution: 'Example University',
            name: 'Semester One',
            startDate: CivilDate(2026, 9, 1),
            endDate: CivilDate(2026, 12, 15),
          ),
        ],
        supervisors: const [
          SupervisorProfile(
            id: 'synthetic-supervisor-1',
            name: 'Sample Supervisor',
            type: SupervisorType.acting,
            phone: '555-0100',
            notes: 'Synthetic backup contact',
          ),
        ],
      );

      expect(utf8.decode(bytes), isNot(contains('Synthetic recurring class')));
      final decoded = await codec.decode(bytes, passphrase: passphrase);
      expect(decoded.createdAt, createdAt);
      expect(decoded.items, hasLength(source.length));
      expect(
        decoded.items.map((item) => item.id),
        source.map((item) => item.id),
      );
      expect(decoded.items.first.intervals, source.first.intervals);
      expect(decoded.items.first.reminderMinutesBefore, 30);
      expect(
        decoded.items
            .singleWhere((item) => item.id == 'synthetic-overtime')
            .workCategory,
        WorkCategory.overtime,
      );
      final overtime = decoded.items.singleWhere(
        (item) => item.id == 'synthetic-overtime',
      );
      expect(overtime.isCompleted, isTrue);
      expect(overtime.intervals.single.endMinute, 1260);
      expect(overtime.actualIntervals!.single.endMinute, 1350);
      expect(decoded.items.first.codeMeaning, 'Synthetic ramp duty');
      expect(decoded.items.first.employerName, 'Synthetic Air');
      expect(decoded.items.first.departmentName, 'Synthetic ramp operations');
      expect(decoded.items.first.jobRole, 'Ramp agent');
      expect(decoded.workCodeLegends.single.code, 'QX');
      expect(decoded.workCodeLegends.single.flightIds, ['AA100', 'LI200']);
      expect(decoded.workCodeLegends.single.timeWindows, const [
        WorkCodeTimeWindow(startMinute: 360, endMinute: 540),
        WorkCodeTimeWindow(startMinute: 720, endMinute: 960),
      ]);
      expect(decoded.academicTerms.single.name, 'Semester One');
      expect(decoded.supervisors, const [
        SupervisorProfile(
          id: 'synthetic-supervisor-1',
          name: 'Sample Supervisor',
          type: SupervisorType.acting,
          phone: '555-0100',
          notes: 'Synthetic backup contact',
        ),
      ]);
      expect(decoded.items[1].academicTermId, 'synthetic-term-1');
      expect(
        decoded.items.first.reportingInstruction,
        'Synthetic report at service desk',
      );
      expect(decoded.items.first.supervisorName, 'Synthetic supervisor');
      expect(decoded.items.first.supervisorPhone, '+1 246 555 0100 ext 3');
      expect(decoded.items.first.contactName, 'Synthetic operations desk');
      expect(decoded.items.first.contactPhone, '+1 246 555 0101');
      expect(decoded.items[1].recurrence!.weekdays, {
        DateTime.monday,
        DateTime.wednesday,
      });
      expect(decoded.items[1].recurrence!.exceptionDates, {
        CivilDate(2026, 11, 4),
      });
      expect(decoded.items[2].hasNoTime, isTrue);
      expect(decoded.items[2].deadlineType, DeadlineType.assignment);
      expect(decoded.items[2].isCompleted, isTrue);
      expect(decoded.items[3].deadlineType, DeadlineType.examination);
      expect(decoded.items[4].allDay, isTrue);
      expect(
        decoded.items[4].importProvenance!.sourceText,
        source[4].importProvenance!.sourceText,
      );

      await expectLater(
        codec.decode(bytes, passphrase: 'wrong-backup-passphrase'),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('version 1 encrypted backup restores legacy single-window codes', () async {
    final bytes = await _legacyVersionOneBackup(passphrase);
    final decoded = await codec.decode(bytes, passphrase: passphrase);
    expect(decoded.workCodeLegends.single.timeWindows, const [
      WorkCodeTimeWindow(startMinute: 360, endMinute: 540),
    ]);
  });

  test('new backup envelope uses version 2 for multi-window data', () async {
    final bytes = await codec.encode(const [], passphrase: passphrase);
    final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect(envelope['version'], 2);
  });

  test(
    'encrypted backup refuses a study event with an omitted term record',
    () async {
      final item = ScheduleItem(
        id: 'synthetic-class-with-term',
        kind: ScheduleKind.classSession,
        title: 'Synthetic term class',
        academicTermId: 'missing-term',
        startDate: CivilDate(2026, 9, 2),
        intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
      );

      await expectLater(
        codec.encode([item], passphrase: passphrase),
        throwsFormatException,
      );
    },
  );

  test(
    'tampering, unsupported files and weak passphrases are rejected',
    () async {
      await expectLater(
        codec.encode(const [], passphrase: 'too short'),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        codec.decode(utf8.encode('{"version":2}'), passphrase: passphrase),
        throwsA(isA<FormatException>()),
      );
      final bytes = await codec.encode([
        ScheduleItem(
          id: 'synthetic-tamper-target',
          kind: ScheduleKind.personal,
          title: 'Synthetic tamper target',
          startDate: CivilDate(2026, 11, 6),
          intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
        ),
      ], passphrase: passphrase);
      final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final ciphertext = base64Decode(envelope['ciphertext'] as String);
      ciphertext[0] ^= 1;
      envelope['ciphertext'] = base64Encode(ciphertext);
      await expectLater(
        codec.decode(utf8.encode(jsonEncode(envelope)), passphrase: passphrase),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'restore merges only new IDs and replaces atomically when selected',
    () async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = ScheduleRepository(database);
      final existing = ScheduleItem(
        id: 'synthetic-existing',
        kind: ScheduleKind.work,
        title: 'Keep existing record',
        startDate: CivilDate(2026, 11, 6),
        intervals: [EventInterval.sameDay(startMinute: 480, endMinute: 960)],
      );
      await repository.save(existing);

      final merge = await repository.restoreItems([
        existing.copyWith(title: 'Must not overwrite'),
        ScheduleItem(
          id: 'synthetic-new',
          kind: ScheduleKind.deadline,
          title: 'New assignment',
          startDate: CivilDate(2026, 11, 13),
          intervals: const [],
          deadlineType: DeadlineType.assignment,
        ),
      ], replaceExisting: false);
      expect(merge.inserted, 1);
      expect(merge.skipped, 1);
      expect((await repository.getItems()).map((item) => item.title), {
        'Keep existing record',
        'New assignment',
      });

      final replace = await repository.restoreItems([
        ScheduleItem(
          id: 'synthetic-replacement',
          kind: ScheduleKind.personal,
          title: 'Replacement plan',
          startDate: CivilDate(2026, 11, 14),
          intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
        ),
      ], replaceExisting: true);
      expect(replace.inserted, 1);
      expect(replace.removed, 2);
      expect(replace.skipped, 0);
      expect((await repository.getItems()).map((item) => item.id), {
        'synthetic-replacement',
      });
    },
  );
}

Future<List<int>> _legacyVersionOneBackup(String passphrase) async {
  const iterations = 600000;
  final salt = List<int>.generate(16, (index) => index + 1);
  final payload = utf8.encode(
    jsonEncode({
      'format': 'shift-study-schedule',
      'version': 1,
      'createdAt': '2026-11-17T12:00:00.000Z',
      'events': [],
      'workCodeLegends': [
        {
          'id': 'legacy-code',
          'employer': 'Synthetic Employer',
          'code': 'A1',
          'meaning': 'Synthetic split shift',
          'startMinute': 360,
          'endMinute': 540,
          'flightIds': <String>[],
        },
      ],
    }),
  );
  final key = await Pbkdf2.hmacSha256(
    iterations: iterations,
    bits: 256,
  ).deriveKeyFromPassword(password: passphrase, nonce: salt);
  final box = await AesGcm.with256bits().encrypt(
    payload,
    secretKey: key,
    nonce: List<int>.generate(12, (index) => 30 + index),
    aad: utf8.encode('ShiftStudy.ScheduleBackup.v1'),
  );
  return utf8.encode(
    jsonEncode({
      'format': 'shift-study-encrypted-backup',
      'version': 1,
      'cipher': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'ciphertext': base64Encode(box.cipherText),
    }),
  );
}
