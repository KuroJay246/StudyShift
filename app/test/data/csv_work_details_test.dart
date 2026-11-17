import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/csv_schedule_import.dart';
import 'package:shift_study/domain/schedule.dart';

void main() {
  test(
    'CSV accepts optional department and job role on work entries',
    () async {
      final preview = await const CsvScheduleImportParser().parse(
        'date,title,category,start,end,time_zone,department,job_role\n'
        '2026-11-14,Synthetic shift,shift,09:00,17:00,America/Barbados,Synthetic ramp,Ramp agent\n',
        sourceName: 'synthetic-work.csv',
        importedAt: DateTime.utc(2026, 11, 13),
      );

      expect(
        preview.notices,
        isEmpty,
        reason: preview.notices.map((notice) => notice.message).join('; '),
      );
      final imported = preview.proposals.single.item;
      expect(imported.kind, ScheduleKind.work);
      expect(imported.departmentName, 'Synthetic ramp');
      expect(imported.jobRole, 'Ramp agent');
    },
  );
}
