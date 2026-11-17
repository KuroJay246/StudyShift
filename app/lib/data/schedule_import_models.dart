import '../domain/schedule.dart';

class ScheduleImportNotice {
  const ScheduleImportNotice(this.message, {this.uid});

  final String message;
  final String? uid;
}

class ScheduleImportProposal {
  const ScheduleImportProposal({
    required this.item,
    required this.sourceText,
    this.studyShiftSeriesId,
    this.studyShiftExpandedThrough,
  });

  final ScheduleItem item;
  final String sourceText;

  /// Source identity and expansion horizon used only for conservative
  /// reconstruction of a StudyShift ICS file that expanded a weekly series.
  final String? studyShiftSeriesId;
  final CivilDate? studyShiftExpandedThrough;
}

class ScheduleImportPreview {
  const ScheduleImportPreview({required this.proposals, required this.notices});

  final List<ScheduleImportProposal> proposals;
  final List<ScheduleImportNotice> notices;
}
