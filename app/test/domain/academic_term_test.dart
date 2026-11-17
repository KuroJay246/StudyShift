import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/domain/academic_term.dart';
import 'package:shift_study/domain/schedule.dart';

void main() {
  test('academic term normalizes labels and accepts an inclusive date range', () {
    final term = AcademicTerm(
      id: 'term-1',
      institution: '  Example University  ',
      name: '  Semester One  ',
      startDate: CivilDate(2026, 9, 1),
      endDate: CivilDate(2026, 12, 15),
    );

    expect(term.institution, 'Example University');
    expect(term.name, 'Semester One');
    expect(term.contains(CivilDate(2026, 12, 15)), isTrue);
    expect(term.contains(CivilDate(2026, 12, 16)), isFalse);
  });

  test('academic term rejects reversed or invalid dates and blank names', () {
    expect(
      () => AcademicTerm(
        id: 'term-1',
        institution: 'Example University',
        name: 'Semester One',
        startDate: CivilDate(2026, 12, 15),
        endDate: CivilDate(2026, 9, 1),
      ),
      throwsArgumentError,
    );
    expect(
      () => AcademicTerm(
        id: 'term-1',
        institution: ' ',
        name: 'Semester One',
        startDate: CivilDate(2026, 9, 1),
        endDate: CivilDate(2026, 12, 15),
      ),
      throwsArgumentError,
    );
  });
}
