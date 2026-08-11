// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CoursesTable extends Courses with TableInfo<$CoursesTable, Course> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoursesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clientUuidMeta = const VerificationMeta(
    'clientUuid',
  );
  @override
  late final GeneratedColumn<String> clientUuid = GeneratedColumn<String>(
    'client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pendingSyncMeta = const VerificationMeta(
    'pendingSync',
  );
  @override
  late final GeneratedColumn<bool> pendingSync = GeneratedColumn<bool>(
    'pending_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending_sync" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncVersionMeta = const VerificationMeta(
    'syncVersion',
  );
  @override
  late final GeneratedColumn<int> syncVersion = GeneratedColumn<int>(
    'sync_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientUuid,
    serverId,
    title,
    description,
    pendingSync,
    deleted,
    syncVersion,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'courses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Course> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_uuid')) {
      context.handle(
        _clientUuidMeta,
        clientUuid.isAcceptableOrUnknown(data['client_uuid']!, _clientUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_clientUuidMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('pending_sync')) {
      context.handle(
        _pendingSyncMeta,
        pendingSync.isAcceptableOrUnknown(
          data['pending_sync']!,
          _pendingSyncMeta,
        ),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('sync_version')) {
      context.handle(
        _syncVersionMeta,
        syncVersion.isAcceptableOrUnknown(
          data['sync_version']!,
          _syncVersionMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Course map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Course(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_uuid'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      pendingSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending_sync'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      syncVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CoursesTable createAlias(String alias) {
    return $CoursesTable(attachedDatabase, alias);
  }
}

class Course extends DataClass implements Insertable<Course> {
  final int id;
  final String clientUuid;
  final String? serverId;
  final String title;
  final String? description;
  final bool pendingSync;
  final bool deleted;
  final int syncVersion;
  final DateTime updatedAt;
  const Course({
    required this.id,
    required this.clientUuid,
    this.serverId,
    required this.title,
    this.description,
    required this.pendingSync,
    required this.deleted,
    required this.syncVersion,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_uuid'] = Variable<String>(clientUuid);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['pending_sync'] = Variable<bool>(pendingSync);
    map['deleted'] = Variable<bool>(deleted);
    map['sync_version'] = Variable<int>(syncVersion);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CoursesCompanion toCompanion(bool nullToAbsent) {
    return CoursesCompanion(
      id: Value(id),
      clientUuid: Value(clientUuid),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      pendingSync: Value(pendingSync),
      deleted: Value(deleted),
      syncVersion: Value(syncVersion),
      updatedAt: Value(updatedAt),
    );
  }

  factory Course.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Course(
      id: serializer.fromJson<int>(json['id']),
      clientUuid: serializer.fromJson<String>(json['clientUuid']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      pendingSync: serializer.fromJson<bool>(json['pendingSync']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      syncVersion: serializer.fromJson<int>(json['syncVersion']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientUuid': serializer.toJson<String>(clientUuid),
      'serverId': serializer.toJson<String?>(serverId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'pendingSync': serializer.toJson<bool>(pendingSync),
      'deleted': serializer.toJson<bool>(deleted),
      'syncVersion': serializer.toJson<int>(syncVersion),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Course copyWith({
    int? id,
    String? clientUuid,
    Value<String?> serverId = const Value.absent(),
    String? title,
    Value<String?> description = const Value.absent(),
    bool? pendingSync,
    bool? deleted,
    int? syncVersion,
    DateTime? updatedAt,
  }) => Course(
    id: id ?? this.id,
    clientUuid: clientUuid ?? this.clientUuid,
    serverId: serverId.present ? serverId.value : this.serverId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    pendingSync: pendingSync ?? this.pendingSync,
    deleted: deleted ?? this.deleted,
    syncVersion: syncVersion ?? this.syncVersion,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Course copyWithCompanion(CoursesCompanion data) {
    return Course(
      id: data.id.present ? data.id.value : this.id,
      clientUuid: data.clientUuid.present
          ? data.clientUuid.value
          : this.clientUuid,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      pendingSync: data.pendingSync.present
          ? data.pendingSync.value
          : this.pendingSync,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      syncVersion: data.syncVersion.present
          ? data.syncVersion.value
          : this.syncVersion,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Course(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('serverId: $serverId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('deleted: $deleted, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientUuid,
    serverId,
    title,
    description,
    pendingSync,
    deleted,
    syncVersion,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Course &&
          other.id == this.id &&
          other.clientUuid == this.clientUuid &&
          other.serverId == this.serverId &&
          other.title == this.title &&
          other.description == this.description &&
          other.pendingSync == this.pendingSync &&
          other.deleted == this.deleted &&
          other.syncVersion == this.syncVersion &&
          other.updatedAt == this.updatedAt);
}

class CoursesCompanion extends UpdateCompanion<Course> {
  final Value<int> id;
  final Value<String> clientUuid;
  final Value<String?> serverId;
  final Value<String> title;
  final Value<String?> description;
  final Value<bool> pendingSync;
  final Value<bool> deleted;
  final Value<int> syncVersion;
  final Value<DateTime> updatedAt;
  const CoursesCompanion({
    this.id = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.serverId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.deleted = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  CoursesCompanion.insert({
    this.id = const Value.absent(),
    required String clientUuid,
    this.serverId = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.deleted = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : clientUuid = Value(clientUuid),
       title = Value(title);
  static Insertable<Course> custom({
    Expression<int>? id,
    Expression<String>? clientUuid,
    Expression<String>? serverId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<bool>? pendingSync,
    Expression<bool>? deleted,
    Expression<int>? syncVersion,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientUuid != null) 'client_uuid': clientUuid,
      if (serverId != null) 'server_id': serverId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (pendingSync != null) 'pending_sync': pendingSync,
      if (deleted != null) 'deleted': deleted,
      if (syncVersion != null) 'sync_version': syncVersion,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  CoursesCompanion copyWith({
    Value<int>? id,
    Value<String>? clientUuid,
    Value<String?>? serverId,
    Value<String>? title,
    Value<String?>? description,
    Value<bool>? pendingSync,
    Value<bool>? deleted,
    Value<int>? syncVersion,
    Value<DateTime>? updatedAt,
  }) {
    return CoursesCompanion(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      serverId: serverId ?? this.serverId,
      title: title ?? this.title,
      description: description ?? this.description,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
      syncVersion: syncVersion ?? this.syncVersion,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientUuid.present) {
      map['client_uuid'] = Variable<String>(clientUuid.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (pendingSync.present) {
      map['pending_sync'] = Variable<bool>(pendingSync.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (syncVersion.present) {
      map['sync_version'] = Variable<int>(syncVersion.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoursesCompanion(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('serverId: $serverId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('deleted: $deleted, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $LessonsTable extends Lessons with TableInfo<$LessonsTable, Lesson> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LessonsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clientUuidMeta = const VerificationMeta(
    'clientUuid',
  );
  @override
  late final GeneratedColumn<String> clientUuid = GeneratedColumn<String>(
    'client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _courseClientUuidMeta = const VerificationMeta(
    'courseClientUuid',
  );
  @override
  late final GeneratedColumn<String> courseClientUuid = GeneratedColumn<String>(
    'course_client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pendingSyncMeta = const VerificationMeta(
    'pendingSync',
  );
  @override
  late final GeneratedColumn<bool> pendingSync = GeneratedColumn<bool>(
    'pending_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending_sync" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncVersionMeta = const VerificationMeta(
    'syncVersion',
  );
  @override
  late final GeneratedColumn<int> syncVersion = GeneratedColumn<int>(
    'sync_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientUuid,
    serverId,
    courseClientUuid,
    title,
    position,
    pendingSync,
    deleted,
    syncVersion,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lessons';
  @override
  VerificationContext validateIntegrity(
    Insertable<Lesson> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_uuid')) {
      context.handle(
        _clientUuidMeta,
        clientUuid.isAcceptableOrUnknown(data['client_uuid']!, _clientUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_clientUuidMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('course_client_uuid')) {
      context.handle(
        _courseClientUuidMeta,
        courseClientUuid.isAcceptableOrUnknown(
          data['course_client_uuid']!,
          _courseClientUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_courseClientUuidMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('pending_sync')) {
      context.handle(
        _pendingSyncMeta,
        pendingSync.isAcceptableOrUnknown(
          data['pending_sync']!,
          _pendingSyncMeta,
        ),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('sync_version')) {
      context.handle(
        _syncVersionMeta,
        syncVersion.isAcceptableOrUnknown(
          data['sync_version']!,
          _syncVersionMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Lesson map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Lesson(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_uuid'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      courseClientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_client_uuid'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      pendingSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending_sync'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      syncVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LessonsTable createAlias(String alias) {
    return $LessonsTable(attachedDatabase, alias);
  }
}

class Lesson extends DataClass implements Insertable<Lesson> {
  final int id;
  final String clientUuid;
  final String? serverId;
  final String courseClientUuid;
  final String title;
  final int position;
  final bool pendingSync;
  final bool deleted;
  final int syncVersion;
  final DateTime updatedAt;
  const Lesson({
    required this.id,
    required this.clientUuid,
    this.serverId,
    required this.courseClientUuid,
    required this.title,
    required this.position,
    required this.pendingSync,
    required this.deleted,
    required this.syncVersion,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_uuid'] = Variable<String>(clientUuid);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['course_client_uuid'] = Variable<String>(courseClientUuid);
    map['title'] = Variable<String>(title);
    map['position'] = Variable<int>(position);
    map['pending_sync'] = Variable<bool>(pendingSync);
    map['deleted'] = Variable<bool>(deleted);
    map['sync_version'] = Variable<int>(syncVersion);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LessonsCompanion toCompanion(bool nullToAbsent) {
    return LessonsCompanion(
      id: Value(id),
      clientUuid: Value(clientUuid),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      courseClientUuid: Value(courseClientUuid),
      title: Value(title),
      position: Value(position),
      pendingSync: Value(pendingSync),
      deleted: Value(deleted),
      syncVersion: Value(syncVersion),
      updatedAt: Value(updatedAt),
    );
  }

  factory Lesson.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Lesson(
      id: serializer.fromJson<int>(json['id']),
      clientUuid: serializer.fromJson<String>(json['clientUuid']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      courseClientUuid: serializer.fromJson<String>(json['courseClientUuid']),
      title: serializer.fromJson<String>(json['title']),
      position: serializer.fromJson<int>(json['position']),
      pendingSync: serializer.fromJson<bool>(json['pendingSync']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      syncVersion: serializer.fromJson<int>(json['syncVersion']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientUuid': serializer.toJson<String>(clientUuid),
      'serverId': serializer.toJson<String?>(serverId),
      'courseClientUuid': serializer.toJson<String>(courseClientUuid),
      'title': serializer.toJson<String>(title),
      'position': serializer.toJson<int>(position),
      'pendingSync': serializer.toJson<bool>(pendingSync),
      'deleted': serializer.toJson<bool>(deleted),
      'syncVersion': serializer.toJson<int>(syncVersion),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Lesson copyWith({
    int? id,
    String? clientUuid,
    Value<String?> serverId = const Value.absent(),
    String? courseClientUuid,
    String? title,
    int? position,
    bool? pendingSync,
    bool? deleted,
    int? syncVersion,
    DateTime? updatedAt,
  }) => Lesson(
    id: id ?? this.id,
    clientUuid: clientUuid ?? this.clientUuid,
    serverId: serverId.present ? serverId.value : this.serverId,
    courseClientUuid: courseClientUuid ?? this.courseClientUuid,
    title: title ?? this.title,
    position: position ?? this.position,
    pendingSync: pendingSync ?? this.pendingSync,
    deleted: deleted ?? this.deleted,
    syncVersion: syncVersion ?? this.syncVersion,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Lesson copyWithCompanion(LessonsCompanion data) {
    return Lesson(
      id: data.id.present ? data.id.value : this.id,
      clientUuid: data.clientUuid.present
          ? data.clientUuid.value
          : this.clientUuid,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      courseClientUuid: data.courseClientUuid.present
          ? data.courseClientUuid.value
          : this.courseClientUuid,
      title: data.title.present ? data.title.value : this.title,
      position: data.position.present ? data.position.value : this.position,
      pendingSync: data.pendingSync.present
          ? data.pendingSync.value
          : this.pendingSync,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      syncVersion: data.syncVersion.present
          ? data.syncVersion.value
          : this.syncVersion,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Lesson(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('serverId: $serverId, ')
          ..write('courseClientUuid: $courseClientUuid, ')
          ..write('title: $title, ')
          ..write('position: $position, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('deleted: $deleted, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientUuid,
    serverId,
    courseClientUuid,
    title,
    position,
    pendingSync,
    deleted,
    syncVersion,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Lesson &&
          other.id == this.id &&
          other.clientUuid == this.clientUuid &&
          other.serverId == this.serverId &&
          other.courseClientUuid == this.courseClientUuid &&
          other.title == this.title &&
          other.position == this.position &&
          other.pendingSync == this.pendingSync &&
          other.deleted == this.deleted &&
          other.syncVersion == this.syncVersion &&
          other.updatedAt == this.updatedAt);
}

class LessonsCompanion extends UpdateCompanion<Lesson> {
  final Value<int> id;
  final Value<String> clientUuid;
  final Value<String?> serverId;
  final Value<String> courseClientUuid;
  final Value<String> title;
  final Value<int> position;
  final Value<bool> pendingSync;
  final Value<bool> deleted;
  final Value<int> syncVersion;
  final Value<DateTime> updatedAt;
  const LessonsCompanion({
    this.id = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.serverId = const Value.absent(),
    this.courseClientUuid = const Value.absent(),
    this.title = const Value.absent(),
    this.position = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.deleted = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LessonsCompanion.insert({
    this.id = const Value.absent(),
    required String clientUuid,
    this.serverId = const Value.absent(),
    required String courseClientUuid,
    required String title,
    this.position = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.deleted = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : clientUuid = Value(clientUuid),
       courseClientUuid = Value(courseClientUuid),
       title = Value(title);
  static Insertable<Lesson> custom({
    Expression<int>? id,
    Expression<String>? clientUuid,
    Expression<String>? serverId,
    Expression<String>? courseClientUuid,
    Expression<String>? title,
    Expression<int>? position,
    Expression<bool>? pendingSync,
    Expression<bool>? deleted,
    Expression<int>? syncVersion,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientUuid != null) 'client_uuid': clientUuid,
      if (serverId != null) 'server_id': serverId,
      if (courseClientUuid != null) 'course_client_uuid': courseClientUuid,
      if (title != null) 'title': title,
      if (position != null) 'position': position,
      if (pendingSync != null) 'pending_sync': pendingSync,
      if (deleted != null) 'deleted': deleted,
      if (syncVersion != null) 'sync_version': syncVersion,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LessonsCompanion copyWith({
    Value<int>? id,
    Value<String>? clientUuid,
    Value<String?>? serverId,
    Value<String>? courseClientUuid,
    Value<String>? title,
    Value<int>? position,
    Value<bool>? pendingSync,
    Value<bool>? deleted,
    Value<int>? syncVersion,
    Value<DateTime>? updatedAt,
  }) {
    return LessonsCompanion(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      serverId: serverId ?? this.serverId,
      courseClientUuid: courseClientUuid ?? this.courseClientUuid,
      title: title ?? this.title,
      position: position ?? this.position,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
      syncVersion: syncVersion ?? this.syncVersion,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientUuid.present) {
      map['client_uuid'] = Variable<String>(clientUuid.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (courseClientUuid.present) {
      map['course_client_uuid'] = Variable<String>(courseClientUuid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (pendingSync.present) {
      map['pending_sync'] = Variable<bool>(pendingSync.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (syncVersion.present) {
      map['sync_version'] = Variable<int>(syncVersion.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LessonsCompanion(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('serverId: $serverId, ')
          ..write('courseClientUuid: $courseClientUuid, ')
          ..write('title: $title, ')
          ..write('position: $position, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('deleted: $deleted, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ChaptersTable extends Chapters with TableInfo<$ChaptersTable, Chapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChaptersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clientUuidMeta = const VerificationMeta(
    'clientUuid',
  );
  @override
  late final GeneratedColumn<String> clientUuid = GeneratedColumn<String>(
    'client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lessonClientUuidMeta = const VerificationMeta(
    'lessonClientUuid',
  );
  @override
  late final GeneratedColumn<String> lessonClientUuid = GeneratedColumn<String>(
    'lesson_client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pendingSyncMeta = const VerificationMeta(
    'pendingSync',
  );
  @override
  late final GeneratedColumn<bool> pendingSync = GeneratedColumn<bool>(
    'pending_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending_sync" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncVersionMeta = const VerificationMeta(
    'syncVersion',
  );
  @override
  late final GeneratedColumn<int> syncVersion = GeneratedColumn<int>(
    'sync_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientUuid,
    serverId,
    lessonClientUuid,
    title,
    position,
    pendingSync,
    deleted,
    syncVersion,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Chapter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_uuid')) {
      context.handle(
        _clientUuidMeta,
        clientUuid.isAcceptableOrUnknown(data['client_uuid']!, _clientUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_clientUuidMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('lesson_client_uuid')) {
      context.handle(
        _lessonClientUuidMeta,
        lessonClientUuid.isAcceptableOrUnknown(
          data['lesson_client_uuid']!,
          _lessonClientUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lessonClientUuidMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('pending_sync')) {
      context.handle(
        _pendingSyncMeta,
        pendingSync.isAcceptableOrUnknown(
          data['pending_sync']!,
          _pendingSyncMeta,
        ),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('sync_version')) {
      context.handle(
        _syncVersionMeta,
        syncVersion.isAcceptableOrUnknown(
          data['sync_version']!,
          _syncVersionMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Chapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chapter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_uuid'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      lessonClientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_client_uuid'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      pendingSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending_sync'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      syncVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ChaptersTable createAlias(String alias) {
    return $ChaptersTable(attachedDatabase, alias);
  }
}

class Chapter extends DataClass implements Insertable<Chapter> {
  final int id;
  final String clientUuid;
  final String? serverId;
  final String lessonClientUuid;
  final String title;
  final int position;
  final bool pendingSync;
  final bool deleted;
  final int syncVersion;
  final DateTime updatedAt;
  const Chapter({
    required this.id,
    required this.clientUuid,
    this.serverId,
    required this.lessonClientUuid,
    required this.title,
    required this.position,
    required this.pendingSync,
    required this.deleted,
    required this.syncVersion,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_uuid'] = Variable<String>(clientUuid);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['lesson_client_uuid'] = Variable<String>(lessonClientUuid);
    map['title'] = Variable<String>(title);
    map['position'] = Variable<int>(position);
    map['pending_sync'] = Variable<bool>(pendingSync);
    map['deleted'] = Variable<bool>(deleted);
    map['sync_version'] = Variable<int>(syncVersion);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ChaptersCompanion toCompanion(bool nullToAbsent) {
    return ChaptersCompanion(
      id: Value(id),
      clientUuid: Value(clientUuid),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      lessonClientUuid: Value(lessonClientUuid),
      title: Value(title),
      position: Value(position),
      pendingSync: Value(pendingSync),
      deleted: Value(deleted),
      syncVersion: Value(syncVersion),
      updatedAt: Value(updatedAt),
    );
  }

  factory Chapter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chapter(
      id: serializer.fromJson<int>(json['id']),
      clientUuid: serializer.fromJson<String>(json['clientUuid']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      lessonClientUuid: serializer.fromJson<String>(json['lessonClientUuid']),
      title: serializer.fromJson<String>(json['title']),
      position: serializer.fromJson<int>(json['position']),
      pendingSync: serializer.fromJson<bool>(json['pendingSync']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      syncVersion: serializer.fromJson<int>(json['syncVersion']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientUuid': serializer.toJson<String>(clientUuid),
      'serverId': serializer.toJson<String?>(serverId),
      'lessonClientUuid': serializer.toJson<String>(lessonClientUuid),
      'title': serializer.toJson<String>(title),
      'position': serializer.toJson<int>(position),
      'pendingSync': serializer.toJson<bool>(pendingSync),
      'deleted': serializer.toJson<bool>(deleted),
      'syncVersion': serializer.toJson<int>(syncVersion),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Chapter copyWith({
    int? id,
    String? clientUuid,
    Value<String?> serverId = const Value.absent(),
    String? lessonClientUuid,
    String? title,
    int? position,
    bool? pendingSync,
    bool? deleted,
    int? syncVersion,
    DateTime? updatedAt,
  }) => Chapter(
    id: id ?? this.id,
    clientUuid: clientUuid ?? this.clientUuid,
    serverId: serverId.present ? serverId.value : this.serverId,
    lessonClientUuid: lessonClientUuid ?? this.lessonClientUuid,
    title: title ?? this.title,
    position: position ?? this.position,
    pendingSync: pendingSync ?? this.pendingSync,
    deleted: deleted ?? this.deleted,
    syncVersion: syncVersion ?? this.syncVersion,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Chapter copyWithCompanion(ChaptersCompanion data) {
    return Chapter(
      id: data.id.present ? data.id.value : this.id,
      clientUuid: data.clientUuid.present
          ? data.clientUuid.value
          : this.clientUuid,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      lessonClientUuid: data.lessonClientUuid.present
          ? data.lessonClientUuid.value
          : this.lessonClientUuid,
      title: data.title.present ? data.title.value : this.title,
      position: data.position.present ? data.position.value : this.position,
      pendingSync: data.pendingSync.present
          ? data.pendingSync.value
          : this.pendingSync,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      syncVersion: data.syncVersion.present
          ? data.syncVersion.value
          : this.syncVersion,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chapter(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('serverId: $serverId, ')
          ..write('lessonClientUuid: $lessonClientUuid, ')
          ..write('title: $title, ')
          ..write('position: $position, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('deleted: $deleted, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientUuid,
    serverId,
    lessonClientUuid,
    title,
    position,
    pendingSync,
    deleted,
    syncVersion,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chapter &&
          other.id == this.id &&
          other.clientUuid == this.clientUuid &&
          other.serverId == this.serverId &&
          other.lessonClientUuid == this.lessonClientUuid &&
          other.title == this.title &&
          other.position == this.position &&
          other.pendingSync == this.pendingSync &&
          other.deleted == this.deleted &&
          other.syncVersion == this.syncVersion &&
          other.updatedAt == this.updatedAt);
}

class ChaptersCompanion extends UpdateCompanion<Chapter> {
  final Value<int> id;
  final Value<String> clientUuid;
  final Value<String?> serverId;
  final Value<String> lessonClientUuid;
  final Value<String> title;
  final Value<int> position;
  final Value<bool> pendingSync;
  final Value<bool> deleted;
  final Value<int> syncVersion;
  final Value<DateTime> updatedAt;
  const ChaptersCompanion({
    this.id = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.serverId = const Value.absent(),
    this.lessonClientUuid = const Value.absent(),
    this.title = const Value.absent(),
    this.position = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.deleted = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ChaptersCompanion.insert({
    this.id = const Value.absent(),
    required String clientUuid,
    this.serverId = const Value.absent(),
    required String lessonClientUuid,
    required String title,
    this.position = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.deleted = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : clientUuid = Value(clientUuid),
       lessonClientUuid = Value(lessonClientUuid),
       title = Value(title);
  static Insertable<Chapter> custom({
    Expression<int>? id,
    Expression<String>? clientUuid,
    Expression<String>? serverId,
    Expression<String>? lessonClientUuid,
    Expression<String>? title,
    Expression<int>? position,
    Expression<bool>? pendingSync,
    Expression<bool>? deleted,
    Expression<int>? syncVersion,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientUuid != null) 'client_uuid': clientUuid,
      if (serverId != null) 'server_id': serverId,
      if (lessonClientUuid != null) 'lesson_client_uuid': lessonClientUuid,
      if (title != null) 'title': title,
      if (position != null) 'position': position,
      if (pendingSync != null) 'pending_sync': pendingSync,
      if (deleted != null) 'deleted': deleted,
      if (syncVersion != null) 'sync_version': syncVersion,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ChaptersCompanion copyWith({
    Value<int>? id,
    Value<String>? clientUuid,
    Value<String?>? serverId,
    Value<String>? lessonClientUuid,
    Value<String>? title,
    Value<int>? position,
    Value<bool>? pendingSync,
    Value<bool>? deleted,
    Value<int>? syncVersion,
    Value<DateTime>? updatedAt,
  }) {
    return ChaptersCompanion(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      serverId: serverId ?? this.serverId,
      lessonClientUuid: lessonClientUuid ?? this.lessonClientUuid,
      title: title ?? this.title,
      position: position ?? this.position,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
      syncVersion: syncVersion ?? this.syncVersion,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientUuid.present) {
      map['client_uuid'] = Variable<String>(clientUuid.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (lessonClientUuid.present) {
      map['lesson_client_uuid'] = Variable<String>(lessonClientUuid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (pendingSync.present) {
      map['pending_sync'] = Variable<bool>(pendingSync.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (syncVersion.present) {
      map['sync_version'] = Variable<int>(syncVersion.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChaptersCompanion(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('serverId: $serverId, ')
          ..write('lessonClientUuid: $lessonClientUuid, ')
          ..write('title: $title, ')
          ..write('position: $position, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('deleted: $deleted, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AgendaItemsTable extends AgendaItems
    with TableInfo<$AgendaItemsTable, AgendaItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgendaItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clientUuidMeta = const VerificationMeta(
    'clientUuid',
  );
  @override
  late final GeneratedColumn<String> clientUuid = GeneratedColumn<String>(
    'client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('course'),
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
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
  static const VerificationMeta _startsAtMeta = const VerificationMeta(
    'startsAt',
  );
  @override
  late final GeneratedColumn<DateTime> startsAt = GeneratedColumn<DateTime>(
    'starts_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endsAtMeta = const VerificationMeta('endsAt');
  @override
  late final GeneratedColumn<DateTime> endsAt = GeneratedColumn<DateTime>(
    'ends_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceMeta = const VerificationMeta(
    'recurrence',
  );
  @override
  late final GeneratedColumn<String> recurrence = GeneratedColumn<String>(
    'recurrence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _recurrenceUntilMeta = const VerificationMeta(
    'recurrenceUntil',
  );
  @override
  late final GeneratedColumn<DateTime> recurrenceUntil =
      GeneratedColumn<DateTime>(
        'recurrence_until',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _reminderMinutesMeta = const VerificationMeta(
    'reminderMinutes',
  );
  @override
  late final GeneratedColumn<int> reminderMinutes = GeneratedColumn<int>(
    'reminder_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chapterClientUuidMeta = const VerificationMeta(
    'chapterClientUuid',
  );
  @override
  late final GeneratedColumn<String> chapterClientUuid =
      GeneratedColumn<String>(
        'chapter_client_uuid',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pendingSyncMeta = const VerificationMeta(
    'pendingSync',
  );
  @override
  late final GeneratedColumn<bool> pendingSync = GeneratedColumn<bool>(
    'pending_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending_sync" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncVersionMeta = const VerificationMeta(
    'syncVersion',
  );
  @override
  late final GeneratedColumn<int> syncVersion = GeneratedColumn<int>(
    'sync_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientUuid,
    serverId,
    title,
    kind,
    subject,
    notes,
    location,
    startsAt,
    endsAt,
    recurrence,
    recurrenceUntil,
    reminderMinutes,
    chapterClientUuid,
    pendingSync,
    deleted,
    syncVersion,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agenda_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgendaItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_uuid')) {
      context.handle(
        _clientUuidMeta,
        clientUuid.isAcceptableOrUnknown(data['client_uuid']!, _clientUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_clientUuidMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('starts_at')) {
      context.handle(
        _startsAtMeta,
        startsAt.isAcceptableOrUnknown(data['starts_at']!, _startsAtMeta),
      );
    }
    if (data.containsKey('ends_at')) {
      context.handle(
        _endsAtMeta,
        endsAt.isAcceptableOrUnknown(data['ends_at']!, _endsAtMeta),
      );
    }
    if (data.containsKey('recurrence')) {
      context.handle(
        _recurrenceMeta,
        recurrence.isAcceptableOrUnknown(data['recurrence']!, _recurrenceMeta),
      );
    }
    if (data.containsKey('recurrence_until')) {
      context.handle(
        _recurrenceUntilMeta,
        recurrenceUntil.isAcceptableOrUnknown(
          data['recurrence_until']!,
          _recurrenceUntilMeta,
        ),
      );
    }
    if (data.containsKey('reminder_minutes')) {
      context.handle(
        _reminderMinutesMeta,
        reminderMinutes.isAcceptableOrUnknown(
          data['reminder_minutes']!,
          _reminderMinutesMeta,
        ),
      );
    }
    if (data.containsKey('chapter_client_uuid')) {
      context.handle(
        _chapterClientUuidMeta,
        chapterClientUuid.isAcceptableOrUnknown(
          data['chapter_client_uuid']!,
          _chapterClientUuidMeta,
        ),
      );
    }
    if (data.containsKey('pending_sync')) {
      context.handle(
        _pendingSyncMeta,
        pendingSync.isAcceptableOrUnknown(
          data['pending_sync']!,
          _pendingSyncMeta,
        ),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('sync_version')) {
      context.handle(
        _syncVersionMeta,
        syncVersion.isAcceptableOrUnknown(
          data['sync_version']!,
          _syncVersionMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AgendaItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgendaItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_uuid'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      startsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}starts_at'],
      ),
      endsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ends_at'],
      ),
      recurrence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence'],
      )!,
      recurrenceUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recurrence_until'],
      ),
      reminderMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minutes'],
      ),
      chapterClientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_client_uuid'],
      ),
      pendingSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending_sync'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      syncVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AgendaItemsTable createAlias(String alias) {
    return $AgendaItemsTable(attachedDatabase, alias);
  }
}

class AgendaItem extends DataClass implements Insertable<AgendaItem> {
  final int id;
  final String clientUuid;
  final String? serverId;
  final String title;

  /// course | revision | reminder
  final String kind;
  final String? subject;
  final String? notes;
  final String? location;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// none | weekly
  final String recurrence;
  final DateTime? recurrenceUntil;
  final int? reminderMinutes;
  final String? chapterClientUuid;
  final bool pendingSync;
  final bool deleted;
  final int syncVersion;
  final DateTime updatedAt;
  const AgendaItem({
    required this.id,
    required this.clientUuid,
    this.serverId,
    required this.title,
    required this.kind,
    this.subject,
    this.notes,
    this.location,
    this.startsAt,
    this.endsAt,
    required this.recurrence,
    this.recurrenceUntil,
    this.reminderMinutes,
    this.chapterClientUuid,
    required this.pendingSync,
    required this.deleted,
    required this.syncVersion,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_uuid'] = Variable<String>(clientUuid);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['title'] = Variable<String>(title);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || subject != null) {
      map['subject'] = Variable<String>(subject);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || startsAt != null) {
      map['starts_at'] = Variable<DateTime>(startsAt);
    }
    if (!nullToAbsent || endsAt != null) {
      map['ends_at'] = Variable<DateTime>(endsAt);
    }
    map['recurrence'] = Variable<String>(recurrence);
    if (!nullToAbsent || recurrenceUntil != null) {
      map['recurrence_until'] = Variable<DateTime>(recurrenceUntil);
    }
    if (!nullToAbsent || reminderMinutes != null) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes);
    }
    if (!nullToAbsent || chapterClientUuid != null) {
      map['chapter_client_uuid'] = Variable<String>(chapterClientUuid);
    }
    map['pending_sync'] = Variable<bool>(pendingSync);
    map['deleted'] = Variable<bool>(deleted);
    map['sync_version'] = Variable<int>(syncVersion);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AgendaItemsCompanion toCompanion(bool nullToAbsent) {
    return AgendaItemsCompanion(
      id: Value(id),
      clientUuid: Value(clientUuid),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      title: Value(title),
      kind: Value(kind),
      subject: subject == null && nullToAbsent
          ? const Value.absent()
          : Value(subject),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      startsAt: startsAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startsAt),
      endsAt: endsAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endsAt),
      recurrence: Value(recurrence),
      recurrenceUntil: recurrenceUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceUntil),
      reminderMinutes: reminderMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderMinutes),
      chapterClientUuid: chapterClientUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterClientUuid),
      pendingSync: Value(pendingSync),
      deleted: Value(deleted),
      syncVersion: Value(syncVersion),
      updatedAt: Value(updatedAt),
    );
  }

  factory AgendaItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgendaItem(
      id: serializer.fromJson<int>(json['id']),
      clientUuid: serializer.fromJson<String>(json['clientUuid']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      title: serializer.fromJson<String>(json['title']),
      kind: serializer.fromJson<String>(json['kind']),
      subject: serializer.fromJson<String?>(json['subject']),
      notes: serializer.fromJson<String?>(json['notes']),
      location: serializer.fromJson<String?>(json['location']),
      startsAt: serializer.fromJson<DateTime?>(json['startsAt']),
      endsAt: serializer.fromJson<DateTime?>(json['endsAt']),
      recurrence: serializer.fromJson<String>(json['recurrence']),
      recurrenceUntil: serializer.fromJson<DateTime?>(json['recurrenceUntil']),
      reminderMinutes: serializer.fromJson<int?>(json['reminderMinutes']),
      chapterClientUuid: serializer.fromJson<String?>(
        json['chapterClientUuid'],
      ),
      pendingSync: serializer.fromJson<bool>(json['pendingSync']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      syncVersion: serializer.fromJson<int>(json['syncVersion']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientUuid': serializer.toJson<String>(clientUuid),
      'serverId': serializer.toJson<String?>(serverId),
      'title': serializer.toJson<String>(title),
      'kind': serializer.toJson<String>(kind),
      'subject': serializer.toJson<String?>(subject),
      'notes': serializer.toJson<String?>(notes),
      'location': serializer.toJson<String?>(location),
      'startsAt': serializer.toJson<DateTime?>(startsAt),
      'endsAt': serializer.toJson<DateTime?>(endsAt),
      'recurrence': serializer.toJson<String>(recurrence),
      'recurrenceUntil': serializer.toJson<DateTime?>(recurrenceUntil),
      'reminderMinutes': serializer.toJson<int?>(reminderMinutes),
      'chapterClientUuid': serializer.toJson<String?>(chapterClientUuid),
      'pendingSync': serializer.toJson<bool>(pendingSync),
      'deleted': serializer.toJson<bool>(deleted),
      'syncVersion': serializer.toJson<int>(syncVersion),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AgendaItem copyWith({
    int? id,
    String? clientUuid,
    Value<String?> serverId = const Value.absent(),
    String? title,
    String? kind,
    Value<String?> subject = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> location = const Value.absent(),
    Value<DateTime?> startsAt = const Value.absent(),
    Value<DateTime?> endsAt = const Value.absent(),
    String? recurrence,
    Value<DateTime?> recurrenceUntil = const Value.absent(),
    Value<int?> reminderMinutes = const Value.absent(),
    Value<String?> chapterClientUuid = const Value.absent(),
    bool? pendingSync,
    bool? deleted,
    int? syncVersion,
    DateTime? updatedAt,
  }) => AgendaItem(
    id: id ?? this.id,
    clientUuid: clientUuid ?? this.clientUuid,
    serverId: serverId.present ? serverId.value : this.serverId,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    subject: subject.present ? subject.value : this.subject,
    notes: notes.present ? notes.value : this.notes,
    location: location.present ? location.value : this.location,
    startsAt: startsAt.present ? startsAt.value : this.startsAt,
    endsAt: endsAt.present ? endsAt.value : this.endsAt,
    recurrence: recurrence ?? this.recurrence,
    recurrenceUntil: recurrenceUntil.present
        ? recurrenceUntil.value
        : this.recurrenceUntil,
    reminderMinutes: reminderMinutes.present
        ? reminderMinutes.value
        : this.reminderMinutes,
    chapterClientUuid: chapterClientUuid.present
        ? chapterClientUuid.value
        : this.chapterClientUuid,
    pendingSync: pendingSync ?? this.pendingSync,
    deleted: deleted ?? this.deleted,
    syncVersion: syncVersion ?? this.syncVersion,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AgendaItem copyWithCompanion(AgendaItemsCompanion data) {
    return AgendaItem(
      id: data.id.present ? data.id.value : this.id,
      clientUuid: data.clientUuid.present
          ? data.clientUuid.value
          : this.clientUuid,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      title: data.title.present ? data.title.value : this.title,
      kind: data.kind.present ? data.kind.value : this.kind,
      subject: data.subject.present ? data.subject.value : this.subject,
      notes: data.notes.present ? data.notes.value : this.notes,
      location: data.location.present ? data.location.value : this.location,
      startsAt: data.startsAt.present ? data.startsAt.value : this.startsAt,
      endsAt: data.endsAt.present ? data.endsAt.value : this.endsAt,
      recurrence: data.recurrence.present
          ? data.recurrence.value
          : this.recurrence,
      recurrenceUntil: data.recurrenceUntil.present
          ? data.recurrenceUntil.value
          : this.recurrenceUntil,
      reminderMinutes: data.reminderMinutes.present
          ? data.reminderMinutes.value
          : this.reminderMinutes,
      chapterClientUuid: data.chapterClientUuid.present
          ? data.chapterClientUuid.value
          : this.chapterClientUuid,
      pendingSync: data.pendingSync.present
          ? data.pendingSync.value
          : this.pendingSync,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      syncVersion: data.syncVersion.present
          ? data.syncVersion.value
          : this.syncVersion,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgendaItem(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('serverId: $serverId, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('subject: $subject, ')
          ..write('notes: $notes, ')
          ..write('location: $location, ')
          ..write('startsAt: $startsAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('recurrence: $recurrence, ')
          ..write('recurrenceUntil: $recurrenceUntil, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('chapterClientUuid: $chapterClientUuid, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('deleted: $deleted, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientUuid,
    serverId,
    title,
    kind,
    subject,
    notes,
    location,
    startsAt,
    endsAt,
    recurrence,
    recurrenceUntil,
    reminderMinutes,
    chapterClientUuid,
    pendingSync,
    deleted,
    syncVersion,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgendaItem &&
          other.id == this.id &&
          other.clientUuid == this.clientUuid &&
          other.serverId == this.serverId &&
          other.title == this.title &&
          other.kind == this.kind &&
          other.subject == this.subject &&
          other.notes == this.notes &&
          other.location == this.location &&
          other.startsAt == this.startsAt &&
          other.endsAt == this.endsAt &&
          other.recurrence == this.recurrence &&
          other.recurrenceUntil == this.recurrenceUntil &&
          other.reminderMinutes == this.reminderMinutes &&
          other.chapterClientUuid == this.chapterClientUuid &&
          other.pendingSync == this.pendingSync &&
          other.deleted == this.deleted &&
          other.syncVersion == this.syncVersion &&
          other.updatedAt == this.updatedAt);
}

class AgendaItemsCompanion extends UpdateCompanion<AgendaItem> {
  final Value<int> id;
  final Value<String> clientUuid;
  final Value<String?> serverId;
  final Value<String> title;
  final Value<String> kind;
  final Value<String?> subject;
  final Value<String?> notes;
  final Value<String?> location;
  final Value<DateTime?> startsAt;
  final Value<DateTime?> endsAt;
  final Value<String> recurrence;
  final Value<DateTime?> recurrenceUntil;
  final Value<int?> reminderMinutes;
  final Value<String?> chapterClientUuid;
  final Value<bool> pendingSync;
  final Value<bool> deleted;
  final Value<int> syncVersion;
  final Value<DateTime> updatedAt;
  const AgendaItemsCompanion({
    this.id = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.serverId = const Value.absent(),
    this.title = const Value.absent(),
    this.kind = const Value.absent(),
    this.subject = const Value.absent(),
    this.notes = const Value.absent(),
    this.location = const Value.absent(),
    this.startsAt = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.recurrenceUntil = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.chapterClientUuid = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.deleted = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AgendaItemsCompanion.insert({
    this.id = const Value.absent(),
    required String clientUuid,
    this.serverId = const Value.absent(),
    required String title,
    this.kind = const Value.absent(),
    this.subject = const Value.absent(),
    this.notes = const Value.absent(),
    this.location = const Value.absent(),
    this.startsAt = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.recurrenceUntil = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.chapterClientUuid = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.deleted = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : clientUuid = Value(clientUuid),
       title = Value(title);
  static Insertable<AgendaItem> custom({
    Expression<int>? id,
    Expression<String>? clientUuid,
    Expression<String>? serverId,
    Expression<String>? title,
    Expression<String>? kind,
    Expression<String>? subject,
    Expression<String>? notes,
    Expression<String>? location,
    Expression<DateTime>? startsAt,
    Expression<DateTime>? endsAt,
    Expression<String>? recurrence,
    Expression<DateTime>? recurrenceUntil,
    Expression<int>? reminderMinutes,
    Expression<String>? chapterClientUuid,
    Expression<bool>? pendingSync,
    Expression<bool>? deleted,
    Expression<int>? syncVersion,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientUuid != null) 'client_uuid': clientUuid,
      if (serverId != null) 'server_id': serverId,
      if (title != null) 'title': title,
      if (kind != null) 'kind': kind,
      if (subject != null) 'subject': subject,
      if (notes != null) 'notes': notes,
      if (location != null) 'location': location,
      if (startsAt != null) 'starts_at': startsAt,
      if (endsAt != null) 'ends_at': endsAt,
      if (recurrence != null) 'recurrence': recurrence,
      if (recurrenceUntil != null) 'recurrence_until': recurrenceUntil,
      if (reminderMinutes != null) 'reminder_minutes': reminderMinutes,
      if (chapterClientUuid != null) 'chapter_client_uuid': chapterClientUuid,
      if (pendingSync != null) 'pending_sync': pendingSync,
      if (deleted != null) 'deleted': deleted,
      if (syncVersion != null) 'sync_version': syncVersion,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AgendaItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? clientUuid,
    Value<String?>? serverId,
    Value<String>? title,
    Value<String>? kind,
    Value<String?>? subject,
    Value<String?>? notes,
    Value<String?>? location,
    Value<DateTime?>? startsAt,
    Value<DateTime?>? endsAt,
    Value<String>? recurrence,
    Value<DateTime?>? recurrenceUntil,
    Value<int?>? reminderMinutes,
    Value<String?>? chapterClientUuid,
    Value<bool>? pendingSync,
    Value<bool>? deleted,
    Value<int>? syncVersion,
    Value<DateTime>? updatedAt,
  }) {
    return AgendaItemsCompanion(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      serverId: serverId ?? this.serverId,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      subject: subject ?? this.subject,
      notes: notes ?? this.notes,
      location: location ?? this.location,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      recurrence: recurrence ?? this.recurrence,
      recurrenceUntil: recurrenceUntil ?? this.recurrenceUntil,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      chapterClientUuid: chapterClientUuid ?? this.chapterClientUuid,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
      syncVersion: syncVersion ?? this.syncVersion,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientUuid.present) {
      map['client_uuid'] = Variable<String>(clientUuid.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (startsAt.present) {
      map['starts_at'] = Variable<DateTime>(startsAt.value);
    }
    if (endsAt.present) {
      map['ends_at'] = Variable<DateTime>(endsAt.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<String>(recurrence.value);
    }
    if (recurrenceUntil.present) {
      map['recurrence_until'] = Variable<DateTime>(recurrenceUntil.value);
    }
    if (reminderMinutes.present) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes.value);
    }
    if (chapterClientUuid.present) {
      map['chapter_client_uuid'] = Variable<String>(chapterClientUuid.value);
    }
    if (pendingSync.present) {
      map['pending_sync'] = Variable<bool>(pendingSync.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (syncVersion.present) {
      map['sync_version'] = Variable<int>(syncVersion.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgendaItemsCompanion(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('serverId: $serverId, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('subject: $subject, ')
          ..write('notes: $notes, ')
          ..write('location: $location, ')
          ..write('startsAt: $startsAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('recurrence: $recurrence, ')
          ..write('recurrenceUntil: $recurrenceUntil, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('chapterClientUuid: $chapterClientUuid, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('deleted: $deleted, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $RecordingsTable extends Recordings
    with TableInfo<$RecordingsTable, Recording> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordingsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clientUuidMeta = const VerificationMeta(
    'clientUuid',
  );
  @override
  late final GeneratedColumn<String> clientUuid = GeneratedColumn<String>(
    'client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _chapterClientUuidMeta = const VerificationMeta(
    'chapterClientUuid',
  );
  @override
  late final GeneratedColumn<String> chapterClientUuid =
      GeneratedColumn<String>(
        'chapter_client_uuid',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecsMeta = const VerificationMeta(
    'durationSecs',
  );
  @override
  late final GeneratedColumn<int> durationSecs = GeneratedColumn<int>(
    'duration_secs',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _uploadedBytesMeta = const VerificationMeta(
    'uploadedBytes',
  );
  @override
  late final GeneratedColumn<int> uploadedBytes = GeneratedColumn<int>(
    'uploaded_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverRecordingIdMeta = const VerificationMeta(
    'serverRecordingId',
  );
  @override
  late final GeneratedColumn<String> serverRecordingId =
      GeneratedColumn<String>(
        'server_recording_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pipelineStageMeta = const VerificationMeta(
    'pipelineStage',
  );
  @override
  late final GeneratedColumn<String> pipelineStage = GeneratedColumn<String>(
    'pipeline_stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('saved_local'),
  );
  static const VerificationMeta _progressPercentMeta = const VerificationMeta(
    'progressPercent',
  );
  @override
  late final GeneratedColumn<int> progressPercent = GeneratedColumn<int>(
    'progress_percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stageCurrentMeta = const VerificationMeta(
    'stageCurrent',
  );
  @override
  late final GeneratedColumn<int> stageCurrent = GeneratedColumn<int>(
    'stage_current',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stageTotalMeta = const VerificationMeta(
    'stageTotal',
  );
  @override
  late final GeneratedColumn<int> stageTotal = GeneratedColumn<int>(
    'stage_total',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMessageMeta = const VerificationMeta(
    'statusMessage',
  );
  @override
  late final GeneratedColumn<String> statusMessage = GeneratedColumn<String>(
    'status_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retryableMeta = const VerificationMeta(
    'retryable',
  );
  @override
  late final GeneratedColumn<bool> retryable = GeneratedColumn<bool>(
    'retryable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("retryable" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stageStartedAtMeta = const VerificationMeta(
    'stageStartedAt',
  );
  @override
  late final GeneratedColumn<DateTime> stageStartedAt =
      GeneratedColumn<DateTime>(
        'stage_started_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastProgressAtMeta = const VerificationMeta(
    'lastProgressAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastProgressAt =
      GeneratedColumn<DateTime>(
        'last_progress_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientUuid,
    chapterClientUuid,
    localPath,
    fileName,
    durationSecs,
    status,
    uploadedBytes,
    serverRecordingId,
    pipelineStage,
    progressPercent,
    stageCurrent,
    stageTotal,
    statusMessage,
    retryable,
    attemptCount,
    nextRetryAt,
    errorCode,
    stageStartedAt,
    lastProgressAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recordings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Recording> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_uuid')) {
      context.handle(
        _clientUuidMeta,
        clientUuid.isAcceptableOrUnknown(data['client_uuid']!, _clientUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_clientUuidMeta);
    }
    if (data.containsKey('chapter_client_uuid')) {
      context.handle(
        _chapterClientUuidMeta,
        chapterClientUuid.isAcceptableOrUnknown(
          data['chapter_client_uuid']!,
          _chapterClientUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterClientUuidMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    }
    if (data.containsKey('duration_secs')) {
      context.handle(
        _durationSecsMeta,
        durationSecs.isAcceptableOrUnknown(
          data['duration_secs']!,
          _durationSecsMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('uploaded_bytes')) {
      context.handle(
        _uploadedBytesMeta,
        uploadedBytes.isAcceptableOrUnknown(
          data['uploaded_bytes']!,
          _uploadedBytesMeta,
        ),
      );
    }
    if (data.containsKey('server_recording_id')) {
      context.handle(
        _serverRecordingIdMeta,
        serverRecordingId.isAcceptableOrUnknown(
          data['server_recording_id']!,
          _serverRecordingIdMeta,
        ),
      );
    }
    if (data.containsKey('pipeline_stage')) {
      context.handle(
        _pipelineStageMeta,
        pipelineStage.isAcceptableOrUnknown(
          data['pipeline_stage']!,
          _pipelineStageMeta,
        ),
      );
    }
    if (data.containsKey('progress_percent')) {
      context.handle(
        _progressPercentMeta,
        progressPercent.isAcceptableOrUnknown(
          data['progress_percent']!,
          _progressPercentMeta,
        ),
      );
    }
    if (data.containsKey('stage_current')) {
      context.handle(
        _stageCurrentMeta,
        stageCurrent.isAcceptableOrUnknown(
          data['stage_current']!,
          _stageCurrentMeta,
        ),
      );
    }
    if (data.containsKey('stage_total')) {
      context.handle(
        _stageTotalMeta,
        stageTotal.isAcceptableOrUnknown(data['stage_total']!, _stageTotalMeta),
      );
    }
    if (data.containsKey('status_message')) {
      context.handle(
        _statusMessageMeta,
        statusMessage.isAcceptableOrUnknown(
          data['status_message']!,
          _statusMessageMeta,
        ),
      );
    }
    if (data.containsKey('retryable')) {
      context.handle(
        _retryableMeta,
        retryable.isAcceptableOrUnknown(data['retryable']!, _retryableMeta),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('stage_started_at')) {
      context.handle(
        _stageStartedAtMeta,
        stageStartedAt.isAcceptableOrUnknown(
          data['stage_started_at']!,
          _stageStartedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_progress_at')) {
      context.handle(
        _lastProgressAtMeta,
        lastProgressAt.isAcceptableOrUnknown(
          data['last_progress_at']!,
          _lastProgressAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Recording map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Recording(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_uuid'],
      )!,
      chapterClientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_client_uuid'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      ),
      durationSecs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_secs'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      uploadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uploaded_bytes'],
      )!,
      serverRecordingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_recording_id'],
      ),
      pipelineStage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pipeline_stage'],
      )!,
      progressPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}progress_percent'],
      )!,
      stageCurrent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage_current'],
      ),
      stageTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage_total'],
      ),
      statusMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status_message'],
      ),
      retryable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}retryable'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_retry_at'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      stageStartedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}stage_started_at'],
      ),
      lastProgressAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_progress_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RecordingsTable createAlias(String alias) {
    return $RecordingsTable(attachedDatabase, alias);
  }
}

class Recording extends DataClass implements Insertable<Recording> {
  final int id;
  final String clientUuid;
  final String chapterClientUuid;
  final String localPath;
  final String? fileName;
  final int? durationSecs;

  /// local_only | pending_sync | uploading | synced | processing | ready | failed
  final String status;
  final int uploadedBytes;
  final String? serverRecordingId;
  final String pipelineStage;
  final int progressPercent;
  final int? stageCurrent;
  final int? stageTotal;
  final String? statusMessage;
  final bool retryable;
  final int attemptCount;
  final DateTime? nextRetryAt;
  final String? errorCode;
  final DateTime? stageStartedAt;
  final DateTime? lastProgressAt;
  final DateTime createdAt;
  const Recording({
    required this.id,
    required this.clientUuid,
    required this.chapterClientUuid,
    required this.localPath,
    this.fileName,
    this.durationSecs,
    required this.status,
    required this.uploadedBytes,
    this.serverRecordingId,
    required this.pipelineStage,
    required this.progressPercent,
    this.stageCurrent,
    this.stageTotal,
    this.statusMessage,
    required this.retryable,
    required this.attemptCount,
    this.nextRetryAt,
    this.errorCode,
    this.stageStartedAt,
    this.lastProgressAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_uuid'] = Variable<String>(clientUuid);
    map['chapter_client_uuid'] = Variable<String>(chapterClientUuid);
    map['local_path'] = Variable<String>(localPath);
    if (!nullToAbsent || fileName != null) {
      map['file_name'] = Variable<String>(fileName);
    }
    if (!nullToAbsent || durationSecs != null) {
      map['duration_secs'] = Variable<int>(durationSecs);
    }
    map['status'] = Variable<String>(status);
    map['uploaded_bytes'] = Variable<int>(uploadedBytes);
    if (!nullToAbsent || serverRecordingId != null) {
      map['server_recording_id'] = Variable<String>(serverRecordingId);
    }
    map['pipeline_stage'] = Variable<String>(pipelineStage);
    map['progress_percent'] = Variable<int>(progressPercent);
    if (!nullToAbsent || stageCurrent != null) {
      map['stage_current'] = Variable<int>(stageCurrent);
    }
    if (!nullToAbsent || stageTotal != null) {
      map['stage_total'] = Variable<int>(stageTotal);
    }
    if (!nullToAbsent || statusMessage != null) {
      map['status_message'] = Variable<String>(statusMessage);
    }
    map['retryable'] = Variable<bool>(retryable);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || stageStartedAt != null) {
      map['stage_started_at'] = Variable<DateTime>(stageStartedAt);
    }
    if (!nullToAbsent || lastProgressAt != null) {
      map['last_progress_at'] = Variable<DateTime>(lastProgressAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RecordingsCompanion toCompanion(bool nullToAbsent) {
    return RecordingsCompanion(
      id: Value(id),
      clientUuid: Value(clientUuid),
      chapterClientUuid: Value(chapterClientUuid),
      localPath: Value(localPath),
      fileName: fileName == null && nullToAbsent
          ? const Value.absent()
          : Value(fileName),
      durationSecs: durationSecs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSecs),
      status: Value(status),
      uploadedBytes: Value(uploadedBytes),
      serverRecordingId: serverRecordingId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverRecordingId),
      pipelineStage: Value(pipelineStage),
      progressPercent: Value(progressPercent),
      stageCurrent: stageCurrent == null && nullToAbsent
          ? const Value.absent()
          : Value(stageCurrent),
      stageTotal: stageTotal == null && nullToAbsent
          ? const Value.absent()
          : Value(stageTotal),
      statusMessage: statusMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(statusMessage),
      retryable: Value(retryable),
      attemptCount: Value(attemptCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      stageStartedAt: stageStartedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(stageStartedAt),
      lastProgressAt: lastProgressAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastProgressAt),
      createdAt: Value(createdAt),
    );
  }

  factory Recording.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Recording(
      id: serializer.fromJson<int>(json['id']),
      clientUuid: serializer.fromJson<String>(json['clientUuid']),
      chapterClientUuid: serializer.fromJson<String>(json['chapterClientUuid']),
      localPath: serializer.fromJson<String>(json['localPath']),
      fileName: serializer.fromJson<String?>(json['fileName']),
      durationSecs: serializer.fromJson<int?>(json['durationSecs']),
      status: serializer.fromJson<String>(json['status']),
      uploadedBytes: serializer.fromJson<int>(json['uploadedBytes']),
      serverRecordingId: serializer.fromJson<String?>(
        json['serverRecordingId'],
      ),
      pipelineStage: serializer.fromJson<String>(json['pipelineStage']),
      progressPercent: serializer.fromJson<int>(json['progressPercent']),
      stageCurrent: serializer.fromJson<int?>(json['stageCurrent']),
      stageTotal: serializer.fromJson<int?>(json['stageTotal']),
      statusMessage: serializer.fromJson<String?>(json['statusMessage']),
      retryable: serializer.fromJson<bool>(json['retryable']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      stageStartedAt: serializer.fromJson<DateTime?>(json['stageStartedAt']),
      lastProgressAt: serializer.fromJson<DateTime?>(json['lastProgressAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientUuid': serializer.toJson<String>(clientUuid),
      'chapterClientUuid': serializer.toJson<String>(chapterClientUuid),
      'localPath': serializer.toJson<String>(localPath),
      'fileName': serializer.toJson<String?>(fileName),
      'durationSecs': serializer.toJson<int?>(durationSecs),
      'status': serializer.toJson<String>(status),
      'uploadedBytes': serializer.toJson<int>(uploadedBytes),
      'serverRecordingId': serializer.toJson<String?>(serverRecordingId),
      'pipelineStage': serializer.toJson<String>(pipelineStage),
      'progressPercent': serializer.toJson<int>(progressPercent),
      'stageCurrent': serializer.toJson<int?>(stageCurrent),
      'stageTotal': serializer.toJson<int?>(stageTotal),
      'statusMessage': serializer.toJson<String?>(statusMessage),
      'retryable': serializer.toJson<bool>(retryable),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'errorCode': serializer.toJson<String?>(errorCode),
      'stageStartedAt': serializer.toJson<DateTime?>(stageStartedAt),
      'lastProgressAt': serializer.toJson<DateTime?>(lastProgressAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Recording copyWith({
    int? id,
    String? clientUuid,
    String? chapterClientUuid,
    String? localPath,
    Value<String?> fileName = const Value.absent(),
    Value<int?> durationSecs = const Value.absent(),
    String? status,
    int? uploadedBytes,
    Value<String?> serverRecordingId = const Value.absent(),
    String? pipelineStage,
    int? progressPercent,
    Value<int?> stageCurrent = const Value.absent(),
    Value<int?> stageTotal = const Value.absent(),
    Value<String?> statusMessage = const Value.absent(),
    bool? retryable,
    int? attemptCount,
    Value<DateTime?> nextRetryAt = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
    Value<DateTime?> stageStartedAt = const Value.absent(),
    Value<DateTime?> lastProgressAt = const Value.absent(),
    DateTime? createdAt,
  }) => Recording(
    id: id ?? this.id,
    clientUuid: clientUuid ?? this.clientUuid,
    chapterClientUuid: chapterClientUuid ?? this.chapterClientUuid,
    localPath: localPath ?? this.localPath,
    fileName: fileName.present ? fileName.value : this.fileName,
    durationSecs: durationSecs.present ? durationSecs.value : this.durationSecs,
    status: status ?? this.status,
    uploadedBytes: uploadedBytes ?? this.uploadedBytes,
    serverRecordingId: serverRecordingId.present
        ? serverRecordingId.value
        : this.serverRecordingId,
    pipelineStage: pipelineStage ?? this.pipelineStage,
    progressPercent: progressPercent ?? this.progressPercent,
    stageCurrent: stageCurrent.present ? stageCurrent.value : this.stageCurrent,
    stageTotal: stageTotal.present ? stageTotal.value : this.stageTotal,
    statusMessage: statusMessage.present
        ? statusMessage.value
        : this.statusMessage,
    retryable: retryable ?? this.retryable,
    attemptCount: attemptCount ?? this.attemptCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    stageStartedAt: stageStartedAt.present
        ? stageStartedAt.value
        : this.stageStartedAt,
    lastProgressAt: lastProgressAt.present
        ? lastProgressAt.value
        : this.lastProgressAt,
    createdAt: createdAt ?? this.createdAt,
  );
  Recording copyWithCompanion(RecordingsCompanion data) {
    return Recording(
      id: data.id.present ? data.id.value : this.id,
      clientUuid: data.clientUuid.present
          ? data.clientUuid.value
          : this.clientUuid,
      chapterClientUuid: data.chapterClientUuid.present
          ? data.chapterClientUuid.value
          : this.chapterClientUuid,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      durationSecs: data.durationSecs.present
          ? data.durationSecs.value
          : this.durationSecs,
      status: data.status.present ? data.status.value : this.status,
      uploadedBytes: data.uploadedBytes.present
          ? data.uploadedBytes.value
          : this.uploadedBytes,
      serverRecordingId: data.serverRecordingId.present
          ? data.serverRecordingId.value
          : this.serverRecordingId,
      pipelineStage: data.pipelineStage.present
          ? data.pipelineStage.value
          : this.pipelineStage,
      progressPercent: data.progressPercent.present
          ? data.progressPercent.value
          : this.progressPercent,
      stageCurrent: data.stageCurrent.present
          ? data.stageCurrent.value
          : this.stageCurrent,
      stageTotal: data.stageTotal.present
          ? data.stageTotal.value
          : this.stageTotal,
      statusMessage: data.statusMessage.present
          ? data.statusMessage.value
          : this.statusMessage,
      retryable: data.retryable.present ? data.retryable.value : this.retryable,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      stageStartedAt: data.stageStartedAt.present
          ? data.stageStartedAt.value
          : this.stageStartedAt,
      lastProgressAt: data.lastProgressAt.present
          ? data.lastProgressAt.value
          : this.lastProgressAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Recording(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('chapterClientUuid: $chapterClientUuid, ')
          ..write('localPath: $localPath, ')
          ..write('fileName: $fileName, ')
          ..write('durationSecs: $durationSecs, ')
          ..write('status: $status, ')
          ..write('uploadedBytes: $uploadedBytes, ')
          ..write('serverRecordingId: $serverRecordingId, ')
          ..write('pipelineStage: $pipelineStage, ')
          ..write('progressPercent: $progressPercent, ')
          ..write('stageCurrent: $stageCurrent, ')
          ..write('stageTotal: $stageTotal, ')
          ..write('statusMessage: $statusMessage, ')
          ..write('retryable: $retryable, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('errorCode: $errorCode, ')
          ..write('stageStartedAt: $stageStartedAt, ')
          ..write('lastProgressAt: $lastProgressAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    clientUuid,
    chapterClientUuid,
    localPath,
    fileName,
    durationSecs,
    status,
    uploadedBytes,
    serverRecordingId,
    pipelineStage,
    progressPercent,
    stageCurrent,
    stageTotal,
    statusMessage,
    retryable,
    attemptCount,
    nextRetryAt,
    errorCode,
    stageStartedAt,
    lastProgressAt,
    createdAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Recording &&
          other.id == this.id &&
          other.clientUuid == this.clientUuid &&
          other.chapterClientUuid == this.chapterClientUuid &&
          other.localPath == this.localPath &&
          other.fileName == this.fileName &&
          other.durationSecs == this.durationSecs &&
          other.status == this.status &&
          other.uploadedBytes == this.uploadedBytes &&
          other.serverRecordingId == this.serverRecordingId &&
          other.pipelineStage == this.pipelineStage &&
          other.progressPercent == this.progressPercent &&
          other.stageCurrent == this.stageCurrent &&
          other.stageTotal == this.stageTotal &&
          other.statusMessage == this.statusMessage &&
          other.retryable == this.retryable &&
          other.attemptCount == this.attemptCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.errorCode == this.errorCode &&
          other.stageStartedAt == this.stageStartedAt &&
          other.lastProgressAt == this.lastProgressAt &&
          other.createdAt == this.createdAt);
}

class RecordingsCompanion extends UpdateCompanion<Recording> {
  final Value<int> id;
  final Value<String> clientUuid;
  final Value<String> chapterClientUuid;
  final Value<String> localPath;
  final Value<String?> fileName;
  final Value<int?> durationSecs;
  final Value<String> status;
  final Value<int> uploadedBytes;
  final Value<String?> serverRecordingId;
  final Value<String> pipelineStage;
  final Value<int> progressPercent;
  final Value<int?> stageCurrent;
  final Value<int?> stageTotal;
  final Value<String?> statusMessage;
  final Value<bool> retryable;
  final Value<int> attemptCount;
  final Value<DateTime?> nextRetryAt;
  final Value<String?> errorCode;
  final Value<DateTime?> stageStartedAt;
  final Value<DateTime?> lastProgressAt;
  final Value<DateTime> createdAt;
  const RecordingsCompanion({
    this.id = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.chapterClientUuid = const Value.absent(),
    this.localPath = const Value.absent(),
    this.fileName = const Value.absent(),
    this.durationSecs = const Value.absent(),
    this.status = const Value.absent(),
    this.uploadedBytes = const Value.absent(),
    this.serverRecordingId = const Value.absent(),
    this.pipelineStage = const Value.absent(),
    this.progressPercent = const Value.absent(),
    this.stageCurrent = const Value.absent(),
    this.stageTotal = const Value.absent(),
    this.statusMessage = const Value.absent(),
    this.retryable = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.stageStartedAt = const Value.absent(),
    this.lastProgressAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  RecordingsCompanion.insert({
    this.id = const Value.absent(),
    required String clientUuid,
    required String chapterClientUuid,
    required String localPath,
    this.fileName = const Value.absent(),
    this.durationSecs = const Value.absent(),
    this.status = const Value.absent(),
    this.uploadedBytes = const Value.absent(),
    this.serverRecordingId = const Value.absent(),
    this.pipelineStage = const Value.absent(),
    this.progressPercent = const Value.absent(),
    this.stageCurrent = const Value.absent(),
    this.stageTotal = const Value.absent(),
    this.statusMessage = const Value.absent(),
    this.retryable = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.stageStartedAt = const Value.absent(),
    this.lastProgressAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : clientUuid = Value(clientUuid),
       chapterClientUuid = Value(chapterClientUuid),
       localPath = Value(localPath);
  static Insertable<Recording> custom({
    Expression<int>? id,
    Expression<String>? clientUuid,
    Expression<String>? chapterClientUuid,
    Expression<String>? localPath,
    Expression<String>? fileName,
    Expression<int>? durationSecs,
    Expression<String>? status,
    Expression<int>? uploadedBytes,
    Expression<String>? serverRecordingId,
    Expression<String>? pipelineStage,
    Expression<int>? progressPercent,
    Expression<int>? stageCurrent,
    Expression<int>? stageTotal,
    Expression<String>? statusMessage,
    Expression<bool>? retryable,
    Expression<int>? attemptCount,
    Expression<DateTime>? nextRetryAt,
    Expression<String>? errorCode,
    Expression<DateTime>? stageStartedAt,
    Expression<DateTime>? lastProgressAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientUuid != null) 'client_uuid': clientUuid,
      if (chapterClientUuid != null) 'chapter_client_uuid': chapterClientUuid,
      if (localPath != null) 'local_path': localPath,
      if (fileName != null) 'file_name': fileName,
      if (durationSecs != null) 'duration_secs': durationSecs,
      if (status != null) 'status': status,
      if (uploadedBytes != null) 'uploaded_bytes': uploadedBytes,
      if (serverRecordingId != null) 'server_recording_id': serverRecordingId,
      if (pipelineStage != null) 'pipeline_stage': pipelineStage,
      if (progressPercent != null) 'progress_percent': progressPercent,
      if (stageCurrent != null) 'stage_current': stageCurrent,
      if (stageTotal != null) 'stage_total': stageTotal,
      if (statusMessage != null) 'status_message': statusMessage,
      if (retryable != null) 'retryable': retryable,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (errorCode != null) 'error_code': errorCode,
      if (stageStartedAt != null) 'stage_started_at': stageStartedAt,
      if (lastProgressAt != null) 'last_progress_at': lastProgressAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  RecordingsCompanion copyWith({
    Value<int>? id,
    Value<String>? clientUuid,
    Value<String>? chapterClientUuid,
    Value<String>? localPath,
    Value<String?>? fileName,
    Value<int?>? durationSecs,
    Value<String>? status,
    Value<int>? uploadedBytes,
    Value<String?>? serverRecordingId,
    Value<String>? pipelineStage,
    Value<int>? progressPercent,
    Value<int?>? stageCurrent,
    Value<int?>? stageTotal,
    Value<String?>? statusMessage,
    Value<bool>? retryable,
    Value<int>? attemptCount,
    Value<DateTime?>? nextRetryAt,
    Value<String?>? errorCode,
    Value<DateTime?>? stageStartedAt,
    Value<DateTime?>? lastProgressAt,
    Value<DateTime>? createdAt,
  }) {
    return RecordingsCompanion(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      chapterClientUuid: chapterClientUuid ?? this.chapterClientUuid,
      localPath: localPath ?? this.localPath,
      fileName: fileName ?? this.fileName,
      durationSecs: durationSecs ?? this.durationSecs,
      status: status ?? this.status,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      serverRecordingId: serverRecordingId ?? this.serverRecordingId,
      pipelineStage: pipelineStage ?? this.pipelineStage,
      progressPercent: progressPercent ?? this.progressPercent,
      stageCurrent: stageCurrent ?? this.stageCurrent,
      stageTotal: stageTotal ?? this.stageTotal,
      statusMessage: statusMessage ?? this.statusMessage,
      retryable: retryable ?? this.retryable,
      attemptCount: attemptCount ?? this.attemptCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      errorCode: errorCode ?? this.errorCode,
      stageStartedAt: stageStartedAt ?? this.stageStartedAt,
      lastProgressAt: lastProgressAt ?? this.lastProgressAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientUuid.present) {
      map['client_uuid'] = Variable<String>(clientUuid.value);
    }
    if (chapterClientUuid.present) {
      map['chapter_client_uuid'] = Variable<String>(chapterClientUuid.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (durationSecs.present) {
      map['duration_secs'] = Variable<int>(durationSecs.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (uploadedBytes.present) {
      map['uploaded_bytes'] = Variable<int>(uploadedBytes.value);
    }
    if (serverRecordingId.present) {
      map['server_recording_id'] = Variable<String>(serverRecordingId.value);
    }
    if (pipelineStage.present) {
      map['pipeline_stage'] = Variable<String>(pipelineStage.value);
    }
    if (progressPercent.present) {
      map['progress_percent'] = Variable<int>(progressPercent.value);
    }
    if (stageCurrent.present) {
      map['stage_current'] = Variable<int>(stageCurrent.value);
    }
    if (stageTotal.present) {
      map['stage_total'] = Variable<int>(stageTotal.value);
    }
    if (statusMessage.present) {
      map['status_message'] = Variable<String>(statusMessage.value);
    }
    if (retryable.present) {
      map['retryable'] = Variable<bool>(retryable.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (stageStartedAt.present) {
      map['stage_started_at'] = Variable<DateTime>(stageStartedAt.value);
    }
    if (lastProgressAt.present) {
      map['last_progress_at'] = Variable<DateTime>(lastProgressAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordingsCompanion(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('chapterClientUuid: $chapterClientUuid, ')
          ..write('localPath: $localPath, ')
          ..write('fileName: $fileName, ')
          ..write('durationSecs: $durationSecs, ')
          ..write('status: $status, ')
          ..write('uploadedBytes: $uploadedBytes, ')
          ..write('serverRecordingId: $serverRecordingId, ')
          ..write('pipelineStage: $pipelineStage, ')
          ..write('progressPercent: $progressPercent, ')
          ..write('stageCurrent: $stageCurrent, ')
          ..write('stageTotal: $stageTotal, ')
          ..write('statusMessage: $statusMessage, ')
          ..write('retryable: $retryable, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('errorCode: $errorCode, ')
          ..write('stageStartedAt: $stageStartedAt, ')
          ..write('lastProgressAt: $lastProgressAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TranscriptsTable extends Transcripts
    with TableInfo<$TranscriptsTable, Transcript> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _recordingServerIdMeta = const VerificationMeta(
    'recordingServerId',
  );
  @override
  late final GeneratedColumn<String> recordingServerId =
      GeneratedColumn<String>(
        'recording_server_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _recordingClientUuidMeta =
      const VerificationMeta('recordingClientUuid');
  @override
  late final GeneratedColumn<String> recordingClientUuid =
      GeneratedColumn<String>(
        'recording_client_uuid',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
      );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _segmentsJsonMeta = const VerificationMeta(
    'segmentsJson',
  );
  @override
  late final GeneratedColumn<String> segmentsJson = GeneratedColumn<String>(
    'segments_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _syncVersionMeta = const VerificationMeta(
    'syncVersion',
  );
  @override
  late final GeneratedColumn<int> syncVersion = GeneratedColumn<int>(
    'sync_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    recordingServerId,
    recordingClientUuid,
    content,
    language,
    segmentsJson,
    syncVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcripts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transcript> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('recording_server_id')) {
      context.handle(
        _recordingServerIdMeta,
        recordingServerId.isAcceptableOrUnknown(
          data['recording_server_id']!,
          _recordingServerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordingServerIdMeta);
    }
    if (data.containsKey('recording_client_uuid')) {
      context.handle(
        _recordingClientUuidMeta,
        recordingClientUuid.isAcceptableOrUnknown(
          data['recording_client_uuid']!,
          _recordingClientUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordingClientUuidMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('segments_json')) {
      context.handle(
        _segmentsJsonMeta,
        segmentsJson.isAcceptableOrUnknown(
          data['segments_json']!,
          _segmentsJsonMeta,
        ),
      );
    }
    if (data.containsKey('sync_version')) {
      context.handle(
        _syncVersionMeta,
        syncVersion.isAcceptableOrUnknown(
          data['sync_version']!,
          _syncVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transcript map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transcript(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      recordingServerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_server_id'],
      )!,
      recordingClientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_client_uuid'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      segmentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segments_json'],
      )!,
      syncVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_version'],
      )!,
    );
  }

  @override
  $TranscriptsTable createAlias(String alias) {
    return $TranscriptsTable(attachedDatabase, alias);
  }
}

class Transcript extends DataClass implements Insertable<Transcript> {
  final int id;
  final String serverId;
  final String recordingServerId;
  final String recordingClientUuid;
  final String content;
  final String? language;
  final String segmentsJson;
  final int syncVersion;
  const Transcript({
    required this.id,
    required this.serverId,
    required this.recordingServerId,
    required this.recordingClientUuid,
    required this.content,
    this.language,
    required this.segmentsJson,
    required this.syncVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['server_id'] = Variable<String>(serverId);
    map['recording_server_id'] = Variable<String>(recordingServerId);
    map['recording_client_uuid'] = Variable<String>(recordingClientUuid);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    map['segments_json'] = Variable<String>(segmentsJson);
    map['sync_version'] = Variable<int>(syncVersion);
    return map;
  }

  TranscriptsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptsCompanion(
      id: Value(id),
      serverId: Value(serverId),
      recordingServerId: Value(recordingServerId),
      recordingClientUuid: Value(recordingClientUuid),
      content: Value(content),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      segmentsJson: Value(segmentsJson),
      syncVersion: Value(syncVersion),
    );
  }

  factory Transcript.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transcript(
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<String>(json['serverId']),
      recordingServerId: serializer.fromJson<String>(json['recordingServerId']),
      recordingClientUuid: serializer.fromJson<String>(
        json['recordingClientUuid'],
      ),
      content: serializer.fromJson<String>(json['content']),
      language: serializer.fromJson<String?>(json['language']),
      segmentsJson: serializer.fromJson<String>(json['segmentsJson']),
      syncVersion: serializer.fromJson<int>(json['syncVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<String>(serverId),
      'recordingServerId': serializer.toJson<String>(recordingServerId),
      'recordingClientUuid': serializer.toJson<String>(recordingClientUuid),
      'content': serializer.toJson<String>(content),
      'language': serializer.toJson<String?>(language),
      'segmentsJson': serializer.toJson<String>(segmentsJson),
      'syncVersion': serializer.toJson<int>(syncVersion),
    };
  }

  Transcript copyWith({
    int? id,
    String? serverId,
    String? recordingServerId,
    String? recordingClientUuid,
    String? content,
    Value<String?> language = const Value.absent(),
    String? segmentsJson,
    int? syncVersion,
  }) => Transcript(
    id: id ?? this.id,
    serverId: serverId ?? this.serverId,
    recordingServerId: recordingServerId ?? this.recordingServerId,
    recordingClientUuid: recordingClientUuid ?? this.recordingClientUuid,
    content: content ?? this.content,
    language: language.present ? language.value : this.language,
    segmentsJson: segmentsJson ?? this.segmentsJson,
    syncVersion: syncVersion ?? this.syncVersion,
  );
  Transcript copyWithCompanion(TranscriptsCompanion data) {
    return Transcript(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      recordingServerId: data.recordingServerId.present
          ? data.recordingServerId.value
          : this.recordingServerId,
      recordingClientUuid: data.recordingClientUuid.present
          ? data.recordingClientUuid.value
          : this.recordingClientUuid,
      content: data.content.present ? data.content.value : this.content,
      language: data.language.present ? data.language.value : this.language,
      segmentsJson: data.segmentsJson.present
          ? data.segmentsJson.value
          : this.segmentsJson,
      syncVersion: data.syncVersion.present
          ? data.syncVersion.value
          : this.syncVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transcript(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('recordingServerId: $recordingServerId, ')
          ..write('recordingClientUuid: $recordingClientUuid, ')
          ..write('content: $content, ')
          ..write('language: $language, ')
          ..write('segmentsJson: $segmentsJson, ')
          ..write('syncVersion: $syncVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    recordingServerId,
    recordingClientUuid,
    content,
    language,
    segmentsJson,
    syncVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transcript &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.recordingServerId == this.recordingServerId &&
          other.recordingClientUuid == this.recordingClientUuid &&
          other.content == this.content &&
          other.language == this.language &&
          other.segmentsJson == this.segmentsJson &&
          other.syncVersion == this.syncVersion);
}

class TranscriptsCompanion extends UpdateCompanion<Transcript> {
  final Value<int> id;
  final Value<String> serverId;
  final Value<String> recordingServerId;
  final Value<String> recordingClientUuid;
  final Value<String> content;
  final Value<String?> language;
  final Value<String> segmentsJson;
  final Value<int> syncVersion;
  const TranscriptsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.recordingServerId = const Value.absent(),
    this.recordingClientUuid = const Value.absent(),
    this.content = const Value.absent(),
    this.language = const Value.absent(),
    this.segmentsJson = const Value.absent(),
    this.syncVersion = const Value.absent(),
  });
  TranscriptsCompanion.insert({
    this.id = const Value.absent(),
    required String serverId,
    required String recordingServerId,
    required String recordingClientUuid,
    required String content,
    this.language = const Value.absent(),
    this.segmentsJson = const Value.absent(),
    this.syncVersion = const Value.absent(),
  }) : serverId = Value(serverId),
       recordingServerId = Value(recordingServerId),
       recordingClientUuid = Value(recordingClientUuid),
       content = Value(content);
  static Insertable<Transcript> custom({
    Expression<int>? id,
    Expression<String>? serverId,
    Expression<String>? recordingServerId,
    Expression<String>? recordingClientUuid,
    Expression<String>? content,
    Expression<String>? language,
    Expression<String>? segmentsJson,
    Expression<int>? syncVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (recordingServerId != null) 'recording_server_id': recordingServerId,
      if (recordingClientUuid != null)
        'recording_client_uuid': recordingClientUuid,
      if (content != null) 'content': content,
      if (language != null) 'language': language,
      if (segmentsJson != null) 'segments_json': segmentsJson,
      if (syncVersion != null) 'sync_version': syncVersion,
    });
  }

  TranscriptsCompanion copyWith({
    Value<int>? id,
    Value<String>? serverId,
    Value<String>? recordingServerId,
    Value<String>? recordingClientUuid,
    Value<String>? content,
    Value<String?>? language,
    Value<String>? segmentsJson,
    Value<int>? syncVersion,
  }) {
    return TranscriptsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      recordingServerId: recordingServerId ?? this.recordingServerId,
      recordingClientUuid: recordingClientUuid ?? this.recordingClientUuid,
      content: content ?? this.content,
      language: language ?? this.language,
      segmentsJson: segmentsJson ?? this.segmentsJson,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (recordingServerId.present) {
      map['recording_server_id'] = Variable<String>(recordingServerId.value);
    }
    if (recordingClientUuid.present) {
      map['recording_client_uuid'] = Variable<String>(
        recordingClientUuid.value,
      );
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (segmentsJson.present) {
      map['segments_json'] = Variable<String>(segmentsJson.value);
    }
    if (syncVersion.present) {
      map['sync_version'] = Variable<int>(syncVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('recordingServerId: $recordingServerId, ')
          ..write('recordingClientUuid: $recordingClientUuid, ')
          ..write('content: $content, ')
          ..write('language: $language, ')
          ..write('segmentsJson: $segmentsJson, ')
          ..write('syncVersion: $syncVersion')
          ..write(')'))
        .toString();
  }
}

class $SummariesTable extends Summaries
    with TableInfo<$SummariesTable, Summary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SummariesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordingServerIdMeta = const VerificationMeta(
    'recordingServerId',
  );
  @override
  late final GeneratedColumn<String> recordingServerId =
      GeneratedColumn<String>(
        'recording_server_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _generationIdMeta = const VerificationMeta(
    'generationId',
  );
  @override
  late final GeneratedColumn<String> generationId = GeneratedColumn<String>(
    'generation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chapterClientUuidMeta = const VerificationMeta(
    'chapterClientUuid',
  );
  @override
  late final GeneratedColumn<String> chapterClientUuid =
      GeneratedColumn<String>(
        'chapter_client_uuid',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _contentMdMeta = const VerificationMeta(
    'contentMd',
  );
  @override
  late final GeneratedColumn<String> contentMd = GeneratedColumn<String>(
    'content_md',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _structuredJsonMeta = const VerificationMeta(
    'structuredJson',
  );
  @override
  late final GeneratedColumn<String> structuredJson = GeneratedColumn<String>(
    'structured_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending_review'),
  );
  static const VerificationMeta _syncVersionMeta = const VerificationMeta(
    'syncVersion',
  );
  @override
  late final GeneratedColumn<int> syncVersion = GeneratedColumn<int>(
    'sync_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    recordingServerId,
    generationId,
    chapterClientUuid,
    contentMd,
    structuredJson,
    status,
    syncVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Summary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('recording_server_id')) {
      context.handle(
        _recordingServerIdMeta,
        recordingServerId.isAcceptableOrUnknown(
          data['recording_server_id']!,
          _recordingServerIdMeta,
        ),
      );
    }
    if (data.containsKey('generation_id')) {
      context.handle(
        _generationIdMeta,
        generationId.isAcceptableOrUnknown(
          data['generation_id']!,
          _generationIdMeta,
        ),
      );
    }
    if (data.containsKey('chapter_client_uuid')) {
      context.handle(
        _chapterClientUuidMeta,
        chapterClientUuid.isAcceptableOrUnknown(
          data['chapter_client_uuid']!,
          _chapterClientUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterClientUuidMeta);
    }
    if (data.containsKey('content_md')) {
      context.handle(
        _contentMdMeta,
        contentMd.isAcceptableOrUnknown(data['content_md']!, _contentMdMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMdMeta);
    }
    if (data.containsKey('structured_json')) {
      context.handle(
        _structuredJsonMeta,
        structuredJson.isAcceptableOrUnknown(
          data['structured_json']!,
          _structuredJsonMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('sync_version')) {
      context.handle(
        _syncVersionMeta,
        syncVersion.isAcceptableOrUnknown(
          data['sync_version']!,
          _syncVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Summary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Summary(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      recordingServerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_server_id'],
      ),
      generationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generation_id'],
      ),
      chapterClientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_client_uuid'],
      )!,
      contentMd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_md'],
      )!,
      structuredJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}structured_json'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      syncVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_version'],
      )!,
    );
  }

  @override
  $SummariesTable createAlias(String alias) {
    return $SummariesTable(attachedDatabase, alias);
  }
}

class Summary extends DataClass implements Insertable<Summary> {
  final int id;
  final String? serverId;
  final String? recordingServerId;
  final String? generationId;
  final String chapterClientUuid;
  final String contentMd;
  final String? structuredJson;
  final String status;
  final int syncVersion;
  const Summary({
    required this.id,
    this.serverId,
    this.recordingServerId,
    this.generationId,
    required this.chapterClientUuid,
    required this.contentMd,
    this.structuredJson,
    required this.status,
    required this.syncVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    if (!nullToAbsent || recordingServerId != null) {
      map['recording_server_id'] = Variable<String>(recordingServerId);
    }
    if (!nullToAbsent || generationId != null) {
      map['generation_id'] = Variable<String>(generationId);
    }
    map['chapter_client_uuid'] = Variable<String>(chapterClientUuid);
    map['content_md'] = Variable<String>(contentMd);
    if (!nullToAbsent || structuredJson != null) {
      map['structured_json'] = Variable<String>(structuredJson);
    }
    map['status'] = Variable<String>(status);
    map['sync_version'] = Variable<int>(syncVersion);
    return map;
  }

  SummariesCompanion toCompanion(bool nullToAbsent) {
    return SummariesCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      recordingServerId: recordingServerId == null && nullToAbsent
          ? const Value.absent()
          : Value(recordingServerId),
      generationId: generationId == null && nullToAbsent
          ? const Value.absent()
          : Value(generationId),
      chapterClientUuid: Value(chapterClientUuid),
      contentMd: Value(contentMd),
      structuredJson: structuredJson == null && nullToAbsent
          ? const Value.absent()
          : Value(structuredJson),
      status: Value(status),
      syncVersion: Value(syncVersion),
    );
  }

  factory Summary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Summary(
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      recordingServerId: serializer.fromJson<String?>(
        json['recordingServerId'],
      ),
      generationId: serializer.fromJson<String?>(json['generationId']),
      chapterClientUuid: serializer.fromJson<String>(json['chapterClientUuid']),
      contentMd: serializer.fromJson<String>(json['contentMd']),
      structuredJson: serializer.fromJson<String?>(json['structuredJson']),
      status: serializer.fromJson<String>(json['status']),
      syncVersion: serializer.fromJson<int>(json['syncVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<String?>(serverId),
      'recordingServerId': serializer.toJson<String?>(recordingServerId),
      'generationId': serializer.toJson<String?>(generationId),
      'chapterClientUuid': serializer.toJson<String>(chapterClientUuid),
      'contentMd': serializer.toJson<String>(contentMd),
      'structuredJson': serializer.toJson<String?>(structuredJson),
      'status': serializer.toJson<String>(status),
      'syncVersion': serializer.toJson<int>(syncVersion),
    };
  }

  Summary copyWith({
    int? id,
    Value<String?> serverId = const Value.absent(),
    Value<String?> recordingServerId = const Value.absent(),
    Value<String?> generationId = const Value.absent(),
    String? chapterClientUuid,
    String? contentMd,
    Value<String?> structuredJson = const Value.absent(),
    String? status,
    int? syncVersion,
  }) => Summary(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    recordingServerId: recordingServerId.present
        ? recordingServerId.value
        : this.recordingServerId,
    generationId: generationId.present ? generationId.value : this.generationId,
    chapterClientUuid: chapterClientUuid ?? this.chapterClientUuid,
    contentMd: contentMd ?? this.contentMd,
    structuredJson: structuredJson.present
        ? structuredJson.value
        : this.structuredJson,
    status: status ?? this.status,
    syncVersion: syncVersion ?? this.syncVersion,
  );
  Summary copyWithCompanion(SummariesCompanion data) {
    return Summary(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      recordingServerId: data.recordingServerId.present
          ? data.recordingServerId.value
          : this.recordingServerId,
      generationId: data.generationId.present
          ? data.generationId.value
          : this.generationId,
      chapterClientUuid: data.chapterClientUuid.present
          ? data.chapterClientUuid.value
          : this.chapterClientUuid,
      contentMd: data.contentMd.present ? data.contentMd.value : this.contentMd,
      structuredJson: data.structuredJson.present
          ? data.structuredJson.value
          : this.structuredJson,
      status: data.status.present ? data.status.value : this.status,
      syncVersion: data.syncVersion.present
          ? data.syncVersion.value
          : this.syncVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Summary(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('recordingServerId: $recordingServerId, ')
          ..write('generationId: $generationId, ')
          ..write('chapterClientUuid: $chapterClientUuid, ')
          ..write('contentMd: $contentMd, ')
          ..write('structuredJson: $structuredJson, ')
          ..write('status: $status, ')
          ..write('syncVersion: $syncVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    recordingServerId,
    generationId,
    chapterClientUuid,
    contentMd,
    structuredJson,
    status,
    syncVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Summary &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.recordingServerId == this.recordingServerId &&
          other.generationId == this.generationId &&
          other.chapterClientUuid == this.chapterClientUuid &&
          other.contentMd == this.contentMd &&
          other.structuredJson == this.structuredJson &&
          other.status == this.status &&
          other.syncVersion == this.syncVersion);
}

class SummariesCompanion extends UpdateCompanion<Summary> {
  final Value<int> id;
  final Value<String?> serverId;
  final Value<String?> recordingServerId;
  final Value<String?> generationId;
  final Value<String> chapterClientUuid;
  final Value<String> contentMd;
  final Value<String?> structuredJson;
  final Value<String> status;
  final Value<int> syncVersion;
  const SummariesCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.recordingServerId = const Value.absent(),
    this.generationId = const Value.absent(),
    this.chapterClientUuid = const Value.absent(),
    this.contentMd = const Value.absent(),
    this.structuredJson = const Value.absent(),
    this.status = const Value.absent(),
    this.syncVersion = const Value.absent(),
  });
  SummariesCompanion.insert({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.recordingServerId = const Value.absent(),
    this.generationId = const Value.absent(),
    required String chapterClientUuid,
    required String contentMd,
    this.structuredJson = const Value.absent(),
    this.status = const Value.absent(),
    this.syncVersion = const Value.absent(),
  }) : chapterClientUuid = Value(chapterClientUuid),
       contentMd = Value(contentMd);
  static Insertable<Summary> custom({
    Expression<int>? id,
    Expression<String>? serverId,
    Expression<String>? recordingServerId,
    Expression<String>? generationId,
    Expression<String>? chapterClientUuid,
    Expression<String>? contentMd,
    Expression<String>? structuredJson,
    Expression<String>? status,
    Expression<int>? syncVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (recordingServerId != null) 'recording_server_id': recordingServerId,
      if (generationId != null) 'generation_id': generationId,
      if (chapterClientUuid != null) 'chapter_client_uuid': chapterClientUuid,
      if (contentMd != null) 'content_md': contentMd,
      if (structuredJson != null) 'structured_json': structuredJson,
      if (status != null) 'status': status,
      if (syncVersion != null) 'sync_version': syncVersion,
    });
  }

  SummariesCompanion copyWith({
    Value<int>? id,
    Value<String?>? serverId,
    Value<String?>? recordingServerId,
    Value<String?>? generationId,
    Value<String>? chapterClientUuid,
    Value<String>? contentMd,
    Value<String?>? structuredJson,
    Value<String>? status,
    Value<int>? syncVersion,
  }) {
    return SummariesCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      recordingServerId: recordingServerId ?? this.recordingServerId,
      generationId: generationId ?? this.generationId,
      chapterClientUuid: chapterClientUuid ?? this.chapterClientUuid,
      contentMd: contentMd ?? this.contentMd,
      structuredJson: structuredJson ?? this.structuredJson,
      status: status ?? this.status,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (recordingServerId.present) {
      map['recording_server_id'] = Variable<String>(recordingServerId.value);
    }
    if (generationId.present) {
      map['generation_id'] = Variable<String>(generationId.value);
    }
    if (chapterClientUuid.present) {
      map['chapter_client_uuid'] = Variable<String>(chapterClientUuid.value);
    }
    if (contentMd.present) {
      map['content_md'] = Variable<String>(contentMd.value);
    }
    if (structuredJson.present) {
      map['structured_json'] = Variable<String>(structuredJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (syncVersion.present) {
      map['sync_version'] = Variable<int>(syncVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SummariesCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('recordingServerId: $recordingServerId, ')
          ..write('generationId: $generationId, ')
          ..write('chapterClientUuid: $chapterClientUuid, ')
          ..write('contentMd: $contentMd, ')
          ..write('structuredJson: $structuredJson, ')
          ..write('status: $status, ')
          ..write('syncVersion: $syncVersion')
          ..write(')'))
        .toString();
  }
}

class $ExercisesTable extends Exercises
    with TableInfo<$ExercisesTable, Exercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordingServerIdMeta = const VerificationMeta(
    'recordingServerId',
  );
  @override
  late final GeneratedColumn<String> recordingServerId =
      GeneratedColumn<String>(
        'recording_server_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _generationIdMeta = const VerificationMeta(
    'generationId',
  );
  @override
  late final GeneratedColumn<String> generationId = GeneratedColumn<String>(
    'generation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chapterClientUuidMeta = const VerificationMeta(
    'chapterClientUuid',
  );
  @override
  late final GeneratedColumn<String> chapterClientUuid =
      GeneratedColumn<String>(
        'chapter_client_uuid',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _itemsJsonMeta = const VerificationMeta(
    'itemsJson',
  );
  @override
  late final GeneratedColumn<String> itemsJson = GeneratedColumn<String>(
    'items_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending_review'),
  );
  static const VerificationMeta _syncVersionMeta = const VerificationMeta(
    'syncVersion',
  );
  @override
  late final GeneratedColumn<int> syncVersion = GeneratedColumn<int>(
    'sync_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    recordingServerId,
    generationId,
    chapterClientUuid,
    itemsJson,
    status,
    syncVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<Exercise> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('recording_server_id')) {
      context.handle(
        _recordingServerIdMeta,
        recordingServerId.isAcceptableOrUnknown(
          data['recording_server_id']!,
          _recordingServerIdMeta,
        ),
      );
    }
    if (data.containsKey('generation_id')) {
      context.handle(
        _generationIdMeta,
        generationId.isAcceptableOrUnknown(
          data['generation_id']!,
          _generationIdMeta,
        ),
      );
    }
    if (data.containsKey('chapter_client_uuid')) {
      context.handle(
        _chapterClientUuidMeta,
        chapterClientUuid.isAcceptableOrUnknown(
          data['chapter_client_uuid']!,
          _chapterClientUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterClientUuidMeta);
    }
    if (data.containsKey('items_json')) {
      context.handle(
        _itemsJsonMeta,
        itemsJson.isAcceptableOrUnknown(data['items_json']!, _itemsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_itemsJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('sync_version')) {
      context.handle(
        _syncVersionMeta,
        syncVersion.isAcceptableOrUnknown(
          data['sync_version']!,
          _syncVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Exercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Exercise(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      recordingServerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_server_id'],
      ),
      generationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generation_id'],
      ),
      chapterClientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_client_uuid'],
      )!,
      itemsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      syncVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_version'],
      )!,
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }
}

class Exercise extends DataClass implements Insertable<Exercise> {
  final int id;
  final String? serverId;
  final String? recordingServerId;
  final String? generationId;
  final String chapterClientUuid;
  final String itemsJson;
  final String status;
  final int syncVersion;
  const Exercise({
    required this.id,
    this.serverId,
    this.recordingServerId,
    this.generationId,
    required this.chapterClientUuid,
    required this.itemsJson,
    required this.status,
    required this.syncVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    if (!nullToAbsent || recordingServerId != null) {
      map['recording_server_id'] = Variable<String>(recordingServerId);
    }
    if (!nullToAbsent || generationId != null) {
      map['generation_id'] = Variable<String>(generationId);
    }
    map['chapter_client_uuid'] = Variable<String>(chapterClientUuid);
    map['items_json'] = Variable<String>(itemsJson);
    map['status'] = Variable<String>(status);
    map['sync_version'] = Variable<int>(syncVersion);
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      recordingServerId: recordingServerId == null && nullToAbsent
          ? const Value.absent()
          : Value(recordingServerId),
      generationId: generationId == null && nullToAbsent
          ? const Value.absent()
          : Value(generationId),
      chapterClientUuid: Value(chapterClientUuid),
      itemsJson: Value(itemsJson),
      status: Value(status),
      syncVersion: Value(syncVersion),
    );
  }

  factory Exercise.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Exercise(
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      recordingServerId: serializer.fromJson<String?>(
        json['recordingServerId'],
      ),
      generationId: serializer.fromJson<String?>(json['generationId']),
      chapterClientUuid: serializer.fromJson<String>(json['chapterClientUuid']),
      itemsJson: serializer.fromJson<String>(json['itemsJson']),
      status: serializer.fromJson<String>(json['status']),
      syncVersion: serializer.fromJson<int>(json['syncVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<String?>(serverId),
      'recordingServerId': serializer.toJson<String?>(recordingServerId),
      'generationId': serializer.toJson<String?>(generationId),
      'chapterClientUuid': serializer.toJson<String>(chapterClientUuid),
      'itemsJson': serializer.toJson<String>(itemsJson),
      'status': serializer.toJson<String>(status),
      'syncVersion': serializer.toJson<int>(syncVersion),
    };
  }

  Exercise copyWith({
    int? id,
    Value<String?> serverId = const Value.absent(),
    Value<String?> recordingServerId = const Value.absent(),
    Value<String?> generationId = const Value.absent(),
    String? chapterClientUuid,
    String? itemsJson,
    String? status,
    int? syncVersion,
  }) => Exercise(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    recordingServerId: recordingServerId.present
        ? recordingServerId.value
        : this.recordingServerId,
    generationId: generationId.present ? generationId.value : this.generationId,
    chapterClientUuid: chapterClientUuid ?? this.chapterClientUuid,
    itemsJson: itemsJson ?? this.itemsJson,
    status: status ?? this.status,
    syncVersion: syncVersion ?? this.syncVersion,
  );
  Exercise copyWithCompanion(ExercisesCompanion data) {
    return Exercise(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      recordingServerId: data.recordingServerId.present
          ? data.recordingServerId.value
          : this.recordingServerId,
      generationId: data.generationId.present
          ? data.generationId.value
          : this.generationId,
      chapterClientUuid: data.chapterClientUuid.present
          ? data.chapterClientUuid.value
          : this.chapterClientUuid,
      itemsJson: data.itemsJson.present ? data.itemsJson.value : this.itemsJson,
      status: data.status.present ? data.status.value : this.status,
      syncVersion: data.syncVersion.present
          ? data.syncVersion.value
          : this.syncVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Exercise(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('recordingServerId: $recordingServerId, ')
          ..write('generationId: $generationId, ')
          ..write('chapterClientUuid: $chapterClientUuid, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('status: $status, ')
          ..write('syncVersion: $syncVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    recordingServerId,
    generationId,
    chapterClientUuid,
    itemsJson,
    status,
    syncVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Exercise &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.recordingServerId == this.recordingServerId &&
          other.generationId == this.generationId &&
          other.chapterClientUuid == this.chapterClientUuid &&
          other.itemsJson == this.itemsJson &&
          other.status == this.status &&
          other.syncVersion == this.syncVersion);
}

class ExercisesCompanion extends UpdateCompanion<Exercise> {
  final Value<int> id;
  final Value<String?> serverId;
  final Value<String?> recordingServerId;
  final Value<String?> generationId;
  final Value<String> chapterClientUuid;
  final Value<String> itemsJson;
  final Value<String> status;
  final Value<int> syncVersion;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.recordingServerId = const Value.absent(),
    this.generationId = const Value.absent(),
    this.chapterClientUuid = const Value.absent(),
    this.itemsJson = const Value.absent(),
    this.status = const Value.absent(),
    this.syncVersion = const Value.absent(),
  });
  ExercisesCompanion.insert({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.recordingServerId = const Value.absent(),
    this.generationId = const Value.absent(),
    required String chapterClientUuid,
    required String itemsJson,
    this.status = const Value.absent(),
    this.syncVersion = const Value.absent(),
  }) : chapterClientUuid = Value(chapterClientUuid),
       itemsJson = Value(itemsJson);
  static Insertable<Exercise> custom({
    Expression<int>? id,
    Expression<String>? serverId,
    Expression<String>? recordingServerId,
    Expression<String>? generationId,
    Expression<String>? chapterClientUuid,
    Expression<String>? itemsJson,
    Expression<String>? status,
    Expression<int>? syncVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (recordingServerId != null) 'recording_server_id': recordingServerId,
      if (generationId != null) 'generation_id': generationId,
      if (chapterClientUuid != null) 'chapter_client_uuid': chapterClientUuid,
      if (itemsJson != null) 'items_json': itemsJson,
      if (status != null) 'status': status,
      if (syncVersion != null) 'sync_version': syncVersion,
    });
  }

  ExercisesCompanion copyWith({
    Value<int>? id,
    Value<String?>? serverId,
    Value<String?>? recordingServerId,
    Value<String?>? generationId,
    Value<String>? chapterClientUuid,
    Value<String>? itemsJson,
    Value<String>? status,
    Value<int>? syncVersion,
  }) {
    return ExercisesCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      recordingServerId: recordingServerId ?? this.recordingServerId,
      generationId: generationId ?? this.generationId,
      chapterClientUuid: chapterClientUuid ?? this.chapterClientUuid,
      itemsJson: itemsJson ?? this.itemsJson,
      status: status ?? this.status,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (recordingServerId.present) {
      map['recording_server_id'] = Variable<String>(recordingServerId.value);
    }
    if (generationId.present) {
      map['generation_id'] = Variable<String>(generationId.value);
    }
    if (chapterClientUuid.present) {
      map['chapter_client_uuid'] = Variable<String>(chapterClientUuid.value);
    }
    if (itemsJson.present) {
      map['items_json'] = Variable<String>(itemsJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (syncVersion.present) {
      map['sync_version'] = Variable<int>(syncVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('recordingServerId: $recordingServerId, ')
          ..write('generationId: $generationId, ')
          ..write('chapterClientUuid: $chapterClientUuid, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('status: $status, ')
          ..write('syncVersion: $syncVersion')
          ..write(')'))
        .toString();
  }
}

class $QuizzesTable extends Quizzes with TableInfo<$QuizzesTable, Quizze> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuizzesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordingServerIdMeta = const VerificationMeta(
    'recordingServerId',
  );
  @override
  late final GeneratedColumn<String> recordingServerId =
      GeneratedColumn<String>(
        'recording_server_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _generationIdMeta = const VerificationMeta(
    'generationId',
  );
  @override
  late final GeneratedColumn<String> generationId = GeneratedColumn<String>(
    'generation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chapterClientUuidMeta = const VerificationMeta(
    'chapterClientUuid',
  );
  @override
  late final GeneratedColumn<String> chapterClientUuid =
      GeneratedColumn<String>(
        'chapter_client_uuid',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _questionsJsonMeta = const VerificationMeta(
    'questionsJson',
  );
  @override
  late final GeneratedColumn<String> questionsJson = GeneratedColumn<String>(
    'questions_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending_review'),
  );
  static const VerificationMeta _syncVersionMeta = const VerificationMeta(
    'syncVersion',
  );
  @override
  late final GeneratedColumn<int> syncVersion = GeneratedColumn<int>(
    'sync_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    recordingServerId,
    generationId,
    chapterClientUuid,
    questionsJson,
    status,
    syncVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quizzes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Quizze> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('recording_server_id')) {
      context.handle(
        _recordingServerIdMeta,
        recordingServerId.isAcceptableOrUnknown(
          data['recording_server_id']!,
          _recordingServerIdMeta,
        ),
      );
    }
    if (data.containsKey('generation_id')) {
      context.handle(
        _generationIdMeta,
        generationId.isAcceptableOrUnknown(
          data['generation_id']!,
          _generationIdMeta,
        ),
      );
    }
    if (data.containsKey('chapter_client_uuid')) {
      context.handle(
        _chapterClientUuidMeta,
        chapterClientUuid.isAcceptableOrUnknown(
          data['chapter_client_uuid']!,
          _chapterClientUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterClientUuidMeta);
    }
    if (data.containsKey('questions_json')) {
      context.handle(
        _questionsJsonMeta,
        questionsJson.isAcceptableOrUnknown(
          data['questions_json']!,
          _questionsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_questionsJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('sync_version')) {
      context.handle(
        _syncVersionMeta,
        syncVersion.isAcceptableOrUnknown(
          data['sync_version']!,
          _syncVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Quizze map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Quizze(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      recordingServerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_server_id'],
      ),
      generationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generation_id'],
      ),
      chapterClientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_client_uuid'],
      )!,
      questionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}questions_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      syncVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_version'],
      )!,
    );
  }

  @override
  $QuizzesTable createAlias(String alias) {
    return $QuizzesTable(attachedDatabase, alias);
  }
}

class Quizze extends DataClass implements Insertable<Quizze> {
  final int id;
  final String? serverId;
  final String? recordingServerId;
  final String? generationId;
  final String chapterClientUuid;
  final String questionsJson;
  final String status;
  final int syncVersion;
  const Quizze({
    required this.id,
    this.serverId,
    this.recordingServerId,
    this.generationId,
    required this.chapterClientUuid,
    required this.questionsJson,
    required this.status,
    required this.syncVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    if (!nullToAbsent || recordingServerId != null) {
      map['recording_server_id'] = Variable<String>(recordingServerId);
    }
    if (!nullToAbsent || generationId != null) {
      map['generation_id'] = Variable<String>(generationId);
    }
    map['chapter_client_uuid'] = Variable<String>(chapterClientUuid);
    map['questions_json'] = Variable<String>(questionsJson);
    map['status'] = Variable<String>(status);
    map['sync_version'] = Variable<int>(syncVersion);
    return map;
  }

  QuizzesCompanion toCompanion(bool nullToAbsent) {
    return QuizzesCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      recordingServerId: recordingServerId == null && nullToAbsent
          ? const Value.absent()
          : Value(recordingServerId),
      generationId: generationId == null && nullToAbsent
          ? const Value.absent()
          : Value(generationId),
      chapterClientUuid: Value(chapterClientUuid),
      questionsJson: Value(questionsJson),
      status: Value(status),
      syncVersion: Value(syncVersion),
    );
  }

  factory Quizze.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Quizze(
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      recordingServerId: serializer.fromJson<String?>(
        json['recordingServerId'],
      ),
      generationId: serializer.fromJson<String?>(json['generationId']),
      chapterClientUuid: serializer.fromJson<String>(json['chapterClientUuid']),
      questionsJson: serializer.fromJson<String>(json['questionsJson']),
      status: serializer.fromJson<String>(json['status']),
      syncVersion: serializer.fromJson<int>(json['syncVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<String?>(serverId),
      'recordingServerId': serializer.toJson<String?>(recordingServerId),
      'generationId': serializer.toJson<String?>(generationId),
      'chapterClientUuid': serializer.toJson<String>(chapterClientUuid),
      'questionsJson': serializer.toJson<String>(questionsJson),
      'status': serializer.toJson<String>(status),
      'syncVersion': serializer.toJson<int>(syncVersion),
    };
  }

  Quizze copyWith({
    int? id,
    Value<String?> serverId = const Value.absent(),
    Value<String?> recordingServerId = const Value.absent(),
    Value<String?> generationId = const Value.absent(),
    String? chapterClientUuid,
    String? questionsJson,
    String? status,
    int? syncVersion,
  }) => Quizze(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    recordingServerId: recordingServerId.present
        ? recordingServerId.value
        : this.recordingServerId,
    generationId: generationId.present ? generationId.value : this.generationId,
    chapterClientUuid: chapterClientUuid ?? this.chapterClientUuid,
    questionsJson: questionsJson ?? this.questionsJson,
    status: status ?? this.status,
    syncVersion: syncVersion ?? this.syncVersion,
  );
  Quizze copyWithCompanion(QuizzesCompanion data) {
    return Quizze(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      recordingServerId: data.recordingServerId.present
          ? data.recordingServerId.value
          : this.recordingServerId,
      generationId: data.generationId.present
          ? data.generationId.value
          : this.generationId,
      chapterClientUuid: data.chapterClientUuid.present
          ? data.chapterClientUuid.value
          : this.chapterClientUuid,
      questionsJson: data.questionsJson.present
          ? data.questionsJson.value
          : this.questionsJson,
      status: data.status.present ? data.status.value : this.status,
      syncVersion: data.syncVersion.present
          ? data.syncVersion.value
          : this.syncVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Quizze(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('recordingServerId: $recordingServerId, ')
          ..write('generationId: $generationId, ')
          ..write('chapterClientUuid: $chapterClientUuid, ')
          ..write('questionsJson: $questionsJson, ')
          ..write('status: $status, ')
          ..write('syncVersion: $syncVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    recordingServerId,
    generationId,
    chapterClientUuid,
    questionsJson,
    status,
    syncVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Quizze &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.recordingServerId == this.recordingServerId &&
          other.generationId == this.generationId &&
          other.chapterClientUuid == this.chapterClientUuid &&
          other.questionsJson == this.questionsJson &&
          other.status == this.status &&
          other.syncVersion == this.syncVersion);
}

class QuizzesCompanion extends UpdateCompanion<Quizze> {
  final Value<int> id;
  final Value<String?> serverId;
  final Value<String?> recordingServerId;
  final Value<String?> generationId;
  final Value<String> chapterClientUuid;
  final Value<String> questionsJson;
  final Value<String> status;
  final Value<int> syncVersion;
  const QuizzesCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.recordingServerId = const Value.absent(),
    this.generationId = const Value.absent(),
    this.chapterClientUuid = const Value.absent(),
    this.questionsJson = const Value.absent(),
    this.status = const Value.absent(),
    this.syncVersion = const Value.absent(),
  });
  QuizzesCompanion.insert({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.recordingServerId = const Value.absent(),
    this.generationId = const Value.absent(),
    required String chapterClientUuid,
    required String questionsJson,
    this.status = const Value.absent(),
    this.syncVersion = const Value.absent(),
  }) : chapterClientUuid = Value(chapterClientUuid),
       questionsJson = Value(questionsJson);
  static Insertable<Quizze> custom({
    Expression<int>? id,
    Expression<String>? serverId,
    Expression<String>? recordingServerId,
    Expression<String>? generationId,
    Expression<String>? chapterClientUuid,
    Expression<String>? questionsJson,
    Expression<String>? status,
    Expression<int>? syncVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (recordingServerId != null) 'recording_server_id': recordingServerId,
      if (generationId != null) 'generation_id': generationId,
      if (chapterClientUuid != null) 'chapter_client_uuid': chapterClientUuid,
      if (questionsJson != null) 'questions_json': questionsJson,
      if (status != null) 'status': status,
      if (syncVersion != null) 'sync_version': syncVersion,
    });
  }

  QuizzesCompanion copyWith({
    Value<int>? id,
    Value<String?>? serverId,
    Value<String?>? recordingServerId,
    Value<String?>? generationId,
    Value<String>? chapterClientUuid,
    Value<String>? questionsJson,
    Value<String>? status,
    Value<int>? syncVersion,
  }) {
    return QuizzesCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      recordingServerId: recordingServerId ?? this.recordingServerId,
      generationId: generationId ?? this.generationId,
      chapterClientUuid: chapterClientUuid ?? this.chapterClientUuid,
      questionsJson: questionsJson ?? this.questionsJson,
      status: status ?? this.status,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (recordingServerId.present) {
      map['recording_server_id'] = Variable<String>(recordingServerId.value);
    }
    if (generationId.present) {
      map['generation_id'] = Variable<String>(generationId.value);
    }
    if (chapterClientUuid.present) {
      map['chapter_client_uuid'] = Variable<String>(chapterClientUuid.value);
    }
    if (questionsJson.present) {
      map['questions_json'] = Variable<String>(questionsJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (syncVersion.present) {
      map['sync_version'] = Variable<int>(syncVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuizzesCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('recordingServerId: $recordingServerId, ')
          ..write('generationId: $generationId, ')
          ..write('chapterClientUuid: $chapterClientUuid, ')
          ..write('questionsJson: $questionsJson, ')
          ..write('status: $status, ')
          ..write('syncVersion: $syncVersion')
          ..write(')'))
        .toString();
  }
}

class $QuizAttemptsTable extends QuizAttempts
    with TableInfo<$QuizAttemptsTable, QuizAttempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuizAttemptsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clientUuidMeta = const VerificationMeta(
    'clientUuid',
  );
  @override
  late final GeneratedColumn<String> clientUuid = GeneratedColumn<String>(
    'client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quizServerIdMeta = const VerificationMeta(
    'quizServerId',
  );
  @override
  late final GeneratedColumn<String> quizServerId = GeneratedColumn<String>(
    'quiz_server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterClientUuidMeta = const VerificationMeta(
    'chapterClientUuid',
  );
  @override
  late final GeneratedColumn<String> chapterClientUuid =
      GeneratedColumn<String>(
        'chapter_client_uuid',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answersJsonMeta = const VerificationMeta(
    'answersJson',
  );
  @override
  late final GeneratedColumn<String> answersJson = GeneratedColumn<String>(
    'answers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pendingSyncMeta = const VerificationMeta(
    'pendingSync',
  );
  @override
  late final GeneratedColumn<bool> pendingSync = GeneratedColumn<bool>(
    'pending_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending_sync" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<DateTime> takenAt = GeneratedColumn<DateTime>(
    'taken_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientUuid,
    serverId,
    quizServerId,
    chapterClientUuid,
    score,
    total,
    answersJson,
    pendingSync,
    takenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quiz_attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuizAttempt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_uuid')) {
      context.handle(
        _clientUuidMeta,
        clientUuid.isAcceptableOrUnknown(data['client_uuid']!, _clientUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_clientUuidMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('quiz_server_id')) {
      context.handle(
        _quizServerIdMeta,
        quizServerId.isAcceptableOrUnknown(
          data['quiz_server_id']!,
          _quizServerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_quizServerIdMeta);
    }
    if (data.containsKey('chapter_client_uuid')) {
      context.handle(
        _chapterClientUuidMeta,
        chapterClientUuid.isAcceptableOrUnknown(
          data['chapter_client_uuid']!,
          _chapterClientUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterClientUuidMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('answers_json')) {
      context.handle(
        _answersJsonMeta,
        answersJson.isAcceptableOrUnknown(
          data['answers_json']!,
          _answersJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_answersJsonMeta);
    }
    if (data.containsKey('pending_sync')) {
      context.handle(
        _pendingSyncMeta,
        pendingSync.isAcceptableOrUnknown(
          data['pending_sync']!,
          _pendingSyncMeta,
        ),
      );
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuizAttempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuizAttempt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_uuid'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      quizServerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quiz_server_id'],
      )!,
      chapterClientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_client_uuid'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      answersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answers_json'],
      )!,
      pendingSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending_sync'],
      )!,
      takenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}taken_at'],
      )!,
    );
  }

  @override
  $QuizAttemptsTable createAlias(String alias) {
    return $QuizAttemptsTable(attachedDatabase, alias);
  }
}

class QuizAttempt extends DataClass implements Insertable<QuizAttempt> {
  final int id;
  final String clientUuid;
  final String? serverId;
  final String quizServerId;
  final String chapterClientUuid;
  final int score;
  final int total;
  final String answersJson;
  final bool pendingSync;
  final DateTime takenAt;
  const QuizAttempt({
    required this.id,
    required this.clientUuid,
    this.serverId,
    required this.quizServerId,
    required this.chapterClientUuid,
    required this.score,
    required this.total,
    required this.answersJson,
    required this.pendingSync,
    required this.takenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_uuid'] = Variable<String>(clientUuid);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['quiz_server_id'] = Variable<String>(quizServerId);
    map['chapter_client_uuid'] = Variable<String>(chapterClientUuid);
    map['score'] = Variable<int>(score);
    map['total'] = Variable<int>(total);
    map['answers_json'] = Variable<String>(answersJson);
    map['pending_sync'] = Variable<bool>(pendingSync);
    map['taken_at'] = Variable<DateTime>(takenAt);
    return map;
  }

  QuizAttemptsCompanion toCompanion(bool nullToAbsent) {
    return QuizAttemptsCompanion(
      id: Value(id),
      clientUuid: Value(clientUuid),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      quizServerId: Value(quizServerId),
      chapterClientUuid: Value(chapterClientUuid),
      score: Value(score),
      total: Value(total),
      answersJson: Value(answersJson),
      pendingSync: Value(pendingSync),
      takenAt: Value(takenAt),
    );
  }

  factory QuizAttempt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuizAttempt(
      id: serializer.fromJson<int>(json['id']),
      clientUuid: serializer.fromJson<String>(json['clientUuid']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      quizServerId: serializer.fromJson<String>(json['quizServerId']),
      chapterClientUuid: serializer.fromJson<String>(json['chapterClientUuid']),
      score: serializer.fromJson<int>(json['score']),
      total: serializer.fromJson<int>(json['total']),
      answersJson: serializer.fromJson<String>(json['answersJson']),
      pendingSync: serializer.fromJson<bool>(json['pendingSync']),
      takenAt: serializer.fromJson<DateTime>(json['takenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientUuid': serializer.toJson<String>(clientUuid),
      'serverId': serializer.toJson<String?>(serverId),
      'quizServerId': serializer.toJson<String>(quizServerId),
      'chapterClientUuid': serializer.toJson<String>(chapterClientUuid),
      'score': serializer.toJson<int>(score),
      'total': serializer.toJson<int>(total),
      'answersJson': serializer.toJson<String>(answersJson),
      'pendingSync': serializer.toJson<bool>(pendingSync),
      'takenAt': serializer.toJson<DateTime>(takenAt),
    };
  }

  QuizAttempt copyWith({
    int? id,
    String? clientUuid,
    Value<String?> serverId = const Value.absent(),
    String? quizServerId,
    String? chapterClientUuid,
    int? score,
    int? total,
    String? answersJson,
    bool? pendingSync,
    DateTime? takenAt,
  }) => QuizAttempt(
    id: id ?? this.id,
    clientUuid: clientUuid ?? this.clientUuid,
    serverId: serverId.present ? serverId.value : this.serverId,
    quizServerId: quizServerId ?? this.quizServerId,
    chapterClientUuid: chapterClientUuid ?? this.chapterClientUuid,
    score: score ?? this.score,
    total: total ?? this.total,
    answersJson: answersJson ?? this.answersJson,
    pendingSync: pendingSync ?? this.pendingSync,
    takenAt: takenAt ?? this.takenAt,
  );
  QuizAttempt copyWithCompanion(QuizAttemptsCompanion data) {
    return QuizAttempt(
      id: data.id.present ? data.id.value : this.id,
      clientUuid: data.clientUuid.present
          ? data.clientUuid.value
          : this.clientUuid,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      quizServerId: data.quizServerId.present
          ? data.quizServerId.value
          : this.quizServerId,
      chapterClientUuid: data.chapterClientUuid.present
          ? data.chapterClientUuid.value
          : this.chapterClientUuid,
      score: data.score.present ? data.score.value : this.score,
      total: data.total.present ? data.total.value : this.total,
      answersJson: data.answersJson.present
          ? data.answersJson.value
          : this.answersJson,
      pendingSync: data.pendingSync.present
          ? data.pendingSync.value
          : this.pendingSync,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuizAttempt(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('serverId: $serverId, ')
          ..write('quizServerId: $quizServerId, ')
          ..write('chapterClientUuid: $chapterClientUuid, ')
          ..write('score: $score, ')
          ..write('total: $total, ')
          ..write('answersJson: $answersJson, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('takenAt: $takenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientUuid,
    serverId,
    quizServerId,
    chapterClientUuid,
    score,
    total,
    answersJson,
    pendingSync,
    takenAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuizAttempt &&
          other.id == this.id &&
          other.clientUuid == this.clientUuid &&
          other.serverId == this.serverId &&
          other.quizServerId == this.quizServerId &&
          other.chapterClientUuid == this.chapterClientUuid &&
          other.score == this.score &&
          other.total == this.total &&
          other.answersJson == this.answersJson &&
          other.pendingSync == this.pendingSync &&
          other.takenAt == this.takenAt);
}

class QuizAttemptsCompanion extends UpdateCompanion<QuizAttempt> {
  final Value<int> id;
  final Value<String> clientUuid;
  final Value<String?> serverId;
  final Value<String> quizServerId;
  final Value<String> chapterClientUuid;
  final Value<int> score;
  final Value<int> total;
  final Value<String> answersJson;
  final Value<bool> pendingSync;
  final Value<DateTime> takenAt;
  const QuizAttemptsCompanion({
    this.id = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.serverId = const Value.absent(),
    this.quizServerId = const Value.absent(),
    this.chapterClientUuid = const Value.absent(),
    this.score = const Value.absent(),
    this.total = const Value.absent(),
    this.answersJson = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.takenAt = const Value.absent(),
  });
  QuizAttemptsCompanion.insert({
    this.id = const Value.absent(),
    required String clientUuid,
    this.serverId = const Value.absent(),
    required String quizServerId,
    required String chapterClientUuid,
    required int score,
    required int total,
    required String answersJson,
    this.pendingSync = const Value.absent(),
    this.takenAt = const Value.absent(),
  }) : clientUuid = Value(clientUuid),
       quizServerId = Value(quizServerId),
       chapterClientUuid = Value(chapterClientUuid),
       score = Value(score),
       total = Value(total),
       answersJson = Value(answersJson);
  static Insertable<QuizAttempt> custom({
    Expression<int>? id,
    Expression<String>? clientUuid,
    Expression<String>? serverId,
    Expression<String>? quizServerId,
    Expression<String>? chapterClientUuid,
    Expression<int>? score,
    Expression<int>? total,
    Expression<String>? answersJson,
    Expression<bool>? pendingSync,
    Expression<DateTime>? takenAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientUuid != null) 'client_uuid': clientUuid,
      if (serverId != null) 'server_id': serverId,
      if (quizServerId != null) 'quiz_server_id': quizServerId,
      if (chapterClientUuid != null) 'chapter_client_uuid': chapterClientUuid,
      if (score != null) 'score': score,
      if (total != null) 'total': total,
      if (answersJson != null) 'answers_json': answersJson,
      if (pendingSync != null) 'pending_sync': pendingSync,
      if (takenAt != null) 'taken_at': takenAt,
    });
  }

  QuizAttemptsCompanion copyWith({
    Value<int>? id,
    Value<String>? clientUuid,
    Value<String?>? serverId,
    Value<String>? quizServerId,
    Value<String>? chapterClientUuid,
    Value<int>? score,
    Value<int>? total,
    Value<String>? answersJson,
    Value<bool>? pendingSync,
    Value<DateTime>? takenAt,
  }) {
    return QuizAttemptsCompanion(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      serverId: serverId ?? this.serverId,
      quizServerId: quizServerId ?? this.quizServerId,
      chapterClientUuid: chapterClientUuid ?? this.chapterClientUuid,
      score: score ?? this.score,
      total: total ?? this.total,
      answersJson: answersJson ?? this.answersJson,
      pendingSync: pendingSync ?? this.pendingSync,
      takenAt: takenAt ?? this.takenAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientUuid.present) {
      map['client_uuid'] = Variable<String>(clientUuid.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (quizServerId.present) {
      map['quiz_server_id'] = Variable<String>(quizServerId.value);
    }
    if (chapterClientUuid.present) {
      map['chapter_client_uuid'] = Variable<String>(chapterClientUuid.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (answersJson.present) {
      map['answers_json'] = Variable<String>(answersJson.value);
    }
    if (pendingSync.present) {
      map['pending_sync'] = Variable<bool>(pendingSync.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<DateTime>(takenAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuizAttemptsCompanion(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('serverId: $serverId, ')
          ..write('quizServerId: $quizServerId, ')
          ..write('chapterClientUuid: $chapterClientUuid, ')
          ..write('score: $score, ')
          ..write('total: $total, ')
          ..write('answersJson: $answersJson, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('takenAt: $takenAt')
          ..write(')'))
        .toString();
  }
}

class $MetaTable extends Meta with TableInfo<$MetaTable, MetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaData> instance, {
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
  MetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaData(
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
  $MetaTable createAlias(String alias) {
    return $MetaTable(attachedDatabase, alias);
  }
}

class MetaData extends DataClass implements Insertable<MetaData> {
  final String key;
  final String value;
  const MetaData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaCompanion toCompanion(bool nullToAbsent) {
    return MetaCompanion(key: Value(key), value: Value(value));
  }

  factory MetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaData(
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

  MetaData copyWith({String? key, String? value}) =>
      MetaData(key: key ?? this.key, value: value ?? this.value);
  MetaData copyWithCompanion(MetaCompanion data) {
    return MetaData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaData(')
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
      (other is MetaData && other.key == this.key && other.value == this.value);
}

class MetaCompanion extends UpdateCompanion<MetaData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaData> custom({
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

  MetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaCompanion(
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
    return (StringBuffer('MetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CoursesTable courses = $CoursesTable(this);
  late final $LessonsTable lessons = $LessonsTable(this);
  late final $ChaptersTable chapters = $ChaptersTable(this);
  late final $AgendaItemsTable agendaItems = $AgendaItemsTable(this);
  late final $RecordingsTable recordings = $RecordingsTable(this);
  late final $TranscriptsTable transcripts = $TranscriptsTable(this);
  late final $SummariesTable summaries = $SummariesTable(this);
  late final $ExercisesTable exercises = $ExercisesTable(this);
  late final $QuizzesTable quizzes = $QuizzesTable(this);
  late final $QuizAttemptsTable quizAttempts = $QuizAttemptsTable(this);
  late final $MetaTable meta = $MetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    courses,
    lessons,
    chapters,
    agendaItems,
    recordings,
    transcripts,
    summaries,
    exercises,
    quizzes,
    quizAttempts,
    meta,
  ];
}

typedef $$CoursesTableCreateCompanionBuilder =
    CoursesCompanion Function({
      Value<int> id,
      required String clientUuid,
      Value<String?> serverId,
      required String title,
      Value<String?> description,
      Value<bool> pendingSync,
      Value<bool> deleted,
      Value<int> syncVersion,
      Value<DateTime> updatedAt,
    });
typedef $$CoursesTableUpdateCompanionBuilder =
    CoursesCompanion Function({
      Value<int> id,
      Value<String> clientUuid,
      Value<String?> serverId,
      Value<String> title,
      Value<String?> description,
      Value<bool> pendingSync,
      Value<bool> deleted,
      Value<int> syncVersion,
      Value<DateTime> updatedAt,
    });

class $$CoursesTableFilterComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableFilterComposer({
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

  ColumnFilters<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CoursesTableOrderingComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableOrderingComposer({
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

  ColumnOrderings<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoursesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CoursesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoursesTable,
          Course,
          $$CoursesTableFilterComposer,
          $$CoursesTableOrderingComposer,
          $$CoursesTableAnnotationComposer,
          $$CoursesTableCreateCompanionBuilder,
          $$CoursesTableUpdateCompanionBuilder,
          (Course, BaseReferences<_$AppDatabase, $CoursesTable, Course>),
          Course,
          PrefetchHooks Function()
        > {
  $$CoursesTableTableManager(_$AppDatabase db, $CoursesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoursesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoursesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoursesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> pendingSync = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CoursesCompanion(
                id: id,
                clientUuid: clientUuid,
                serverId: serverId,
                title: title,
                description: description,
                pendingSync: pendingSync,
                deleted: deleted,
                syncVersion: syncVersion,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientUuid,
                Value<String?> serverId = const Value.absent(),
                required String title,
                Value<String?> description = const Value.absent(),
                Value<bool> pendingSync = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CoursesCompanion.insert(
                id: id,
                clientUuid: clientUuid,
                serverId: serverId,
                title: title,
                description: description,
                pendingSync: pendingSync,
                deleted: deleted,
                syncVersion: syncVersion,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CoursesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoursesTable,
      Course,
      $$CoursesTableFilterComposer,
      $$CoursesTableOrderingComposer,
      $$CoursesTableAnnotationComposer,
      $$CoursesTableCreateCompanionBuilder,
      $$CoursesTableUpdateCompanionBuilder,
      (Course, BaseReferences<_$AppDatabase, $CoursesTable, Course>),
      Course,
      PrefetchHooks Function()
    >;
typedef $$LessonsTableCreateCompanionBuilder =
    LessonsCompanion Function({
      Value<int> id,
      required String clientUuid,
      Value<String?> serverId,
      required String courseClientUuid,
      required String title,
      Value<int> position,
      Value<bool> pendingSync,
      Value<bool> deleted,
      Value<int> syncVersion,
      Value<DateTime> updatedAt,
    });
typedef $$LessonsTableUpdateCompanionBuilder =
    LessonsCompanion Function({
      Value<int> id,
      Value<String> clientUuid,
      Value<String?> serverId,
      Value<String> courseClientUuid,
      Value<String> title,
      Value<int> position,
      Value<bool> pendingSync,
      Value<bool> deleted,
      Value<int> syncVersion,
      Value<DateTime> updatedAt,
    });

class $$LessonsTableFilterComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableFilterComposer({
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

  ColumnFilters<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseClientUuid => $composableBuilder(
    column: $table.courseClientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LessonsTableOrderingComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableOrderingComposer({
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

  ColumnOrderings<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseClientUuid => $composableBuilder(
    column: $table.courseClientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LessonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get courseClientUuid => $composableBuilder(
    column: $table.courseClientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LessonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LessonsTable,
          Lesson,
          $$LessonsTableFilterComposer,
          $$LessonsTableOrderingComposer,
          $$LessonsTableAnnotationComposer,
          $$LessonsTableCreateCompanionBuilder,
          $$LessonsTableUpdateCompanionBuilder,
          (Lesson, BaseReferences<_$AppDatabase, $LessonsTable, Lesson>),
          Lesson,
          PrefetchHooks Function()
        > {
  $$LessonsTableTableManager(_$AppDatabase db, $LessonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LessonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LessonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LessonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> courseClientUuid = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<bool> pendingSync = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LessonsCompanion(
                id: id,
                clientUuid: clientUuid,
                serverId: serverId,
                courseClientUuid: courseClientUuid,
                title: title,
                position: position,
                pendingSync: pendingSync,
                deleted: deleted,
                syncVersion: syncVersion,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientUuid,
                Value<String?> serverId = const Value.absent(),
                required String courseClientUuid,
                required String title,
                Value<int> position = const Value.absent(),
                Value<bool> pendingSync = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LessonsCompanion.insert(
                id: id,
                clientUuid: clientUuid,
                serverId: serverId,
                courseClientUuid: courseClientUuid,
                title: title,
                position: position,
                pendingSync: pendingSync,
                deleted: deleted,
                syncVersion: syncVersion,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LessonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LessonsTable,
      Lesson,
      $$LessonsTableFilterComposer,
      $$LessonsTableOrderingComposer,
      $$LessonsTableAnnotationComposer,
      $$LessonsTableCreateCompanionBuilder,
      $$LessonsTableUpdateCompanionBuilder,
      (Lesson, BaseReferences<_$AppDatabase, $LessonsTable, Lesson>),
      Lesson,
      PrefetchHooks Function()
    >;
typedef $$ChaptersTableCreateCompanionBuilder =
    ChaptersCompanion Function({
      Value<int> id,
      required String clientUuid,
      Value<String?> serverId,
      required String lessonClientUuid,
      required String title,
      Value<int> position,
      Value<bool> pendingSync,
      Value<bool> deleted,
      Value<int> syncVersion,
      Value<DateTime> updatedAt,
    });
typedef $$ChaptersTableUpdateCompanionBuilder =
    ChaptersCompanion Function({
      Value<int> id,
      Value<String> clientUuid,
      Value<String?> serverId,
      Value<String> lessonClientUuid,
      Value<String> title,
      Value<int> position,
      Value<bool> pendingSync,
      Value<bool> deleted,
      Value<int> syncVersion,
      Value<DateTime> updatedAt,
    });

class $$ChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableFilterComposer({
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

  ColumnFilters<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonClientUuid => $composableBuilder(
    column: $table.lessonClientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableOrderingComposer({
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

  ColumnOrderings<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonClientUuid => $composableBuilder(
    column: $table.lessonClientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get lessonClientUuid => $composableBuilder(
    column: $table.lessonClientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChaptersTable,
          Chapter,
          $$ChaptersTableFilterComposer,
          $$ChaptersTableOrderingComposer,
          $$ChaptersTableAnnotationComposer,
          $$ChaptersTableCreateCompanionBuilder,
          $$ChaptersTableUpdateCompanionBuilder,
          (Chapter, BaseReferences<_$AppDatabase, $ChaptersTable, Chapter>),
          Chapter,
          PrefetchHooks Function()
        > {
  $$ChaptersTableTableManager(_$AppDatabase db, $ChaptersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> lessonClientUuid = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<bool> pendingSync = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ChaptersCompanion(
                id: id,
                clientUuid: clientUuid,
                serverId: serverId,
                lessonClientUuid: lessonClientUuid,
                title: title,
                position: position,
                pendingSync: pendingSync,
                deleted: deleted,
                syncVersion: syncVersion,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientUuid,
                Value<String?> serverId = const Value.absent(),
                required String lessonClientUuid,
                required String title,
                Value<int> position = const Value.absent(),
                Value<bool> pendingSync = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ChaptersCompanion.insert(
                id: id,
                clientUuid: clientUuid,
                serverId: serverId,
                lessonClientUuid: lessonClientUuid,
                title: title,
                position: position,
                pendingSync: pendingSync,
                deleted: deleted,
                syncVersion: syncVersion,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChaptersTable,
      Chapter,
      $$ChaptersTableFilterComposer,
      $$ChaptersTableOrderingComposer,
      $$ChaptersTableAnnotationComposer,
      $$ChaptersTableCreateCompanionBuilder,
      $$ChaptersTableUpdateCompanionBuilder,
      (Chapter, BaseReferences<_$AppDatabase, $ChaptersTable, Chapter>),
      Chapter,
      PrefetchHooks Function()
    >;
typedef $$AgendaItemsTableCreateCompanionBuilder =
    AgendaItemsCompanion Function({
      Value<int> id,
      required String clientUuid,
      Value<String?> serverId,
      required String title,
      Value<String> kind,
      Value<String?> subject,
      Value<String?> notes,
      Value<String?> location,
      Value<DateTime?> startsAt,
      Value<DateTime?> endsAt,
      Value<String> recurrence,
      Value<DateTime?> recurrenceUntil,
      Value<int?> reminderMinutes,
      Value<String?> chapterClientUuid,
      Value<bool> pendingSync,
      Value<bool> deleted,
      Value<int> syncVersion,
      Value<DateTime> updatedAt,
    });
typedef $$AgendaItemsTableUpdateCompanionBuilder =
    AgendaItemsCompanion Function({
      Value<int> id,
      Value<String> clientUuid,
      Value<String?> serverId,
      Value<String> title,
      Value<String> kind,
      Value<String?> subject,
      Value<String?> notes,
      Value<String?> location,
      Value<DateTime?> startsAt,
      Value<DateTime?> endsAt,
      Value<String> recurrence,
      Value<DateTime?> recurrenceUntil,
      Value<int?> reminderMinutes,
      Value<String?> chapterClientUuid,
      Value<bool> pendingSync,
      Value<bool> deleted,
      Value<int> syncVersion,
      Value<DateTime> updatedAt,
    });

class $$AgendaItemsTableFilterComposer
    extends Composer<_$AppDatabase, $AgendaItemsTable> {
  $$AgendaItemsTableFilterComposer({
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

  ColumnFilters<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startsAt => $composableBuilder(
    column: $table.startsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recurrenceUntil => $composableBuilder(
    column: $table.recurrenceUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AgendaItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $AgendaItemsTable> {
  $$AgendaItemsTableOrderingComposer({
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

  ColumnOrderings<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startsAt => $composableBuilder(
    column: $table.startsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recurrenceUntil => $composableBuilder(
    column: $table.recurrenceUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AgendaItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AgendaItemsTable> {
  $$AgendaItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<DateTime> get startsAt =>
      $composableBuilder(column: $table.startsAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endsAt =>
      $composableBuilder(column: $table.endsAt, builder: (column) => column);

  GeneratedColumn<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get recurrenceUntil => $composableBuilder(
    column: $table.recurrenceUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AgendaItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AgendaItemsTable,
          AgendaItem,
          $$AgendaItemsTableFilterComposer,
          $$AgendaItemsTableOrderingComposer,
          $$AgendaItemsTableAnnotationComposer,
          $$AgendaItemsTableCreateCompanionBuilder,
          $$AgendaItemsTableUpdateCompanionBuilder,
          (
            AgendaItem,
            BaseReferences<_$AppDatabase, $AgendaItemsTable, AgendaItem>,
          ),
          AgendaItem,
          PrefetchHooks Function()
        > {
  $$AgendaItemsTableTableManager(_$AppDatabase db, $AgendaItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgendaItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgendaItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgendaItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> subject = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<DateTime?> startsAt = const Value.absent(),
                Value<DateTime?> endsAt = const Value.absent(),
                Value<String> recurrence = const Value.absent(),
                Value<DateTime?> recurrenceUntil = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                Value<String?> chapterClientUuid = const Value.absent(),
                Value<bool> pendingSync = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AgendaItemsCompanion(
                id: id,
                clientUuid: clientUuid,
                serverId: serverId,
                title: title,
                kind: kind,
                subject: subject,
                notes: notes,
                location: location,
                startsAt: startsAt,
                endsAt: endsAt,
                recurrence: recurrence,
                recurrenceUntil: recurrenceUntil,
                reminderMinutes: reminderMinutes,
                chapterClientUuid: chapterClientUuid,
                pendingSync: pendingSync,
                deleted: deleted,
                syncVersion: syncVersion,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientUuid,
                Value<String?> serverId = const Value.absent(),
                required String title,
                Value<String> kind = const Value.absent(),
                Value<String?> subject = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<DateTime?> startsAt = const Value.absent(),
                Value<DateTime?> endsAt = const Value.absent(),
                Value<String> recurrence = const Value.absent(),
                Value<DateTime?> recurrenceUntil = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                Value<String?> chapterClientUuid = const Value.absent(),
                Value<bool> pendingSync = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AgendaItemsCompanion.insert(
                id: id,
                clientUuid: clientUuid,
                serverId: serverId,
                title: title,
                kind: kind,
                subject: subject,
                notes: notes,
                location: location,
                startsAt: startsAt,
                endsAt: endsAt,
                recurrence: recurrence,
                recurrenceUntil: recurrenceUntil,
                reminderMinutes: reminderMinutes,
                chapterClientUuid: chapterClientUuid,
                pendingSync: pendingSync,
                deleted: deleted,
                syncVersion: syncVersion,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AgendaItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AgendaItemsTable,
      AgendaItem,
      $$AgendaItemsTableFilterComposer,
      $$AgendaItemsTableOrderingComposer,
      $$AgendaItemsTableAnnotationComposer,
      $$AgendaItemsTableCreateCompanionBuilder,
      $$AgendaItemsTableUpdateCompanionBuilder,
      (
        AgendaItem,
        BaseReferences<_$AppDatabase, $AgendaItemsTable, AgendaItem>,
      ),
      AgendaItem,
      PrefetchHooks Function()
    >;
typedef $$RecordingsTableCreateCompanionBuilder =
    RecordingsCompanion Function({
      Value<int> id,
      required String clientUuid,
      required String chapterClientUuid,
      required String localPath,
      Value<String?> fileName,
      Value<int?> durationSecs,
      Value<String> status,
      Value<int> uploadedBytes,
      Value<String?> serverRecordingId,
      Value<String> pipelineStage,
      Value<int> progressPercent,
      Value<int?> stageCurrent,
      Value<int?> stageTotal,
      Value<String?> statusMessage,
      Value<bool> retryable,
      Value<int> attemptCount,
      Value<DateTime?> nextRetryAt,
      Value<String?> errorCode,
      Value<DateTime?> stageStartedAt,
      Value<DateTime?> lastProgressAt,
      Value<DateTime> createdAt,
    });
typedef $$RecordingsTableUpdateCompanionBuilder =
    RecordingsCompanion Function({
      Value<int> id,
      Value<String> clientUuid,
      Value<String> chapterClientUuid,
      Value<String> localPath,
      Value<String?> fileName,
      Value<int?> durationSecs,
      Value<String> status,
      Value<int> uploadedBytes,
      Value<String?> serverRecordingId,
      Value<String> pipelineStage,
      Value<int> progressPercent,
      Value<int?> stageCurrent,
      Value<int?> stageTotal,
      Value<String?> statusMessage,
      Value<bool> retryable,
      Value<int> attemptCount,
      Value<DateTime?> nextRetryAt,
      Value<String?> errorCode,
      Value<DateTime?> stageStartedAt,
      Value<DateTime?> lastProgressAt,
      Value<DateTime> createdAt,
    });

class $$RecordingsTableFilterComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableFilterComposer({
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

  ColumnFilters<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSecs => $composableBuilder(
    column: $table.durationSecs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uploadedBytes => $composableBuilder(
    column: $table.uploadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverRecordingId => $composableBuilder(
    column: $table.serverRecordingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pipelineStage => $composableBuilder(
    column: $table.pipelineStage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get progressPercent => $composableBuilder(
    column: $table.progressPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stageCurrent => $composableBuilder(
    column: $table.stageCurrent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stageTotal => $composableBuilder(
    column: $table.stageTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statusMessage => $composableBuilder(
    column: $table.statusMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get retryable => $composableBuilder(
    column: $table.retryable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get stageStartedAt => $composableBuilder(
    column: $table.stageStartedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastProgressAt => $composableBuilder(
    column: $table.lastProgressAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecordingsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableOrderingComposer({
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

  ColumnOrderings<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSecs => $composableBuilder(
    column: $table.durationSecs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uploadedBytes => $composableBuilder(
    column: $table.uploadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverRecordingId => $composableBuilder(
    column: $table.serverRecordingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pipelineStage => $composableBuilder(
    column: $table.pipelineStage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get progressPercent => $composableBuilder(
    column: $table.progressPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stageCurrent => $composableBuilder(
    column: $table.stageCurrent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stageTotal => $composableBuilder(
    column: $table.stageTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statusMessage => $composableBuilder(
    column: $table.statusMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get retryable => $composableBuilder(
    column: $table.retryable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get stageStartedAt => $composableBuilder(
    column: $table.stageStartedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastProgressAt => $composableBuilder(
    column: $table.lastProgressAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecordingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get durationSecs => $composableBuilder(
    column: $table.durationSecs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get uploadedBytes => $composableBuilder(
    column: $table.uploadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverRecordingId => $composableBuilder(
    column: $table.serverRecordingId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pipelineStage => $composableBuilder(
    column: $table.pipelineStage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get progressPercent => $composableBuilder(
    column: $table.progressPercent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stageCurrent => $composableBuilder(
    column: $table.stageCurrent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stageTotal => $composableBuilder(
    column: $table.stageTotal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get statusMessage => $composableBuilder(
    column: $table.statusMessage,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get retryable =>
      $composableBuilder(column: $table.retryable, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<DateTime> get stageStartedAt => $composableBuilder(
    column: $table.stageStartedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastProgressAt => $composableBuilder(
    column: $table.lastProgressAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RecordingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecordingsTable,
          Recording,
          $$RecordingsTableFilterComposer,
          $$RecordingsTableOrderingComposer,
          $$RecordingsTableAnnotationComposer,
          $$RecordingsTableCreateCompanionBuilder,
          $$RecordingsTableUpdateCompanionBuilder,
          (
            Recording,
            BaseReferences<_$AppDatabase, $RecordingsTable, Recording>,
          ),
          Recording,
          PrefetchHooks Function()
        > {
  $$RecordingsTableTableManager(_$AppDatabase db, $RecordingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<String> chapterClientUuid = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<String?> fileName = const Value.absent(),
                Value<int?> durationSecs = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> uploadedBytes = const Value.absent(),
                Value<String?> serverRecordingId = const Value.absent(),
                Value<String> pipelineStage = const Value.absent(),
                Value<int> progressPercent = const Value.absent(),
                Value<int?> stageCurrent = const Value.absent(),
                Value<int?> stageTotal = const Value.absent(),
                Value<String?> statusMessage = const Value.absent(),
                Value<bool> retryable = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<DateTime?> stageStartedAt = const Value.absent(),
                Value<DateTime?> lastProgressAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RecordingsCompanion(
                id: id,
                clientUuid: clientUuid,
                chapterClientUuid: chapterClientUuid,
                localPath: localPath,
                fileName: fileName,
                durationSecs: durationSecs,
                status: status,
                uploadedBytes: uploadedBytes,
                serverRecordingId: serverRecordingId,
                pipelineStage: pipelineStage,
                progressPercent: progressPercent,
                stageCurrent: stageCurrent,
                stageTotal: stageTotal,
                statusMessage: statusMessage,
                retryable: retryable,
                attemptCount: attemptCount,
                nextRetryAt: nextRetryAt,
                errorCode: errorCode,
                stageStartedAt: stageStartedAt,
                lastProgressAt: lastProgressAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientUuid,
                required String chapterClientUuid,
                required String localPath,
                Value<String?> fileName = const Value.absent(),
                Value<int?> durationSecs = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> uploadedBytes = const Value.absent(),
                Value<String?> serverRecordingId = const Value.absent(),
                Value<String> pipelineStage = const Value.absent(),
                Value<int> progressPercent = const Value.absent(),
                Value<int?> stageCurrent = const Value.absent(),
                Value<int?> stageTotal = const Value.absent(),
                Value<String?> statusMessage = const Value.absent(),
                Value<bool> retryable = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<DateTime?> stageStartedAt = const Value.absent(),
                Value<DateTime?> lastProgressAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RecordingsCompanion.insert(
                id: id,
                clientUuid: clientUuid,
                chapterClientUuid: chapterClientUuid,
                localPath: localPath,
                fileName: fileName,
                durationSecs: durationSecs,
                status: status,
                uploadedBytes: uploadedBytes,
                serverRecordingId: serverRecordingId,
                pipelineStage: pipelineStage,
                progressPercent: progressPercent,
                stageCurrent: stageCurrent,
                stageTotal: stageTotal,
                statusMessage: statusMessage,
                retryable: retryable,
                attemptCount: attemptCount,
                nextRetryAt: nextRetryAt,
                errorCode: errorCode,
                stageStartedAt: stageStartedAt,
                lastProgressAt: lastProgressAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecordingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecordingsTable,
      Recording,
      $$RecordingsTableFilterComposer,
      $$RecordingsTableOrderingComposer,
      $$RecordingsTableAnnotationComposer,
      $$RecordingsTableCreateCompanionBuilder,
      $$RecordingsTableUpdateCompanionBuilder,
      (Recording, BaseReferences<_$AppDatabase, $RecordingsTable, Recording>),
      Recording,
      PrefetchHooks Function()
    >;
typedef $$TranscriptsTableCreateCompanionBuilder =
    TranscriptsCompanion Function({
      Value<int> id,
      required String serverId,
      required String recordingServerId,
      required String recordingClientUuid,
      required String content,
      Value<String?> language,
      Value<String> segmentsJson,
      Value<int> syncVersion,
    });
typedef $$TranscriptsTableUpdateCompanionBuilder =
    TranscriptsCompanion Function({
      Value<int> id,
      Value<String> serverId,
      Value<String> recordingServerId,
      Value<String> recordingClientUuid,
      Value<String> content,
      Value<String?> language,
      Value<String> segmentsJson,
      Value<int> syncVersion,
    });

class $$TranscriptsTableFilterComposer
    extends Composer<_$AppDatabase, $TranscriptsTable> {
  $$TranscriptsTableFilterComposer({
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

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordingServerId => $composableBuilder(
    column: $table.recordingServerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordingClientUuid => $composableBuilder(
    column: $table.recordingClientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get segmentsJson => $composableBuilder(
    column: $table.segmentsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TranscriptsTableOrderingComposer
    extends Composer<_$AppDatabase, $TranscriptsTable> {
  $$TranscriptsTableOrderingComposer({
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

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordingServerId => $composableBuilder(
    column: $table.recordingServerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordingClientUuid => $composableBuilder(
    column: $table.recordingClientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get segmentsJson => $composableBuilder(
    column: $table.segmentsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TranscriptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TranscriptsTable> {
  $$TranscriptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get recordingServerId => $composableBuilder(
    column: $table.recordingServerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordingClientUuid => $composableBuilder(
    column: $table.recordingClientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get segmentsJson => $composableBuilder(
    column: $table.segmentsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => column,
  );
}

class $$TranscriptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TranscriptsTable,
          Transcript,
          $$TranscriptsTableFilterComposer,
          $$TranscriptsTableOrderingComposer,
          $$TranscriptsTableAnnotationComposer,
          $$TranscriptsTableCreateCompanionBuilder,
          $$TranscriptsTableUpdateCompanionBuilder,
          (
            Transcript,
            BaseReferences<_$AppDatabase, $TranscriptsTable, Transcript>,
          ),
          Transcript,
          PrefetchHooks Function()
        > {
  $$TranscriptsTableTableManager(_$AppDatabase db, $TranscriptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<String> recordingServerId = const Value.absent(),
                Value<String> recordingClientUuid = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String> segmentsJson = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
              }) => TranscriptsCompanion(
                id: id,
                serverId: serverId,
                recordingServerId: recordingServerId,
                recordingClientUuid: recordingClientUuid,
                content: content,
                language: language,
                segmentsJson: segmentsJson,
                syncVersion: syncVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String serverId,
                required String recordingServerId,
                required String recordingClientUuid,
                required String content,
                Value<String?> language = const Value.absent(),
                Value<String> segmentsJson = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
              }) => TranscriptsCompanion.insert(
                id: id,
                serverId: serverId,
                recordingServerId: recordingServerId,
                recordingClientUuid: recordingClientUuid,
                content: content,
                language: language,
                segmentsJson: segmentsJson,
                syncVersion: syncVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TranscriptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TranscriptsTable,
      Transcript,
      $$TranscriptsTableFilterComposer,
      $$TranscriptsTableOrderingComposer,
      $$TranscriptsTableAnnotationComposer,
      $$TranscriptsTableCreateCompanionBuilder,
      $$TranscriptsTableUpdateCompanionBuilder,
      (
        Transcript,
        BaseReferences<_$AppDatabase, $TranscriptsTable, Transcript>,
      ),
      Transcript,
      PrefetchHooks Function()
    >;
typedef $$SummariesTableCreateCompanionBuilder =
    SummariesCompanion Function({
      Value<int> id,
      Value<String?> serverId,
      Value<String?> recordingServerId,
      Value<String?> generationId,
      required String chapterClientUuid,
      required String contentMd,
      Value<String?> structuredJson,
      Value<String> status,
      Value<int> syncVersion,
    });
typedef $$SummariesTableUpdateCompanionBuilder =
    SummariesCompanion Function({
      Value<int> id,
      Value<String?> serverId,
      Value<String?> recordingServerId,
      Value<String?> generationId,
      Value<String> chapterClientUuid,
      Value<String> contentMd,
      Value<String?> structuredJson,
      Value<String> status,
      Value<int> syncVersion,
    });

class $$SummariesTableFilterComposer
    extends Composer<_$AppDatabase, $SummariesTable> {
  $$SummariesTableFilterComposer({
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

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordingServerId => $composableBuilder(
    column: $table.recordingServerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentMd => $composableBuilder(
    column: $table.contentMd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get structuredJson => $composableBuilder(
    column: $table.structuredJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $SummariesTable> {
  $$SummariesTableOrderingComposer({
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

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordingServerId => $composableBuilder(
    column: $table.recordingServerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentMd => $composableBuilder(
    column: $table.contentMd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get structuredJson => $composableBuilder(
    column: $table.structuredJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SummariesTable> {
  $$SummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get recordingServerId => $composableBuilder(
    column: $table.recordingServerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentMd =>
      $composableBuilder(column: $table.contentMd, builder: (column) => column);

  GeneratedColumn<String> get structuredJson => $composableBuilder(
    column: $table.structuredJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => column,
  );
}

class $$SummariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SummariesTable,
          Summary,
          $$SummariesTableFilterComposer,
          $$SummariesTableOrderingComposer,
          $$SummariesTableAnnotationComposer,
          $$SummariesTableCreateCompanionBuilder,
          $$SummariesTableUpdateCompanionBuilder,
          (Summary, BaseReferences<_$AppDatabase, $SummariesTable, Summary>),
          Summary,
          PrefetchHooks Function()
        > {
  $$SummariesTableTableManager(_$AppDatabase db, $SummariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String?> recordingServerId = const Value.absent(),
                Value<String?> generationId = const Value.absent(),
                Value<String> chapterClientUuid = const Value.absent(),
                Value<String> contentMd = const Value.absent(),
                Value<String?> structuredJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
              }) => SummariesCompanion(
                id: id,
                serverId: serverId,
                recordingServerId: recordingServerId,
                generationId: generationId,
                chapterClientUuid: chapterClientUuid,
                contentMd: contentMd,
                structuredJson: structuredJson,
                status: status,
                syncVersion: syncVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String?> recordingServerId = const Value.absent(),
                Value<String?> generationId = const Value.absent(),
                required String chapterClientUuid,
                required String contentMd,
                Value<String?> structuredJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
              }) => SummariesCompanion.insert(
                id: id,
                serverId: serverId,
                recordingServerId: recordingServerId,
                generationId: generationId,
                chapterClientUuid: chapterClientUuid,
                contentMd: contentMd,
                structuredJson: structuredJson,
                status: status,
                syncVersion: syncVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SummariesTable,
      Summary,
      $$SummariesTableFilterComposer,
      $$SummariesTableOrderingComposer,
      $$SummariesTableAnnotationComposer,
      $$SummariesTableCreateCompanionBuilder,
      $$SummariesTableUpdateCompanionBuilder,
      (Summary, BaseReferences<_$AppDatabase, $SummariesTable, Summary>),
      Summary,
      PrefetchHooks Function()
    >;
typedef $$ExercisesTableCreateCompanionBuilder =
    ExercisesCompanion Function({
      Value<int> id,
      Value<String?> serverId,
      Value<String?> recordingServerId,
      Value<String?> generationId,
      required String chapterClientUuid,
      required String itemsJson,
      Value<String> status,
      Value<int> syncVersion,
    });
typedef $$ExercisesTableUpdateCompanionBuilder =
    ExercisesCompanion Function({
      Value<int> id,
      Value<String?> serverId,
      Value<String?> recordingServerId,
      Value<String?> generationId,
      Value<String> chapterClientUuid,
      Value<String> itemsJson,
      Value<String> status,
      Value<int> syncVersion,
    });

class $$ExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableFilterComposer({
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

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordingServerId => $composableBuilder(
    column: $table.recordingServerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer({
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

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordingServerId => $composableBuilder(
    column: $table.recordingServerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get recordingServerId => $composableBuilder(
    column: $table.recordingServerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemsJson =>
      $composableBuilder(column: $table.itemsJson, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => column,
  );
}

class $$ExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExercisesTable,
          Exercise,
          $$ExercisesTableFilterComposer,
          $$ExercisesTableOrderingComposer,
          $$ExercisesTableAnnotationComposer,
          $$ExercisesTableCreateCompanionBuilder,
          $$ExercisesTableUpdateCompanionBuilder,
          (Exercise, BaseReferences<_$AppDatabase, $ExercisesTable, Exercise>),
          Exercise,
          PrefetchHooks Function()
        > {
  $$ExercisesTableTableManager(_$AppDatabase db, $ExercisesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String?> recordingServerId = const Value.absent(),
                Value<String?> generationId = const Value.absent(),
                Value<String> chapterClientUuid = const Value.absent(),
                Value<String> itemsJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
              }) => ExercisesCompanion(
                id: id,
                serverId: serverId,
                recordingServerId: recordingServerId,
                generationId: generationId,
                chapterClientUuid: chapterClientUuid,
                itemsJson: itemsJson,
                status: status,
                syncVersion: syncVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String?> recordingServerId = const Value.absent(),
                Value<String?> generationId = const Value.absent(),
                required String chapterClientUuid,
                required String itemsJson,
                Value<String> status = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
              }) => ExercisesCompanion.insert(
                id: id,
                serverId: serverId,
                recordingServerId: recordingServerId,
                generationId: generationId,
                chapterClientUuid: chapterClientUuid,
                itemsJson: itemsJson,
                status: status,
                syncVersion: syncVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExercisesTable,
      Exercise,
      $$ExercisesTableFilterComposer,
      $$ExercisesTableOrderingComposer,
      $$ExercisesTableAnnotationComposer,
      $$ExercisesTableCreateCompanionBuilder,
      $$ExercisesTableUpdateCompanionBuilder,
      (Exercise, BaseReferences<_$AppDatabase, $ExercisesTable, Exercise>),
      Exercise,
      PrefetchHooks Function()
    >;
typedef $$QuizzesTableCreateCompanionBuilder =
    QuizzesCompanion Function({
      Value<int> id,
      Value<String?> serverId,
      Value<String?> recordingServerId,
      Value<String?> generationId,
      required String chapterClientUuid,
      required String questionsJson,
      Value<String> status,
      Value<int> syncVersion,
    });
typedef $$QuizzesTableUpdateCompanionBuilder =
    QuizzesCompanion Function({
      Value<int> id,
      Value<String?> serverId,
      Value<String?> recordingServerId,
      Value<String?> generationId,
      Value<String> chapterClientUuid,
      Value<String> questionsJson,
      Value<String> status,
      Value<int> syncVersion,
    });

class $$QuizzesTableFilterComposer
    extends Composer<_$AppDatabase, $QuizzesTable> {
  $$QuizzesTableFilterComposer({
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

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordingServerId => $composableBuilder(
    column: $table.recordingServerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionsJson => $composableBuilder(
    column: $table.questionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuizzesTableOrderingComposer
    extends Composer<_$AppDatabase, $QuizzesTable> {
  $$QuizzesTableOrderingComposer({
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

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordingServerId => $composableBuilder(
    column: $table.recordingServerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionsJson => $composableBuilder(
    column: $table.questionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuizzesTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuizzesTable> {
  $$QuizzesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get recordingServerId => $composableBuilder(
    column: $table.recordingServerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get generationId => $composableBuilder(
    column: $table.generationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get questionsJson => $composableBuilder(
    column: $table.questionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => column,
  );
}

class $$QuizzesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuizzesTable,
          Quizze,
          $$QuizzesTableFilterComposer,
          $$QuizzesTableOrderingComposer,
          $$QuizzesTableAnnotationComposer,
          $$QuizzesTableCreateCompanionBuilder,
          $$QuizzesTableUpdateCompanionBuilder,
          (Quizze, BaseReferences<_$AppDatabase, $QuizzesTable, Quizze>),
          Quizze,
          PrefetchHooks Function()
        > {
  $$QuizzesTableTableManager(_$AppDatabase db, $QuizzesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuizzesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuizzesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuizzesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String?> recordingServerId = const Value.absent(),
                Value<String?> generationId = const Value.absent(),
                Value<String> chapterClientUuid = const Value.absent(),
                Value<String> questionsJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
              }) => QuizzesCompanion(
                id: id,
                serverId: serverId,
                recordingServerId: recordingServerId,
                generationId: generationId,
                chapterClientUuid: chapterClientUuid,
                questionsJson: questionsJson,
                status: status,
                syncVersion: syncVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String?> recordingServerId = const Value.absent(),
                Value<String?> generationId = const Value.absent(),
                required String chapterClientUuid,
                required String questionsJson,
                Value<String> status = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
              }) => QuizzesCompanion.insert(
                id: id,
                serverId: serverId,
                recordingServerId: recordingServerId,
                generationId: generationId,
                chapterClientUuid: chapterClientUuid,
                questionsJson: questionsJson,
                status: status,
                syncVersion: syncVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuizzesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuizzesTable,
      Quizze,
      $$QuizzesTableFilterComposer,
      $$QuizzesTableOrderingComposer,
      $$QuizzesTableAnnotationComposer,
      $$QuizzesTableCreateCompanionBuilder,
      $$QuizzesTableUpdateCompanionBuilder,
      (Quizze, BaseReferences<_$AppDatabase, $QuizzesTable, Quizze>),
      Quizze,
      PrefetchHooks Function()
    >;
typedef $$QuizAttemptsTableCreateCompanionBuilder =
    QuizAttemptsCompanion Function({
      Value<int> id,
      required String clientUuid,
      Value<String?> serverId,
      required String quizServerId,
      required String chapterClientUuid,
      required int score,
      required int total,
      required String answersJson,
      Value<bool> pendingSync,
      Value<DateTime> takenAt,
    });
typedef $$QuizAttemptsTableUpdateCompanionBuilder =
    QuizAttemptsCompanion Function({
      Value<int> id,
      Value<String> clientUuid,
      Value<String?> serverId,
      Value<String> quizServerId,
      Value<String> chapterClientUuid,
      Value<int> score,
      Value<int> total,
      Value<String> answersJson,
      Value<bool> pendingSync,
      Value<DateTime> takenAt,
    });

class $$QuizAttemptsTableFilterComposer
    extends Composer<_$AppDatabase, $QuizAttemptsTable> {
  $$QuizAttemptsTableFilterComposer({
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

  ColumnFilters<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quizServerId => $composableBuilder(
    column: $table.quizServerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answersJson => $composableBuilder(
    column: $table.answersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuizAttemptsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuizAttemptsTable> {
  $$QuizAttemptsTableOrderingComposer({
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

  ColumnOrderings<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quizServerId => $composableBuilder(
    column: $table.quizServerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answersJson => $composableBuilder(
    column: $table.answersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuizAttemptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuizAttemptsTable> {
  $$QuizAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get quizServerId => $composableBuilder(
    column: $table.quizServerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterClientUuid => $composableBuilder(
    column: $table.chapterClientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get answersJson => $composableBuilder(
    column: $table.answersJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pendingSync => $composableBuilder(
    column: $table.pendingSync,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);
}

class $$QuizAttemptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuizAttemptsTable,
          QuizAttempt,
          $$QuizAttemptsTableFilterComposer,
          $$QuizAttemptsTableOrderingComposer,
          $$QuizAttemptsTableAnnotationComposer,
          $$QuizAttemptsTableCreateCompanionBuilder,
          $$QuizAttemptsTableUpdateCompanionBuilder,
          (
            QuizAttempt,
            BaseReferences<_$AppDatabase, $QuizAttemptsTable, QuizAttempt>,
          ),
          QuizAttempt,
          PrefetchHooks Function()
        > {
  $$QuizAttemptsTableTableManager(_$AppDatabase db, $QuizAttemptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuizAttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuizAttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuizAttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> quizServerId = const Value.absent(),
                Value<String> chapterClientUuid = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<String> answersJson = const Value.absent(),
                Value<bool> pendingSync = const Value.absent(),
                Value<DateTime> takenAt = const Value.absent(),
              }) => QuizAttemptsCompanion(
                id: id,
                clientUuid: clientUuid,
                serverId: serverId,
                quizServerId: quizServerId,
                chapterClientUuid: chapterClientUuid,
                score: score,
                total: total,
                answersJson: answersJson,
                pendingSync: pendingSync,
                takenAt: takenAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientUuid,
                Value<String?> serverId = const Value.absent(),
                required String quizServerId,
                required String chapterClientUuid,
                required int score,
                required int total,
                required String answersJson,
                Value<bool> pendingSync = const Value.absent(),
                Value<DateTime> takenAt = const Value.absent(),
              }) => QuizAttemptsCompanion.insert(
                id: id,
                clientUuid: clientUuid,
                serverId: serverId,
                quizServerId: quizServerId,
                chapterClientUuid: chapterClientUuid,
                score: score,
                total: total,
                answersJson: answersJson,
                pendingSync: pendingSync,
                takenAt: takenAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuizAttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuizAttemptsTable,
      QuizAttempt,
      $$QuizAttemptsTableFilterComposer,
      $$QuizAttemptsTableOrderingComposer,
      $$QuizAttemptsTableAnnotationComposer,
      $$QuizAttemptsTableCreateCompanionBuilder,
      $$QuizAttemptsTableUpdateCompanionBuilder,
      (
        QuizAttempt,
        BaseReferences<_$AppDatabase, $QuizAttemptsTable, QuizAttempt>,
      ),
      QuizAttempt,
      PrefetchHooks Function()
    >;
typedef $$MetaTableCreateCompanionBuilder =
    MetaCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$MetaTableUpdateCompanionBuilder =
    MetaCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$MetaTableFilterComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableFilterComposer({
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

class $$MetaTableOrderingComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableOrderingComposer({
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

class $$MetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableAnnotationComposer({
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

class $$MetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetaTable,
          MetaData,
          $$MetaTableFilterComposer,
          $$MetaTableOrderingComposer,
          $$MetaTableAnnotationComposer,
          $$MetaTableCreateCompanionBuilder,
          $$MetaTableUpdateCompanionBuilder,
          (MetaData, BaseReferences<_$AppDatabase, $MetaTable, MetaData>),
          MetaData,
          PrefetchHooks Function()
        > {
  $$MetaTableTableManager(_$AppDatabase db, $MetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetaTable,
      MetaData,
      $$MetaTableFilterComposer,
      $$MetaTableOrderingComposer,
      $$MetaTableAnnotationComposer,
      $$MetaTableCreateCompanionBuilder,
      $$MetaTableUpdateCompanionBuilder,
      (MetaData, BaseReferences<_$AppDatabase, $MetaTable, MetaData>),
      MetaData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db, _db.courses);
  $$LessonsTableTableManager get lessons =>
      $$LessonsTableTableManager(_db, _db.lessons);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db, _db.chapters);
  $$AgendaItemsTableTableManager get agendaItems =>
      $$AgendaItemsTableTableManager(_db, _db.agendaItems);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db, _db.recordings);
  $$TranscriptsTableTableManager get transcripts =>
      $$TranscriptsTableTableManager(_db, _db.transcripts);
  $$SummariesTableTableManager get summaries =>
      $$SummariesTableTableManager(_db, _db.summaries);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db, _db.exercises);
  $$QuizzesTableTableManager get quizzes =>
      $$QuizzesTableTableManager(_db, _db.quizzes);
  $$QuizAttemptsTableTableManager get quizAttempts =>
      $$QuizAttemptsTableTableManager(_db, _db.quizAttempts);
  $$MetaTableTableManager get meta => $$MetaTableTableManager(_db, _db.meta);
}
