import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../domain/academic_term.dart';
import '../domain/schedule.dart';
import '../domain/supervisor_profile.dart';
import '../domain/work_code_legend.dart';

class ScheduleBackup {
  const ScheduleBackup({
    required this.createdAt,
    required this.items,
    this.workCodeLegends = const [],
    this.academicTerms = const [],
    this.supervisors = const [],
  });

  final DateTime createdAt;
  final List<ScheduleItem> items;
  final List<WorkCodeLegend> workCodeLegends;
  final List<AcademicTerm> academicTerms;
  final List<SupervisorProfile> supervisors;
}

/// A portable, authenticated, passphrase-encrypted schedule backup.
class ScheduleBackupCodec {
  const ScheduleBackupCodec();

  static const maxBytes = 10 * 1024 * 1024;
  static const maxItems = 10000;
  static const _iterations = 600000;
  static const _saltBytes = 16;
  static const _format = 'shift-study-encrypted-backup';
  static const _payloadFormat = 'shift-study-schedule';
  static const _currentVersion = 2;
  static const _supportedVersions = {1, _currentVersion};

  static String _aadFor(int version) => 'ShiftStudy.ScheduleBackup.v$version';

  Future<Uint8List> encode(
    List<ScheduleItem> items, {
    required String passphrase,
    DateTime? createdAt,
    List<WorkCodeLegend> workCodeLegends = const [],
    List<AcademicTerm> academicTerms = const [],
    List<SupervisorProfile> supervisors = const [],
  }) async {
    _validatePassphrase(passphrase);
    if (items.length > maxItems) {
      throw const FormatException('This schedule contains too many events.');
    }
    _checkUniqueIds(items);
    _checkTermReferences(items, academicTerms);
    if (supervisors.length > 1000) {
      throw const FormatException(
        'This schedule contains too many supervisors.',
      );
    }
    final supervisorIds = <String>{};
    for (final profile in supervisors) {
      if (profile.id.trim().isEmpty ||
          profile.id.length > 256 ||
          profile.name.trim().isEmpty ||
          profile.name.trim().length > 256 ||
          profile.phone.trim().length > 128 ||
          profile.notes.trim().length > 2000 ||
          !supervisorIds.add(profile.id)) {
        throw const FormatException('Supervisor contacts are invalid.');
      }
    }
    for (final entry in workCodeLegends) {
      final windows = entry.timeWindows;
      if (entry.id.trim().isEmpty ||
          entry.id.length > 256 ||
          entry.employer.trim().isEmpty ||
          entry.employer.trim().length > 512 ||
          entry.code.trim().isEmpty ||
          entry.code.trim().length > 128 ||
          entry.assignmentDetails.trim().length > 4000 ||
          windows.length > 2 ||
          windows.any((window) => !window.isValid) ||
          (windows.isEmpty && entry.assignmentDetails.trim().isEmpty) ||
          ((entry.startMinute == null) != (entry.endMinute == null))) {
        throw const FormatException('Roster-code definitions are invalid.');
      }
    }
    final plain = utf8.encode(
      jsonEncode({
        'format': _payloadFormat,
        'version': _currentVersion,
        'createdAt': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
        'events': [for (final item in items) _encodeItem(item)],
        'academicTerms': [for (final term in academicTerms) _encodeTerm(term)],
        'workCodeLegends': [
          for (final entry in workCodeLegends)
            {
              'id': entry.id,
              'employer': entry.employer,
              'code': entry.code,
              'meaning': entry.assignmentDetails,
              'assignmentDetails': entry.assignmentDetails,
              'startMinute': entry.startMinute,
              'endMinute': entry.endMinute,
              'timeWindows': [
                for (final window in entry.timeWindows)
                  {
                    'startMinute': window.startMinute,
                    'endMinute': window.endMinute,
                    'endDayOffset': window.endDayOffset,
                  },
              ],
              'flightIds': entry.flightIds,
            },
        ],
        'supervisors': [
          for (final profile in supervisors)
            {
              'id': profile.id,
              'name': profile.name,
              'type': profile.type.name,
              'phone': profile.phone,
              'notes': profile.notes,
            },
        ],
      }),
    );
    if (plain.length > maxBytes) {
      throw const FormatException('This schedule is too large to back up.');
    }

    final random = Random.secure();
    final salt = List<int>.generate(_saltBytes, (_) => random.nextInt(256));
    final key = await _kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    final box = await _cipher.encrypt(
      plain,
      secretKey: key,
      aad: utf8.encode(_aadFor(_currentVersion)),
    );
    final bytes = utf8.encode(
      jsonEncode({
        'format': _format,
        'version': _currentVersion,
        'cipher': 'AES-256-GCM',
        'kdf': 'PBKDF2-HMAC-SHA256',
        'iterations': _iterations,
        'salt': base64Encode(salt),
        'nonce': base64Encode(box.nonce),
        'mac': base64Encode(box.mac.bytes),
        'ciphertext': base64Encode(box.cipherText),
      }),
    );
    if (bytes.length > maxBytes) {
      throw const FormatException('This schedule is too large to back up.');
    }
    return Uint8List.fromList(bytes);
  }

  Future<ScheduleBackup> decode(
    List<int> bytes, {
    required String passphrase,
  }) async {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('This backup file is empty or too large.');
    }
    _validatePassphrase(passphrase);
    final envelope = _readObject(
      _decodeJson(bytes, 'Backup file is not valid.'),
      'Backup file is not valid.',
    );
    final version = envelope['version'];
    if (envelope['format'] != _format ||
        version is! int ||
        !_supportedVersions.contains(version)) {
      throw const FormatException('This backup format is not supported.');
    }
    if (envelope['cipher'] != 'AES-256-GCM' ||
        envelope['kdf'] != 'PBKDF2-HMAC-SHA256' ||
        envelope['iterations'] != _iterations) {
      throw const FormatException(
        'This backup uses unsupported security settings.',
      );
    }
    final salt = _base64Field(
      envelope,
      'salt',
      'Backup security data is invalid.',
    );
    final nonce = _base64Field(
      envelope,
      'nonce',
      'Backup security data is invalid.',
    );
    final mac = _base64Field(
      envelope,
      'mac',
      'Backup security data is invalid.',
    );
    final ciphertext = _base64Field(
      envelope,
      'ciphertext',
      'Backup security data is invalid.',
    );
    if (salt.length != _saltBytes ||
        nonce.length != _cipher.nonceLength ||
        mac.length != 16 ||
        ciphertext.isEmpty ||
        ciphertext.length > maxBytes) {
      throw const FormatException('Backup security data is invalid.');
    }
    final key = await _kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    late final List<int> clear;
    try {
      clear = await _cipher.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
        aad: utf8.encode(_aadFor(version)),
      );
    } on Object {
      throw const FormatException(
        'This backup could not be unlocked. Check the passphrase and file.',
      );
    }
    final payload = _readObject(
      _decodeJson(clear, 'Backup contents are not valid.'),
      'Backup contents are not valid.',
    );
    if (payload['format'] != _payloadFormat ||
        payload['version'] != version ||
        payload['createdAt'] is! String ||
        payload['events'] is! List ||
        (payload['workCodeLegends'] != null &&
            payload['workCodeLegends'] is! List) ||
        (payload['academicTerms'] != null &&
            payload['academicTerms'] is! List) ||
        (payload['supervisors'] != null && payload['supervisors'] is! List)) {
      throw const FormatException('Backup contents are not supported.');
    }
    final createdAt = DateTime.tryParse(payload['createdAt']! as String);
    if (createdAt == null || !createdAt.isUtc) {
      throw const FormatException('Backup date is invalid.');
    }
    final rawItems = payload['events']! as List;
    if (rawItems.length > maxItems) {
      throw const FormatException('This backup contains too many events.');
    }
    final items = <ScheduleItem>[];
    try {
      for (final raw in rawItems) {
        items.add(_decodeItem(_readObject(raw, 'Backup event is invalid.')));
      }
      _checkUniqueIds(items);
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException(
        'A saved event in this backup is incomplete or invalid.',
      );
    }
    final terms = <AcademicTerm>[];
    final termIds = <String>{};
    final termNames = <String>{};
    final rawTerms = payload['academicTerms'] as List? ?? const [];
    if (rawTerms.length > maxItems) {
      throw const FormatException('This backup contains too many terms.');
    }
    for (final raw in rawTerms) {
      final term = _decodeTerm(_readObject(raw, 'Backup term is invalid.'));
      final naturalKey =
          '${term.institution.toLowerCase()}\u0000${term.name.toLowerCase()}';
      if (!termIds.add(term.id) || !termNames.add(naturalKey)) {
        throw const FormatException(
          'Backup academic terms contain duplicate entries.',
        );
      }
      terms.add(term);
    }
    _checkTermReferences(items, terms);
    final legends = <WorkCodeLegend>[];
    final rawLegends = payload['workCodeLegends'] as List? ?? const [];
    if (rawLegends.length > maxItems) {
      throw const FormatException(
        'This backup contains too many roster codes.',
      );
    }
    final legendIds = <String>{};
    final legendKeys = <String>{};
    for (final raw in rawLegends) {
      final value = _readObject(raw, 'Backup roster code is invalid.');
      final entry = WorkCodeLegend(
        id: _requiredString(value, 'id', 256),
        employer: (value['employer'] as String? ?? '').trim(),
        code: _requiredString(value, 'code', 128).trim(),
        assignmentDetails:
            (value['assignmentDetails'] as String? ??
                    value['meaning'] as String? ??
                    '')
                .trim(),
        startMinute: value['startMinute'] as int?,
        endMinute: value['endMinute'] as int?,
        timeWindows: _readTimeWindows(value['timeWindows']),
        flightIds: _readFlightIds(value['flightIds']),
      );
      final windows = entry.timeWindows;
      final key =
          '${entry.employer.toLowerCase()}\u0000${entry.code.toLowerCase()}';
      if (entry.employer.isEmpty ||
          entry.code.isEmpty ||
          (entry.assignmentDetails.isEmpty && windows.isEmpty) ||
          windows.length > 2 ||
          windows.any((window) => !window.isValid) ||
          !legendIds.add(entry.id) ||
          !legendKeys.add(key)) {
        throw const FormatException(
          'Backup roster codes contain invalid or duplicate entries.',
        );
      }
      legends.add(entry);
    }
    final supervisors = <SupervisorProfile>[];
    final rawSupervisors = payload['supervisors'] as List? ?? const [];
    if (rawSupervisors.length > 1000) {
      throw const FormatException('This backup contains too many supervisors.');
    }
    final supervisorIds = <String>{};
    for (final raw in rawSupervisors) {
      final value = _readObject(raw, 'Backup supervisor is invalid.');
      final typeName = value['type'] as String? ?? 'permanent';
      final type = SupervisorType.values.where(
        (entry) => entry.name == typeName,
      );
      if (type.isEmpty) {
        throw const FormatException('Backup supervisor type is invalid.');
      }
      final profile = SupervisorProfile(
        id: _requiredString(value, 'id', 256),
        name: _requiredString(value, 'name', 256).trim(),
        type: type.first,
        phone: (value['phone'] as String? ?? '').trim(),
        notes: (value['notes'] as String? ?? '').trim(),
      );
      if (profile.name.isEmpty ||
          profile.phone.length > 128 ||
          profile.notes.length > 2000 ||
          !supervisorIds.add(profile.id)) {
        throw const FormatException(
          'Backup supervisor contacts contain invalid or duplicate entries.',
        );
      }
      supervisors.add(profile);
    }
    return ScheduleBackup(
      createdAt: createdAt,
      items: items,
      workCodeLegends: legends,
      academicTerms: terms,
      supervisors: supervisors,
    );
  }

  static final _cipher = AesGcm.with256bits();
  static final _kdf = Pbkdf2.hmacSha256(iterations: _iterations, bits: 256);

  static void _validatePassphrase(String value) {
    if (value.trim().length < 12 || value.length > 256) {
      throw const FormatException(
        'Use a passphrase between 12 and 256 characters.',
      );
    }
  }

  static void _checkUniqueIds(List<ScheduleItem> items) {
    final ids = <String>{};
    for (final item in items) {
      if (!ids.add(item.id)) {
        throw const FormatException('The backup contains duplicate event IDs.');
      }
    }
  }

  static void _checkTermReferences(
    List<ScheduleItem> items,
    List<AcademicTerm> terms,
  ) {
    final termIds = terms.map((term) => term.id).toSet();
    if (items.any(
      (item) =>
          item.academicTermId != null && !termIds.contains(item.academicTermId),
    )) {
      throw const FormatException(
        'A study event refers to an academic term missing from this backup.',
      );
    }
  }

  static Map<String, Object?> _encodeTerm(AcademicTerm term) => {
    'id': term.id,
    'institution': term.institution,
    'name': term.name,
    'startDate': term.startDate.toString(),
    'endDate': term.endDate.toString(),
  };

  static AcademicTerm _decodeTerm(Map<String, Object?> json) => AcademicTerm(
    id: _requiredString(json, 'id', 256),
    institution: _requiredString(json, 'institution', 512),
    name: _requiredString(json, 'name', 256),
    startDate: _readDateValue(json['startDate']),
    endDate: _readDateValue(json['endDate']),
  );

  static Map<String, Object?> _encodeItem(ScheduleItem item) => {
    'id': item.id,
    'kind': item.kind.name,
    'title': item.title,
    'startDate': item.startDate.toString(),
    'timeZoneId': item.timeZoneId,
    'code': item.code,
    'academicTermId': item.academicTermId,
    'employerName': item.employerName,
    'departmentName': item.departmentName,
    'jobRole': item.jobRole,
    'codeMeaning': item.codeMeaning,
    'location': item.location,
    'notes': item.notes,
    'reportingInstruction': item.reportingInstruction,
    'supervisorName': item.supervisorName,
    'supervisorPhone': item.supervisorPhone,
    'contactName': item.contactName,
    'contactPhone': item.contactPhone,
    'intervals': [
      for (final interval in item.intervals) _encodeInterval(interval),
    ],
    'actualIntervals': item.actualIntervals == null
        ? null
        : [
            for (final interval in item.actualIntervals!)
              _encodeInterval(interval),
          ],
    'recurrence': item.recurrence == null
        ? null
        : {
            'weekdays': item.recurrence!.weekdays.toList()..sort(),
            'until': item.recurrence!.until?.toString(),
            'exceptionDates':
                item.recurrence!.exceptionDates
                    .map((date) => date.toString())
                    .toList()
                  ..sort(),
          },
    'workCategory': item.workCategory?.name,
    'deadlineType': item.deadlineType?.name,
    'isCompleted': item.isCompleted,
    'allDay': item.allDay,
    'reminderMinutesBefore': item.reminderMinutesBefore,
    'importProvenance': item.importProvenance == null
        ? null
        : {
            'format': item.importProvenance!.format,
            'uid': item.importProvenance!.uid,
            'sourceName': item.importProvenance!.sourceName,
            'sourceText': item.importProvenance!.sourceText,
            'importedAt': item.importProvenance!.importedAt
                .toUtc()
                .toIso8601String(),
          },
  };

  static ScheduleItem _decodeItem(Map<String, Object?> json) {
    List<EventInterval> decodeIntervals(String key) =>
        _requiredList(json, key, 32)
            .map((raw) {
              final interval = _readObject(raw, 'Backup interval is invalid.');
              return EventInterval(
                startDayOffset: _requiredInt(interval, 'startDayOffset'),
                startMinute: _requiredInt(interval, 'startMinute'),
                endDayOffset: _requiredInt(interval, 'endDayOffset'),
                endMinute: _requiredInt(interval, 'endMinute'),
                startFoldChoice: _optionalEnum(
                  CivilTimeFoldChoice.values,
                  interval['startFoldChoice'],
                ),
                endFoldChoice: _optionalEnum(
                  CivilTimeFoldChoice.values,
                  interval['endFoldChoice'],
                ),
              );
            })
            .toList(growable: false);
    final intervals = decodeIntervals('intervals');
    final actualIntervals = json['actualIntervals'] == null
        ? null
        : decodeIntervals('actualIntervals');
    final recurrenceJson = json['recurrence'];
    WeeklyRecurrence? recurrence;
    if (recurrenceJson != null) {
      final value = _readObject(
        recurrenceJson,
        'Backup recurrence is invalid.',
      );
      final weekdays = _requiredList(
        value,
        'weekdays',
        7,
      ).map((day) => day is int ? day : -1).toSet();
      final until = _optionalDate(value['until']);
      final exceptions = _requiredList(
        value,
        'exceptionDates',
        10000,
      ).map(_readDateValue).toSet();
      recurrence = WeeklyRecurrence(
        weekdays: weekdays,
        until: until,
        exceptionDates: exceptions,
      );
    }
    final kind = _requiredEnum(ScheduleKind.values, json['kind'], 'kind');
    final allDay = json['allDay'];
    if (allDay != null && allDay is! bool) {
      throw const FormatException('Backup all-day value is invalid.');
    }
    final reminderMinutesBefore = json['reminderMinutesBefore'];
    if (reminderMinutesBefore != null && reminderMinutesBefore is! int) {
      throw const FormatException('Backup reminder is invalid.');
    }
    final workCategory = _optionalEnum(
      WorkCategory.values,
      json['workCategory'],
    );
    final deadlineType = _optionalEnum(
      DeadlineType.values,
      json['deadlineType'],
    );
    if (kind == ScheduleKind.work && workCategory == null) {
      throw const FormatException('Backup work category is missing.');
    }
    if (kind == ScheduleKind.deadline && deadlineType == null) {
      throw const FormatException('Backup deadline type is missing.');
    }
    final isCompleted = json['isCompleted'];
    if (isCompleted != null && isCompleted is! bool) {
      throw const FormatException('Backup completion status is invalid.');
    }
    final completionSupported =
        kind == ScheduleKind.deadline ||
        (kind == ScheduleKind.work &&
            (workCategory == WorkCategory.shift ||
                workCategory == WorkCategory.overtime));
    if (isCompleted == true && !completionSupported) {
      throw const FormatException(
        'This event type does not support completion tracking.',
      );
    }
    if (actualIntervals != null && isCompleted != true) {
      throw const FormatException(
        'Actual shift times require a completed shift.',
      );
    }
    final provenanceJson = json['importProvenance'];
    ScheduleImportProvenance? provenance;
    if (provenanceJson != null) {
      final value = _readObject(
        provenanceJson,
        'Backup import provenance is invalid.',
      );
      final importedAt = DateTime.tryParse(
        _requiredString(value, 'importedAt', 64),
      );
      if (importedAt == null || !importedAt.isUtc) {
        throw const FormatException('Backup import date is invalid.');
      }
      provenance = ScheduleImportProvenance(
        format: _requiredString(value, 'format', 64),
        uid: _requiredString(value, 'uid', 1024),
        sourceName: _requiredString(value, 'sourceName', 512),
        sourceText: _requiredString(value, 'sourceText', maxBytes),
        importedAt: importedAt,
      );
    }
    return ScheduleItem(
      id: _requiredString(json, 'id', 256),
      kind: kind,
      title: _requiredString(json, 'title', 16384),
      startDate: _readDateValue(json['startDate']),
      timeZoneId: _optionalString(json, 'timeZoneId', 128),
      code: _optionalString(json, 'code', 16384),
      academicTermId: _optionalString(json, 'academicTermId', 256),
      employerName: _optionalString(json, 'employerName', 512),
      departmentName: _optionalString(json, 'departmentName', 512),
      jobRole: _optionalString(json, 'jobRole', 512),
      codeMeaning: _optionalString(json, 'codeMeaning', 16384),
      location: _optionalString(json, 'location', 16384),
      notes: _optionalString(json, 'notes', 16384),
      reportingInstruction: _optionalString(
        json,
        'reportingInstruction',
        16384,
      ),
      supervisorName: _optionalString(json, 'supervisorName', 512),
      supervisorPhone: _optionalString(json, 'supervisorPhone', 256),
      contactName: _optionalString(json, 'contactName', 512),
      contactPhone: _optionalString(json, 'contactPhone', 256),
      intervals: intervals,
      recurrence: recurrence,
      workCategory: workCategory,
      deadlineType: deadlineType,
      isCompleted: isCompleted == true,
      actualIntervals: actualIntervals,
      allDay: allDay == true,
      reminderMinutesBefore: reminderMinutesBefore as int?,
      importProvenance: provenance,
    );
  }

  static Map<String, Object?> _encodeInterval(EventInterval interval) => {
    'startDayOffset': interval.startDayOffset,
    'startMinute': interval.startMinute,
    'endDayOffset': interval.endDayOffset,
    'endMinute': interval.endMinute,
    'startFoldChoice': interval.startFoldChoice?.name,
    'endFoldChoice': interval.endFoldChoice?.name,
  };

  static Object? _decodeJson(List<int> bytes, String error) {
    try {
      return jsonDecode(utf8.decode(bytes, allowMalformed: false));
    } on Object {
      throw FormatException(error);
    }
  }

  static Map<String, Object?> _readObject(Object? value, String error) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw FormatException(error);
    }
    return value.cast<String, Object?>();
  }

  static List<Object?> _requiredList(
    Map<String, Object?> json,
    String key,
    int maxLength,
  ) {
    final value = json[key];
    if (value is! List || value.length > maxLength) {
      throw FormatException('Backup $key list is invalid.');
    }
    return value.cast<Object?>();
  }

  static int _requiredInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int) throw FormatException('Backup $key is invalid.');
    return value;
  }

  static String _requiredString(
    Map<String, Object?> json,
    String key,
    int maxLength,
  ) {
    final value = json[key];
    if (value is! String || value.isEmpty || value.length > maxLength) {
      throw FormatException('Backup $key is invalid.');
    }
    return value;
  }

  static List<String> _readFlightIds(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List ||
        raw.length > 100 ||
        raw.any((value) => value is! String)) {
      throw const FormatException('Backup flight references are invalid.');
    }
    final result = <String>[];
    final seen = <String>{};
    for (final value in raw.cast<String>()) {
      final id = value.trim();
      if (id.isEmpty || id.length > 32 || !seen.add(id.toUpperCase())) {
        throw const FormatException('Backup flight references are invalid.');
      }
      result.add(id);
    }
    return result;
  }

  static List<WorkCodeTimeWindow> _readTimeWindows(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List || raw.length > 2) {
      throw const FormatException('Backup shift-code times are invalid.');
    }
    return [for (final value in raw) _readTimeWindow(value)];
  }

  static WorkCodeTimeWindow _readTimeWindow(Object? raw) {
    final value = _readObject(raw, 'Backup shift-code time is invalid.');
    final startMinute = value['startMinute'];
    final endMinute = value['endMinute'];
    final endDayOffset = value['endDayOffset'] ?? 0;
    if (startMinute is! int || endMinute is! int || endDayOffset is! int) {
      throw const FormatException('Backup shift-code time is invalid.');
    }
    final window = WorkCodeTimeWindow(
      startMinute: startMinute,
      endMinute: endMinute,
      endDayOffset: endDayOffset,
    );
    if (!window.isValid) {
      throw const FormatException('Backup shift-code time is invalid.');
    }
    return window;
  }

  static String? _optionalString(
    Map<String, Object?> json,
    String key,
    int maxLength,
  ) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String || value.length > maxLength) {
      throw FormatException('Backup $key is invalid.');
    }
    return value;
  }

  static T _requiredEnum<T extends Enum>(
    List<T> values,
    Object? raw,
    String key,
  ) {
    if (raw is! String) throw FormatException('Backup $key is invalid.');
    for (final value in values) {
      if (value.name == raw) return value;
    }
    throw FormatException('Backup $key is not supported.');
  }

  static T? _optionalEnum<T extends Enum>(List<T> values, Object? raw) {
    if (raw == null) return null;
    if (raw is! String) {
      throw const FormatException('Backup category is invalid.');
    }
    for (final value in values) {
      if (value.name == raw) return value;
    }
    throw const FormatException('Backup category is not supported.');
  }

  static CivilDate _readDateValue(Object? raw) {
    if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      throw const FormatException('Backup date is invalid.');
    }
    final parts = raw.split('-').map(int.parse).toList();
    final date = CivilDate(parts[0], parts[1], parts[2]);
    if (!date.isValid) throw const FormatException('Backup date is invalid.');
    return date;
  }

  static CivilDate? _optionalDate(Object? raw) =>
      raw == null ? null : _readDateValue(raw);

  static List<int> _base64Field(
    Map<String, Object?> json,
    String key,
    String error,
  ) {
    final value = json[key];
    if (value is! String) throw FormatException(error);
    try {
      return base64Decode(value);
    } on Object {
      throw FormatException(error);
    }
  }
}
