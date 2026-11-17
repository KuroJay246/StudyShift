// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_database.dart';

// ignore_for_file: type=lint
class $AcademicTermRowsTable extends AcademicTermRows
    with TableInfo<$AcademicTermRowsTable, AcademicTermRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AcademicTermRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _institutionMeta = const VerificationMeta(
    'institution',
  );
  @override
  late final GeneratedColumn<String> institution = GeneratedColumn<String>(
    'institution',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<String> endDate = GeneratedColumn<String>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    institution,
    name,
    startDate,
    endDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'academic_term_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<AcademicTermRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('institution')) {
      context.handle(
        _institutionMeta,
        institution.isAcceptableOrUnknown(
          data['institution']!,
          _institutionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_institutionMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AcademicTermRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AcademicTermRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      institution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date'],
      )!,
    );
  }

  @override
  $AcademicTermRowsTable createAlias(String alias) {
    return $AcademicTermRowsTable(attachedDatabase, alias);
  }
}

class AcademicTermRow extends DataClass implements Insertable<AcademicTermRow> {
  final String id;
  final String institution;
  final String name;
  final String startDate;
  final String endDate;
  const AcademicTermRow({
    required this.id,
    required this.institution,
    required this.name,
    required this.startDate,
    required this.endDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['institution'] = Variable<String>(institution);
    map['name'] = Variable<String>(name);
    map['start_date'] = Variable<String>(startDate);
    map['end_date'] = Variable<String>(endDate);
    return map;
  }

  AcademicTermRowsCompanion toCompanion(bool nullToAbsent) {
    return AcademicTermRowsCompanion(
      id: Value(id),
      institution: Value(institution),
      name: Value(name),
      startDate: Value(startDate),
      endDate: Value(endDate),
    );
  }

  factory AcademicTermRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AcademicTermRow(
      id: serializer.fromJson<String>(json['id']),
      institution: serializer.fromJson<String>(json['institution']),
      name: serializer.fromJson<String>(json['name']),
      startDate: serializer.fromJson<String>(json['startDate']),
      endDate: serializer.fromJson<String>(json['endDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'institution': serializer.toJson<String>(institution),
      'name': serializer.toJson<String>(name),
      'startDate': serializer.toJson<String>(startDate),
      'endDate': serializer.toJson<String>(endDate),
    };
  }

  AcademicTermRow copyWith({
    String? id,
    String? institution,
    String? name,
    String? startDate,
    String? endDate,
  }) => AcademicTermRow(
    id: id ?? this.id,
    institution: institution ?? this.institution,
    name: name ?? this.name,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
  );
  AcademicTermRow copyWithCompanion(AcademicTermRowsCompanion data) {
    return AcademicTermRow(
      id: data.id.present ? data.id.value : this.id,
      institution: data.institution.present
          ? data.institution.value
          : this.institution,
      name: data.name.present ? data.name.value : this.name,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AcademicTermRow(')
          ..write('id: $id, ')
          ..write('institution: $institution, ')
          ..write('name: $name, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, institution, name, startDate, endDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AcademicTermRow &&
          other.id == this.id &&
          other.institution == this.institution &&
          other.name == this.name &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate);
}

class AcademicTermRowsCompanion extends UpdateCompanion<AcademicTermRow> {
  final Value<String> id;
  final Value<String> institution;
  final Value<String> name;
  final Value<String> startDate;
  final Value<String> endDate;
  final Value<int> rowid;
  const AcademicTermRowsCompanion({
    this.id = const Value.absent(),
    this.institution = const Value.absent(),
    this.name = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AcademicTermRowsCompanion.insert({
    required String id,
    required String institution,
    required String name,
    required String startDate,
    required String endDate,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       institution = Value(institution),
       name = Value(name),
       startDate = Value(startDate),
       endDate = Value(endDate);
  static Insertable<AcademicTermRow> custom({
    Expression<String>? id,
    Expression<String>? institution,
    Expression<String>? name,
    Expression<String>? startDate,
    Expression<String>? endDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (institution != null) 'institution': institution,
      if (name != null) 'name': name,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AcademicTermRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? institution,
    Value<String>? name,
    Value<String>? startDate,
    Value<String>? endDate,
    Value<int>? rowid,
  }) {
    return AcademicTermRowsCompanion(
      id: id ?? this.id,
      institution: institution ?? this.institution,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (institution.present) {
      map['institution'] = Variable<String>(institution.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AcademicTermRowsCompanion(')
          ..write('id: $id, ')
          ..write('institution: $institution, ')
          ..write('name: $name, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScheduleRowsTable extends ScheduleRows
    with TableInfo<$ScheduleRowsTable, ScheduleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduleRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeZoneIdMeta = const VerificationMeta(
    'timeZoneId',
  );
  @override
  late final GeneratedColumn<String> timeZoneId = GeneratedColumn<String>(
    'time_zone_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codeMeaningMeta = const VerificationMeta(
    'codeMeaning',
  );
  @override
  late final GeneratedColumn<String> codeMeaning = GeneratedColumn<String>(
    'code_meaning',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _employerNameMeta = const VerificationMeta(
    'employerName',
  );
  @override
  late final GeneratedColumn<String> employerName = GeneratedColumn<String>(
    'employer_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _departmentNameMeta = const VerificationMeta(
    'departmentName',
  );
  @override
  late final GeneratedColumn<String> departmentName = GeneratedColumn<String>(
    'department_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _jobRoleMeta = const VerificationMeta(
    'jobRole',
  );
  @override
  late final GeneratedColumn<String> jobRole = GeneratedColumn<String>(
    'job_role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reportingInstructionMeta =
      const VerificationMeta('reportingInstruction');
  @override
  late final GeneratedColumn<String> reportingInstruction =
      GeneratedColumn<String>(
        'reporting_instruction',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _supervisorNameMeta = const VerificationMeta(
    'supervisorName',
  );
  @override
  late final GeneratedColumn<String> supervisorName = GeneratedColumn<String>(
    'supervisor_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _supervisorPhoneMeta = const VerificationMeta(
    'supervisorPhone',
  );
  @override
  late final GeneratedColumn<String> supervisorPhone = GeneratedColumn<String>(
    'supervisor_phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactNameMeta = const VerificationMeta(
    'contactName',
  );
  @override
  late final GeneratedColumn<String> contactName = GeneratedColumn<String>(
    'contact_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactPhoneMeta = const VerificationMeta(
    'contactPhone',
  );
  @override
  late final GeneratedColumn<String> contactPhone = GeneratedColumn<String>(
    'contact_phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _academicTermIdMeta = const VerificationMeta(
    'academicTermId',
  );
  @override
  late final GeneratedColumn<String> academicTermId = GeneratedColumn<String>(
    'academic_term_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES academic_term_rows (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _weekdaysMeta = const VerificationMeta(
    'weekdays',
  );
  @override
  late final GeneratedColumn<String> weekdays = GeneratedColumn<String>(
    'weekdays',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _untilDateMeta = const VerificationMeta(
    'untilDate',
  );
  @override
  late final GeneratedColumn<String> untilDate = GeneratedColumn<String>(
    'until_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exceptionDatesMeta = const VerificationMeta(
    'exceptionDates',
  );
  @override
  late final GeneratedColumn<String> exceptionDates = GeneratedColumn<String>(
    'exception_dates',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDayOffMeta = const VerificationMeta(
    'isDayOff',
  );
  @override
  late final GeneratedColumn<bool> isDayOff = GeneratedColumn<bool>(
    'is_day_off',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_day_off" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _workCategoryMeta = const VerificationMeta(
    'workCategory',
  );
  @override
  late final GeneratedColumn<int> workCategory = GeneratedColumn<int>(
    'work_category',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deadlineTypeMeta = const VerificationMeta(
    'deadlineType',
  );
  @override
  late final GeneratedColumn<int> deadlineType = GeneratedColumn<int>(
    'deadline_type',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allDayMeta = const VerificationMeta('allDay');
  @override
  late final GeneratedColumn<bool> allDay = GeneratedColumn<bool>(
    'all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _importFormatMeta = const VerificationMeta(
    'importFormat',
  );
  @override
  late final GeneratedColumn<String> importFormat = GeneratedColumn<String>(
    'import_format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importUidMeta = const VerificationMeta(
    'importUid',
  );
  @override
  late final GeneratedColumn<String> importUid = GeneratedColumn<String>(
    'import_uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importSourceNameMeta = const VerificationMeta(
    'importSourceName',
  );
  @override
  late final GeneratedColumn<String> importSourceName = GeneratedColumn<String>(
    'import_source_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importSourceTextMeta = const VerificationMeta(
    'importSourceText',
  );
  @override
  late final GeneratedColumn<String> importSourceText = GeneratedColumn<String>(
    'import_source_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<String> importedAt = GeneratedColumn<String>(
    'imported_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderMinutesBeforeMeta =
      const VerificationMeta('reminderMinutesBefore');
  @override
  late final GeneratedColumn<int> reminderMinutesBefore = GeneratedColumn<int>(
    'reminder_minutes_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _actualIntervalsJsonMeta =
      const VerificationMeta('actualIntervalsJson');
  @override
  late final GeneratedColumn<String> actualIntervalsJson =
      GeneratedColumn<String>(
        'actual_intervals_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    title,
    startDate,
    timeZoneId,
    code,
    codeMeaning,
    employerName,
    departmentName,
    jobRole,
    location,
    notes,
    reportingInstruction,
    supervisorName,
    supervisorPhone,
    contactName,
    contactPhone,
    academicTermId,
    weekdays,
    untilDate,
    exceptionDates,
    isDayOff,
    workCategory,
    deadlineType,
    allDay,
    importFormat,
    importUid,
    importSourceName,
    importSourceText,
    importedAt,
    reminderMinutesBefore,
    isCompleted,
    actualIntervalsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schedule_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('time_zone_id')) {
      context.handle(
        _timeZoneIdMeta,
        timeZoneId.isAcceptableOrUnknown(
          data['time_zone_id']!,
          _timeZoneIdMeta,
        ),
      );
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    }
    if (data.containsKey('code_meaning')) {
      context.handle(
        _codeMeaningMeta,
        codeMeaning.isAcceptableOrUnknown(
          data['code_meaning']!,
          _codeMeaningMeta,
        ),
      );
    }
    if (data.containsKey('employer_name')) {
      context.handle(
        _employerNameMeta,
        employerName.isAcceptableOrUnknown(
          data['employer_name']!,
          _employerNameMeta,
        ),
      );
    }
    if (data.containsKey('department_name')) {
      context.handle(
        _departmentNameMeta,
        departmentName.isAcceptableOrUnknown(
          data['department_name']!,
          _departmentNameMeta,
        ),
      );
    }
    if (data.containsKey('job_role')) {
      context.handle(
        _jobRoleMeta,
        jobRole.isAcceptableOrUnknown(data['job_role']!, _jobRoleMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('reporting_instruction')) {
      context.handle(
        _reportingInstructionMeta,
        reportingInstruction.isAcceptableOrUnknown(
          data['reporting_instruction']!,
          _reportingInstructionMeta,
        ),
      );
    }
    if (data.containsKey('supervisor_name')) {
      context.handle(
        _supervisorNameMeta,
        supervisorName.isAcceptableOrUnknown(
          data['supervisor_name']!,
          _supervisorNameMeta,
        ),
      );
    }
    if (data.containsKey('supervisor_phone')) {
      context.handle(
        _supervisorPhoneMeta,
        supervisorPhone.isAcceptableOrUnknown(
          data['supervisor_phone']!,
          _supervisorPhoneMeta,
        ),
      );
    }
    if (data.containsKey('contact_name')) {
      context.handle(
        _contactNameMeta,
        contactName.isAcceptableOrUnknown(
          data['contact_name']!,
          _contactNameMeta,
        ),
      );
    }
    if (data.containsKey('contact_phone')) {
      context.handle(
        _contactPhoneMeta,
        contactPhone.isAcceptableOrUnknown(
          data['contact_phone']!,
          _contactPhoneMeta,
        ),
      );
    }
    if (data.containsKey('academic_term_id')) {
      context.handle(
        _academicTermIdMeta,
        academicTermId.isAcceptableOrUnknown(
          data['academic_term_id']!,
          _academicTermIdMeta,
        ),
      );
    }
    if (data.containsKey('weekdays')) {
      context.handle(
        _weekdaysMeta,
        weekdays.isAcceptableOrUnknown(data['weekdays']!, _weekdaysMeta),
      );
    }
    if (data.containsKey('until_date')) {
      context.handle(
        _untilDateMeta,
        untilDate.isAcceptableOrUnknown(data['until_date']!, _untilDateMeta),
      );
    }
    if (data.containsKey('exception_dates')) {
      context.handle(
        _exceptionDatesMeta,
        exceptionDates.isAcceptableOrUnknown(
          data['exception_dates']!,
          _exceptionDatesMeta,
        ),
      );
    }
    if (data.containsKey('is_day_off')) {
      context.handle(
        _isDayOffMeta,
        isDayOff.isAcceptableOrUnknown(data['is_day_off']!, _isDayOffMeta),
      );
    }
    if (data.containsKey('work_category')) {
      context.handle(
        _workCategoryMeta,
        workCategory.isAcceptableOrUnknown(
          data['work_category']!,
          _workCategoryMeta,
        ),
      );
    }
    if (data.containsKey('deadline_type')) {
      context.handle(
        _deadlineTypeMeta,
        deadlineType.isAcceptableOrUnknown(
          data['deadline_type']!,
          _deadlineTypeMeta,
        ),
      );
    }
    if (data.containsKey('all_day')) {
      context.handle(
        _allDayMeta,
        allDay.isAcceptableOrUnknown(data['all_day']!, _allDayMeta),
      );
    }
    if (data.containsKey('import_format')) {
      context.handle(
        _importFormatMeta,
        importFormat.isAcceptableOrUnknown(
          data['import_format']!,
          _importFormatMeta,
        ),
      );
    }
    if (data.containsKey('import_uid')) {
      context.handle(
        _importUidMeta,
        importUid.isAcceptableOrUnknown(data['import_uid']!, _importUidMeta),
      );
    }
    if (data.containsKey('import_source_name')) {
      context.handle(
        _importSourceNameMeta,
        importSourceName.isAcceptableOrUnknown(
          data['import_source_name']!,
          _importSourceNameMeta,
        ),
      );
    }
    if (data.containsKey('import_source_text')) {
      context.handle(
        _importSourceTextMeta,
        importSourceText.isAcceptableOrUnknown(
          data['import_source_text']!,
          _importSourceTextMeta,
        ),
      );
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    }
    if (data.containsKey('reminder_minutes_before')) {
      context.handle(
        _reminderMinutesBeforeMeta,
        reminderMinutesBefore.isAcceptableOrUnknown(
          data['reminder_minutes_before']!,
          _reminderMinutesBeforeMeta,
        ),
      );
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('actual_intervals_json')) {
      context.handle(
        _actualIntervalsJsonMeta,
        actualIntervalsJson.isAcceptableOrUnknown(
          data['actual_intervals_json']!,
          _actualIntervalsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      timeZoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone_id'],
      ),
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      ),
      codeMeaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code_meaning'],
      ),
      employerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employer_name'],
      ),
      departmentName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}department_name'],
      ),
      jobRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_role'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      reportingInstruction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reporting_instruction'],
      ),
      supervisorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supervisor_name'],
      ),
      supervisorPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supervisor_phone'],
      ),
      contactName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_name'],
      ),
      contactPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_phone'],
      ),
      academicTermId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}academic_term_id'],
      ),
      weekdays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weekdays'],
      ),
      untilDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}until_date'],
      ),
      exceptionDates: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exception_dates'],
      ),
      isDayOff: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_day_off'],
      )!,
      workCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}work_category'],
      ),
      deadlineType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deadline_type'],
      ),
      allDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}all_day'],
      )!,
      importFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_format'],
      ),
      importUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_uid'],
      ),
      importSourceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_source_name'],
      ),
      importSourceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_source_text'],
      ),
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imported_at'],
      ),
      reminderMinutesBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minutes_before'],
      ),
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
      actualIntervalsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actual_intervals_json'],
      ),
    );
  }

  @override
  $ScheduleRowsTable createAlias(String alias) {
    return $ScheduleRowsTable(attachedDatabase, alias);
  }
}

class ScheduleRow extends DataClass implements Insertable<ScheduleRow> {
  final String id;
  final int kind;
  final String title;
  final String startDate;
  final String? timeZoneId;
  final String? code;
  final String? codeMeaning;
  final String? employerName;
  final String? departmentName;
  final String? jobRole;
  final String? location;
  final String? notes;
  final String? reportingInstruction;
  final String? supervisorName;
  final String? supervisorPhone;
  final String? contactName;
  final String? contactPhone;
  final String? academicTermId;
  final String? weekdays;
  final String? untilDate;
  final String? exceptionDates;
  final bool isDayOff;
  final int? workCategory;
  final int? deadlineType;
  final bool allDay;
  final String? importFormat;
  final String? importUid;
  final String? importSourceName;
  final String? importSourceText;
  final String? importedAt;
  final int? reminderMinutesBefore;
  final bool isCompleted;
  final String? actualIntervalsJson;
  const ScheduleRow({
    required this.id,
    required this.kind,
    required this.title,
    required this.startDate,
    this.timeZoneId,
    this.code,
    this.codeMeaning,
    this.employerName,
    this.departmentName,
    this.jobRole,
    this.location,
    this.notes,
    this.reportingInstruction,
    this.supervisorName,
    this.supervisorPhone,
    this.contactName,
    this.contactPhone,
    this.academicTermId,
    this.weekdays,
    this.untilDate,
    this.exceptionDates,
    required this.isDayOff,
    this.workCategory,
    this.deadlineType,
    required this.allDay,
    this.importFormat,
    this.importUid,
    this.importSourceName,
    this.importSourceText,
    this.importedAt,
    this.reminderMinutesBefore,
    required this.isCompleted,
    this.actualIntervalsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<int>(kind);
    map['title'] = Variable<String>(title);
    map['start_date'] = Variable<String>(startDate);
    if (!nullToAbsent || timeZoneId != null) {
      map['time_zone_id'] = Variable<String>(timeZoneId);
    }
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    if (!nullToAbsent || codeMeaning != null) {
      map['code_meaning'] = Variable<String>(codeMeaning);
    }
    if (!nullToAbsent || employerName != null) {
      map['employer_name'] = Variable<String>(employerName);
    }
    if (!nullToAbsent || departmentName != null) {
      map['department_name'] = Variable<String>(departmentName);
    }
    if (!nullToAbsent || jobRole != null) {
      map['job_role'] = Variable<String>(jobRole);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || reportingInstruction != null) {
      map['reporting_instruction'] = Variable<String>(reportingInstruction);
    }
    if (!nullToAbsent || supervisorName != null) {
      map['supervisor_name'] = Variable<String>(supervisorName);
    }
    if (!nullToAbsent || supervisorPhone != null) {
      map['supervisor_phone'] = Variable<String>(supervisorPhone);
    }
    if (!nullToAbsent || contactName != null) {
      map['contact_name'] = Variable<String>(contactName);
    }
    if (!nullToAbsent || contactPhone != null) {
      map['contact_phone'] = Variable<String>(contactPhone);
    }
    if (!nullToAbsent || academicTermId != null) {
      map['academic_term_id'] = Variable<String>(academicTermId);
    }
    if (!nullToAbsent || weekdays != null) {
      map['weekdays'] = Variable<String>(weekdays);
    }
    if (!nullToAbsent || untilDate != null) {
      map['until_date'] = Variable<String>(untilDate);
    }
    if (!nullToAbsent || exceptionDates != null) {
      map['exception_dates'] = Variable<String>(exceptionDates);
    }
    map['is_day_off'] = Variable<bool>(isDayOff);
    if (!nullToAbsent || workCategory != null) {
      map['work_category'] = Variable<int>(workCategory);
    }
    if (!nullToAbsent || deadlineType != null) {
      map['deadline_type'] = Variable<int>(deadlineType);
    }
    map['all_day'] = Variable<bool>(allDay);
    if (!nullToAbsent || importFormat != null) {
      map['import_format'] = Variable<String>(importFormat);
    }
    if (!nullToAbsent || importUid != null) {
      map['import_uid'] = Variable<String>(importUid);
    }
    if (!nullToAbsent || importSourceName != null) {
      map['import_source_name'] = Variable<String>(importSourceName);
    }
    if (!nullToAbsent || importSourceText != null) {
      map['import_source_text'] = Variable<String>(importSourceText);
    }
    if (!nullToAbsent || importedAt != null) {
      map['imported_at'] = Variable<String>(importedAt);
    }
    if (!nullToAbsent || reminderMinutesBefore != null) {
      map['reminder_minutes_before'] = Variable<int>(reminderMinutesBefore);
    }
    map['is_completed'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || actualIntervalsJson != null) {
      map['actual_intervals_json'] = Variable<String>(actualIntervalsJson);
    }
    return map;
  }

  ScheduleRowsCompanion toCompanion(bool nullToAbsent) {
    return ScheduleRowsCompanion(
      id: Value(id),
      kind: Value(kind),
      title: Value(title),
      startDate: Value(startDate),
      timeZoneId: timeZoneId == null && nullToAbsent
          ? const Value.absent()
          : Value(timeZoneId),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      codeMeaning: codeMeaning == null && nullToAbsent
          ? const Value.absent()
          : Value(codeMeaning),
      employerName: employerName == null && nullToAbsent
          ? const Value.absent()
          : Value(employerName),
      departmentName: departmentName == null && nullToAbsent
          ? const Value.absent()
          : Value(departmentName),
      jobRole: jobRole == null && nullToAbsent
          ? const Value.absent()
          : Value(jobRole),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      reportingInstruction: reportingInstruction == null && nullToAbsent
          ? const Value.absent()
          : Value(reportingInstruction),
      supervisorName: supervisorName == null && nullToAbsent
          ? const Value.absent()
          : Value(supervisorName),
      supervisorPhone: supervisorPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(supervisorPhone),
      contactName: contactName == null && nullToAbsent
          ? const Value.absent()
          : Value(contactName),
      contactPhone: contactPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(contactPhone),
      academicTermId: academicTermId == null && nullToAbsent
          ? const Value.absent()
          : Value(academicTermId),
      weekdays: weekdays == null && nullToAbsent
          ? const Value.absent()
          : Value(weekdays),
      untilDate: untilDate == null && nullToAbsent
          ? const Value.absent()
          : Value(untilDate),
      exceptionDates: exceptionDates == null && nullToAbsent
          ? const Value.absent()
          : Value(exceptionDates),
      isDayOff: Value(isDayOff),
      workCategory: workCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(workCategory),
      deadlineType: deadlineType == null && nullToAbsent
          ? const Value.absent()
          : Value(deadlineType),
      allDay: Value(allDay),
      importFormat: importFormat == null && nullToAbsent
          ? const Value.absent()
          : Value(importFormat),
      importUid: importUid == null && nullToAbsent
          ? const Value.absent()
          : Value(importUid),
      importSourceName: importSourceName == null && nullToAbsent
          ? const Value.absent()
          : Value(importSourceName),
      importSourceText: importSourceText == null && nullToAbsent
          ? const Value.absent()
          : Value(importSourceText),
      importedAt: importedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(importedAt),
      reminderMinutesBefore: reminderMinutesBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderMinutesBefore),
      isCompleted: Value(isCompleted),
      actualIntervalsJson: actualIntervalsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(actualIntervalsJson),
    );
  }

  factory ScheduleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduleRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<int>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      startDate: serializer.fromJson<String>(json['startDate']),
      timeZoneId: serializer.fromJson<String?>(json['timeZoneId']),
      code: serializer.fromJson<String?>(json['code']),
      codeMeaning: serializer.fromJson<String?>(json['codeMeaning']),
      employerName: serializer.fromJson<String?>(json['employerName']),
      departmentName: serializer.fromJson<String?>(json['departmentName']),
      jobRole: serializer.fromJson<String?>(json['jobRole']),
      location: serializer.fromJson<String?>(json['location']),
      notes: serializer.fromJson<String?>(json['notes']),
      reportingInstruction: serializer.fromJson<String?>(
        json['reportingInstruction'],
      ),
      supervisorName: serializer.fromJson<String?>(json['supervisorName']),
      supervisorPhone: serializer.fromJson<String?>(json['supervisorPhone']),
      contactName: serializer.fromJson<String?>(json['contactName']),
      contactPhone: serializer.fromJson<String?>(json['contactPhone']),
      academicTermId: serializer.fromJson<String?>(json['academicTermId']),
      weekdays: serializer.fromJson<String?>(json['weekdays']),
      untilDate: serializer.fromJson<String?>(json['untilDate']),
      exceptionDates: serializer.fromJson<String?>(json['exceptionDates']),
      isDayOff: serializer.fromJson<bool>(json['isDayOff']),
      workCategory: serializer.fromJson<int?>(json['workCategory']),
      deadlineType: serializer.fromJson<int?>(json['deadlineType']),
      allDay: serializer.fromJson<bool>(json['allDay']),
      importFormat: serializer.fromJson<String?>(json['importFormat']),
      importUid: serializer.fromJson<String?>(json['importUid']),
      importSourceName: serializer.fromJson<String?>(json['importSourceName']),
      importSourceText: serializer.fromJson<String?>(json['importSourceText']),
      importedAt: serializer.fromJson<String?>(json['importedAt']),
      reminderMinutesBefore: serializer.fromJson<int?>(
        json['reminderMinutesBefore'],
      ),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      actualIntervalsJson: serializer.fromJson<String?>(
        json['actualIntervalsJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<int>(kind),
      'title': serializer.toJson<String>(title),
      'startDate': serializer.toJson<String>(startDate),
      'timeZoneId': serializer.toJson<String?>(timeZoneId),
      'code': serializer.toJson<String?>(code),
      'codeMeaning': serializer.toJson<String?>(codeMeaning),
      'employerName': serializer.toJson<String?>(employerName),
      'departmentName': serializer.toJson<String?>(departmentName),
      'jobRole': serializer.toJson<String?>(jobRole),
      'location': serializer.toJson<String?>(location),
      'notes': serializer.toJson<String?>(notes),
      'reportingInstruction': serializer.toJson<String?>(reportingInstruction),
      'supervisorName': serializer.toJson<String?>(supervisorName),
      'supervisorPhone': serializer.toJson<String?>(supervisorPhone),
      'contactName': serializer.toJson<String?>(contactName),
      'contactPhone': serializer.toJson<String?>(contactPhone),
      'academicTermId': serializer.toJson<String?>(academicTermId),
      'weekdays': serializer.toJson<String?>(weekdays),
      'untilDate': serializer.toJson<String?>(untilDate),
      'exceptionDates': serializer.toJson<String?>(exceptionDates),
      'isDayOff': serializer.toJson<bool>(isDayOff),
      'workCategory': serializer.toJson<int?>(workCategory),
      'deadlineType': serializer.toJson<int?>(deadlineType),
      'allDay': serializer.toJson<bool>(allDay),
      'importFormat': serializer.toJson<String?>(importFormat),
      'importUid': serializer.toJson<String?>(importUid),
      'importSourceName': serializer.toJson<String?>(importSourceName),
      'importSourceText': serializer.toJson<String?>(importSourceText),
      'importedAt': serializer.toJson<String?>(importedAt),
      'reminderMinutesBefore': serializer.toJson<int?>(reminderMinutesBefore),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'actualIntervalsJson': serializer.toJson<String?>(actualIntervalsJson),
    };
  }

  ScheduleRow copyWith({
    String? id,
    int? kind,
    String? title,
    String? startDate,
    Value<String?> timeZoneId = const Value.absent(),
    Value<String?> code = const Value.absent(),
    Value<String?> codeMeaning = const Value.absent(),
    Value<String?> employerName = const Value.absent(),
    Value<String?> departmentName = const Value.absent(),
    Value<String?> jobRole = const Value.absent(),
    Value<String?> location = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> reportingInstruction = const Value.absent(),
    Value<String?> supervisorName = const Value.absent(),
    Value<String?> supervisorPhone = const Value.absent(),
    Value<String?> contactName = const Value.absent(),
    Value<String?> contactPhone = const Value.absent(),
    Value<String?> academicTermId = const Value.absent(),
    Value<String?> weekdays = const Value.absent(),
    Value<String?> untilDate = const Value.absent(),
    Value<String?> exceptionDates = const Value.absent(),
    bool? isDayOff,
    Value<int?> workCategory = const Value.absent(),
    Value<int?> deadlineType = const Value.absent(),
    bool? allDay,
    Value<String?> importFormat = const Value.absent(),
    Value<String?> importUid = const Value.absent(),
    Value<String?> importSourceName = const Value.absent(),
    Value<String?> importSourceText = const Value.absent(),
    Value<String?> importedAt = const Value.absent(),
    Value<int?> reminderMinutesBefore = const Value.absent(),
    bool? isCompleted,
    Value<String?> actualIntervalsJson = const Value.absent(),
  }) => ScheduleRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    startDate: startDate ?? this.startDate,
    timeZoneId: timeZoneId.present ? timeZoneId.value : this.timeZoneId,
    code: code.present ? code.value : this.code,
    codeMeaning: codeMeaning.present ? codeMeaning.value : this.codeMeaning,
    employerName: employerName.present ? employerName.value : this.employerName,
    departmentName: departmentName.present
        ? departmentName.value
        : this.departmentName,
    jobRole: jobRole.present ? jobRole.value : this.jobRole,
    location: location.present ? location.value : this.location,
    notes: notes.present ? notes.value : this.notes,
    reportingInstruction: reportingInstruction.present
        ? reportingInstruction.value
        : this.reportingInstruction,
    supervisorName: supervisorName.present
        ? supervisorName.value
        : this.supervisorName,
    supervisorPhone: supervisorPhone.present
        ? supervisorPhone.value
        : this.supervisorPhone,
    contactName: contactName.present ? contactName.value : this.contactName,
    contactPhone: contactPhone.present ? contactPhone.value : this.contactPhone,
    academicTermId: academicTermId.present
        ? academicTermId.value
        : this.academicTermId,
    weekdays: weekdays.present ? weekdays.value : this.weekdays,
    untilDate: untilDate.present ? untilDate.value : this.untilDate,
    exceptionDates: exceptionDates.present
        ? exceptionDates.value
        : this.exceptionDates,
    isDayOff: isDayOff ?? this.isDayOff,
    workCategory: workCategory.present ? workCategory.value : this.workCategory,
    deadlineType: deadlineType.present ? deadlineType.value : this.deadlineType,
    allDay: allDay ?? this.allDay,
    importFormat: importFormat.present ? importFormat.value : this.importFormat,
    importUid: importUid.present ? importUid.value : this.importUid,
    importSourceName: importSourceName.present
        ? importSourceName.value
        : this.importSourceName,
    importSourceText: importSourceText.present
        ? importSourceText.value
        : this.importSourceText,
    importedAt: importedAt.present ? importedAt.value : this.importedAt,
    reminderMinutesBefore: reminderMinutesBefore.present
        ? reminderMinutesBefore.value
        : this.reminderMinutesBefore,
    isCompleted: isCompleted ?? this.isCompleted,
    actualIntervalsJson: actualIntervalsJson.present
        ? actualIntervalsJson.value
        : this.actualIntervalsJson,
  );
  ScheduleRow copyWithCompanion(ScheduleRowsCompanion data) {
    return ScheduleRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      timeZoneId: data.timeZoneId.present
          ? data.timeZoneId.value
          : this.timeZoneId,
      code: data.code.present ? data.code.value : this.code,
      codeMeaning: data.codeMeaning.present
          ? data.codeMeaning.value
          : this.codeMeaning,
      employerName: data.employerName.present
          ? data.employerName.value
          : this.employerName,
      departmentName: data.departmentName.present
          ? data.departmentName.value
          : this.departmentName,
      jobRole: data.jobRole.present ? data.jobRole.value : this.jobRole,
      location: data.location.present ? data.location.value : this.location,
      notes: data.notes.present ? data.notes.value : this.notes,
      reportingInstruction: data.reportingInstruction.present
          ? data.reportingInstruction.value
          : this.reportingInstruction,
      supervisorName: data.supervisorName.present
          ? data.supervisorName.value
          : this.supervisorName,
      supervisorPhone: data.supervisorPhone.present
          ? data.supervisorPhone.value
          : this.supervisorPhone,
      contactName: data.contactName.present
          ? data.contactName.value
          : this.contactName,
      contactPhone: data.contactPhone.present
          ? data.contactPhone.value
          : this.contactPhone,
      academicTermId: data.academicTermId.present
          ? data.academicTermId.value
          : this.academicTermId,
      weekdays: data.weekdays.present ? data.weekdays.value : this.weekdays,
      untilDate: data.untilDate.present ? data.untilDate.value : this.untilDate,
      exceptionDates: data.exceptionDates.present
          ? data.exceptionDates.value
          : this.exceptionDates,
      isDayOff: data.isDayOff.present ? data.isDayOff.value : this.isDayOff,
      workCategory: data.workCategory.present
          ? data.workCategory.value
          : this.workCategory,
      deadlineType: data.deadlineType.present
          ? data.deadlineType.value
          : this.deadlineType,
      allDay: data.allDay.present ? data.allDay.value : this.allDay,
      importFormat: data.importFormat.present
          ? data.importFormat.value
          : this.importFormat,
      importUid: data.importUid.present ? data.importUid.value : this.importUid,
      importSourceName: data.importSourceName.present
          ? data.importSourceName.value
          : this.importSourceName,
      importSourceText: data.importSourceText.present
          ? data.importSourceText.value
          : this.importSourceText,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      reminderMinutesBefore: data.reminderMinutesBefore.present
          ? data.reminderMinutesBefore.value
          : this.reminderMinutesBefore,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      actualIntervalsJson: data.actualIntervalsJson.present
          ? data.actualIntervalsJson.value
          : this.actualIntervalsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('startDate: $startDate, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('code: $code, ')
          ..write('codeMeaning: $codeMeaning, ')
          ..write('employerName: $employerName, ')
          ..write('departmentName: $departmentName, ')
          ..write('jobRole: $jobRole, ')
          ..write('location: $location, ')
          ..write('notes: $notes, ')
          ..write('reportingInstruction: $reportingInstruction, ')
          ..write('supervisorName: $supervisorName, ')
          ..write('supervisorPhone: $supervisorPhone, ')
          ..write('contactName: $contactName, ')
          ..write('contactPhone: $contactPhone, ')
          ..write('academicTermId: $academicTermId, ')
          ..write('weekdays: $weekdays, ')
          ..write('untilDate: $untilDate, ')
          ..write('exceptionDates: $exceptionDates, ')
          ..write('isDayOff: $isDayOff, ')
          ..write('workCategory: $workCategory, ')
          ..write('deadlineType: $deadlineType, ')
          ..write('allDay: $allDay, ')
          ..write('importFormat: $importFormat, ')
          ..write('importUid: $importUid, ')
          ..write('importSourceName: $importSourceName, ')
          ..write('importSourceText: $importSourceText, ')
          ..write('importedAt: $importedAt, ')
          ..write('reminderMinutesBefore: $reminderMinutesBefore, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('actualIntervalsJson: $actualIntervalsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    kind,
    title,
    startDate,
    timeZoneId,
    code,
    codeMeaning,
    employerName,
    departmentName,
    jobRole,
    location,
    notes,
    reportingInstruction,
    supervisorName,
    supervisorPhone,
    contactName,
    contactPhone,
    academicTermId,
    weekdays,
    untilDate,
    exceptionDates,
    isDayOff,
    workCategory,
    deadlineType,
    allDay,
    importFormat,
    importUid,
    importSourceName,
    importSourceText,
    importedAt,
    reminderMinutesBefore,
    isCompleted,
    actualIntervalsJson,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduleRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.startDate == this.startDate &&
          other.timeZoneId == this.timeZoneId &&
          other.code == this.code &&
          other.codeMeaning == this.codeMeaning &&
          other.employerName == this.employerName &&
          other.departmentName == this.departmentName &&
          other.jobRole == this.jobRole &&
          other.location == this.location &&
          other.notes == this.notes &&
          other.reportingInstruction == this.reportingInstruction &&
          other.supervisorName == this.supervisorName &&
          other.supervisorPhone == this.supervisorPhone &&
          other.contactName == this.contactName &&
          other.contactPhone == this.contactPhone &&
          other.academicTermId == this.academicTermId &&
          other.weekdays == this.weekdays &&
          other.untilDate == this.untilDate &&
          other.exceptionDates == this.exceptionDates &&
          other.isDayOff == this.isDayOff &&
          other.workCategory == this.workCategory &&
          other.deadlineType == this.deadlineType &&
          other.allDay == this.allDay &&
          other.importFormat == this.importFormat &&
          other.importUid == this.importUid &&
          other.importSourceName == this.importSourceName &&
          other.importSourceText == this.importSourceText &&
          other.importedAt == this.importedAt &&
          other.reminderMinutesBefore == this.reminderMinutesBefore &&
          other.isCompleted == this.isCompleted &&
          other.actualIntervalsJson == this.actualIntervalsJson);
}

class ScheduleRowsCompanion extends UpdateCompanion<ScheduleRow> {
  final Value<String> id;
  final Value<int> kind;
  final Value<String> title;
  final Value<String> startDate;
  final Value<String?> timeZoneId;
  final Value<String?> code;
  final Value<String?> codeMeaning;
  final Value<String?> employerName;
  final Value<String?> departmentName;
  final Value<String?> jobRole;
  final Value<String?> location;
  final Value<String?> notes;
  final Value<String?> reportingInstruction;
  final Value<String?> supervisorName;
  final Value<String?> supervisorPhone;
  final Value<String?> contactName;
  final Value<String?> contactPhone;
  final Value<String?> academicTermId;
  final Value<String?> weekdays;
  final Value<String?> untilDate;
  final Value<String?> exceptionDates;
  final Value<bool> isDayOff;
  final Value<int?> workCategory;
  final Value<int?> deadlineType;
  final Value<bool> allDay;
  final Value<String?> importFormat;
  final Value<String?> importUid;
  final Value<String?> importSourceName;
  final Value<String?> importSourceText;
  final Value<String?> importedAt;
  final Value<int?> reminderMinutesBefore;
  final Value<bool> isCompleted;
  final Value<String?> actualIntervalsJson;
  final Value<int> rowid;
  const ScheduleRowsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.startDate = const Value.absent(),
    this.timeZoneId = const Value.absent(),
    this.code = const Value.absent(),
    this.codeMeaning = const Value.absent(),
    this.employerName = const Value.absent(),
    this.departmentName = const Value.absent(),
    this.jobRole = const Value.absent(),
    this.location = const Value.absent(),
    this.notes = const Value.absent(),
    this.reportingInstruction = const Value.absent(),
    this.supervisorName = const Value.absent(),
    this.supervisorPhone = const Value.absent(),
    this.contactName = const Value.absent(),
    this.contactPhone = const Value.absent(),
    this.academicTermId = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.untilDate = const Value.absent(),
    this.exceptionDates = const Value.absent(),
    this.isDayOff = const Value.absent(),
    this.workCategory = const Value.absent(),
    this.deadlineType = const Value.absent(),
    this.allDay = const Value.absent(),
    this.importFormat = const Value.absent(),
    this.importUid = const Value.absent(),
    this.importSourceName = const Value.absent(),
    this.importSourceText = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.reminderMinutesBefore = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.actualIntervalsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScheduleRowsCompanion.insert({
    required String id,
    required int kind,
    required String title,
    required String startDate,
    this.timeZoneId = const Value.absent(),
    this.code = const Value.absent(),
    this.codeMeaning = const Value.absent(),
    this.employerName = const Value.absent(),
    this.departmentName = const Value.absent(),
    this.jobRole = const Value.absent(),
    this.location = const Value.absent(),
    this.notes = const Value.absent(),
    this.reportingInstruction = const Value.absent(),
    this.supervisorName = const Value.absent(),
    this.supervisorPhone = const Value.absent(),
    this.contactName = const Value.absent(),
    this.contactPhone = const Value.absent(),
    this.academicTermId = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.untilDate = const Value.absent(),
    this.exceptionDates = const Value.absent(),
    this.isDayOff = const Value.absent(),
    this.workCategory = const Value.absent(),
    this.deadlineType = const Value.absent(),
    this.allDay = const Value.absent(),
    this.importFormat = const Value.absent(),
    this.importUid = const Value.absent(),
    this.importSourceName = const Value.absent(),
    this.importSourceText = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.reminderMinutesBefore = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.actualIntervalsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       title = Value(title),
       startDate = Value(startDate);
  static Insertable<ScheduleRow> custom({
    Expression<String>? id,
    Expression<int>? kind,
    Expression<String>? title,
    Expression<String>? startDate,
    Expression<String>? timeZoneId,
    Expression<String>? code,
    Expression<String>? codeMeaning,
    Expression<String>? employerName,
    Expression<String>? departmentName,
    Expression<String>? jobRole,
    Expression<String>? location,
    Expression<String>? notes,
    Expression<String>? reportingInstruction,
    Expression<String>? supervisorName,
    Expression<String>? supervisorPhone,
    Expression<String>? contactName,
    Expression<String>? contactPhone,
    Expression<String>? academicTermId,
    Expression<String>? weekdays,
    Expression<String>? untilDate,
    Expression<String>? exceptionDates,
    Expression<bool>? isDayOff,
    Expression<int>? workCategory,
    Expression<int>? deadlineType,
    Expression<bool>? allDay,
    Expression<String>? importFormat,
    Expression<String>? importUid,
    Expression<String>? importSourceName,
    Expression<String>? importSourceText,
    Expression<String>? importedAt,
    Expression<int>? reminderMinutesBefore,
    Expression<bool>? isCompleted,
    Expression<String>? actualIntervalsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (startDate != null) 'start_date': startDate,
      if (timeZoneId != null) 'time_zone_id': timeZoneId,
      if (code != null) 'code': code,
      if (codeMeaning != null) 'code_meaning': codeMeaning,
      if (employerName != null) 'employer_name': employerName,
      if (departmentName != null) 'department_name': departmentName,
      if (jobRole != null) 'job_role': jobRole,
      if (location != null) 'location': location,
      if (notes != null) 'notes': notes,
      if (reportingInstruction != null)
        'reporting_instruction': reportingInstruction,
      if (supervisorName != null) 'supervisor_name': supervisorName,
      if (supervisorPhone != null) 'supervisor_phone': supervisorPhone,
      if (contactName != null) 'contact_name': contactName,
      if (contactPhone != null) 'contact_phone': contactPhone,
      if (academicTermId != null) 'academic_term_id': academicTermId,
      if (weekdays != null) 'weekdays': weekdays,
      if (untilDate != null) 'until_date': untilDate,
      if (exceptionDates != null) 'exception_dates': exceptionDates,
      if (isDayOff != null) 'is_day_off': isDayOff,
      if (workCategory != null) 'work_category': workCategory,
      if (deadlineType != null) 'deadline_type': deadlineType,
      if (allDay != null) 'all_day': allDay,
      if (importFormat != null) 'import_format': importFormat,
      if (importUid != null) 'import_uid': importUid,
      if (importSourceName != null) 'import_source_name': importSourceName,
      if (importSourceText != null) 'import_source_text': importSourceText,
      if (importedAt != null) 'imported_at': importedAt,
      if (reminderMinutesBefore != null)
        'reminder_minutes_before': reminderMinutesBefore,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (actualIntervalsJson != null)
        'actual_intervals_json': actualIntervalsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScheduleRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? kind,
    Value<String>? title,
    Value<String>? startDate,
    Value<String?>? timeZoneId,
    Value<String?>? code,
    Value<String?>? codeMeaning,
    Value<String?>? employerName,
    Value<String?>? departmentName,
    Value<String?>? jobRole,
    Value<String?>? location,
    Value<String?>? notes,
    Value<String?>? reportingInstruction,
    Value<String?>? supervisorName,
    Value<String?>? supervisorPhone,
    Value<String?>? contactName,
    Value<String?>? contactPhone,
    Value<String?>? academicTermId,
    Value<String?>? weekdays,
    Value<String?>? untilDate,
    Value<String?>? exceptionDates,
    Value<bool>? isDayOff,
    Value<int?>? workCategory,
    Value<int?>? deadlineType,
    Value<bool>? allDay,
    Value<String?>? importFormat,
    Value<String?>? importUid,
    Value<String?>? importSourceName,
    Value<String?>? importSourceText,
    Value<String?>? importedAt,
    Value<int?>? reminderMinutesBefore,
    Value<bool>? isCompleted,
    Value<String?>? actualIntervalsJson,
    Value<int>? rowid,
  }) {
    return ScheduleRowsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      code: code ?? this.code,
      codeMeaning: codeMeaning ?? this.codeMeaning,
      employerName: employerName ?? this.employerName,
      departmentName: departmentName ?? this.departmentName,
      jobRole: jobRole ?? this.jobRole,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      reportingInstruction: reportingInstruction ?? this.reportingInstruction,
      supervisorName: supervisorName ?? this.supervisorName,
      supervisorPhone: supervisorPhone ?? this.supervisorPhone,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      academicTermId: academicTermId ?? this.academicTermId,
      weekdays: weekdays ?? this.weekdays,
      untilDate: untilDate ?? this.untilDate,
      exceptionDates: exceptionDates ?? this.exceptionDates,
      isDayOff: isDayOff ?? this.isDayOff,
      workCategory: workCategory ?? this.workCategory,
      deadlineType: deadlineType ?? this.deadlineType,
      allDay: allDay ?? this.allDay,
      importFormat: importFormat ?? this.importFormat,
      importUid: importUid ?? this.importUid,
      importSourceName: importSourceName ?? this.importSourceName,
      importSourceText: importSourceText ?? this.importSourceText,
      importedAt: importedAt ?? this.importedAt,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      isCompleted: isCompleted ?? this.isCompleted,
      actualIntervalsJson: actualIntervalsJson ?? this.actualIntervalsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (timeZoneId.present) {
      map['time_zone_id'] = Variable<String>(timeZoneId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (codeMeaning.present) {
      map['code_meaning'] = Variable<String>(codeMeaning.value);
    }
    if (employerName.present) {
      map['employer_name'] = Variable<String>(employerName.value);
    }
    if (departmentName.present) {
      map['department_name'] = Variable<String>(departmentName.value);
    }
    if (jobRole.present) {
      map['job_role'] = Variable<String>(jobRole.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (reportingInstruction.present) {
      map['reporting_instruction'] = Variable<String>(
        reportingInstruction.value,
      );
    }
    if (supervisorName.present) {
      map['supervisor_name'] = Variable<String>(supervisorName.value);
    }
    if (supervisorPhone.present) {
      map['supervisor_phone'] = Variable<String>(supervisorPhone.value);
    }
    if (contactName.present) {
      map['contact_name'] = Variable<String>(contactName.value);
    }
    if (contactPhone.present) {
      map['contact_phone'] = Variable<String>(contactPhone.value);
    }
    if (academicTermId.present) {
      map['academic_term_id'] = Variable<String>(academicTermId.value);
    }
    if (weekdays.present) {
      map['weekdays'] = Variable<String>(weekdays.value);
    }
    if (untilDate.present) {
      map['until_date'] = Variable<String>(untilDate.value);
    }
    if (exceptionDates.present) {
      map['exception_dates'] = Variable<String>(exceptionDates.value);
    }
    if (isDayOff.present) {
      map['is_day_off'] = Variable<bool>(isDayOff.value);
    }
    if (workCategory.present) {
      map['work_category'] = Variable<int>(workCategory.value);
    }
    if (deadlineType.present) {
      map['deadline_type'] = Variable<int>(deadlineType.value);
    }
    if (allDay.present) {
      map['all_day'] = Variable<bool>(allDay.value);
    }
    if (importFormat.present) {
      map['import_format'] = Variable<String>(importFormat.value);
    }
    if (importUid.present) {
      map['import_uid'] = Variable<String>(importUid.value);
    }
    if (importSourceName.present) {
      map['import_source_name'] = Variable<String>(importSourceName.value);
    }
    if (importSourceText.present) {
      map['import_source_text'] = Variable<String>(importSourceText.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<String>(importedAt.value);
    }
    if (reminderMinutesBefore.present) {
      map['reminder_minutes_before'] = Variable<int>(
        reminderMinutesBefore.value,
      );
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (actualIntervalsJson.present) {
      map['actual_intervals_json'] = Variable<String>(
        actualIntervalsJson.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleRowsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('startDate: $startDate, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('code: $code, ')
          ..write('codeMeaning: $codeMeaning, ')
          ..write('employerName: $employerName, ')
          ..write('departmentName: $departmentName, ')
          ..write('jobRole: $jobRole, ')
          ..write('location: $location, ')
          ..write('notes: $notes, ')
          ..write('reportingInstruction: $reportingInstruction, ')
          ..write('supervisorName: $supervisorName, ')
          ..write('supervisorPhone: $supervisorPhone, ')
          ..write('contactName: $contactName, ')
          ..write('contactPhone: $contactPhone, ')
          ..write('academicTermId: $academicTermId, ')
          ..write('weekdays: $weekdays, ')
          ..write('untilDate: $untilDate, ')
          ..write('exceptionDates: $exceptionDates, ')
          ..write('isDayOff: $isDayOff, ')
          ..write('workCategory: $workCategory, ')
          ..write('deadlineType: $deadlineType, ')
          ..write('allDay: $allDay, ')
          ..write('importFormat: $importFormat, ')
          ..write('importUid: $importUid, ')
          ..write('importSourceName: $importSourceName, ')
          ..write('importSourceText: $importSourceText, ')
          ..write('importedAt: $importedAt, ')
          ..write('reminderMinutesBefore: $reminderMinutesBefore, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('actualIntervalsJson: $actualIntervalsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IntervalRowsTable extends IntervalRows
    with TableInfo<$IntervalRowsTable, IntervalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IntervalRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<int> rowId = GeneratedColumn<int>(
    'row_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES schedule_rows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _startDayOffsetMeta = const VerificationMeta(
    'startDayOffset',
  );
  @override
  late final GeneratedColumn<int> startDayOffset = GeneratedColumn<int>(
    'start_day_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDayOffsetMeta = const VerificationMeta(
    'endDayOffset',
  );
  @override
  late final GeneratedColumn<int> endDayOffset = GeneratedColumn<int>(
    'end_day_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startFoldChoiceMeta = const VerificationMeta(
    'startFoldChoice',
  );
  @override
  late final GeneratedColumn<String> startFoldChoice = GeneratedColumn<String>(
    'start_fold_choice',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endFoldChoiceMeta = const VerificationMeta(
    'endFoldChoice',
  );
  @override
  late final GeneratedColumn<String> endFoldChoice = GeneratedColumn<String>(
    'end_fold_choice',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    rowId,
    itemId,
    startDayOffset,
    startMinute,
    endDayOffset,
    endMinute,
    startFoldChoice,
    endFoldChoice,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'interval_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<IntervalRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('start_day_offset')) {
      context.handle(
        _startDayOffsetMeta,
        startDayOffset.isAcceptableOrUnknown(
          data['start_day_offset']!,
          _startDayOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startDayOffsetMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMinuteMeta);
    }
    if (data.containsKey('end_day_offset')) {
      context.handle(
        _endDayOffsetMeta,
        endDayOffset.isAcceptableOrUnknown(
          data['end_day_offset']!,
          _endDayOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_endDayOffsetMeta);
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinuteMeta);
    }
    if (data.containsKey('start_fold_choice')) {
      context.handle(
        _startFoldChoiceMeta,
        startFoldChoice.isAcceptableOrUnknown(
          data['start_fold_choice']!,
          _startFoldChoiceMeta,
        ),
      );
    }
    if (data.containsKey('end_fold_choice')) {
      context.handle(
        _endFoldChoiceMeta,
        endFoldChoice.isAcceptableOrUnknown(
          data['end_fold_choice']!,
          _endFoldChoiceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rowId};
  @override
  IntervalRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IntervalRow(
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      startDayOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_day_offset'],
      )!,
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      )!,
      endDayOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_day_offset'],
      )!,
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      )!,
      startFoldChoice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_fold_choice'],
      ),
      endFoldChoice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_fold_choice'],
      ),
    );
  }

  @override
  $IntervalRowsTable createAlias(String alias) {
    return $IntervalRowsTable(attachedDatabase, alias);
  }
}

class IntervalRow extends DataClass implements Insertable<IntervalRow> {
  final int rowId;
  final String itemId;
  final int startDayOffset;
  final int startMinute;
  final int endDayOffset;
  final int endMinute;
  final String? startFoldChoice;
  final String? endFoldChoice;
  const IntervalRow({
    required this.rowId,
    required this.itemId,
    required this.startDayOffset,
    required this.startMinute,
    required this.endDayOffset,
    required this.endMinute,
    this.startFoldChoice,
    this.endFoldChoice,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['row_id'] = Variable<int>(rowId);
    map['item_id'] = Variable<String>(itemId);
    map['start_day_offset'] = Variable<int>(startDayOffset);
    map['start_minute'] = Variable<int>(startMinute);
    map['end_day_offset'] = Variable<int>(endDayOffset);
    map['end_minute'] = Variable<int>(endMinute);
    if (!nullToAbsent || startFoldChoice != null) {
      map['start_fold_choice'] = Variable<String>(startFoldChoice);
    }
    if (!nullToAbsent || endFoldChoice != null) {
      map['end_fold_choice'] = Variable<String>(endFoldChoice);
    }
    return map;
  }

  IntervalRowsCompanion toCompanion(bool nullToAbsent) {
    return IntervalRowsCompanion(
      rowId: Value(rowId),
      itemId: Value(itemId),
      startDayOffset: Value(startDayOffset),
      startMinute: Value(startMinute),
      endDayOffset: Value(endDayOffset),
      endMinute: Value(endMinute),
      startFoldChoice: startFoldChoice == null && nullToAbsent
          ? const Value.absent()
          : Value(startFoldChoice),
      endFoldChoice: endFoldChoice == null && nullToAbsent
          ? const Value.absent()
          : Value(endFoldChoice),
    );
  }

  factory IntervalRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IntervalRow(
      rowId: serializer.fromJson<int>(json['rowId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      startDayOffset: serializer.fromJson<int>(json['startDayOffset']),
      startMinute: serializer.fromJson<int>(json['startMinute']),
      endDayOffset: serializer.fromJson<int>(json['endDayOffset']),
      endMinute: serializer.fromJson<int>(json['endMinute']),
      startFoldChoice: serializer.fromJson<String?>(json['startFoldChoice']),
      endFoldChoice: serializer.fromJson<String?>(json['endFoldChoice']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rowId': serializer.toJson<int>(rowId),
      'itemId': serializer.toJson<String>(itemId),
      'startDayOffset': serializer.toJson<int>(startDayOffset),
      'startMinute': serializer.toJson<int>(startMinute),
      'endDayOffset': serializer.toJson<int>(endDayOffset),
      'endMinute': serializer.toJson<int>(endMinute),
      'startFoldChoice': serializer.toJson<String?>(startFoldChoice),
      'endFoldChoice': serializer.toJson<String?>(endFoldChoice),
    };
  }

  IntervalRow copyWith({
    int? rowId,
    String? itemId,
    int? startDayOffset,
    int? startMinute,
    int? endDayOffset,
    int? endMinute,
    Value<String?> startFoldChoice = const Value.absent(),
    Value<String?> endFoldChoice = const Value.absent(),
  }) => IntervalRow(
    rowId: rowId ?? this.rowId,
    itemId: itemId ?? this.itemId,
    startDayOffset: startDayOffset ?? this.startDayOffset,
    startMinute: startMinute ?? this.startMinute,
    endDayOffset: endDayOffset ?? this.endDayOffset,
    endMinute: endMinute ?? this.endMinute,
    startFoldChoice: startFoldChoice.present
        ? startFoldChoice.value
        : this.startFoldChoice,
    endFoldChoice: endFoldChoice.present
        ? endFoldChoice.value
        : this.endFoldChoice,
  );
  IntervalRow copyWithCompanion(IntervalRowsCompanion data) {
    return IntervalRow(
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      startDayOffset: data.startDayOffset.present
          ? data.startDayOffset.value
          : this.startDayOffset,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endDayOffset: data.endDayOffset.present
          ? data.endDayOffset.value
          : this.endDayOffset,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      startFoldChoice: data.startFoldChoice.present
          ? data.startFoldChoice.value
          : this.startFoldChoice,
      endFoldChoice: data.endFoldChoice.present
          ? data.endFoldChoice.value
          : this.endFoldChoice,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IntervalRow(')
          ..write('rowId: $rowId, ')
          ..write('itemId: $itemId, ')
          ..write('startDayOffset: $startDayOffset, ')
          ..write('startMinute: $startMinute, ')
          ..write('endDayOffset: $endDayOffset, ')
          ..write('endMinute: $endMinute, ')
          ..write('startFoldChoice: $startFoldChoice, ')
          ..write('endFoldChoice: $endFoldChoice')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    rowId,
    itemId,
    startDayOffset,
    startMinute,
    endDayOffset,
    endMinute,
    startFoldChoice,
    endFoldChoice,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntervalRow &&
          other.rowId == this.rowId &&
          other.itemId == this.itemId &&
          other.startDayOffset == this.startDayOffset &&
          other.startMinute == this.startMinute &&
          other.endDayOffset == this.endDayOffset &&
          other.endMinute == this.endMinute &&
          other.startFoldChoice == this.startFoldChoice &&
          other.endFoldChoice == this.endFoldChoice);
}

class IntervalRowsCompanion extends UpdateCompanion<IntervalRow> {
  final Value<int> rowId;
  final Value<String> itemId;
  final Value<int> startDayOffset;
  final Value<int> startMinute;
  final Value<int> endDayOffset;
  final Value<int> endMinute;
  final Value<String?> startFoldChoice;
  final Value<String?> endFoldChoice;
  const IntervalRowsCompanion({
    this.rowId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.startDayOffset = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endDayOffset = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.startFoldChoice = const Value.absent(),
    this.endFoldChoice = const Value.absent(),
  });
  IntervalRowsCompanion.insert({
    this.rowId = const Value.absent(),
    required String itemId,
    required int startDayOffset,
    required int startMinute,
    required int endDayOffset,
    required int endMinute,
    this.startFoldChoice = const Value.absent(),
    this.endFoldChoice = const Value.absent(),
  }) : itemId = Value(itemId),
       startDayOffset = Value(startDayOffset),
       startMinute = Value(startMinute),
       endDayOffset = Value(endDayOffset),
       endMinute = Value(endMinute);
  static Insertable<IntervalRow> custom({
    Expression<int>? rowId,
    Expression<String>? itemId,
    Expression<int>? startDayOffset,
    Expression<int>? startMinute,
    Expression<int>? endDayOffset,
    Expression<int>? endMinute,
    Expression<String>? startFoldChoice,
    Expression<String>? endFoldChoice,
  }) {
    return RawValuesInsertable({
      if (rowId != null) 'row_id': rowId,
      if (itemId != null) 'item_id': itemId,
      if (startDayOffset != null) 'start_day_offset': startDayOffset,
      if (startMinute != null) 'start_minute': startMinute,
      if (endDayOffset != null) 'end_day_offset': endDayOffset,
      if (endMinute != null) 'end_minute': endMinute,
      if (startFoldChoice != null) 'start_fold_choice': startFoldChoice,
      if (endFoldChoice != null) 'end_fold_choice': endFoldChoice,
    });
  }

  IntervalRowsCompanion copyWith({
    Value<int>? rowId,
    Value<String>? itemId,
    Value<int>? startDayOffset,
    Value<int>? startMinute,
    Value<int>? endDayOffset,
    Value<int>? endMinute,
    Value<String?>? startFoldChoice,
    Value<String?>? endFoldChoice,
  }) {
    return IntervalRowsCompanion(
      rowId: rowId ?? this.rowId,
      itemId: itemId ?? this.itemId,
      startDayOffset: startDayOffset ?? this.startDayOffset,
      startMinute: startMinute ?? this.startMinute,
      endDayOffset: endDayOffset ?? this.endDayOffset,
      endMinute: endMinute ?? this.endMinute,
      startFoldChoice: startFoldChoice ?? this.startFoldChoice,
      endFoldChoice: endFoldChoice ?? this.endFoldChoice,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rowId.present) {
      map['row_id'] = Variable<int>(rowId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (startDayOffset.present) {
      map['start_day_offset'] = Variable<int>(startDayOffset.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endDayOffset.present) {
      map['end_day_offset'] = Variable<int>(endDayOffset.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (startFoldChoice.present) {
      map['start_fold_choice'] = Variable<String>(startFoldChoice.value);
    }
    if (endFoldChoice.present) {
      map['end_fold_choice'] = Variable<String>(endFoldChoice.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IntervalRowsCompanion(')
          ..write('rowId: $rowId, ')
          ..write('itemId: $itemId, ')
          ..write('startDayOffset: $startDayOffset, ')
          ..write('startMinute: $startMinute, ')
          ..write('endDayOffset: $endDayOffset, ')
          ..write('endMinute: $endMinute, ')
          ..write('startFoldChoice: $startFoldChoice, ')
          ..write('endFoldChoice: $endFoldChoice')
          ..write(')'))
        .toString();
  }
}

class $PreferenceRowsTable extends PreferenceRows
    with TableInfo<$PreferenceRowsTable, PreferenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferenceRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preference_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<PreferenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  PreferenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PreferenceRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $PreferenceRowsTable createAlias(String alias) {
    return $PreferenceRowsTable(attachedDatabase, alias);
  }
}

class PreferenceRow extends DataClass implements Insertable<PreferenceRow> {
  final String key;
  final String value;
  const PreferenceRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  PreferenceRowsCompanion toCompanion(bool nullToAbsent) {
    return PreferenceRowsCompanion(key: Value(key), value: Value(value));
  }

  factory PreferenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PreferenceRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  PreferenceRow copyWith({String? key, String? value}) =>
      PreferenceRow(key: key ?? this.key, value: value ?? this.value);
  PreferenceRow copyWithCompanion(PreferenceRowsCompanion data) {
    return PreferenceRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PreferenceRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PreferenceRow &&
          other.key == this.key &&
          other.value == this.value);
}

class PreferenceRowsCompanion extends UpdateCompanion<PreferenceRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const PreferenceRowsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PreferenceRowsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<PreferenceRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PreferenceRowsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return PreferenceRowsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferenceRowsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkCodeLegendRowsTable extends WorkCodeLegendRows
    with TableInfo<$WorkCodeLegendRowsTable, WorkCodeLegendRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkCodeLegendRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _employerMeta = const VerificationMeta(
    'employer',
  );
  @override
  late final GeneratedColumn<String> employer = GeneratedColumn<String>(
    'employer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meaningMeta = const VerificationMeta(
    'meaning',
  );
  @override
  late final GeneratedColumn<String> meaning = GeneratedColumn<String>(
    'meaning',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _flightIdsJsonMeta = const VerificationMeta(
    'flightIdsJson',
  );
  @override
  late final GeneratedColumn<String> flightIdsJson = GeneratedColumn<String>(
    'flight_ids_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employer,
    code,
    meaning,
    startMinute,
    endMinute,
    flightIdsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'work_code_legend_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkCodeLegendRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('employer')) {
      context.handle(
        _employerMeta,
        employer.isAcceptableOrUnknown(data['employer']!, _employerMeta),
      );
    } else if (isInserting) {
      context.missing(_employerMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('meaning')) {
      context.handle(
        _meaningMeta,
        meaning.isAcceptableOrUnknown(data['meaning']!, _meaningMeta),
      );
    } else if (isInserting) {
      context.missing(_meaningMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    }
    if (data.containsKey('flight_ids_json')) {
      context.handle(
        _flightIdsJsonMeta,
        flightIdsJson.isAcceptableOrUnknown(
          data['flight_ids_json']!,
          _flightIdsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkCodeLegendRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkCodeLegendRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      employer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employer'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      meaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meaning'],
      )!,
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      ),
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      ),
      flightIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}flight_ids_json'],
      )!,
    );
  }

  @override
  $WorkCodeLegendRowsTable createAlias(String alias) {
    return $WorkCodeLegendRowsTable(attachedDatabase, alias);
  }
}

class WorkCodeLegendRow extends DataClass
    implements Insertable<WorkCodeLegendRow> {
  final String id;
  final String employer;
  final String code;
  final String meaning;
  final int? startMinute;
  final int? endMinute;
  final String flightIdsJson;
  const WorkCodeLegendRow({
    required this.id,
    required this.employer,
    required this.code,
    required this.meaning,
    this.startMinute,
    this.endMinute,
    required this.flightIdsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['employer'] = Variable<String>(employer);
    map['code'] = Variable<String>(code);
    map['meaning'] = Variable<String>(meaning);
    if (!nullToAbsent || startMinute != null) {
      map['start_minute'] = Variable<int>(startMinute);
    }
    if (!nullToAbsent || endMinute != null) {
      map['end_minute'] = Variable<int>(endMinute);
    }
    map['flight_ids_json'] = Variable<String>(flightIdsJson);
    return map;
  }

  WorkCodeLegendRowsCompanion toCompanion(bool nullToAbsent) {
    return WorkCodeLegendRowsCompanion(
      id: Value(id),
      employer: Value(employer),
      code: Value(code),
      meaning: Value(meaning),
      startMinute: startMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(startMinute),
      endMinute: endMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(endMinute),
      flightIdsJson: Value(flightIdsJson),
    );
  }

  factory WorkCodeLegendRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkCodeLegendRow(
      id: serializer.fromJson<String>(json['id']),
      employer: serializer.fromJson<String>(json['employer']),
      code: serializer.fromJson<String>(json['code']),
      meaning: serializer.fromJson<String>(json['meaning']),
      startMinute: serializer.fromJson<int?>(json['startMinute']),
      endMinute: serializer.fromJson<int?>(json['endMinute']),
      flightIdsJson: serializer.fromJson<String>(json['flightIdsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'employer': serializer.toJson<String>(employer),
      'code': serializer.toJson<String>(code),
      'meaning': serializer.toJson<String>(meaning),
      'startMinute': serializer.toJson<int?>(startMinute),
      'endMinute': serializer.toJson<int?>(endMinute),
      'flightIdsJson': serializer.toJson<String>(flightIdsJson),
    };
  }

  WorkCodeLegendRow copyWith({
    String? id,
    String? employer,
    String? code,
    String? meaning,
    Value<int?> startMinute = const Value.absent(),
    Value<int?> endMinute = const Value.absent(),
    String? flightIdsJson,
  }) => WorkCodeLegendRow(
    id: id ?? this.id,
    employer: employer ?? this.employer,
    code: code ?? this.code,
    meaning: meaning ?? this.meaning,
    startMinute: startMinute.present ? startMinute.value : this.startMinute,
    endMinute: endMinute.present ? endMinute.value : this.endMinute,
    flightIdsJson: flightIdsJson ?? this.flightIdsJson,
  );
  WorkCodeLegendRow copyWithCompanion(WorkCodeLegendRowsCompanion data) {
    return WorkCodeLegendRow(
      id: data.id.present ? data.id.value : this.id,
      employer: data.employer.present ? data.employer.value : this.employer,
      code: data.code.present ? data.code.value : this.code,
      meaning: data.meaning.present ? data.meaning.value : this.meaning,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      flightIdsJson: data.flightIdsJson.present
          ? data.flightIdsJson.value
          : this.flightIdsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkCodeLegendRow(')
          ..write('id: $id, ')
          ..write('employer: $employer, ')
          ..write('code: $code, ')
          ..write('meaning: $meaning, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('flightIdsJson: $flightIdsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employer,
    code,
    meaning,
    startMinute,
    endMinute,
    flightIdsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkCodeLegendRow &&
          other.id == this.id &&
          other.employer == this.employer &&
          other.code == this.code &&
          other.meaning == this.meaning &&
          other.startMinute == this.startMinute &&
          other.endMinute == this.endMinute &&
          other.flightIdsJson == this.flightIdsJson);
}

class WorkCodeLegendRowsCompanion extends UpdateCompanion<WorkCodeLegendRow> {
  final Value<String> id;
  final Value<String> employer;
  final Value<String> code;
  final Value<String> meaning;
  final Value<int?> startMinute;
  final Value<int?> endMinute;
  final Value<String> flightIdsJson;
  final Value<int> rowid;
  const WorkCodeLegendRowsCompanion({
    this.id = const Value.absent(),
    this.employer = const Value.absent(),
    this.code = const Value.absent(),
    this.meaning = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.flightIdsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkCodeLegendRowsCompanion.insert({
    required String id,
    required String employer,
    required String code,
    required String meaning,
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.flightIdsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       employer = Value(employer),
       code = Value(code),
       meaning = Value(meaning);
  static Insertable<WorkCodeLegendRow> custom({
    Expression<String>? id,
    Expression<String>? employer,
    Expression<String>? code,
    Expression<String>? meaning,
    Expression<int>? startMinute,
    Expression<int>? endMinute,
    Expression<String>? flightIdsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employer != null) 'employer': employer,
      if (code != null) 'code': code,
      if (meaning != null) 'meaning': meaning,
      if (startMinute != null) 'start_minute': startMinute,
      if (endMinute != null) 'end_minute': endMinute,
      if (flightIdsJson != null) 'flight_ids_json': flightIdsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkCodeLegendRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? employer,
    Value<String>? code,
    Value<String>? meaning,
    Value<int?>? startMinute,
    Value<int?>? endMinute,
    Value<String>? flightIdsJson,
    Value<int>? rowid,
  }) {
    return WorkCodeLegendRowsCompanion(
      id: id ?? this.id,
      employer: employer ?? this.employer,
      code: code ?? this.code,
      meaning: meaning ?? this.meaning,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      flightIdsJson: flightIdsJson ?? this.flightIdsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (employer.present) {
      map['employer'] = Variable<String>(employer.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (meaning.present) {
      map['meaning'] = Variable<String>(meaning.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (flightIdsJson.present) {
      map['flight_ids_json'] = Variable<String>(flightIdsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkCodeLegendRowsCompanion(')
          ..write('id: $id, ')
          ..write('employer: $employer, ')
          ..write('code: $code, ')
          ..write('meaning: $meaning, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('flightIdsJson: $flightIdsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScheduleImportHistoryRowsTable extends ScheduleImportHistoryRows
    with TableInfo<$ScheduleImportHistoryRowsTable, ScheduleImportHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduleImportHistoryRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<String> importedAt = GeneratedColumn<String>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parserVersionMeta = const VerificationMeta(
    'parserVersion',
  );
  @override
  late final GeneratedColumn<String> parserVersion = GeneratedColumn<String>(
    'parser_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proposedCountMeta = const VerificationMeta(
    'proposedCount',
  );
  @override
  late final GeneratedColumn<int> proposedCount = GeneratedColumn<int>(
    'proposed_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acceptedCountMeta = const VerificationMeta(
    'acceptedCount',
  );
  @override
  late final GeneratedColumn<int> acceptedCount = GeneratedColumn<int>(
    'accepted_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rejectedCountMeta = const VerificationMeta(
    'rejectedCount',
  );
  @override
  late final GeneratedColumn<int> rejectedCount = GeneratedColumn<int>(
    'rejected_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skippedCountMeta = const VerificationMeta(
    'skippedCount',
  );
  @override
  late final GeneratedColumn<int> skippedCount = GeneratedColumn<int>(
    'skipped_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _warningsCountMeta = const VerificationMeta(
    'warningsCount',
  );
  @override
  late final GeneratedColumn<int> warningsCount = GeneratedColumn<int>(
    'warnings_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceType,
    importedAt,
    parserVersion,
    proposedCount,
    acceptedCount,
    rejectedCount,
    skippedCount,
    warningsCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schedule_import_history_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduleImportHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    if (data.containsKey('parser_version')) {
      context.handle(
        _parserVersionMeta,
        parserVersion.isAcceptableOrUnknown(
          data['parser_version']!,
          _parserVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parserVersionMeta);
    }
    if (data.containsKey('proposed_count')) {
      context.handle(
        _proposedCountMeta,
        proposedCount.isAcceptableOrUnknown(
          data['proposed_count']!,
          _proposedCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_proposedCountMeta);
    }
    if (data.containsKey('accepted_count')) {
      context.handle(
        _acceptedCountMeta,
        acceptedCount.isAcceptableOrUnknown(
          data['accepted_count']!,
          _acceptedCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_acceptedCountMeta);
    }
    if (data.containsKey('rejected_count')) {
      context.handle(
        _rejectedCountMeta,
        rejectedCount.isAcceptableOrUnknown(
          data['rejected_count']!,
          _rejectedCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rejectedCountMeta);
    }
    if (data.containsKey('skipped_count')) {
      context.handle(
        _skippedCountMeta,
        skippedCount.isAcceptableOrUnknown(
          data['skipped_count']!,
          _skippedCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_skippedCountMeta);
    }
    if (data.containsKey('warnings_count')) {
      context.handle(
        _warningsCountMeta,
        warningsCount.isAcceptableOrUnknown(
          data['warnings_count']!,
          _warningsCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_warningsCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduleImportHistoryRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduleImportHistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imported_at'],
      )!,
      parserVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parser_version'],
      )!,
      proposedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}proposed_count'],
      )!,
      acceptedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accepted_count'],
      )!,
      rejectedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rejected_count'],
      )!,
      skippedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}skipped_count'],
      )!,
      warningsCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}warnings_count'],
      )!,
    );
  }

  @override
  $ScheduleImportHistoryRowsTable createAlias(String alias) {
    return $ScheduleImportHistoryRowsTable(attachedDatabase, alias);
  }
}

class ScheduleImportHistoryRow extends DataClass
    implements Insertable<ScheduleImportHistoryRow> {
  final int id;
  final String sourceType;
  final String importedAt;
  final String parserVersion;
  final int proposedCount;
  final int acceptedCount;
  final int rejectedCount;
  final int skippedCount;
  final int warningsCount;
  const ScheduleImportHistoryRow({
    required this.id,
    required this.sourceType,
    required this.importedAt,
    required this.parserVersion,
    required this.proposedCount,
    required this.acceptedCount,
    required this.rejectedCount,
    required this.skippedCount,
    required this.warningsCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_type'] = Variable<String>(sourceType);
    map['imported_at'] = Variable<String>(importedAt);
    map['parser_version'] = Variable<String>(parserVersion);
    map['proposed_count'] = Variable<int>(proposedCount);
    map['accepted_count'] = Variable<int>(acceptedCount);
    map['rejected_count'] = Variable<int>(rejectedCount);
    map['skipped_count'] = Variable<int>(skippedCount);
    map['warnings_count'] = Variable<int>(warningsCount);
    return map;
  }

  ScheduleImportHistoryRowsCompanion toCompanion(bool nullToAbsent) {
    return ScheduleImportHistoryRowsCompanion(
      id: Value(id),
      sourceType: Value(sourceType),
      importedAt: Value(importedAt),
      parserVersion: Value(parserVersion),
      proposedCount: Value(proposedCount),
      acceptedCount: Value(acceptedCount),
      rejectedCount: Value(rejectedCount),
      skippedCount: Value(skippedCount),
      warningsCount: Value(warningsCount),
    );
  }

  factory ScheduleImportHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduleImportHistoryRow(
      id: serializer.fromJson<int>(json['id']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      importedAt: serializer.fromJson<String>(json['importedAt']),
      parserVersion: serializer.fromJson<String>(json['parserVersion']),
      proposedCount: serializer.fromJson<int>(json['proposedCount']),
      acceptedCount: serializer.fromJson<int>(json['acceptedCount']),
      rejectedCount: serializer.fromJson<int>(json['rejectedCount']),
      skippedCount: serializer.fromJson<int>(json['skippedCount']),
      warningsCount: serializer.fromJson<int>(json['warningsCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceType': serializer.toJson<String>(sourceType),
      'importedAt': serializer.toJson<String>(importedAt),
      'parserVersion': serializer.toJson<String>(parserVersion),
      'proposedCount': serializer.toJson<int>(proposedCount),
      'acceptedCount': serializer.toJson<int>(acceptedCount),
      'rejectedCount': serializer.toJson<int>(rejectedCount),
      'skippedCount': serializer.toJson<int>(skippedCount),
      'warningsCount': serializer.toJson<int>(warningsCount),
    };
  }

  ScheduleImportHistoryRow copyWith({
    int? id,
    String? sourceType,
    String? importedAt,
    String? parserVersion,
    int? proposedCount,
    int? acceptedCount,
    int? rejectedCount,
    int? skippedCount,
    int? warningsCount,
  }) => ScheduleImportHistoryRow(
    id: id ?? this.id,
    sourceType: sourceType ?? this.sourceType,
    importedAt: importedAt ?? this.importedAt,
    parserVersion: parserVersion ?? this.parserVersion,
    proposedCount: proposedCount ?? this.proposedCount,
    acceptedCount: acceptedCount ?? this.acceptedCount,
    rejectedCount: rejectedCount ?? this.rejectedCount,
    skippedCount: skippedCount ?? this.skippedCount,
    warningsCount: warningsCount ?? this.warningsCount,
  );
  ScheduleImportHistoryRow copyWithCompanion(
    ScheduleImportHistoryRowsCompanion data,
  ) {
    return ScheduleImportHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      parserVersion: data.parserVersion.present
          ? data.parserVersion.value
          : this.parserVersion,
      proposedCount: data.proposedCount.present
          ? data.proposedCount.value
          : this.proposedCount,
      acceptedCount: data.acceptedCount.present
          ? data.acceptedCount.value
          : this.acceptedCount,
      rejectedCount: data.rejectedCount.present
          ? data.rejectedCount.value
          : this.rejectedCount,
      skippedCount: data.skippedCount.present
          ? data.skippedCount.value
          : this.skippedCount,
      warningsCount: data.warningsCount.present
          ? data.warningsCount.value
          : this.warningsCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleImportHistoryRow(')
          ..write('id: $id, ')
          ..write('sourceType: $sourceType, ')
          ..write('importedAt: $importedAt, ')
          ..write('parserVersion: $parserVersion, ')
          ..write('proposedCount: $proposedCount, ')
          ..write('acceptedCount: $acceptedCount, ')
          ..write('rejectedCount: $rejectedCount, ')
          ..write('skippedCount: $skippedCount, ')
          ..write('warningsCount: $warningsCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceType,
    importedAt,
    parserVersion,
    proposedCount,
    acceptedCount,
    rejectedCount,
    skippedCount,
    warningsCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduleImportHistoryRow &&
          other.id == this.id &&
          other.sourceType == this.sourceType &&
          other.importedAt == this.importedAt &&
          other.parserVersion == this.parserVersion &&
          other.proposedCount == this.proposedCount &&
          other.acceptedCount == this.acceptedCount &&
          other.rejectedCount == this.rejectedCount &&
          other.skippedCount == this.skippedCount &&
          other.warningsCount == this.warningsCount);
}

class ScheduleImportHistoryRowsCompanion
    extends UpdateCompanion<ScheduleImportHistoryRow> {
  final Value<int> id;
  final Value<String> sourceType;
  final Value<String> importedAt;
  final Value<String> parserVersion;
  final Value<int> proposedCount;
  final Value<int> acceptedCount;
  final Value<int> rejectedCount;
  final Value<int> skippedCount;
  final Value<int> warningsCount;
  const ScheduleImportHistoryRowsCompanion({
    this.id = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.parserVersion = const Value.absent(),
    this.proposedCount = const Value.absent(),
    this.acceptedCount = const Value.absent(),
    this.rejectedCount = const Value.absent(),
    this.skippedCount = const Value.absent(),
    this.warningsCount = const Value.absent(),
  });
  ScheduleImportHistoryRowsCompanion.insert({
    this.id = const Value.absent(),
    required String sourceType,
    required String importedAt,
    required String parserVersion,
    required int proposedCount,
    required int acceptedCount,
    required int rejectedCount,
    required int skippedCount,
    required int warningsCount,
  }) : sourceType = Value(sourceType),
       importedAt = Value(importedAt),
       parserVersion = Value(parserVersion),
       proposedCount = Value(proposedCount),
       acceptedCount = Value(acceptedCount),
       rejectedCount = Value(rejectedCount),
       skippedCount = Value(skippedCount),
       warningsCount = Value(warningsCount);
  static Insertable<ScheduleImportHistoryRow> custom({
    Expression<int>? id,
    Expression<String>? sourceType,
    Expression<String>? importedAt,
    Expression<String>? parserVersion,
    Expression<int>? proposedCount,
    Expression<int>? acceptedCount,
    Expression<int>? rejectedCount,
    Expression<int>? skippedCount,
    Expression<int>? warningsCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceType != null) 'source_type': sourceType,
      if (importedAt != null) 'imported_at': importedAt,
      if (parserVersion != null) 'parser_version': parserVersion,
      if (proposedCount != null) 'proposed_count': proposedCount,
      if (acceptedCount != null) 'accepted_count': acceptedCount,
      if (rejectedCount != null) 'rejected_count': rejectedCount,
      if (skippedCount != null) 'skipped_count': skippedCount,
      if (warningsCount != null) 'warnings_count': warningsCount,
    });
  }

  ScheduleImportHistoryRowsCompanion copyWith({
    Value<int>? id,
    Value<String>? sourceType,
    Value<String>? importedAt,
    Value<String>? parserVersion,
    Value<int>? proposedCount,
    Value<int>? acceptedCount,
    Value<int>? rejectedCount,
    Value<int>? skippedCount,
    Value<int>? warningsCount,
  }) {
    return ScheduleImportHistoryRowsCompanion(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      importedAt: importedAt ?? this.importedAt,
      parserVersion: parserVersion ?? this.parserVersion,
      proposedCount: proposedCount ?? this.proposedCount,
      acceptedCount: acceptedCount ?? this.acceptedCount,
      rejectedCount: rejectedCount ?? this.rejectedCount,
      skippedCount: skippedCount ?? this.skippedCount,
      warningsCount: warningsCount ?? this.warningsCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<String>(importedAt.value);
    }
    if (parserVersion.present) {
      map['parser_version'] = Variable<String>(parserVersion.value);
    }
    if (proposedCount.present) {
      map['proposed_count'] = Variable<int>(proposedCount.value);
    }
    if (acceptedCount.present) {
      map['accepted_count'] = Variable<int>(acceptedCount.value);
    }
    if (rejectedCount.present) {
      map['rejected_count'] = Variable<int>(rejectedCount.value);
    }
    if (skippedCount.present) {
      map['skipped_count'] = Variable<int>(skippedCount.value);
    }
    if (warningsCount.present) {
      map['warnings_count'] = Variable<int>(warningsCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleImportHistoryRowsCompanion(')
          ..write('id: $id, ')
          ..write('sourceType: $sourceType, ')
          ..write('importedAt: $importedAt, ')
          ..write('parserVersion: $parserVersion, ')
          ..write('proposedCount: $proposedCount, ')
          ..write('acceptedCount: $acceptedCount, ')
          ..write('rejectedCount: $rejectedCount, ')
          ..write('skippedCount: $skippedCount, ')
          ..write('warningsCount: $warningsCount')
          ..write(')'))
        .toString();
  }
}

abstract class _$ScheduleDatabase extends GeneratedDatabase {
  _$ScheduleDatabase(QueryExecutor e) : super(e);
  $ScheduleDatabaseManager get managers => $ScheduleDatabaseManager(this);
  late final $AcademicTermRowsTable academicTermRows = $AcademicTermRowsTable(
    this,
  );
  late final $ScheduleRowsTable scheduleRows = $ScheduleRowsTable(this);
  late final $IntervalRowsTable intervalRows = $IntervalRowsTable(this);
  late final $PreferenceRowsTable preferenceRows = $PreferenceRowsTable(this);
  late final $WorkCodeLegendRowsTable workCodeLegendRows =
      $WorkCodeLegendRowsTable(this);
  late final $ScheduleImportHistoryRowsTable scheduleImportHistoryRows =
      $ScheduleImportHistoryRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    academicTermRows,
    scheduleRows,
    intervalRows,
    preferenceRows,
    workCodeLegendRows,
    scheduleImportHistoryRows,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'academic_term_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('schedule_rows', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'schedule_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('interval_rows', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AcademicTermRowsTableCreateCompanionBuilder =
    AcademicTermRowsCompanion Function({
      required String id,
      required String institution,
      required String name,
      required String startDate,
      required String endDate,
      Value<int> rowid,
    });
typedef $$AcademicTermRowsTableUpdateCompanionBuilder =
    AcademicTermRowsCompanion Function({
      Value<String> id,
      Value<String> institution,
      Value<String> name,
      Value<String> startDate,
      Value<String> endDate,
      Value<int> rowid,
    });

final class $$AcademicTermRowsTableReferences
    extends
        BaseReferences<
          _$ScheduleDatabase,
          $AcademicTermRowsTable,
          AcademicTermRow
        > {
  $$AcademicTermRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ScheduleRowsTable, List<ScheduleRow>>
  _scheduleRowsRefsTable(_$ScheduleDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.scheduleRows,
        aliasName: 'academic_term_rows__id__schedule_rows__academic_term_id',
      );

  $$ScheduleRowsTableProcessedTableManager get scheduleRowsRefs {
    final manager = $$ScheduleRowsTableTableManager(
      $_db,
      $_db.scheduleRows,
    ).filter((f) => f.academicTermId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_scheduleRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AcademicTermRowsTableFilterComposer
    extends Composer<_$ScheduleDatabase, $AcademicTermRowsTable> {
  $$AcademicTermRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> scheduleRowsRefs(
    Expression<bool> Function($$ScheduleRowsTableFilterComposer f) f,
  ) {
    final $$ScheduleRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scheduleRows,
      getReferencedColumn: (t) => t.academicTermId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleRowsTableFilterComposer(
            $db: $db,
            $table: $db.scheduleRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AcademicTermRowsTableOrderingComposer
    extends Composer<_$ScheduleDatabase, $AcademicTermRowsTable> {
  $$AcademicTermRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AcademicTermRowsTableAnnotationComposer
    extends Composer<_$ScheduleDatabase, $AcademicTermRowsTable> {
  $$AcademicTermRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  Expression<T> scheduleRowsRefs<T extends Object>(
    Expression<T> Function($$ScheduleRowsTableAnnotationComposer a) f,
  ) {
    final $$ScheduleRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scheduleRows,
      getReferencedColumn: (t) => t.academicTermId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.scheduleRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AcademicTermRowsTableTableManager
    extends
        RootTableManager<
          _$ScheduleDatabase,
          $AcademicTermRowsTable,
          AcademicTermRow,
          $$AcademicTermRowsTableFilterComposer,
          $$AcademicTermRowsTableOrderingComposer,
          $$AcademicTermRowsTableAnnotationComposer,
          $$AcademicTermRowsTableCreateCompanionBuilder,
          $$AcademicTermRowsTableUpdateCompanionBuilder,
          (AcademicTermRow, $$AcademicTermRowsTableReferences),
          AcademicTermRow,
          PrefetchHooks Function({bool scheduleRowsRefs})
        > {
  $$AcademicTermRowsTableTableManager(
    _$ScheduleDatabase db,
    $AcademicTermRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AcademicTermRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AcademicTermRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AcademicTermRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> institution = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<String> endDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AcademicTermRowsCompanion(
                id: id,
                institution: institution,
                name: name,
                startDate: startDate,
                endDate: endDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String institution,
                required String name,
                required String startDate,
                required String endDate,
                Value<int> rowid = const Value.absent(),
              }) => AcademicTermRowsCompanion.insert(
                id: id,
                institution: institution,
                name: name,
                startDate: startDate,
                endDate: endDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AcademicTermRowsTable, AcademicTermRow>(table),
                  $$AcademicTermRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scheduleRowsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (scheduleRowsRefs) db.scheduleRows],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (scheduleRowsRefs)
                    await $_getPrefetchedDataByColumns<
                      AcademicTermRow,
                      $AcademicTermRowsTable,
                      ScheduleRow,
                      $ScheduleRowsTable
                    >(
                      currentTable: table,
                      referencedTable: $$AcademicTermRowsTableReferences
                          ._scheduleRowsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AcademicTermRowsTableReferences(
                            db,
                            table,
                            p0,
                          ).scheduleRowsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'academic_term_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AcademicTermRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$ScheduleDatabase,
      $AcademicTermRowsTable,
      AcademicTermRow,
      $$AcademicTermRowsTableFilterComposer,
      $$AcademicTermRowsTableOrderingComposer,
      $$AcademicTermRowsTableAnnotationComposer,
      $$AcademicTermRowsTableCreateCompanionBuilder,
      $$AcademicTermRowsTableUpdateCompanionBuilder,
      (AcademicTermRow, $$AcademicTermRowsTableReferences),
      AcademicTermRow,
      PrefetchHooks Function({bool scheduleRowsRefs})
    >;
typedef $$ScheduleRowsTableCreateCompanionBuilder =
    ScheduleRowsCompanion Function({
      required String id,
      required int kind,
      required String title,
      required String startDate,
      Value<String?> timeZoneId,
      Value<String?> code,
      Value<String?> codeMeaning,
      Value<String?> employerName,
      Value<String?> departmentName,
      Value<String?> jobRole,
      Value<String?> location,
      Value<String?> notes,
      Value<String?> reportingInstruction,
      Value<String?> supervisorName,
      Value<String?> supervisorPhone,
      Value<String?> contactName,
      Value<String?> contactPhone,
      Value<String?> academicTermId,
      Value<String?> weekdays,
      Value<String?> untilDate,
      Value<String?> exceptionDates,
      Value<bool> isDayOff,
      Value<int?> workCategory,
      Value<int?> deadlineType,
      Value<bool> allDay,
      Value<String?> importFormat,
      Value<String?> importUid,
      Value<String?> importSourceName,
      Value<String?> importSourceText,
      Value<String?> importedAt,
      Value<int?> reminderMinutesBefore,
      Value<bool> isCompleted,
      Value<String?> actualIntervalsJson,
      Value<int> rowid,
    });
typedef $$ScheduleRowsTableUpdateCompanionBuilder =
    ScheduleRowsCompanion Function({
      Value<String> id,
      Value<int> kind,
      Value<String> title,
      Value<String> startDate,
      Value<String?> timeZoneId,
      Value<String?> code,
      Value<String?> codeMeaning,
      Value<String?> employerName,
      Value<String?> departmentName,
      Value<String?> jobRole,
      Value<String?> location,
      Value<String?> notes,
      Value<String?> reportingInstruction,
      Value<String?> supervisorName,
      Value<String?> supervisorPhone,
      Value<String?> contactName,
      Value<String?> contactPhone,
      Value<String?> academicTermId,
      Value<String?> weekdays,
      Value<String?> untilDate,
      Value<String?> exceptionDates,
      Value<bool> isDayOff,
      Value<int?> workCategory,
      Value<int?> deadlineType,
      Value<bool> allDay,
      Value<String?> importFormat,
      Value<String?> importUid,
      Value<String?> importSourceName,
      Value<String?> importSourceText,
      Value<String?> importedAt,
      Value<int?> reminderMinutesBefore,
      Value<bool> isCompleted,
      Value<String?> actualIntervalsJson,
      Value<int> rowid,
    });

final class $$ScheduleRowsTableReferences
    extends
        BaseReferences<_$ScheduleDatabase, $ScheduleRowsTable, ScheduleRow> {
  $$ScheduleRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AcademicTermRowsTable _academicTermIdTable(_$ScheduleDatabase db) =>
      db.academicTermRows.createAlias(
        'schedule_rows__academic_term_id__academic_term_rows__id',
      );

  $$AcademicTermRowsTableProcessedTableManager? get academicTermId {
    final $_column = $_itemColumn<String>('academic_term_id');
    if ($_column == null) return null;
    final manager = $$AcademicTermRowsTableTableManager(
      $_db,
      $_db.academicTermRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_academicTermIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$IntervalRowsTable, List<IntervalRow>>
  _intervalRowsRefsTable(_$ScheduleDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.intervalRows,
        aliasName: 'schedule_rows__id__interval_rows__item_id',
      );

  $$IntervalRowsTableProcessedTableManager get intervalRowsRefs {
    final manager = $$IntervalRowsTableTableManager(
      $_db,
      $_db.intervalRows,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_intervalRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ScheduleRowsTableFilterComposer
    extends Composer<_$ScheduleDatabase, $ScheduleRowsTable> {
  $$ScheduleRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get codeMeaning => $composableBuilder(
    column: $table.codeMeaning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get employerName => $composableBuilder(
    column: $table.employerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get departmentName => $composableBuilder(
    column: $table.departmentName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobRole => $composableBuilder(
    column: $table.jobRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reportingInstruction => $composableBuilder(
    column: $table.reportingInstruction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supervisorName => $composableBuilder(
    column: $table.supervisorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supervisorPhone => $composableBuilder(
    column: $table.supervisorPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactName => $composableBuilder(
    column: $table.contactName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactPhone => $composableBuilder(
    column: $table.contactPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get untilDate => $composableBuilder(
    column: $table.untilDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exceptionDates => $composableBuilder(
    column: $table.exceptionDates,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDayOff => $composableBuilder(
    column: $table.isDayOff,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get workCategory => $composableBuilder(
    column: $table.workCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deadlineType => $composableBuilder(
    column: $table.deadlineType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importFormat => $composableBuilder(
    column: $table.importFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importUid => $composableBuilder(
    column: $table.importUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importSourceName => $composableBuilder(
    column: $table.importSourceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importSourceText => $composableBuilder(
    column: $table.importSourceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actualIntervalsJson => $composableBuilder(
    column: $table.actualIntervalsJson,
    builder: (column) => ColumnFilters(column),
  );

  $$AcademicTermRowsTableFilterComposer get academicTermId {
    final $$AcademicTermRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.academicTermId,
      referencedTable: $db.academicTermRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AcademicTermRowsTableFilterComposer(
            $db: $db,
            $table: $db.academicTermRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> intervalRowsRefs(
    Expression<bool> Function($$IntervalRowsTableFilterComposer f) f,
  ) {
    final $$IntervalRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.intervalRows,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IntervalRowsTableFilterComposer(
            $db: $db,
            $table: $db.intervalRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ScheduleRowsTableOrderingComposer
    extends Composer<_$ScheduleDatabase, $ScheduleRowsTable> {
  $$ScheduleRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get codeMeaning => $composableBuilder(
    column: $table.codeMeaning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get employerName => $composableBuilder(
    column: $table.employerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get departmentName => $composableBuilder(
    column: $table.departmentName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobRole => $composableBuilder(
    column: $table.jobRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reportingInstruction => $composableBuilder(
    column: $table.reportingInstruction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supervisorName => $composableBuilder(
    column: $table.supervisorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supervisorPhone => $composableBuilder(
    column: $table.supervisorPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactName => $composableBuilder(
    column: $table.contactName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactPhone => $composableBuilder(
    column: $table.contactPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get untilDate => $composableBuilder(
    column: $table.untilDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exceptionDates => $composableBuilder(
    column: $table.exceptionDates,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDayOff => $composableBuilder(
    column: $table.isDayOff,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get workCategory => $composableBuilder(
    column: $table.workCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deadlineType => $composableBuilder(
    column: $table.deadlineType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importFormat => $composableBuilder(
    column: $table.importFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importUid => $composableBuilder(
    column: $table.importUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importSourceName => $composableBuilder(
    column: $table.importSourceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importSourceText => $composableBuilder(
    column: $table.importSourceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actualIntervalsJson => $composableBuilder(
    column: $table.actualIntervalsJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$AcademicTermRowsTableOrderingComposer get academicTermId {
    final $$AcademicTermRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.academicTermId,
      referencedTable: $db.academicTermRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AcademicTermRowsTableOrderingComposer(
            $db: $db,
            $table: $db.academicTermRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduleRowsTableAnnotationComposer
    extends Composer<_$ScheduleDatabase, $ScheduleRowsTable> {
  $$ScheduleRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get codeMeaning => $composableBuilder(
    column: $table.codeMeaning,
    builder: (column) => column,
  );

  GeneratedColumn<String> get employerName => $composableBuilder(
    column: $table.employerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get departmentName => $composableBuilder(
    column: $table.departmentName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get jobRole =>
      $composableBuilder(column: $table.jobRole, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get reportingInstruction => $composableBuilder(
    column: $table.reportingInstruction,
    builder: (column) => column,
  );

  GeneratedColumn<String> get supervisorName => $composableBuilder(
    column: $table.supervisorName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get supervisorPhone => $composableBuilder(
    column: $table.supervisorPhone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contactName => $composableBuilder(
    column: $table.contactName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contactPhone => $composableBuilder(
    column: $table.contactPhone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weekdays =>
      $composableBuilder(column: $table.weekdays, builder: (column) => column);

  GeneratedColumn<String> get untilDate =>
      $composableBuilder(column: $table.untilDate, builder: (column) => column);

  GeneratedColumn<String> get exceptionDates => $composableBuilder(
    column: $table.exceptionDates,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDayOff =>
      $composableBuilder(column: $table.isDayOff, builder: (column) => column);

  GeneratedColumn<int> get workCategory => $composableBuilder(
    column: $table.workCategory,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deadlineType => $composableBuilder(
    column: $table.deadlineType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allDay =>
      $composableBuilder(column: $table.allDay, builder: (column) => column);

  GeneratedColumn<String> get importFormat => $composableBuilder(
    column: $table.importFormat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importUid =>
      $composableBuilder(column: $table.importUid, builder: (column) => column);

  GeneratedColumn<String> get importSourceName => $composableBuilder(
    column: $table.importSourceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importSourceText => $composableBuilder(
    column: $table.importSourceText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actualIntervalsJson => $composableBuilder(
    column: $table.actualIntervalsJson,
    builder: (column) => column,
  );

  $$AcademicTermRowsTableAnnotationComposer get academicTermId {
    final $$AcademicTermRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.academicTermId,
      referencedTable: $db.academicTermRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AcademicTermRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.academicTermRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> intervalRowsRefs<T extends Object>(
    Expression<T> Function($$IntervalRowsTableAnnotationComposer a) f,
  ) {
    final $$IntervalRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.intervalRows,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IntervalRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.intervalRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ScheduleRowsTableTableManager
    extends
        RootTableManager<
          _$ScheduleDatabase,
          $ScheduleRowsTable,
          ScheduleRow,
          $$ScheduleRowsTableFilterComposer,
          $$ScheduleRowsTableOrderingComposer,
          $$ScheduleRowsTableAnnotationComposer,
          $$ScheduleRowsTableCreateCompanionBuilder,
          $$ScheduleRowsTableUpdateCompanionBuilder,
          (ScheduleRow, $$ScheduleRowsTableReferences),
          ScheduleRow,
          PrefetchHooks Function({bool academicTermId, bool intervalRowsRefs})
        > {
  $$ScheduleRowsTableTableManager(
    _$ScheduleDatabase db,
    $ScheduleRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduleRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScheduleRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScheduleRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<String?> timeZoneId = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<String?> codeMeaning = const Value.absent(),
                Value<String?> employerName = const Value.absent(),
                Value<String?> departmentName = const Value.absent(),
                Value<String?> jobRole = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> reportingInstruction = const Value.absent(),
                Value<String?> supervisorName = const Value.absent(),
                Value<String?> supervisorPhone = const Value.absent(),
                Value<String?> contactName = const Value.absent(),
                Value<String?> contactPhone = const Value.absent(),
                Value<String?> academicTermId = const Value.absent(),
                Value<String?> weekdays = const Value.absent(),
                Value<String?> untilDate = const Value.absent(),
                Value<String?> exceptionDates = const Value.absent(),
                Value<bool> isDayOff = const Value.absent(),
                Value<int?> workCategory = const Value.absent(),
                Value<int?> deadlineType = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<String?> importFormat = const Value.absent(),
                Value<String?> importUid = const Value.absent(),
                Value<String?> importSourceName = const Value.absent(),
                Value<String?> importSourceText = const Value.absent(),
                Value<String?> importedAt = const Value.absent(),
                Value<int?> reminderMinutesBefore = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<String?> actualIntervalsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduleRowsCompanion(
                id: id,
                kind: kind,
                title: title,
                startDate: startDate,
                timeZoneId: timeZoneId,
                code: code,
                codeMeaning: codeMeaning,
                employerName: employerName,
                departmentName: departmentName,
                jobRole: jobRole,
                location: location,
                notes: notes,
                reportingInstruction: reportingInstruction,
                supervisorName: supervisorName,
                supervisorPhone: supervisorPhone,
                contactName: contactName,
                contactPhone: contactPhone,
                academicTermId: academicTermId,
                weekdays: weekdays,
                untilDate: untilDate,
                exceptionDates: exceptionDates,
                isDayOff: isDayOff,
                workCategory: workCategory,
                deadlineType: deadlineType,
                allDay: allDay,
                importFormat: importFormat,
                importUid: importUid,
                importSourceName: importSourceName,
                importSourceText: importSourceText,
                importedAt: importedAt,
                reminderMinutesBefore: reminderMinutesBefore,
                isCompleted: isCompleted,
                actualIntervalsJson: actualIntervalsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int kind,
                required String title,
                required String startDate,
                Value<String?> timeZoneId = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<String?> codeMeaning = const Value.absent(),
                Value<String?> employerName = const Value.absent(),
                Value<String?> departmentName = const Value.absent(),
                Value<String?> jobRole = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> reportingInstruction = const Value.absent(),
                Value<String?> supervisorName = const Value.absent(),
                Value<String?> supervisorPhone = const Value.absent(),
                Value<String?> contactName = const Value.absent(),
                Value<String?> contactPhone = const Value.absent(),
                Value<String?> academicTermId = const Value.absent(),
                Value<String?> weekdays = const Value.absent(),
                Value<String?> untilDate = const Value.absent(),
                Value<String?> exceptionDates = const Value.absent(),
                Value<bool> isDayOff = const Value.absent(),
                Value<int?> workCategory = const Value.absent(),
                Value<int?> deadlineType = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<String?> importFormat = const Value.absent(),
                Value<String?> importUid = const Value.absent(),
                Value<String?> importSourceName = const Value.absent(),
                Value<String?> importSourceText = const Value.absent(),
                Value<String?> importedAt = const Value.absent(),
                Value<int?> reminderMinutesBefore = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<String?> actualIntervalsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduleRowsCompanion.insert(
                id: id,
                kind: kind,
                title: title,
                startDate: startDate,
                timeZoneId: timeZoneId,
                code: code,
                codeMeaning: codeMeaning,
                employerName: employerName,
                departmentName: departmentName,
                jobRole: jobRole,
                location: location,
                notes: notes,
                reportingInstruction: reportingInstruction,
                supervisorName: supervisorName,
                supervisorPhone: supervisorPhone,
                contactName: contactName,
                contactPhone: contactPhone,
                academicTermId: academicTermId,
                weekdays: weekdays,
                untilDate: untilDate,
                exceptionDates: exceptionDates,
                isDayOff: isDayOff,
                workCategory: workCategory,
                deadlineType: deadlineType,
                allDay: allDay,
                importFormat: importFormat,
                importUid: importUid,
                importSourceName: importSourceName,
                importSourceText: importSourceText,
                importedAt: importedAt,
                reminderMinutesBefore: reminderMinutesBefore,
                isCompleted: isCompleted,
                actualIntervalsJson: actualIntervalsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScheduleRowsTable, ScheduleRow>(table),
                  $$ScheduleRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({academicTermId = false, intervalRowsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (intervalRowsRefs) db.intervalRows,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (academicTermId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.academicTermId,
                            referencedTable: $$ScheduleRowsTableReferences
                                ._academicTermIdTable(db),
                            referencedColumn: $$ScheduleRowsTableReferences
                                ._academicTermIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (intervalRowsRefs)
                        await $_getPrefetchedDataByColumns<
                          ScheduleRow,
                          $ScheduleRowsTable,
                          IntervalRow,
                          $IntervalRowsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ScheduleRowsTableReferences
                              ._intervalRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ScheduleRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).intervalRowsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'item_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ScheduleRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$ScheduleDatabase,
      $ScheduleRowsTable,
      ScheduleRow,
      $$ScheduleRowsTableFilterComposer,
      $$ScheduleRowsTableOrderingComposer,
      $$ScheduleRowsTableAnnotationComposer,
      $$ScheduleRowsTableCreateCompanionBuilder,
      $$ScheduleRowsTableUpdateCompanionBuilder,
      (ScheduleRow, $$ScheduleRowsTableReferences),
      ScheduleRow,
      PrefetchHooks Function({bool academicTermId, bool intervalRowsRefs})
    >;
typedef $$IntervalRowsTableCreateCompanionBuilder =
    IntervalRowsCompanion Function({
      Value<int> rowId,
      required String itemId,
      required int startDayOffset,
      required int startMinute,
      required int endDayOffset,
      required int endMinute,
      Value<String?> startFoldChoice,
      Value<String?> endFoldChoice,
    });
typedef $$IntervalRowsTableUpdateCompanionBuilder =
    IntervalRowsCompanion Function({
      Value<int> rowId,
      Value<String> itemId,
      Value<int> startDayOffset,
      Value<int> startMinute,
      Value<int> endDayOffset,
      Value<int> endMinute,
      Value<String?> startFoldChoice,
      Value<String?> endFoldChoice,
    });

final class $$IntervalRowsTableReferences
    extends
        BaseReferences<_$ScheduleDatabase, $IntervalRowsTable, IntervalRow> {
  $$IntervalRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ScheduleRowsTable _itemIdTable(_$ScheduleDatabase db) =>
      db.scheduleRows.createAlias('interval_rows__item_id__schedule_rows__id');

  $$ScheduleRowsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ScheduleRowsTableTableManager(
      $_db,
      $_db.scheduleRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$IntervalRowsTableFilterComposer
    extends Composer<_$ScheduleDatabase, $IntervalRowsTable> {
  $$IntervalRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startDayOffset => $composableBuilder(
    column: $table.startDayOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endDayOffset => $composableBuilder(
    column: $table.endDayOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startFoldChoice => $composableBuilder(
    column: $table.startFoldChoice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endFoldChoice => $composableBuilder(
    column: $table.endFoldChoice,
    builder: (column) => ColumnFilters(column),
  );

  $$ScheduleRowsTableFilterComposer get itemId {
    final $$ScheduleRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.scheduleRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleRowsTableFilterComposer(
            $db: $db,
            $table: $db.scheduleRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IntervalRowsTableOrderingComposer
    extends Composer<_$ScheduleDatabase, $IntervalRowsTable> {
  $$IntervalRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startDayOffset => $composableBuilder(
    column: $table.startDayOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endDayOffset => $composableBuilder(
    column: $table.endDayOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startFoldChoice => $composableBuilder(
    column: $table.startFoldChoice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endFoldChoice => $composableBuilder(
    column: $table.endFoldChoice,
    builder: (column) => ColumnOrderings(column),
  );

  $$ScheduleRowsTableOrderingComposer get itemId {
    final $$ScheduleRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.scheduleRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleRowsTableOrderingComposer(
            $db: $db,
            $table: $db.scheduleRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IntervalRowsTableAnnotationComposer
    extends Composer<_$ScheduleDatabase, $IntervalRowsTable> {
  $$IntervalRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<int> get startDayOffset => $composableBuilder(
    column: $table.startDayOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endDayOffset => $composableBuilder(
    column: $table.endDayOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<String> get startFoldChoice => $composableBuilder(
    column: $table.startFoldChoice,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endFoldChoice => $composableBuilder(
    column: $table.endFoldChoice,
    builder: (column) => column,
  );

  $$ScheduleRowsTableAnnotationComposer get itemId {
    final $$ScheduleRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.scheduleRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.scheduleRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IntervalRowsTableTableManager
    extends
        RootTableManager<
          _$ScheduleDatabase,
          $IntervalRowsTable,
          IntervalRow,
          $$IntervalRowsTableFilterComposer,
          $$IntervalRowsTableOrderingComposer,
          $$IntervalRowsTableAnnotationComposer,
          $$IntervalRowsTableCreateCompanionBuilder,
          $$IntervalRowsTableUpdateCompanionBuilder,
          (IntervalRow, $$IntervalRowsTableReferences),
          IntervalRow,
          PrefetchHooks Function({bool itemId})
        > {
  $$IntervalRowsTableTableManager(
    _$ScheduleDatabase db,
    $IntervalRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IntervalRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IntervalRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IntervalRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> rowId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<int> startDayOffset = const Value.absent(),
                Value<int> startMinute = const Value.absent(),
                Value<int> endDayOffset = const Value.absent(),
                Value<int> endMinute = const Value.absent(),
                Value<String?> startFoldChoice = const Value.absent(),
                Value<String?> endFoldChoice = const Value.absent(),
              }) => IntervalRowsCompanion(
                rowId: rowId,
                itemId: itemId,
                startDayOffset: startDayOffset,
                startMinute: startMinute,
                endDayOffset: endDayOffset,
                endMinute: endMinute,
                startFoldChoice: startFoldChoice,
                endFoldChoice: endFoldChoice,
              ),
          createCompanionCallback:
              ({
                Value<int> rowId = const Value.absent(),
                required String itemId,
                required int startDayOffset,
                required int startMinute,
                required int endDayOffset,
                required int endMinute,
                Value<String?> startFoldChoice = const Value.absent(),
                Value<String?> endFoldChoice = const Value.absent(),
              }) => IntervalRowsCompanion.insert(
                rowId: rowId,
                itemId: itemId,
                startDayOffset: startDayOffset,
                startMinute: startMinute,
                endDayOffset: endDayOffset,
                endMinute: endMinute,
                startFoldChoice: startFoldChoice,
                endFoldChoice: endFoldChoice,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IntervalRowsTable, IntervalRow>(table),
                  $$IntervalRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.itemId,
                        referencedTable: $$IntervalRowsTableReferences
                            ._itemIdTable(db),
                        referencedColumn: $$IntervalRowsTableReferences
                            ._itemIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$IntervalRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$ScheduleDatabase,
      $IntervalRowsTable,
      IntervalRow,
      $$IntervalRowsTableFilterComposer,
      $$IntervalRowsTableOrderingComposer,
      $$IntervalRowsTableAnnotationComposer,
      $$IntervalRowsTableCreateCompanionBuilder,
      $$IntervalRowsTableUpdateCompanionBuilder,
      (IntervalRow, $$IntervalRowsTableReferences),
      IntervalRow,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$PreferenceRowsTableCreateCompanionBuilder =
    PreferenceRowsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$PreferenceRowsTableUpdateCompanionBuilder =
    PreferenceRowsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$PreferenceRowsTableFilterComposer
    extends Composer<_$ScheduleDatabase, $PreferenceRowsTable> {
  $$PreferenceRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PreferenceRowsTableOrderingComposer
    extends Composer<_$ScheduleDatabase, $PreferenceRowsTable> {
  $$PreferenceRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreferenceRowsTableAnnotationComposer
    extends Composer<_$ScheduleDatabase, $PreferenceRowsTable> {
  $$PreferenceRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$PreferenceRowsTableTableManager
    extends
        RootTableManager<
          _$ScheduleDatabase,
          $PreferenceRowsTable,
          PreferenceRow,
          $$PreferenceRowsTableFilterComposer,
          $$PreferenceRowsTableOrderingComposer,
          $$PreferenceRowsTableAnnotationComposer,
          $$PreferenceRowsTableCreateCompanionBuilder,
          $$PreferenceRowsTableUpdateCompanionBuilder,
          (
            PreferenceRow,
            BaseReferences<
              _$ScheduleDatabase,
              $PreferenceRowsTable,
              PreferenceRow
            >,
          ),
          PreferenceRow,
          PrefetchHooks Function()
        > {
  $$PreferenceRowsTableTableManager(
    _$ScheduleDatabase db,
    $PreferenceRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferenceRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferenceRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferenceRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => PreferenceRowsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => PreferenceRowsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PreferenceRowsTable, PreferenceRow>(table),
                  BaseReferences<
                    _$ScheduleDatabase,
                    $PreferenceRowsTable,
                    PreferenceRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PreferenceRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$ScheduleDatabase,
      $PreferenceRowsTable,
      PreferenceRow,
      $$PreferenceRowsTableFilterComposer,
      $$PreferenceRowsTableOrderingComposer,
      $$PreferenceRowsTableAnnotationComposer,
      $$PreferenceRowsTableCreateCompanionBuilder,
      $$PreferenceRowsTableUpdateCompanionBuilder,
      (
        PreferenceRow,
        BaseReferences<_$ScheduleDatabase, $PreferenceRowsTable, PreferenceRow>,
      ),
      PreferenceRow,
      PrefetchHooks Function()
    >;
typedef $$WorkCodeLegendRowsTableCreateCompanionBuilder =
    WorkCodeLegendRowsCompanion Function({
      required String id,
      required String employer,
      required String code,
      required String meaning,
      Value<int?> startMinute,
      Value<int?> endMinute,
      Value<String> flightIdsJson,
      Value<int> rowid,
    });
typedef $$WorkCodeLegendRowsTableUpdateCompanionBuilder =
    WorkCodeLegendRowsCompanion Function({
      Value<String> id,
      Value<String> employer,
      Value<String> code,
      Value<String> meaning,
      Value<int?> startMinute,
      Value<int?> endMinute,
      Value<String> flightIdsJson,
      Value<int> rowid,
    });

class $$WorkCodeLegendRowsTableFilterComposer
    extends Composer<_$ScheduleDatabase, $WorkCodeLegendRowsTable> {
  $$WorkCodeLegendRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get employer => $composableBuilder(
    column: $table.employer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get flightIdsJson => $composableBuilder(
    column: $table.flightIdsJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkCodeLegendRowsTableOrderingComposer
    extends Composer<_$ScheduleDatabase, $WorkCodeLegendRowsTable> {
  $$WorkCodeLegendRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get employer => $composableBuilder(
    column: $table.employer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flightIdsJson => $composableBuilder(
    column: $table.flightIdsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkCodeLegendRowsTableAnnotationComposer
    extends Composer<_$ScheduleDatabase, $WorkCodeLegendRowsTable> {
  $$WorkCodeLegendRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get employer =>
      $composableBuilder(column: $table.employer, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get meaning =>
      $composableBuilder(column: $table.meaning, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<String> get flightIdsJson => $composableBuilder(
    column: $table.flightIdsJson,
    builder: (column) => column,
  );
}

class $$WorkCodeLegendRowsTableTableManager
    extends
        RootTableManager<
          _$ScheduleDatabase,
          $WorkCodeLegendRowsTable,
          WorkCodeLegendRow,
          $$WorkCodeLegendRowsTableFilterComposer,
          $$WorkCodeLegendRowsTableOrderingComposer,
          $$WorkCodeLegendRowsTableAnnotationComposer,
          $$WorkCodeLegendRowsTableCreateCompanionBuilder,
          $$WorkCodeLegendRowsTableUpdateCompanionBuilder,
          (
            WorkCodeLegendRow,
            BaseReferences<
              _$ScheduleDatabase,
              $WorkCodeLegendRowsTable,
              WorkCodeLegendRow
            >,
          ),
          WorkCodeLegendRow,
          PrefetchHooks Function()
        > {
  $$WorkCodeLegendRowsTableTableManager(
    _$ScheduleDatabase db,
    $WorkCodeLegendRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkCodeLegendRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkCodeLegendRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkCodeLegendRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> employer = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> meaning = const Value.absent(),
                Value<int?> startMinute = const Value.absent(),
                Value<int?> endMinute = const Value.absent(),
                Value<String> flightIdsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkCodeLegendRowsCompanion(
                id: id,
                employer: employer,
                code: code,
                meaning: meaning,
                startMinute: startMinute,
                endMinute: endMinute,
                flightIdsJson: flightIdsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String employer,
                required String code,
                required String meaning,
                Value<int?> startMinute = const Value.absent(),
                Value<int?> endMinute = const Value.absent(),
                Value<String> flightIdsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkCodeLegendRowsCompanion.insert(
                id: id,
                employer: employer,
                code: code,
                meaning: meaning,
                startMinute: startMinute,
                endMinute: endMinute,
                flightIdsJson: flightIdsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkCodeLegendRowsTable, WorkCodeLegendRow>(
                    table,
                  ),
                  BaseReferences<
                    _$ScheduleDatabase,
                    $WorkCodeLegendRowsTable,
                    WorkCodeLegendRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkCodeLegendRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$ScheduleDatabase,
      $WorkCodeLegendRowsTable,
      WorkCodeLegendRow,
      $$WorkCodeLegendRowsTableFilterComposer,
      $$WorkCodeLegendRowsTableOrderingComposer,
      $$WorkCodeLegendRowsTableAnnotationComposer,
      $$WorkCodeLegendRowsTableCreateCompanionBuilder,
      $$WorkCodeLegendRowsTableUpdateCompanionBuilder,
      (
        WorkCodeLegendRow,
        BaseReferences<
          _$ScheduleDatabase,
          $WorkCodeLegendRowsTable,
          WorkCodeLegendRow
        >,
      ),
      WorkCodeLegendRow,
      PrefetchHooks Function()
    >;
typedef $$ScheduleImportHistoryRowsTableCreateCompanionBuilder =
    ScheduleImportHistoryRowsCompanion Function({
      Value<int> id,
      required String sourceType,
      required String importedAt,
      required String parserVersion,
      required int proposedCount,
      required int acceptedCount,
      required int rejectedCount,
      required int skippedCount,
      required int warningsCount,
    });
typedef $$ScheduleImportHistoryRowsTableUpdateCompanionBuilder =
    ScheduleImportHistoryRowsCompanion Function({
      Value<int> id,
      Value<String> sourceType,
      Value<String> importedAt,
      Value<String> parserVersion,
      Value<int> proposedCount,
      Value<int> acceptedCount,
      Value<int> rejectedCount,
      Value<int> skippedCount,
      Value<int> warningsCount,
    });

class $$ScheduleImportHistoryRowsTableFilterComposer
    extends Composer<_$ScheduleDatabase, $ScheduleImportHistoryRowsTable> {
  $$ScheduleImportHistoryRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parserVersion => $composableBuilder(
    column: $table.parserVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get proposedCount => $composableBuilder(
    column: $table.proposedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get acceptedCount => $composableBuilder(
    column: $table.acceptedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rejectedCount => $composableBuilder(
    column: $table.rejectedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get skippedCount => $composableBuilder(
    column: $table.skippedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get warningsCount => $composableBuilder(
    column: $table.warningsCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScheduleImportHistoryRowsTableOrderingComposer
    extends Composer<_$ScheduleDatabase, $ScheduleImportHistoryRowsTable> {
  $$ScheduleImportHistoryRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parserVersion => $composableBuilder(
    column: $table.parserVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get proposedCount => $composableBuilder(
    column: $table.proposedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get acceptedCount => $composableBuilder(
    column: $table.acceptedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rejectedCount => $composableBuilder(
    column: $table.rejectedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get skippedCount => $composableBuilder(
    column: $table.skippedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get warningsCount => $composableBuilder(
    column: $table.warningsCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScheduleImportHistoryRowsTableAnnotationComposer
    extends Composer<_$ScheduleDatabase, $ScheduleImportHistoryRowsTable> {
  $$ScheduleImportHistoryRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parserVersion => $composableBuilder(
    column: $table.parserVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get proposedCount => $composableBuilder(
    column: $table.proposedCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get acceptedCount => $composableBuilder(
    column: $table.acceptedCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rejectedCount => $composableBuilder(
    column: $table.rejectedCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get skippedCount => $composableBuilder(
    column: $table.skippedCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get warningsCount => $composableBuilder(
    column: $table.warningsCount,
    builder: (column) => column,
  );
}

class $$ScheduleImportHistoryRowsTableTableManager
    extends
        RootTableManager<
          _$ScheduleDatabase,
          $ScheduleImportHistoryRowsTable,
          ScheduleImportHistoryRow,
          $$ScheduleImportHistoryRowsTableFilterComposer,
          $$ScheduleImportHistoryRowsTableOrderingComposer,
          $$ScheduleImportHistoryRowsTableAnnotationComposer,
          $$ScheduleImportHistoryRowsTableCreateCompanionBuilder,
          $$ScheduleImportHistoryRowsTableUpdateCompanionBuilder,
          (
            ScheduleImportHistoryRow,
            BaseReferences<
              _$ScheduleDatabase,
              $ScheduleImportHistoryRowsTable,
              ScheduleImportHistoryRow
            >,
          ),
          ScheduleImportHistoryRow,
          PrefetchHooks Function()
        > {
  $$ScheduleImportHistoryRowsTableTableManager(
    _$ScheduleDatabase db,
    $ScheduleImportHistoryRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduleImportHistoryRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ScheduleImportHistoryRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ScheduleImportHistoryRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> importedAt = const Value.absent(),
                Value<String> parserVersion = const Value.absent(),
                Value<int> proposedCount = const Value.absent(),
                Value<int> acceptedCount = const Value.absent(),
                Value<int> rejectedCount = const Value.absent(),
                Value<int> skippedCount = const Value.absent(),
                Value<int> warningsCount = const Value.absent(),
              }) => ScheduleImportHistoryRowsCompanion(
                id: id,
                sourceType: sourceType,
                importedAt: importedAt,
                parserVersion: parserVersion,
                proposedCount: proposedCount,
                acceptedCount: acceptedCount,
                rejectedCount: rejectedCount,
                skippedCount: skippedCount,
                warningsCount: warningsCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sourceType,
                required String importedAt,
                required String parserVersion,
                required int proposedCount,
                required int acceptedCount,
                required int rejectedCount,
                required int skippedCount,
                required int warningsCount,
              }) => ScheduleImportHistoryRowsCompanion.insert(
                id: id,
                sourceType: sourceType,
                importedAt: importedAt,
                parserVersion: parserVersion,
                proposedCount: proposedCount,
                acceptedCount: acceptedCount,
                rejectedCount: rejectedCount,
                skippedCount: skippedCount,
                warningsCount: warningsCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ScheduleImportHistoryRowsTable,
                    ScheduleImportHistoryRow
                  >(table),
                  BaseReferences<
                    _$ScheduleDatabase,
                    $ScheduleImportHistoryRowsTable,
                    ScheduleImportHistoryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScheduleImportHistoryRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$ScheduleDatabase,
      $ScheduleImportHistoryRowsTable,
      ScheduleImportHistoryRow,
      $$ScheduleImportHistoryRowsTableFilterComposer,
      $$ScheduleImportHistoryRowsTableOrderingComposer,
      $$ScheduleImportHistoryRowsTableAnnotationComposer,
      $$ScheduleImportHistoryRowsTableCreateCompanionBuilder,
      $$ScheduleImportHistoryRowsTableUpdateCompanionBuilder,
      (
        ScheduleImportHistoryRow,
        BaseReferences<
          _$ScheduleDatabase,
          $ScheduleImportHistoryRowsTable,
          ScheduleImportHistoryRow
        >,
      ),
      ScheduleImportHistoryRow,
      PrefetchHooks Function()
    >;

class $ScheduleDatabaseManager {
  final _$ScheduleDatabase _db;
  $ScheduleDatabaseManager(this._db);
  $$AcademicTermRowsTableTableManager get academicTermRows =>
      $$AcademicTermRowsTableTableManager(_db, _db.academicTermRows);
  $$ScheduleRowsTableTableManager get scheduleRows =>
      $$ScheduleRowsTableTableManager(_db, _db.scheduleRows);
  $$IntervalRowsTableTableManager get intervalRows =>
      $$IntervalRowsTableTableManager(_db, _db.intervalRows);
  $$PreferenceRowsTableTableManager get preferenceRows =>
      $$PreferenceRowsTableTableManager(_db, _db.preferenceRows);
  $$WorkCodeLegendRowsTableTableManager get workCodeLegendRows =>
      $$WorkCodeLegendRowsTableTableManager(_db, _db.workCodeLegendRows);
  $$ScheduleImportHistoryRowsTableTableManager get scheduleImportHistoryRows =>
      $$ScheduleImportHistoryRowsTableTableManager(
        _db,
        _db.scheduleImportHistoryRows,
      );
}
