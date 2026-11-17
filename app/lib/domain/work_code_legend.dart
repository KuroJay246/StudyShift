class WorkCodeTimeWindow {
  const WorkCodeTimeWindow({
    required this.startMinute,
    required this.endMinute,
    this.endDayOffset = 0,
  });

  final int startMinute;
  final int endMinute;
  final int endDayOffset;

  bool get isValid =>
      startMinute >= 0 &&
      startMinute < 1440 &&
      endMinute >= 0 &&
      endMinute < 1440 &&
      endDayOffset >= 0 &&
      endDayOffset <= 1 &&
      (endDayOffset > 0 || endMinute > startMinute);

  @override
  bool operator ==(Object other) =>
      other is WorkCodeTimeWindow &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute &&
      other.endDayOffset == endDayOffset;

  @override
  int get hashCode => Object.hash(startMinute, endMinute, endDayOffset);
}

class WorkCodeLegend {
  const WorkCodeLegend({
    required this.id,
    this.employer = '',
    required this.code,
    String? assignmentDetails,
    String? meaning,
    int? startMinute,
    int? endMinute,
    this.flightIds = const [],
    List<WorkCodeTimeWindow> timeWindows = const [],
  }) : assignmentDetails = assignmentDetails ?? meaning ?? '',
       _legacyStartMinute = startMinute,
       _legacyEndMinute = endMinute,
       // Keep the public parameter name while retaining derived legacy ranges.
       // ignore: prefer_initializing_formals
       _timeWindows = timeWindows;

  final String id;
  final String employer;
  final String code;

  /// Flight, movement, crew or other roster assignment described by the code.
  final String assignmentDetails;

  /// Explicit reference flights associated with this typical code definition.
  /// These are informational roster references, not live flight assignments.
  final List<String> flightIds;

  final int? _legacyStartMinute;
  final int? _legacyEndMinute;
  final List<WorkCodeTimeWindow> _timeWindows;

  /// Time windows for this code. Old single-range records are exposed as one
  /// window and remain readable without a data rewrite.
  List<WorkCodeTimeWindow> get timeWindows {
    if (_timeWindows.isNotEmpty) return _timeWindows;
    final start = _legacyStartMinute;
    final end = _legacyEndMinute;
    if (start == null || end == null) return const [];
    return [
      WorkCodeTimeWindow(
        startMinute: start,
        endMinute: end,
        endDayOffset: end <= start ? 1 : 0,
      ),
    ];
  }

  /// Compatibility with older single-window call sites and backups.
  int? get startMinute => timeWindows.length == 1
      ? timeWindows.single.startMinute
      : _timeWindows.isEmpty
      ? _legacyStartMinute
      : null;

  /// Compatibility with older single-window call sites and backups.
  int? get endMinute => timeWindows.length == 1
      ? timeWindows.single.endMinute
      : _timeWindows.isEmpty
      ? _legacyEndMinute
      : null;

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
    List<WorkCodeTimeWindow>? timeWindows,
    bool clearTimeRange = false,
  }) => WorkCodeLegend(
    id: id,
    employer: employer ?? this.employer,
    code: code ?? this.code,
    assignmentDetails: assignmentDetails ?? meaning ?? this.assignmentDetails,
    startMinute: clearTimeRange ? null : startMinute ?? this.startMinute,
    endMinute: clearTimeRange ? null : endMinute ?? this.endMinute,
    flightIds: flightIds ?? this.flightIds,
    timeWindows: clearTimeRange ? const [] : timeWindows ?? this.timeWindows,
  );
}
