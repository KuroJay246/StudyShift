import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../domain/academic_term.dart';
import '../domain/schedule.dart';
import '../domain/work_code_legend.dart';

class ScheduleBackup {
  const ScheduleBackup({
    required this.createdAt,
    required this.items,
    this.workCodeLegends = const [],
    this.academicTerms = const [],
  });

  final DateTime createdAt;
  final List<ScheduleItem> items;
  final List<WorkCodeLegend> workCodeLegends;
  final List<AcademicTerm> academicTerms;
}

/// A portable, authenticated, passphrase-encrypted schedule backup.
class ScheduleBackupCodec {
  const ScheduleBackupCodec();

  static const maxBytes = 10 * 1024 * 1024;
  static const maxItems = 10000;
  static const _iterations = 600000;
  static const _saltBytes = 16;
  static const _aad = 'ShiftStudy.ScheduleBackup.v1';
  static const _format = 'shift-study-encrypted-backup';
  static const _payloadFormat = 'shift-study-schedule';
  static const _version = 1;

  Future<Uint8List> encode(
    List<ScheduleItem> items, {
    required String passphrase,
    DateTime? createdAt,
    List<WorkCodeLegend> workCodeLegends = const [],
    List<AcademicTerm> academicTerms = const [],
  }) async {
    _validatePassphrase(passphrase);
    if (items.length > maxItems) {
      throw const FormatException('This schedule contains too many events.');
    }
    _checkUniqueIds(items);
    _checkTermReferences(items, academicTerms);
    final plain = utf8.encode(
      jsonEncode({
        'format': _payloadFormat,
        'version': _version,
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
              'flightIds': entry.flightIds,
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
      aad: utf8.encode(_aad),
    );
    final bytes = utf8.encode(
      jsonEncode({
        'format': _format,
        'version': _version,
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
    if (envelope['format'] != _format || envelope['version'] != _version) {
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
        aad: utf8.encode(_aad),
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
        payload['version'] != _version ||
        payload['createdAt'] is! String ||
        payload['events'] is! List ||
        (payload['workCodeLegends'] != null &&
            payload['workCodeLegends'] is! List) ||
        (payload['academicTerms'] != null &&
            payload['academicTerms'] is! List)) {
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
        flightIds: _readFlightIds(value['flightIds']),
      );
      final key =
          '${entry.employer.toLowerCase()}\u0000${entry.code.toLowerCase()}';
      if (entry.employer.isEmpty ||
          entry.code.isEmpty ||
          (entry.assignmentDetails.isEmpty && entry.startMinute == null) ||
          ((entry.startMinute == null) != (entry.endMinute == null)) ||
          (entry.startMinute != null &&
              (entry.startMinute! < 0 ||
                  entry.startMinute! >= 1440 ||
                  entry.endMinute! < 0 ||
                  entry.endMinute! >= 1440)) ||
          !legendIds.add(entry.id) ||
          !legendKeys.add(key)) {
        throw const FormatException(
          'Backup roster codes contain invalid or duplicate entries.',
        );
      }
      legends.add(entry);
    }
    return ScheduleBackup(
      createdAt: createdAt,
      items: items,
      workCodeLegends: legends,
      academicTerms: terms,
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
