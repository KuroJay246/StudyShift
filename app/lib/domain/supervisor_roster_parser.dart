import 'supervisor_profile.dart';

/// A name and category explicitly listed under a supervisor section heading.
class ParsedSupervisorRosterEntry {
  const ParsedSupervisorRosterEntry({required this.name, required this.type});

  final String name;
  final SupervisorType type;
}

/// Parses text that has explicit Permanent Supervisors / Acting Supervisors
/// section headings. Text outside those sections is ignored; this parser does
/// not infer a person's role from their name or position in an unlabelled list.
class SupervisorRosterParser {
  const SupervisorRosterParser();

  List<ParsedSupervisorRosterEntry> parse(String source) {
    final result = <ParsedSupervisorRosterEntry>[];
    final seenNames = <String>{};
    SupervisorType? activeType;

    for (final rawLine in source.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final heading = _sectionType(line);
      if (heading != null) {
        activeType = heading;
        continue;
      }
      if (_endsSection(line)) {
        activeType = null;
        continue;
      }
      if (activeType == null) continue;

      final name = _nameFromLine(line);
      if (name.isEmpty || _isColumnHeader(name)) continue;
      final key = name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (!seenNames.add(key)) continue;
      result.add(ParsedSupervisorRosterEntry(name: name, type: activeType));
    }

    return List.unmodifiable(result);
  }

  SupervisorType? _sectionType(String line) {
    final heading = line
        .replaceFirst(RegExp(r'^[#\[\s]+'), '')
        .replaceFirst(RegExp(r'[\]:\s]+$'), '')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (RegExp(r'^permanent supervisors?$').hasMatch(heading)) {
      return SupervisorType.permanent;
    }
    if (RegExp(r'^acting supervisors?$').hasMatch(heading)) {
      return SupervisorType.acting;
    }
    return null;
  }

  bool _endsSection(String line) {
    final unwrapped = line.replaceFirst(RegExp(r'^[#\[\s]+'), '');
    if (line.startsWith('#') || line.startsWith('[') || line.endsWith(':')) {
      return true;
    }
    final heading = unwrapped.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return const {
      'employees',
      'employee list',
      'staff',
      'staff list',
      'team members',
      'workers',
      'roster',
      'shift roster',
      'work schedule',
      'other personnel',
    }.contains(heading);
  }

  String _nameFromLine(String line) => line
      .replaceFirst(RegExp(r'^(?:[-*•▪]|\d+[.)])\s*'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  bool _isColumnHeader(String name) => const {
    'name',
    'supervisor',
    'supervisors',
    'supervisor name',
    'supervisor names',
  }.contains(name.toLowerCase());
}
