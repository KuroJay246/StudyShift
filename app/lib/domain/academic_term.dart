import 'schedule.dart';

class AcademicTerm {
  AcademicTerm({
    required this.id,
    required String institution,
    required String name,
    required this.startDate,
    required this.endDate,
  }) : institution = institution.trim(),
       name = name.trim() {
    if (id.trim().isEmpty ||
        id.length > 256 ||
        this.institution.isEmpty ||
        this.institution.length > 512 ||
        this.name.isEmpty ||
        this.name.length > 256) {
      throw ArgumentError('An academic term needs valid names and an ID.');
    }
    if (!startDate.isValid || !endDate.isValid ||
        startDate.compareTo(endDate) > 0) {
      throw ArgumentError('An academic term needs a valid date range.');
    }
  }

  final String id;
  final String institution;
  final String name;
  final CivilDate startDate;
  final CivilDate endDate;

  bool contains(CivilDate date) =>
      date.compareTo(startDate) >= 0 && date.compareTo(endDate) <= 0;
}
