import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/domain/supervisor_profile.dart';
import 'package:shift_study/domain/supervisor_roster_parser.dart';

void main() {
  const parser = SupervisorRosterParser();

  test('reads names only inside explicit permanent and acting sections', () {
    final result = parser.parse('''
Roster notes
Staff on duty
Permanent Supervisors:
  - SYNTHETIC Permanent One
  - Synthetic Permanent Two
Acting Supervisors:
  1. Synthetic Acting One
  Synthetic Acting Two
Other Employees:
  Example Employee
''');

    expect(result.map((entry) => (entry.name, entry.type)).toList(), [
      ('SYNTHETIC Permanent One', SupervisorType.permanent),
      ('Synthetic Permanent Two', SupervisorType.permanent),
      ('Synthetic Acting One', SupervisorType.acting),
      ('Synthetic Acting Two', SupervisorType.acting),
    ]);
  });

  test('deduplicates names ignoring case and repeated whitespace', () {
    final result = parser.parse('''
Permanent Supervisors:
Synthetic   Permanent One
sYnThEtIc permanent one
Acting Supervisors:
Synthetic Acting One
''');

    expect(result.map((entry) => entry.name), [
      'Synthetic Permanent One',
      'Synthetic Acting One',
    ]);
    expect(result.first.type, SupervisorType.permanent);
  });

  test('does not infer supervisor groups from unsectioned roster names', () {
    final result = parser.parse('''
Synthetic Person One
Synthetic Person Two
Supervisor list
Synthetic Person Three
''');

    expect(result, isEmpty);
  });

  test('accepts plain section headings with optional colon and case', () {
    final result = parser.parse('''
PERMANENT SUPERVISORS
  Janelle Example
acting supervisors:
  Kai Example
''');

    expect(result.map((entry) => (entry.name, entry.type)).toList(), [
      ('Janelle Example', SupervisorType.permanent),
      ('Kai Example', SupervisorType.acting),
    ]);
  });
}
