import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/schedule_repository.dart';
import 'package:shift_study/data/work_code_legend_repository.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/work_code_legend.dart';

void main() {
  test(
    'version 20 preserves existing code fields during time-window migration',
    () async {
      final database = ScheduleDatabase.forTesting(
        NativeDatabase.memory(
          setup: (db) {
            db.execute(
              'CREATE TABLE schedule_rows (id TEXT NOT NULL PRIMARY KEY)',
            );
            db.execute('''
            CREATE TABLE work_code_legend_rows (
              id TEXT NOT NULL PRIMARY KEY,
              employer TEXT NOT NULL,
              code TEXT NOT NULL,
              meaning TEXT NOT NULL,
              start_minute INTEGER,
              end_minute INTEGER,
              flight_ids_json TEXT NOT NULL DEFAULT '[]'
            )
          ''');
            db.execute('''
            INSERT INTO work_code_legend_rows
            (id, employer, code, meaning, start_minute, end_minute, flight_ids_json)
            VALUES ('legacy-a1', 'Synthetic employer', 'A1', 'Synthetic split duty', 360, 540, '["AA100"]')
          ''');
            db.execute('PRAGMA user_version = 20');
          },
        ),
      );
      addTearDown(database.close);

      final saved = (await WorkCodeLegendRepository(
        database,
      ).getItems()).single;
      expect(saved.code, 'A1');
      expect(saved.startMinute, 360);
      expect(saved.endMinute, 540);
      expect(saved.flightIds, ['AA100']);
      expect(saved.timeWindows, const [
        WorkCodeTimeWindow(startMinute: 360, endMinute: 540),
      ]);
    },
  );

  test(
    'version 17 legend migration adds flight references without loss',
    () async {
      final database = ScheduleDatabase.forTesting(
        NativeDatabase.memory(
          setup: (db) {
            db.execute(
              'CREATE TABLE schedule_rows (id TEXT NOT NULL PRIMARY KEY)',
            );
            db.execute('''
            CREATE TABLE work_code_legend_rows (
              id TEXT NOT NULL PRIMARY KEY,
              employer TEXT NOT NULL,
              code TEXT NOT NULL,
              meaning TEXT NOT NULL,
              start_minute INTEGER,
              end_minute INTEGER
            )
          ''');
            db.execute('''
            INSERT INTO work_code_legend_rows
            (id, employer, code, meaning, start_minute, end_minute)
            VALUES ('legacy-a1', 'Synthetic employer', 'A1', 'Split shift', 360, 540)
          ''');
            db.execute('PRAGMA user_version = 17');
          },
        ),
      );
      addTearDown(database.close);

      final items = await WorkCodeLegendRepository(database).getItems();
      expect(items.single.code, 'A1');
      expect(items.single.assignmentDetails, 'Split shift');
      expect(items.single.startMinute, 360);
      expect(items.single.flightIds, isEmpty);
      await WorkCodeLegendRepository(database)
          .save(items.single.copyWith(flightIds: ['AA100']));
      expect(
        (await WorkCodeLegendRepository(database).getItems()).single.flightIds,
        ['AA100'],
      );
    },
  );

  test('version 1 entries migrate without losing schedule data', () async {
    final directory = await Directory.systemTemp.createTemp('shift-study-v1-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = File(
      '${directory.path}${Platform.pathSeparator}schedule.sqlite',
    );
    final legacy = ScheduleDatabase.forTesting(
      NativeDatabase(
        file,
        enableMigrations: false,
        setup: (db) {
          db.execute('''
            CREATE TABLE schedule_rows (
              id TEXT NOT NULL PRIMARY KEY,
              kind INTEGER NOT NULL,
              title TEXT NOT NULL,
              start_date TEXT NOT NULL,
              code TEXT,
              location TEXT,
              notes TEXT,
              weekdays TEXT,
              until_date TEXT,
              is_day_off INTEGER NOT NULL DEFAULT 0 CHECK (is_day_off IN (0, 1))
            )
          ''');
          db.execute('''
            CREATE TABLE interval_rows (
              row_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              item_id TEXT NOT NULL REFERENCES schedule_rows(id) ON DELETE CASCADE,
              start_day_offset INTEGER NOT NULL,
              start_minute INTEGER NOT NULL,
              end_day_offset INTEGER NOT NULL,
              end_minute INTEGER NOT NULL
            )
          ''');
          db.execute('''
            CREATE TABLE preference_rows (
              key TEXT NOT NULL PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
          db.execute('''
            INSERT INTO schedule_rows(id, kind, title, start_date, code, location, notes)
            VALUES ('legacy-shift', 0, 'Legacy synthetic shift', '2026-11-02', 'TEST', 'Local', 'Preserve me')
          ''');
          db.execute('''
            INSERT INTO interval_rows(item_id, start_day_offset, start_minute, end_day_offset, end_minute)
            VALUES ('legacy-shift', 0, 1320, 1, 360)
          ''');
          db.execute('PRAGMA user_version = 1');
        },
      ),
    );
    await legacy.customSelect('SELECT id FROM schedule_rows').get();
    await legacy.close();

    final upgraded = ScheduleDatabase.forTesting(NativeDatabase(file));
    try {
      final restored = (await ScheduleRepository(upgraded).getItems()).single;
      expect(restored.id, 'legacy-shift');
      expect(restored.title, 'Legacy synthetic shift');
      expect(restored.startDate, CivilDate(2026, 11, 2));
      expect(restored.intervals, [
        EventInterval.overnight(startMinute: 1320, endMinute: 360),
      ]);
      expect(restored.code, 'TEST');
      expect(restored.location, 'Local');
      expect(restored.notes, 'Preserve me');
      expect(restored.timeZoneId, isNull);

      await ScheduleRepository(upgraded)
          .save(restored.copyWith(title: 'Edited legacy shift'));
      expect(
        (await ScheduleRepository(upgraded).getItems()).single.timeZoneId,
        isNull,
      );
    } finally {
      await upgraded.close();
    }
  });

  test('version 2 zone data survives the fold-choice migration', () async {
    final directory = await Directory.systemTemp.createTemp('shift-study-v2-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = File(
      '${directory.path}${Platform.pathSeparator}schedule.sqlite',
    );
    final legacy = ScheduleDatabase.forTesting(
      NativeDatabase(
        file,
        enableMigrations: false,
        setup: (db) {
          db.execute('''
            CREATE TABLE schedule_rows (
              id TEXT NOT NULL PRIMARY KEY,
              kind INTEGER NOT NULL,
              title TEXT NOT NULL,
              start_date TEXT NOT NULL,
              time_zone_id TEXT,
              code TEXT,
              location TEXT,
              notes TEXT,
              weekdays TEXT,
              until_date TEXT,
              is_day_off INTEGER NOT NULL DEFAULT 0 CHECK (is_day_off IN (0, 1))
            )
          ''');
          db.execute('''
            CREATE TABLE interval_rows (
              row_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              item_id TEXT NOT NULL REFERENCES schedule_rows(id) ON DELETE CASCADE,
              start_day_offset INTEGER NOT NULL,
              start_minute INTEGER NOT NULL,
              end_day_offset INTEGER NOT NULL,
              end_minute INTEGER NOT NULL
            )
          ''');
          db.execute('''
            CREATE TABLE preference_rows (
              key TEXT NOT NULL PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
          db.execute('''
            INSERT INTO schedule_rows(id, kind, title, start_date, time_zone_id)
            VALUES ('zone-shift', 0, 'Zone-aware synthetic shift', '2026-11-02', 'America/Barbados')
          ''');
          db.execute('''
            INSERT INTO interval_rows(item_id, start_day_offset, start_minute, end_day_offset, end_minute)
            VALUES ('zone-shift', 0, 420, 0, 900)
          ''');
          db.execute('PRAGMA user_version = 2');
        },
      ),
    );
    await legacy.customSelect('SELECT id FROM schedule_rows').get();
    await legacy.close();

    final upgraded = ScheduleDatabase.forTesting(NativeDatabase(file));
    try {
      final restored = (await ScheduleRepository(upgraded).getItems()).single;
      expect(restored.timeZoneId, 'America/Barbados');
      expect(restored.intervals.single.startFoldChoice, isNull);
      expect(restored.intervals.single.endFoldChoice, isNull);
    } finally {
      await upgraded.close();
    }
  });

  test(
    'version 3 weekly schedules migrate with no cancellation dates',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'shift-study-v3-',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final file = File(
        '${directory.path}${Platform.pathSeparator}schedule.sqlite',
      );
      final legacy = ScheduleDatabase.forTesting(
        NativeDatabase(
          file,
          enableMigrations: false,
          setup: (db) {
            db.execute('''
            CREATE TABLE schedule_rows (
              id TEXT NOT NULL PRIMARY KEY,
              kind INTEGER NOT NULL,
              title TEXT NOT NULL,
              start_date TEXT NOT NULL,
              time_zone_id TEXT,
              code TEXT,
              location TEXT,
              notes TEXT,
              weekdays TEXT,
              until_date TEXT,
              is_day_off INTEGER NOT NULL DEFAULT 0 CHECK (is_day_off IN (0, 1))
            )
          ''');
            db.execute('''
            CREATE TABLE interval_rows (
              row_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              item_id TEXT NOT NULL REFERENCES schedule_rows(id) ON DELETE CASCADE,
              start_day_offset INTEGER NOT NULL,
              start_minute INTEGER NOT NULL,
              end_day_offset INTEGER NOT NULL,
              end_minute INTEGER NOT NULL,
              start_fold_choice TEXT,
              end_fold_choice TEXT
            )
          ''');
            db.execute('''
            CREATE TABLE preference_rows (
              key TEXT NOT NULL PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
            db.execute('''
            INSERT INTO schedule_rows(id, kind, title, start_date, weekdays, until_date)
            VALUES ('weekly-class', 1, 'Legacy weekly class', '2026-11-02', '1,3', '2026-12-10')
          ''');
            db.execute('''
            INSERT INTO interval_rows(item_id, start_day_offset, start_minute, end_day_offset, end_minute)
            VALUES ('weekly-class', 0, 600, 0, 660)
          ''');
            db.execute('PRAGMA user_version = 3');
          },
        ),
      );
      await legacy.customSelect('SELECT id FROM schedule_rows').get();
      await legacy.close();

      final upgraded = ScheduleDatabase.forTesting(NativeDatabase(file));
      try {
        final restored = (await ScheduleRepository(upgraded).getItems()).single;
        expect(restored.id, 'weekly-class');
        expect(restored.recurrence!.weekdays, {
          DateTime.monday,
          DateTime.wednesday,
        });
        expect(restored.recurrence!.exceptionDates, isEmpty);
      } finally {
        await upgraded.close();
      }
    },
  );

  test(
    'version 4 work rows migrate into shift and day-off categories',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'shift-study-v4-',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final file = File(
        '${directory.path}${Platform.pathSeparator}schedule.sqlite',
      );
      final legacy = ScheduleDatabase.forTesting(
        NativeDatabase(
          file,
          enableMigrations: false,
          setup: (db) {
            db.execute('''
            CREATE TABLE schedule_rows (
              id TEXT NOT NULL PRIMARY KEY,
              kind INTEGER NOT NULL,
              title TEXT NOT NULL,
              start_date TEXT NOT NULL,
              time_zone_id TEXT,
              code TEXT,
              location TEXT,
              notes TEXT,
              weekdays TEXT,
              until_date TEXT,
              exception_dates TEXT,
              is_day_off INTEGER NOT NULL DEFAULT 0 CHECK (is_day_off IN (0, 1))
            )
          ''');
            db.execute('''
            CREATE TABLE interval_rows (
              row_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              item_id TEXT NOT NULL REFERENCES schedule_rows(id) ON DELETE CASCADE,
              start_day_offset INTEGER NOT NULL,
              start_minute INTEGER NOT NULL,
              end_day_offset INTEGER NOT NULL,
              end_minute INTEGER NOT NULL,
              start_fold_choice TEXT,
              end_fold_choice TEXT
            )
          ''');
            db.execute(
              '''CREATE TABLE preference_rows (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)''',
            );
            db.execute(
              "INSERT INTO schedule_rows(id,kind,title,start_date,time_zone_id) VALUES ('regular',0,'Old shift','2026-11-03','America/Barbados')",
            );
            db.execute(
              "INSERT INTO schedule_rows(id,kind,title,start_date,time_zone_id,is_day_off) VALUES ('old-day-off',0,'Old day off','2026-11-04','America/Barbados',1)",
            );
            db.execute(
              "INSERT INTO schedule_rows(id,kind,title,start_date,time_zone_id) VALUES ('old-exam',3,'Old timed exam','2026-11-05','America/Barbados')",
            );
            db.execute(
              "INSERT INTO interval_rows(item_id,start_day_offset,start_minute,end_day_offset,end_minute) VALUES ('regular',0,540,0,1020)",
            );
            db.execute(
              "INSERT INTO interval_rows(item_id,start_day_offset,start_minute,end_day_offset,end_minute) VALUES ('old-exam',0,600,0,720)",
            );
            db.execute('PRAGMA user_version = 4');
          },
        ),
      );
      await legacy.customSelect('SELECT id FROM schedule_rows').get();
      await legacy.close();

      final upgraded = ScheduleDatabase.forTesting(NativeDatabase(file));
      try {
        final restored = {
          for (final item in await ScheduleRepository(upgraded).getItems())
            item.id: item,
        };
        expect(restored['regular']!.workCategory, WorkCategory.shift);
        expect(restored['regular']!.intervals, hasLength(1));
        expect(restored['old-day-off']!.workCategory, WorkCategory.dayOff);
        expect(restored['old-day-off']!.hasNoTime, isTrue);
        expect(restored['old-day-off']!.intervals, isEmpty);
        expect(restored['old-exam']!.deadlineType, DeadlineType.examination);
        expect(restored['old-exam']!.hasNoTime, isFalse);
        expect(restored['old-exam']!.intervals, hasLength(1));
      } finally {
        await upgraded.close();
      }
    },
  );

  test(
    'version 6 schedule rows migrate with empty import provenance',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'shift-study-v6-',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final file = File(
        '${directory.path}${Platform.pathSeparator}schedule.sqlite',
      );
      final legacy = ScheduleDatabase.forTesting(
        NativeDatabase(
          file,
          enableMigrations: false,
          setup: (db) {
            db.execute('''
            CREATE TABLE schedule_rows (
              id TEXT NOT NULL PRIMARY KEY,
              kind INTEGER NOT NULL,
              title TEXT NOT NULL,
              start_date TEXT NOT NULL,
              time_zone_id TEXT,
              code TEXT,
              location TEXT,
              notes TEXT,
              weekdays TEXT,
              until_date TEXT,
              exception_dates TEXT,
              is_day_off INTEGER NOT NULL DEFAULT 0 CHECK (is_day_off IN (0, 1)),
              work_category INTEGER,
              deadline_type INTEGER
            )
          ''');
            db.execute('''
            CREATE TABLE interval_rows (
              row_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              item_id TEXT NOT NULL REFERENCES schedule_rows(id) ON DELETE CASCADE,
              start_day_offset INTEGER NOT NULL,
              start_minute INTEGER NOT NULL,
              end_day_offset INTEGER NOT NULL,
              end_minute INTEGER NOT NULL,
              start_fold_choice TEXT,
              end_fold_choice TEXT
            )
          ''');
            db.execute('''
            CREATE TABLE preference_rows (
              key TEXT NOT NULL PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
            db.execute('''
            INSERT INTO schedule_rows(id, kind, title, start_date, time_zone_id)
            VALUES ('v6-shift', 0, 'Existing shift', '2026-11-06', 'America/Barbados')
          ''');
            db.execute('''
            INSERT INTO interval_rows(item_id, start_day_offset, start_minute, end_day_offset, end_minute)
            VALUES ('v6-shift', 0, 540, 0, 1020)
          ''');
            db.execute('PRAGMA user_version = 6');
          },
        ),
      );
      await legacy.customSelect('SELECT id FROM schedule_rows').get();
      await legacy.close();

      final upgraded = ScheduleDatabase.forTesting(NativeDatabase(file));
      try {
        final restored = (await ScheduleRepository(upgraded).getItems()).single;
        expect(restored.title, 'Existing shift');
        expect(restored.timeZoneId, 'America/Barbados');
        expect(restored.allDay, isFalse);
        expect(restored.importProvenance, isNull);
        expect(restored.intervals.single.startMinute, 540);
      } finally {
        await upgraded.close();
      }
    },
  );

  test(
    'version 7 migration adds an unset reminder without changing events',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'shift-study-v7-',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final file = File(
        '${directory.path}${Platform.pathSeparator}schedule.sqlite',
      );
      final legacy = ScheduleDatabase.forTesting(
        NativeDatabase(
          file,
          enableMigrations: false,
          setup: (db) {
            db.execute('''
            CREATE TABLE schedule_rows (
              id TEXT NOT NULL PRIMARY KEY,
              kind INTEGER NOT NULL,
              title TEXT NOT NULL,
              start_date TEXT NOT NULL,
              time_zone_id TEXT,
              code TEXT,
              location TEXT,
              notes TEXT,
              weekdays TEXT,
              until_date TEXT,
              exception_dates TEXT,
              is_day_off INTEGER NOT NULL DEFAULT 0 CHECK (is_day_off IN (0, 1)),
              work_category INTEGER,
              deadline_type INTEGER,
              all_day INTEGER NOT NULL DEFAULT 0 CHECK (all_day IN (0, 1)),
              import_format TEXT,
              import_uid TEXT,
              import_source_name TEXT,
              import_source_text TEXT,
              imported_at TEXT
            )
          ''');
            db.execute('''
            CREATE TABLE interval_rows (
              row_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              item_id TEXT NOT NULL REFERENCES schedule_rows(id) ON DELETE CASCADE,
              start_day_offset INTEGER NOT NULL,
              start_minute INTEGER NOT NULL,
              end_day_offset INTEGER NOT NULL,
              end_minute INTEGER NOT NULL,
              start_fold_choice TEXT,
              end_fold_choice TEXT
            )
          ''');
            db.execute('''
            CREATE TABLE preference_rows (
              key TEXT NOT NULL PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
            db.execute('''
            INSERT INTO schedule_rows(id, kind, title, start_date, time_zone_id)
            VALUES ('v7-class', 1, 'Existing class', '2026-11-06', 'America/Barbados')
          ''');
            db.execute('''
            INSERT INTO interval_rows(item_id, start_day_offset, start_minute, end_day_offset, end_minute)
            VALUES ('v7-class', 0, 540, 0, 600)
          ''');
            db.execute('PRAGMA user_version = 7');
          },
        ),
      );
      await legacy.customSelect('SELECT id FROM schedule_rows').get();
      await legacy.close();

      final upgraded = ScheduleDatabase.forTesting(NativeDatabase(file));
      try {
        final restored = (await ScheduleRepository(upgraded).getItems()).single;
        expect(restored.title, 'Existing class');
        expect(restored.isCompleted, isFalse);
        expect(restored.reminderMinutesBefore, isNull);
        expect(restored.reportingInstruction, isNull);
        expect(restored.codeMeaning, isNull);
        expect(restored.supervisorName, isNull);
        expect(restored.supervisorPhone, isNull);
        expect(restored.contactName, isNull);
        expect(restored.contactPhone, isNull);
        expect(restored.intervals.single.startMinute, 540);
      } finally {
        await upgraded.close();
      }
    },
  );

  test(
    'version 12 upgrade preserves schedules and creates usable legends',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'shift-study-v12-',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final file = File(
        '${directory.path}${Platform.pathSeparator}schedule.sqlite',
      );
      final legacy = ScheduleDatabase.forTesting(
        NativeDatabase(
          file,
          enableMigrations: false,
          setup: (db) {
            db.execute('''
            CREATE TABLE schedule_rows (
              id TEXT NOT NULL PRIMARY KEY,
              kind INTEGER NOT NULL,
              title TEXT NOT NULL,
              start_date TEXT NOT NULL,
              time_zone_id TEXT,
              code TEXT,
              code_meaning TEXT,
              location TEXT,
              notes TEXT,
              reporting_instruction TEXT,
              supervisor_name TEXT,
              supervisor_phone TEXT,
              contact_name TEXT,
              contact_phone TEXT,
              weekdays TEXT,
              until_date TEXT,
              exception_dates TEXT,
              is_day_off INTEGER NOT NULL DEFAULT 0,
              work_category INTEGER,
              deadline_type INTEGER,
              all_day INTEGER NOT NULL DEFAULT 0,
              import_format TEXT,
              import_uid TEXT,
              import_source_name TEXT,
              import_source_text TEXT,
              imported_at TEXT,
              reminder_minutes_before INTEGER,
              is_completed INTEGER NOT NULL DEFAULT 0
            )
          ''');
            db.execute('''
            CREATE TABLE interval_rows (
              row_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              item_id TEXT NOT NULL REFERENCES schedule_rows(id) ON DELETE CASCADE,
              start_day_offset INTEGER NOT NULL,
              start_minute INTEGER NOT NULL,
              end_day_offset INTEGER NOT NULL,
              end_minute INTEGER NOT NULL,
              start_fold_choice TEXT,
              end_fold_choice TEXT
            )
          ''');
            db.execute('''
            CREATE TABLE preference_rows (
              key TEXT NOT NULL PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
            db.execute('''
            INSERT INTO schedule_rows (
              id, kind, title, start_date, time_zone_id, code, code_meaning,
              location, notes, reporting_instruction, supervisor_name,
              supervisor_phone, contact_name, contact_phone, work_category
            ) VALUES (
              'v12-overnight', 0, 'Existing overnight shift', '2026-11-12',
              'America/Barbados', 'N1', 'Night ramp', 'Airport', 'Preserve notes',
              'Report to dispatch', 'Synthetic supervisor', '5550100',
              'Synthetic contact', '5550101', 0
            )
          ''');
            db.execute('''
            INSERT INTO interval_rows (
              item_id, start_day_offset, start_minute, end_day_offset, end_minute
            ) VALUES ('v12-overnight', 0, 1320, 1, 360)
          ''');
            db.execute('PRAGMA user_version = 12');
          },
        ),
      );
      await legacy.customSelect('SELECT id FROM schedule_rows').get();
      await legacy.close();

      final upgraded = ScheduleDatabase.forTesting(NativeDatabase(file));
      try {
        final repository = ScheduleRepository(upgraded);
        final restored = (await repository.getItems()).single;
        expect(restored.id, 'v12-overnight');
        expect(restored.title, 'Existing overnight shift');
        expect(restored.employerName, isNull);
        expect(restored.departmentName, isNull);
        expect(restored.jobRole, isNull);
        expect(restored.code, 'N1');
        expect(restored.codeMeaning, 'Night ramp');
        expect(restored.supervisorName, 'Synthetic supervisor');
        expect(restored.contactPhone, '5550101');
        expect(restored.intervals, [
          EventInterval.overnight(startMinute: 1320, endMinute: 360),
        ]);

        await repository.save(
          restored.copyWith(
            departmentName: 'Synthetic ramp operations',
            jobRole: 'Ramp agent',
          ),
        );
        final updated = (await repository.getItems()).single;
        expect(updated.departmentName, 'Synthetic ramp operations');
        expect(updated.jobRole, 'Ramp agent');

        final legends = WorkCodeLegendRepository(upgraded);
        await legends.save(
          const WorkCodeLegend(
            id: 'v13-legend',
            employer: 'Synthetic employer',
            code: 'N1',
            assignmentDetails: 'Night ramp assignment',
            startMinute: 1320,
            endMinute: 360,
          ),
        );
        final savedLegend = (await legends.getItems()).single;
        expect(savedLegend.code, 'N1');
        expect(savedLegend.assignmentDetails, 'Night ramp assignment');
        expect(savedLegend.startMinute, 1320);
        expect(savedLegend.endMinute, 360);
      } finally {
        await upgraded.close();
      }
    },
  );
}
