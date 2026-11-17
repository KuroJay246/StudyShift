class WorkCodeLegend {
  const WorkCodeLegend({
    required this.id,
    this.employer = '',
    required this.code,
    String? assignmentDetails,
    String? meaning,
    this.startMinute,
    this.endMinute,
    this.flightIds = const [],
  }) : assignmentDetails = assignmentDetails ?? meaning ?? '';

  final String id;
  final String employer;
  final String code;

  /// Flight, movement, crew or other roster assignment described by the code.
  final String assignmentDetails;

  /// Optional local wall-clock times. When [endMinute] is <= [startMinute],
  /// the code window runs past midnight into the following day.
  final int? startMinute;
  final int? endMinute;

  /// Explicit reference flights associated with this typical code definition.
  /// These are informational roster references, not live flight assignments.
  final List<String> flightIds;

  /// Compatibility with schema-v14 code and existing encrypted backups.
  @Deprecated('Use assignmentDetails, which describes the operation.')
  String get meaning => assignmentDetails;

  WorkCodeLegend copyWith({
    String? employer,
    String? code,
    String? assignmentDetails,
    String? meaning,
    int? startMinute,
    int? endMinute,
    List<String>? flightIds,
    bool clearTimeRange = false,
  }) => WorkCodeLegend(
    id: id,
    employer: employer ?? this.employer,
    code: code ?? this.code,
    assignmentDetails: assignmentDetails ?? meaning ?? this.assignmentDetails,
    startMinute: clearTimeRange ? null : startMinute ?? this.startMinute,
    endMinute: clearTimeRange ? null : endMinute ?? this.endMinute,
    flightIds: flightIds ?? this.flightIds,
  );
}
