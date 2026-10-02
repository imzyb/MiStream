// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ConfigSourcesTable extends ConfigSources
    with TableInfo<$ConfigSourcesTable, ConfigSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConfigSourcesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawHashMeta = const VerificationMeta(
    'rawHash',
  );
  @override
  late final GeneratedColumn<String> rawHash = GeneratedColumn<String>(
    'raw_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spiderMeta = const VerificationMeta('spider');
  @override
  late final GeneratedColumn<String> spider = GeneratedColumn<String>(
    'spider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _spiderMd5Meta = const VerificationMeta(
    'spiderMd5',
  );
  @override
  late final GeneratedColumn<String> spiderMd5 = GeneratedColumn<String>(
    'spider_md5',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _autoUpdateMeta = const VerificationMeta(
    'autoUpdate',
  );
  @override
  late final GeneratedColumn<bool> autoUpdate = GeneratedColumn<bool>(
    'auto_update',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_update" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updateIntervalHMeta = const VerificationMeta(
    'updateIntervalH',
  );
  @override
  late final GeneratedColumn<int> updateIntervalH = GeneratedColumn<int>(
    'update_interval_h',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(24),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastSyncAt =
      GeneratedColumn<int>(
        'last_sync_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($ConfigSourcesTable.$converterlastSyncAtn);
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ConfigSourcesTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ConfigSourcesTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    url,
    localPath,
    rawHash,
    spider,
    spiderMd5,
    format,
    autoUpdate,
    updateIntervalH,
    lastSyncAt,
    lastError,
    sortOrder,
    enabled,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'config_source';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConfigSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('raw_hash')) {
      context.handle(
        _rawHashMeta,
        rawHash.isAcceptableOrUnknown(data['raw_hash']!, _rawHashMeta),
      );
    } else if (isInserting) {
      context.missing(_rawHashMeta);
    }
    if (data.containsKey('spider')) {
      context.handle(
        _spiderMeta,
        spider.isAcceptableOrUnknown(data['spider']!, _spiderMeta),
      );
    }
    if (data.containsKey('spider_md5')) {
      context.handle(
        _spiderMd5Meta,
        spiderMd5.isAcceptableOrUnknown(data['spider_md5']!, _spiderMd5Meta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('auto_update')) {
      context.handle(
        _autoUpdateMeta,
        autoUpdate.isAcceptableOrUnknown(data['auto_update']!, _autoUpdateMeta),
      );
    }
    if (data.containsKey('update_interval_h')) {
      context.handle(
        _updateIntervalHMeta,
        updateIntervalH.isAcceptableOrUnknown(
          data['update_interval_h']!,
          _updateIntervalHMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConfigSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConfigSource(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      rawHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_hash'],
      )!,
      spider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spider'],
      ),
      spiderMd5: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spider_md5'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      autoUpdate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_update'],
      )!,
      updateIntervalH: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}update_interval_h'],
      )!,
      lastSyncAt: $ConfigSourcesTable.$converterlastSyncAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_sync_at'],
        ),
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      createdAt: $ConfigSourcesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $ConfigSourcesTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $ConfigSourcesTable createAlias(String alias) {
    return $ConfigSourcesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterlastSyncAt = utcMillis;
  static TypeConverter<DateTime?, int?> $converterlastSyncAtn =
      NullAwareTypeConverter.wrap($converterlastSyncAt);
  static TypeConverter<DateTime, int> $convertercreatedAt = utcMillis;
  static TypeConverter<DateTime, int> $converterupdatedAt = utcMillis;
}

class ConfigSource extends DataClass implements Insertable<ConfigSource> {
  final int id;
  final String name;
  final String? url;
  final String? localPath;
  final String rawHash;
  final String? spider;
  final String? spiderMd5;
  final String format;
  final bool autoUpdate;
  final int updateIntervalH;
  final DateTime? lastSyncAt;
  final String? lastError;
  final int sortOrder;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ConfigSource({
    required this.id,
    required this.name,
    this.url,
    this.localPath,
    required this.rawHash,
    this.spider,
    this.spiderMd5,
    required this.format,
    required this.autoUpdate,
    required this.updateIntervalH,
    this.lastSyncAt,
    this.lastError,
    required this.sortOrder,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['raw_hash'] = Variable<String>(rawHash);
    if (!nullToAbsent || spider != null) {
      map['spider'] = Variable<String>(spider);
    }
    if (!nullToAbsent || spiderMd5 != null) {
      map['spider_md5'] = Variable<String>(spiderMd5);
    }
    map['format'] = Variable<String>(format);
    map['auto_update'] = Variable<bool>(autoUpdate);
    map['update_interval_h'] = Variable<int>(updateIntervalH);
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<int>(
        $ConfigSourcesTable.$converterlastSyncAtn.toSql(lastSyncAt),
      );
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['enabled'] = Variable<bool>(enabled);
    {
      map['created_at'] = Variable<int>(
        $ConfigSourcesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $ConfigSourcesTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  ConfigSourcesCompanion toCompanion(bool nullToAbsent) {
    return ConfigSourcesCompanion(
      id: Value(id),
      name: Value(name),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      rawHash: Value(rawHash),
      spider: spider == null && nullToAbsent
          ? const Value.absent()
          : Value(spider),
      spiderMd5: spiderMd5 == null && nullToAbsent
          ? const Value.absent()
          : Value(spiderMd5),
      format: Value(format),
      autoUpdate: Value(autoUpdate),
      updateIntervalH: Value(updateIntervalH),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      sortOrder: Value(sortOrder),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ConfigSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConfigSource(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      url: serializer.fromJson<String?>(json['url']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      rawHash: serializer.fromJson<String>(json['rawHash']),
      spider: serializer.fromJson<String?>(json['spider']),
      spiderMd5: serializer.fromJson<String?>(json['spiderMd5']),
      format: serializer.fromJson<String>(json['format']),
      autoUpdate: serializer.fromJson<bool>(json['autoUpdate']),
      updateIntervalH: serializer.fromJson<int>(json['updateIntervalH']),
      lastSyncAt: serializer.fromJson<DateTime?>(json['lastSyncAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'url': serializer.toJson<String?>(url),
      'localPath': serializer.toJson<String?>(localPath),
      'rawHash': serializer.toJson<String>(rawHash),
      'spider': serializer.toJson<String?>(spider),
      'spiderMd5': serializer.toJson<String?>(spiderMd5),
      'format': serializer.toJson<String>(format),
      'autoUpdate': serializer.toJson<bool>(autoUpdate),
      'updateIntervalH': serializer.toJson<int>(updateIntervalH),
      'lastSyncAt': serializer.toJson<DateTime?>(lastSyncAt),
      'lastError': serializer.toJson<String?>(lastError),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ConfigSource copyWith({
    int? id,
    String? name,
    Value<String?> url = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    String? rawHash,
    Value<String?> spider = const Value.absent(),
    Value<String?> spiderMd5 = const Value.absent(),
    String? format,
    bool? autoUpdate,
    int? updateIntervalH,
    Value<DateTime?> lastSyncAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    int? sortOrder,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ConfigSource(
    id: id ?? this.id,
    name: name ?? this.name,
    url: url.present ? url.value : this.url,
    localPath: localPath.present ? localPath.value : this.localPath,
    rawHash: rawHash ?? this.rawHash,
    spider: spider.present ? spider.value : this.spider,
    spiderMd5: spiderMd5.present ? spiderMd5.value : this.spiderMd5,
    format: format ?? this.format,
    autoUpdate: autoUpdate ?? this.autoUpdate,
    updateIntervalH: updateIntervalH ?? this.updateIntervalH,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    sortOrder: sortOrder ?? this.sortOrder,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ConfigSource copyWithCompanion(ConfigSourcesCompanion data) {
    return ConfigSource(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      url: data.url.present ? data.url.value : this.url,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      rawHash: data.rawHash.present ? data.rawHash.value : this.rawHash,
      spider: data.spider.present ? data.spider.value : this.spider,
      spiderMd5: data.spiderMd5.present ? data.spiderMd5.value : this.spiderMd5,
      format: data.format.present ? data.format.value : this.format,
      autoUpdate: data.autoUpdate.present
          ? data.autoUpdate.value
          : this.autoUpdate,
      updateIntervalH: data.updateIntervalH.present
          ? data.updateIntervalH.value
          : this.updateIntervalH,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConfigSource(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('localPath: $localPath, ')
          ..write('rawHash: $rawHash, ')
          ..write('spider: $spider, ')
          ..write('spiderMd5: $spiderMd5, ')
          ..write('format: $format, ')
          ..write('autoUpdate: $autoUpdate, ')
          ..write('updateIntervalH: $updateIntervalH, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastError: $lastError, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    url,
    localPath,
    rawHash,
    spider,
    spiderMd5,
    format,
    autoUpdate,
    updateIntervalH,
    lastSyncAt,
    lastError,
    sortOrder,
    enabled,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigSource &&
          other.id == this.id &&
          other.name == this.name &&
          other.url == this.url &&
          other.localPath == this.localPath &&
          other.rawHash == this.rawHash &&
          other.spider == this.spider &&
          other.spiderMd5 == this.spiderMd5 &&
          other.format == this.format &&
          other.autoUpdate == this.autoUpdate &&
          other.updateIntervalH == this.updateIntervalH &&
          other.lastSyncAt == this.lastSyncAt &&
          other.lastError == this.lastError &&
          other.sortOrder == this.sortOrder &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConfigSourcesCompanion extends UpdateCompanion<ConfigSource> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> url;
  final Value<String?> localPath;
  final Value<String> rawHash;
  final Value<String?> spider;
  final Value<String?> spiderMd5;
  final Value<String> format;
  final Value<bool> autoUpdate;
  final Value<int> updateIntervalH;
  final Value<DateTime?> lastSyncAt;
  final Value<String?> lastError;
  final Value<int> sortOrder;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ConfigSourcesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.url = const Value.absent(),
    this.localPath = const Value.absent(),
    this.rawHash = const Value.absent(),
    this.spider = const Value.absent(),
    this.spiderMd5 = const Value.absent(),
    this.format = const Value.absent(),
    this.autoUpdate = const Value.absent(),
    this.updateIntervalH = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ConfigSourcesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.url = const Value.absent(),
    this.localPath = const Value.absent(),
    required String rawHash,
    this.spider = const Value.absent(),
    this.spiderMd5 = const Value.absent(),
    required String format,
    this.autoUpdate = const Value.absent(),
    this.updateIntervalH = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.enabled = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : name = Value(name),
       rawHash = Value(rawHash),
       format = Value(format),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ConfigSource> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? url,
    Expression<String>? localPath,
    Expression<String>? rawHash,
    Expression<String>? spider,
    Expression<String>? spiderMd5,
    Expression<String>? format,
    Expression<bool>? autoUpdate,
    Expression<int>? updateIntervalH,
    Expression<int>? lastSyncAt,
    Expression<String>? lastError,
    Expression<int>? sortOrder,
    Expression<bool>? enabled,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (url != null) 'url': url,
      if (localPath != null) 'local_path': localPath,
      if (rawHash != null) 'raw_hash': rawHash,
      if (spider != null) 'spider': spider,
      if (spiderMd5 != null) 'spider_md5': spiderMd5,
      if (format != null) 'format': format,
      if (autoUpdate != null) 'auto_update': autoUpdate,
      if (updateIntervalH != null) 'update_interval_h': updateIntervalH,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (lastError != null) 'last_error': lastError,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ConfigSourcesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? url,
    Value<String?>? localPath,
    Value<String>? rawHash,
    Value<String?>? spider,
    Value<String?>? spiderMd5,
    Value<String>? format,
    Value<bool>? autoUpdate,
    Value<int>? updateIntervalH,
    Value<DateTime?>? lastSyncAt,
    Value<String?>? lastError,
    Value<int>? sortOrder,
    Value<bool>? enabled,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ConfigSourcesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      localPath: localPath ?? this.localPath,
      rawHash: rawHash ?? this.rawHash,
      spider: spider ?? this.spider,
      spiderMd5: spiderMd5 ?? this.spiderMd5,
      format: format ?? this.format,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      updateIntervalH: updateIntervalH ?? this.updateIntervalH,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: lastError ?? this.lastError,
      sortOrder: sortOrder ?? this.sortOrder,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (rawHash.present) {
      map['raw_hash'] = Variable<String>(rawHash.value);
    }
    if (spider.present) {
      map['spider'] = Variable<String>(spider.value);
    }
    if (spiderMd5.present) {
      map['spider_md5'] = Variable<String>(spiderMd5.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (autoUpdate.present) {
      map['auto_update'] = Variable<bool>(autoUpdate.value);
    }
    if (updateIntervalH.present) {
      map['update_interval_h'] = Variable<int>(updateIntervalH.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<int>(
        $ConfigSourcesTable.$converterlastSyncAtn.toSql(lastSyncAt.value),
      );
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $ConfigSourcesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $ConfigSourcesTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConfigSourcesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('localPath: $localPath, ')
          ..write('rawHash: $rawHash, ')
          ..write('spider: $spider, ')
          ..write('spiderMd5: $spiderMd5, ')
          ..write('format: $format, ')
          ..write('autoUpdate: $autoUpdate, ')
          ..write('updateIntervalH: $updateIntervalH, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastError: $lastError, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PluginsTable extends Plugins with TableInfo<$PluginsTable, Plugin> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PluginsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pluginIdMeta = const VerificationMeta(
    'pluginId',
  );
  @override
  late final GeneratedColumn<String> pluginId = GeneratedColumn<String>(
    'plugin_id',
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
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prevVersionMeta = const VerificationMeta(
    'prevVersion',
  );
  @override
  late final GeneratedColumn<String> prevVersion = GeneratedColumn<String>(
    'prev_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runtimeMeta = const VerificationMeta(
    'runtime',
  );
  @override
  late final GeneratedColumn<String> runtime = GeneratedColumn<String>(
    'runtime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _installPathMeta = const VerificationMeta(
    'installPath',
  );
  @override
  late final GeneratedColumn<String> installPath = GeneratedColumn<String>(
    'install_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMarketMeta = const VerificationMeta(
    'sourceMarket',
  );
  @override
  late final GeneratedColumn<String> sourceMarket = GeneratedColumn<String>(
    'source_market',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _manifestJsonMeta = const VerificationMeta(
    'manifestJson',
  );
  @override
  late final GeneratedColumn<String> manifestJson = GeneratedColumn<String>(
    'manifest_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _grantedPermissionsMeta =
      const VerificationMeta('grantedPermissions');
  @override
  late final GeneratedColumn<String> grantedPermissions =
      GeneratedColumn<String>(
        'granted_permissions',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  static const VerificationMeta _integrityHashMeta = const VerificationMeta(
    'integrityHash',
  );
  @override
  late final GeneratedColumn<String> integrityHash = GeneratedColumn<String>(
    'integrity_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signatureStatusMeta = const VerificationMeta(
    'signatureStatus',
  );
  @override
  late final GeneratedColumn<String> signatureStatus = GeneratedColumn<String>(
    'signature_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unsigned'),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> installedAt =
      GeneratedColumn<int>(
        'installed_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($PluginsTable.$converterinstalledAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($PluginsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    pluginId,
    name,
    version,
    prevVersion,
    type,
    runtime,
    installPath,
    sourceMarket,
    manifestJson,
    grantedPermissions,
    integrityHash,
    signatureStatus,
    enabled,
    installedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plugin';
  @override
  VerificationContext validateIntegrity(
    Insertable<Plugin> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('plugin_id')) {
      context.handle(
        _pluginIdMeta,
        pluginId.isAcceptableOrUnknown(data['plugin_id']!, _pluginIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pluginIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('prev_version')) {
      context.handle(
        _prevVersionMeta,
        prevVersion.isAcceptableOrUnknown(
          data['prev_version']!,
          _prevVersionMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('runtime')) {
      context.handle(
        _runtimeMeta,
        runtime.isAcceptableOrUnknown(data['runtime']!, _runtimeMeta),
      );
    }
    if (data.containsKey('install_path')) {
      context.handle(
        _installPathMeta,
        installPath.isAcceptableOrUnknown(
          data['install_path']!,
          _installPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_installPathMeta);
    }
    if (data.containsKey('source_market')) {
      context.handle(
        _sourceMarketMeta,
        sourceMarket.isAcceptableOrUnknown(
          data['source_market']!,
          _sourceMarketMeta,
        ),
      );
    }
    if (data.containsKey('manifest_json')) {
      context.handle(
        _manifestJsonMeta,
        manifestJson.isAcceptableOrUnknown(
          data['manifest_json']!,
          _manifestJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manifestJsonMeta);
    }
    if (data.containsKey('granted_permissions')) {
      context.handle(
        _grantedPermissionsMeta,
        grantedPermissions.isAcceptableOrUnknown(
          data['granted_permissions']!,
          _grantedPermissionsMeta,
        ),
      );
    }
    if (data.containsKey('integrity_hash')) {
      context.handle(
        _integrityHashMeta,
        integrityHash.isAcceptableOrUnknown(
          data['integrity_hash']!,
          _integrityHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_integrityHashMeta);
    }
    if (data.containsKey('signature_status')) {
      context.handle(
        _signatureStatusMeta,
        signatureStatus.isAcceptableOrUnknown(
          data['signature_status']!,
          _signatureStatusMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pluginId};
  @override
  Plugin map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Plugin(
      pluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      prevVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prev_version'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      runtime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}runtime'],
      ),
      installPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}install_path'],
      )!,
      sourceMarket: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_market'],
      ),
      manifestJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_json'],
      )!,
      grantedPermissions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}granted_permissions'],
      )!,
      integrityHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}integrity_hash'],
      )!,
      signatureStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature_status'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      installedAt: $PluginsTable.$converterinstalledAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}installed_at'],
        )!,
      ),
      updatedAt: $PluginsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $PluginsTable createAlias(String alias) {
    return $PluginsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterinstalledAt = utcMillis;
  static TypeConverter<DateTime, int> $converterupdatedAt = utcMillis;
}

class Plugin extends DataClass implements Insertable<Plugin> {
  final String pluginId;
  final String name;
  final String version;
  final String? prevVersion;
  final String type;
  final String? runtime;
  final String installPath;
  final String? sourceMarket;
  final String manifestJson;
  final String grantedPermissions;
  final String integrityHash;
  final String signatureStatus;
  final bool enabled;
  final DateTime installedAt;
  final DateTime updatedAt;
  const Plugin({
    required this.pluginId,
    required this.name,
    required this.version,
    this.prevVersion,
    required this.type,
    this.runtime,
    required this.installPath,
    this.sourceMarket,
    required this.manifestJson,
    required this.grantedPermissions,
    required this.integrityHash,
    required this.signatureStatus,
    required this.enabled,
    required this.installedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['plugin_id'] = Variable<String>(pluginId);
    map['name'] = Variable<String>(name);
    map['version'] = Variable<String>(version);
    if (!nullToAbsent || prevVersion != null) {
      map['prev_version'] = Variable<String>(prevVersion);
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || runtime != null) {
      map['runtime'] = Variable<String>(runtime);
    }
    map['install_path'] = Variable<String>(installPath);
    if (!nullToAbsent || sourceMarket != null) {
      map['source_market'] = Variable<String>(sourceMarket);
    }
    map['manifest_json'] = Variable<String>(manifestJson);
    map['granted_permissions'] = Variable<String>(grantedPermissions);
    map['integrity_hash'] = Variable<String>(integrityHash);
    map['signature_status'] = Variable<String>(signatureStatus);
    map['enabled'] = Variable<bool>(enabled);
    {
      map['installed_at'] = Variable<int>(
        $PluginsTable.$converterinstalledAt.toSql(installedAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $PluginsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  PluginsCompanion toCompanion(bool nullToAbsent) {
    return PluginsCompanion(
      pluginId: Value(pluginId),
      name: Value(name),
      version: Value(version),
      prevVersion: prevVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(prevVersion),
      type: Value(type),
      runtime: runtime == null && nullToAbsent
          ? const Value.absent()
          : Value(runtime),
      installPath: Value(installPath),
      sourceMarket: sourceMarket == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceMarket),
      manifestJson: Value(manifestJson),
      grantedPermissions: Value(grantedPermissions),
      integrityHash: Value(integrityHash),
      signatureStatus: Value(signatureStatus),
      enabled: Value(enabled),
      installedAt: Value(installedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Plugin.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Plugin(
      pluginId: serializer.fromJson<String>(json['pluginId']),
      name: serializer.fromJson<String>(json['name']),
      version: serializer.fromJson<String>(json['version']),
      prevVersion: serializer.fromJson<String?>(json['prevVersion']),
      type: serializer.fromJson<String>(json['type']),
      runtime: serializer.fromJson<String?>(json['runtime']),
      installPath: serializer.fromJson<String>(json['installPath']),
      sourceMarket: serializer.fromJson<String?>(json['sourceMarket']),
      manifestJson: serializer.fromJson<String>(json['manifestJson']),
      grantedPermissions: serializer.fromJson<String>(
        json['grantedPermissions'],
      ),
      integrityHash: serializer.fromJson<String>(json['integrityHash']),
      signatureStatus: serializer.fromJson<String>(json['signatureStatus']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pluginId': serializer.toJson<String>(pluginId),
      'name': serializer.toJson<String>(name),
      'version': serializer.toJson<String>(version),
      'prevVersion': serializer.toJson<String?>(prevVersion),
      'type': serializer.toJson<String>(type),
      'runtime': serializer.toJson<String?>(runtime),
      'installPath': serializer.toJson<String>(installPath),
      'sourceMarket': serializer.toJson<String?>(sourceMarket),
      'manifestJson': serializer.toJson<String>(manifestJson),
      'grantedPermissions': serializer.toJson<String>(grantedPermissions),
      'integrityHash': serializer.toJson<String>(integrityHash),
      'signatureStatus': serializer.toJson<String>(signatureStatus),
      'enabled': serializer.toJson<bool>(enabled),
      'installedAt': serializer.toJson<DateTime>(installedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Plugin copyWith({
    String? pluginId,
    String? name,
    String? version,
    Value<String?> prevVersion = const Value.absent(),
    String? type,
    Value<String?> runtime = const Value.absent(),
    String? installPath,
    Value<String?> sourceMarket = const Value.absent(),
    String? manifestJson,
    String? grantedPermissions,
    String? integrityHash,
    String? signatureStatus,
    bool? enabled,
    DateTime? installedAt,
    DateTime? updatedAt,
  }) => Plugin(
    pluginId: pluginId ?? this.pluginId,
    name: name ?? this.name,
    version: version ?? this.version,
    prevVersion: prevVersion.present ? prevVersion.value : this.prevVersion,
    type: type ?? this.type,
    runtime: runtime.present ? runtime.value : this.runtime,
    installPath: installPath ?? this.installPath,
    sourceMarket: sourceMarket.present ? sourceMarket.value : this.sourceMarket,
    manifestJson: manifestJson ?? this.manifestJson,
    grantedPermissions: grantedPermissions ?? this.grantedPermissions,
    integrityHash: integrityHash ?? this.integrityHash,
    signatureStatus: signatureStatus ?? this.signatureStatus,
    enabled: enabled ?? this.enabled,
    installedAt: installedAt ?? this.installedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Plugin copyWithCompanion(PluginsCompanion data) {
    return Plugin(
      pluginId: data.pluginId.present ? data.pluginId.value : this.pluginId,
      name: data.name.present ? data.name.value : this.name,
      version: data.version.present ? data.version.value : this.version,
      prevVersion: data.prevVersion.present
          ? data.prevVersion.value
          : this.prevVersion,
      type: data.type.present ? data.type.value : this.type,
      runtime: data.runtime.present ? data.runtime.value : this.runtime,
      installPath: data.installPath.present
          ? data.installPath.value
          : this.installPath,
      sourceMarket: data.sourceMarket.present
          ? data.sourceMarket.value
          : this.sourceMarket,
      manifestJson: data.manifestJson.present
          ? data.manifestJson.value
          : this.manifestJson,
      grantedPermissions: data.grantedPermissions.present
          ? data.grantedPermissions.value
          : this.grantedPermissions,
      integrityHash: data.integrityHash.present
          ? data.integrityHash.value
          : this.integrityHash,
      signatureStatus: data.signatureStatus.present
          ? data.signatureStatus.value
          : this.signatureStatus,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Plugin(')
          ..write('pluginId: $pluginId, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('prevVersion: $prevVersion, ')
          ..write('type: $type, ')
          ..write('runtime: $runtime, ')
          ..write('installPath: $installPath, ')
          ..write('sourceMarket: $sourceMarket, ')
          ..write('manifestJson: $manifestJson, ')
          ..write('grantedPermissions: $grantedPermissions, ')
          ..write('integrityHash: $integrityHash, ')
          ..write('signatureStatus: $signatureStatus, ')
          ..write('enabled: $enabled, ')
          ..write('installedAt: $installedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    pluginId,
    name,
    version,
    prevVersion,
    type,
    runtime,
    installPath,
    sourceMarket,
    manifestJson,
    grantedPermissions,
    integrityHash,
    signatureStatus,
    enabled,
    installedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Plugin &&
          other.pluginId == this.pluginId &&
          other.name == this.name &&
          other.version == this.version &&
          other.prevVersion == this.prevVersion &&
          other.type == this.type &&
          other.runtime == this.runtime &&
          other.installPath == this.installPath &&
          other.sourceMarket == this.sourceMarket &&
          other.manifestJson == this.manifestJson &&
          other.grantedPermissions == this.grantedPermissions &&
          other.integrityHash == this.integrityHash &&
          other.signatureStatus == this.signatureStatus &&
          other.enabled == this.enabled &&
          other.installedAt == this.installedAt &&
          other.updatedAt == this.updatedAt);
}

class PluginsCompanion extends UpdateCompanion<Plugin> {
  final Value<String> pluginId;
  final Value<String> name;
  final Value<String> version;
  final Value<String?> prevVersion;
  final Value<String> type;
  final Value<String?> runtime;
  final Value<String> installPath;
  final Value<String?> sourceMarket;
  final Value<String> manifestJson;
  final Value<String> grantedPermissions;
  final Value<String> integrityHash;
  final Value<String> signatureStatus;
  final Value<bool> enabled;
  final Value<DateTime> installedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PluginsCompanion({
    this.pluginId = const Value.absent(),
    this.name = const Value.absent(),
    this.version = const Value.absent(),
    this.prevVersion = const Value.absent(),
    this.type = const Value.absent(),
    this.runtime = const Value.absent(),
    this.installPath = const Value.absent(),
    this.sourceMarket = const Value.absent(),
    this.manifestJson = const Value.absent(),
    this.grantedPermissions = const Value.absent(),
    this.integrityHash = const Value.absent(),
    this.signatureStatus = const Value.absent(),
    this.enabled = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PluginsCompanion.insert({
    required String pluginId,
    required String name,
    required String version,
    this.prevVersion = const Value.absent(),
    required String type,
    this.runtime = const Value.absent(),
    required String installPath,
    this.sourceMarket = const Value.absent(),
    required String manifestJson,
    this.grantedPermissions = const Value.absent(),
    required String integrityHash,
    this.signatureStatus = const Value.absent(),
    this.enabled = const Value.absent(),
    required DateTime installedAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : pluginId = Value(pluginId),
       name = Value(name),
       version = Value(version),
       type = Value(type),
       installPath = Value(installPath),
       manifestJson = Value(manifestJson),
       integrityHash = Value(integrityHash),
       installedAt = Value(installedAt),
       updatedAt = Value(updatedAt);
  static Insertable<Plugin> custom({
    Expression<String>? pluginId,
    Expression<String>? name,
    Expression<String>? version,
    Expression<String>? prevVersion,
    Expression<String>? type,
    Expression<String>? runtime,
    Expression<String>? installPath,
    Expression<String>? sourceMarket,
    Expression<String>? manifestJson,
    Expression<String>? grantedPermissions,
    Expression<String>? integrityHash,
    Expression<String>? signatureStatus,
    Expression<bool>? enabled,
    Expression<int>? installedAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pluginId != null) 'plugin_id': pluginId,
      if (name != null) 'name': name,
      if (version != null) 'version': version,
      if (prevVersion != null) 'prev_version': prevVersion,
      if (type != null) 'type': type,
      if (runtime != null) 'runtime': runtime,
      if (installPath != null) 'install_path': installPath,
      if (sourceMarket != null) 'source_market': sourceMarket,
      if (manifestJson != null) 'manifest_json': manifestJson,
      if (grantedPermissions != null) 'granted_permissions': grantedPermissions,
      if (integrityHash != null) 'integrity_hash': integrityHash,
      if (signatureStatus != null) 'signature_status': signatureStatus,
      if (enabled != null) 'enabled': enabled,
      if (installedAt != null) 'installed_at': installedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PluginsCompanion copyWith({
    Value<String>? pluginId,
    Value<String>? name,
    Value<String>? version,
    Value<String?>? prevVersion,
    Value<String>? type,
    Value<String?>? runtime,
    Value<String>? installPath,
    Value<String?>? sourceMarket,
    Value<String>? manifestJson,
    Value<String>? grantedPermissions,
    Value<String>? integrityHash,
    Value<String>? signatureStatus,
    Value<bool>? enabled,
    Value<DateTime>? installedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PluginsCompanion(
      pluginId: pluginId ?? this.pluginId,
      name: name ?? this.name,
      version: version ?? this.version,
      prevVersion: prevVersion ?? this.prevVersion,
      type: type ?? this.type,
      runtime: runtime ?? this.runtime,
      installPath: installPath ?? this.installPath,
      sourceMarket: sourceMarket ?? this.sourceMarket,
      manifestJson: manifestJson ?? this.manifestJson,
      grantedPermissions: grantedPermissions ?? this.grantedPermissions,
      integrityHash: integrityHash ?? this.integrityHash,
      signatureStatus: signatureStatus ?? this.signatureStatus,
      enabled: enabled ?? this.enabled,
      installedAt: installedAt ?? this.installedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pluginId.present) {
      map['plugin_id'] = Variable<String>(pluginId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (prevVersion.present) {
      map['prev_version'] = Variable<String>(prevVersion.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (runtime.present) {
      map['runtime'] = Variable<String>(runtime.value);
    }
    if (installPath.present) {
      map['install_path'] = Variable<String>(installPath.value);
    }
    if (sourceMarket.present) {
      map['source_market'] = Variable<String>(sourceMarket.value);
    }
    if (manifestJson.present) {
      map['manifest_json'] = Variable<String>(manifestJson.value);
    }
    if (grantedPermissions.present) {
      map['granted_permissions'] = Variable<String>(grantedPermissions.value);
    }
    if (integrityHash.present) {
      map['integrity_hash'] = Variable<String>(integrityHash.value);
    }
    if (signatureStatus.present) {
      map['signature_status'] = Variable<String>(signatureStatus.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<int>(
        $PluginsTable.$converterinstalledAt.toSql(installedAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $PluginsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PluginsCompanion(')
          ..write('pluginId: $pluginId, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('prevVersion: $prevVersion, ')
          ..write('type: $type, ')
          ..write('runtime: $runtime, ')
          ..write('installPath: $installPath, ')
          ..write('sourceMarket: $sourceMarket, ')
          ..write('manifestJson: $manifestJson, ')
          ..write('grantedPermissions: $grantedPermissions, ')
          ..write('integrityHash: $integrityHash, ')
          ..write('signatureStatus: $signatureStatus, ')
          ..write('enabled: $enabled, ')
          ..write('installedAt: $installedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SitesTable extends Sites with TableInfo<$SitesTable, Site> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SitesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _configIdMeta = const VerificationMeta(
    'configId',
  );
  @override
  late final GeneratedColumn<int> configId = GeneratedColumn<int>(
    'config_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES config_source (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pluginIdMeta = const VerificationMeta(
    'pluginId',
  );
  @override
  late final GeneratedColumn<String> pluginId = GeneratedColumn<String>(
    'plugin_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES plugin (plugin_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _siteKeyMeta = const VerificationMeta(
    'siteKey',
  );
  @override
  late final GeneratedColumn<String> siteKey = GeneratedColumn<String>(
    'site_key',
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
  static const VerificationMeta _typeCodeMeta = const VerificationMeta(
    'typeCode',
  );
  @override
  late final GeneratedColumn<int> typeCode = GeneratedColumn<int>(
    'type_code',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runtimeMeta = const VerificationMeta(
    'runtime',
  );
  @override
  late final GeneratedColumn<String> runtime = GeneratedColumn<String>(
    'runtime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _apiMeta = const VerificationMeta('api');
  @override
  late final GeneratedColumn<String> api = GeneratedColumn<String>(
    'api',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _extMeta = const VerificationMeta('ext');
  @override
  late final GeneratedColumn<String> ext = GeneratedColumn<String>(
    'ext',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _searchableMeta = const VerificationMeta(
    'searchable',
  );
  @override
  late final GeneratedColumn<bool> searchable = GeneratedColumn<bool>(
    'searchable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("searchable" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _quickSearchMeta = const VerificationMeta(
    'quickSearch',
  );
  @override
  late final GeneratedColumn<bool> quickSearch = GeneratedColumn<bool>(
    'quick_search',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("quick_search" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _filterableMeta = const VerificationMeta(
    'filterable',
  );
  @override
  late final GeneratedColumn<bool> filterable = GeneratedColumn<bool>(
    'filterable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("filterable" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  static const VerificationMeta _failCountMeta = const VerificationMeta(
    'failCount',
  );
  @override
  late final GeneratedColumn<int> failCount = GeneratedColumn<int>(
    'fail_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastOkAt =
      GeneratedColumn<int>(
        'last_ok_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($SitesTable.$converterlastOkAtn);
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastLatencyMsMeta = const VerificationMeta(
    'lastLatencyMs',
  );
  @override
  late final GeneratedColumn<int> lastLatencyMs = GeneratedColumn<int>(
    'last_latency_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($SitesTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($SitesTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    configId,
    pluginId,
    siteKey,
    name,
    typeCode,
    runtime,
    api,
    ext,
    searchable,
    quickSearch,
    filterable,
    enabled,
    priority,
    status,
    failCount,
    lastOkAt,
    lastError,
    lastLatencyMs,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'site';
  @override
  VerificationContext validateIntegrity(
    Insertable<Site> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('config_id')) {
      context.handle(
        _configIdMeta,
        configId.isAcceptableOrUnknown(data['config_id']!, _configIdMeta),
      );
    }
    if (data.containsKey('plugin_id')) {
      context.handle(
        _pluginIdMeta,
        pluginId.isAcceptableOrUnknown(data['plugin_id']!, _pluginIdMeta),
      );
    }
    if (data.containsKey('site_key')) {
      context.handle(
        _siteKeyMeta,
        siteKey.isAcceptableOrUnknown(data['site_key']!, _siteKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_siteKeyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type_code')) {
      context.handle(
        _typeCodeMeta,
        typeCode.isAcceptableOrUnknown(data['type_code']!, _typeCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeCodeMeta);
    }
    if (data.containsKey('runtime')) {
      context.handle(
        _runtimeMeta,
        runtime.isAcceptableOrUnknown(data['runtime']!, _runtimeMeta),
      );
    } else if (isInserting) {
      context.missing(_runtimeMeta);
    }
    if (data.containsKey('api')) {
      context.handle(
        _apiMeta,
        api.isAcceptableOrUnknown(data['api']!, _apiMeta),
      );
    } else if (isInserting) {
      context.missing(_apiMeta);
    }
    if (data.containsKey('ext')) {
      context.handle(
        _extMeta,
        ext.isAcceptableOrUnknown(data['ext']!, _extMeta),
      );
    }
    if (data.containsKey('searchable')) {
      context.handle(
        _searchableMeta,
        searchable.isAcceptableOrUnknown(data['searchable']!, _searchableMeta),
      );
    }
    if (data.containsKey('quick_search')) {
      context.handle(
        _quickSearchMeta,
        quickSearch.isAcceptableOrUnknown(
          data['quick_search']!,
          _quickSearchMeta,
        ),
      );
    }
    if (data.containsKey('filterable')) {
      context.handle(
        _filterableMeta,
        filterable.isAcceptableOrUnknown(data['filterable']!, _filterableMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('fail_count')) {
      context.handle(
        _failCountMeta,
        failCount.isAcceptableOrUnknown(data['fail_count']!, _failCountMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('last_latency_ms')) {
      context.handle(
        _lastLatencyMsMeta,
        lastLatencyMs.isAcceptableOrUnknown(
          data['last_latency_ms']!,
          _lastLatencyMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Site map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Site(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      configId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}config_id'],
      ),
      pluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_id'],
      ),
      siteKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}site_key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      typeCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_code'],
      )!,
      runtime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}runtime'],
      )!,
      api: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api'],
      )!,
      ext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ext'],
      ),
      searchable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}searchable'],
      )!,
      quickSearch: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}quick_search'],
      )!,
      filterable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}filterable'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      failCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fail_count'],
      )!,
      lastOkAt: $SitesTable.$converterlastOkAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_ok_at'],
        ),
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      lastLatencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_latency_ms'],
      ),
      createdAt: $SitesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $SitesTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $SitesTable createAlias(String alias) {
    return $SitesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterlastOkAt = utcMillis;
  static TypeConverter<DateTime?, int?> $converterlastOkAtn =
      NullAwareTypeConverter.wrap($converterlastOkAt);
  static TypeConverter<DateTime, int> $convertercreatedAt = utcMillis;
  static TypeConverter<DateTime, int> $converterupdatedAt = utcMillis;
}

class Site extends DataClass implements Insertable<Site> {
  final int id;
  final int? configId;
  final String? pluginId;
  final String siteKey;
  final String name;
  final int typeCode;
  final String runtime;
  final String api;
  final String? ext;
  final bool searchable;
  final bool quickSearch;
  final bool filterable;
  final bool enabled;
  final int priority;
  final String status;
  final int failCount;
  final DateTime? lastOkAt;
  final String? lastError;
  final int? lastLatencyMs;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Site({
    required this.id,
    this.configId,
    this.pluginId,
    required this.siteKey,
    required this.name,
    required this.typeCode,
    required this.runtime,
    required this.api,
    this.ext,
    required this.searchable,
    required this.quickSearch,
    required this.filterable,
    required this.enabled,
    required this.priority,
    required this.status,
    required this.failCount,
    this.lastOkAt,
    this.lastError,
    this.lastLatencyMs,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || configId != null) {
      map['config_id'] = Variable<int>(configId);
    }
    if (!nullToAbsent || pluginId != null) {
      map['plugin_id'] = Variable<String>(pluginId);
    }
    map['site_key'] = Variable<String>(siteKey);
    map['name'] = Variable<String>(name);
    map['type_code'] = Variable<int>(typeCode);
    map['runtime'] = Variable<String>(runtime);
    map['api'] = Variable<String>(api);
    if (!nullToAbsent || ext != null) {
      map['ext'] = Variable<String>(ext);
    }
    map['searchable'] = Variable<bool>(searchable);
    map['quick_search'] = Variable<bool>(quickSearch);
    map['filterable'] = Variable<bool>(filterable);
    map['enabled'] = Variable<bool>(enabled);
    map['priority'] = Variable<int>(priority);
    map['status'] = Variable<String>(status);
    map['fail_count'] = Variable<int>(failCount);
    if (!nullToAbsent || lastOkAt != null) {
      map['last_ok_at'] = Variable<int>(
        $SitesTable.$converterlastOkAtn.toSql(lastOkAt),
      );
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || lastLatencyMs != null) {
      map['last_latency_ms'] = Variable<int>(lastLatencyMs);
    }
    {
      map['created_at'] = Variable<int>(
        $SitesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $SitesTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  SitesCompanion toCompanion(bool nullToAbsent) {
    return SitesCompanion(
      id: Value(id),
      configId: configId == null && nullToAbsent
          ? const Value.absent()
          : Value(configId),
      pluginId: pluginId == null && nullToAbsent
          ? const Value.absent()
          : Value(pluginId),
      siteKey: Value(siteKey),
      name: Value(name),
      typeCode: Value(typeCode),
      runtime: Value(runtime),
      api: Value(api),
      ext: ext == null && nullToAbsent ? const Value.absent() : Value(ext),
      searchable: Value(searchable),
      quickSearch: Value(quickSearch),
      filterable: Value(filterable),
      enabled: Value(enabled),
      priority: Value(priority),
      status: Value(status),
      failCount: Value(failCount),
      lastOkAt: lastOkAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOkAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      lastLatencyMs: lastLatencyMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLatencyMs),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Site.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Site(
      id: serializer.fromJson<int>(json['id']),
      configId: serializer.fromJson<int?>(json['configId']),
      pluginId: serializer.fromJson<String?>(json['pluginId']),
      siteKey: serializer.fromJson<String>(json['siteKey']),
      name: serializer.fromJson<String>(json['name']),
      typeCode: serializer.fromJson<int>(json['typeCode']),
      runtime: serializer.fromJson<String>(json['runtime']),
      api: serializer.fromJson<String>(json['api']),
      ext: serializer.fromJson<String?>(json['ext']),
      searchable: serializer.fromJson<bool>(json['searchable']),
      quickSearch: serializer.fromJson<bool>(json['quickSearch']),
      filterable: serializer.fromJson<bool>(json['filterable']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      priority: serializer.fromJson<int>(json['priority']),
      status: serializer.fromJson<String>(json['status']),
      failCount: serializer.fromJson<int>(json['failCount']),
      lastOkAt: serializer.fromJson<DateTime?>(json['lastOkAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      lastLatencyMs: serializer.fromJson<int?>(json['lastLatencyMs']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'configId': serializer.toJson<int?>(configId),
      'pluginId': serializer.toJson<String?>(pluginId),
      'siteKey': serializer.toJson<String>(siteKey),
      'name': serializer.toJson<String>(name),
      'typeCode': serializer.toJson<int>(typeCode),
      'runtime': serializer.toJson<String>(runtime),
      'api': serializer.toJson<String>(api),
      'ext': serializer.toJson<String?>(ext),
      'searchable': serializer.toJson<bool>(searchable),
      'quickSearch': serializer.toJson<bool>(quickSearch),
      'filterable': serializer.toJson<bool>(filterable),
      'enabled': serializer.toJson<bool>(enabled),
      'priority': serializer.toJson<int>(priority),
      'status': serializer.toJson<String>(status),
      'failCount': serializer.toJson<int>(failCount),
      'lastOkAt': serializer.toJson<DateTime?>(lastOkAt),
      'lastError': serializer.toJson<String?>(lastError),
      'lastLatencyMs': serializer.toJson<int?>(lastLatencyMs),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Site copyWith({
    int? id,
    Value<int?> configId = const Value.absent(),
    Value<String?> pluginId = const Value.absent(),
    String? siteKey,
    String? name,
    int? typeCode,
    String? runtime,
    String? api,
    Value<String?> ext = const Value.absent(),
    bool? searchable,
    bool? quickSearch,
    bool? filterable,
    bool? enabled,
    int? priority,
    String? status,
    int? failCount,
    Value<DateTime?> lastOkAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    Value<int?> lastLatencyMs = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Site(
    id: id ?? this.id,
    configId: configId.present ? configId.value : this.configId,
    pluginId: pluginId.present ? pluginId.value : this.pluginId,
    siteKey: siteKey ?? this.siteKey,
    name: name ?? this.name,
    typeCode: typeCode ?? this.typeCode,
    runtime: runtime ?? this.runtime,
    api: api ?? this.api,
    ext: ext.present ? ext.value : this.ext,
    searchable: searchable ?? this.searchable,
    quickSearch: quickSearch ?? this.quickSearch,
    filterable: filterable ?? this.filterable,
    enabled: enabled ?? this.enabled,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    failCount: failCount ?? this.failCount,
    lastOkAt: lastOkAt.present ? lastOkAt.value : this.lastOkAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    lastLatencyMs: lastLatencyMs.present
        ? lastLatencyMs.value
        : this.lastLatencyMs,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Site copyWithCompanion(SitesCompanion data) {
    return Site(
      id: data.id.present ? data.id.value : this.id,
      configId: data.configId.present ? data.configId.value : this.configId,
      pluginId: data.pluginId.present ? data.pluginId.value : this.pluginId,
      siteKey: data.siteKey.present ? data.siteKey.value : this.siteKey,
      name: data.name.present ? data.name.value : this.name,
      typeCode: data.typeCode.present ? data.typeCode.value : this.typeCode,
      runtime: data.runtime.present ? data.runtime.value : this.runtime,
      api: data.api.present ? data.api.value : this.api,
      ext: data.ext.present ? data.ext.value : this.ext,
      searchable: data.searchable.present
          ? data.searchable.value
          : this.searchable,
      quickSearch: data.quickSearch.present
          ? data.quickSearch.value
          : this.quickSearch,
      filterable: data.filterable.present
          ? data.filterable.value
          : this.filterable,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      priority: data.priority.present ? data.priority.value : this.priority,
      status: data.status.present ? data.status.value : this.status,
      failCount: data.failCount.present ? data.failCount.value : this.failCount,
      lastOkAt: data.lastOkAt.present ? data.lastOkAt.value : this.lastOkAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      lastLatencyMs: data.lastLatencyMs.present
          ? data.lastLatencyMs.value
          : this.lastLatencyMs,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Site(')
          ..write('id: $id, ')
          ..write('configId: $configId, ')
          ..write('pluginId: $pluginId, ')
          ..write('siteKey: $siteKey, ')
          ..write('name: $name, ')
          ..write('typeCode: $typeCode, ')
          ..write('runtime: $runtime, ')
          ..write('api: $api, ')
          ..write('ext: $ext, ')
          ..write('searchable: $searchable, ')
          ..write('quickSearch: $quickSearch, ')
          ..write('filterable: $filterable, ')
          ..write('enabled: $enabled, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('failCount: $failCount, ')
          ..write('lastOkAt: $lastOkAt, ')
          ..write('lastError: $lastError, ')
          ..write('lastLatencyMs: $lastLatencyMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    configId,
    pluginId,
    siteKey,
    name,
    typeCode,
    runtime,
    api,
    ext,
    searchable,
    quickSearch,
    filterable,
    enabled,
    priority,
    status,
    failCount,
    lastOkAt,
    lastError,
    lastLatencyMs,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Site &&
          other.id == this.id &&
          other.configId == this.configId &&
          other.pluginId == this.pluginId &&
          other.siteKey == this.siteKey &&
          other.name == this.name &&
          other.typeCode == this.typeCode &&
          other.runtime == this.runtime &&
          other.api == this.api &&
          other.ext == this.ext &&
          other.searchable == this.searchable &&
          other.quickSearch == this.quickSearch &&
          other.filterable == this.filterable &&
          other.enabled == this.enabled &&
          other.priority == this.priority &&
          other.status == this.status &&
          other.failCount == this.failCount &&
          other.lastOkAt == this.lastOkAt &&
          other.lastError == this.lastError &&
          other.lastLatencyMs == this.lastLatencyMs &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SitesCompanion extends UpdateCompanion<Site> {
  final Value<int> id;
  final Value<int?> configId;
  final Value<String?> pluginId;
  final Value<String> siteKey;
  final Value<String> name;
  final Value<int> typeCode;
  final Value<String> runtime;
  final Value<String> api;
  final Value<String?> ext;
  final Value<bool> searchable;
  final Value<bool> quickSearch;
  final Value<bool> filterable;
  final Value<bool> enabled;
  final Value<int> priority;
  final Value<String> status;
  final Value<int> failCount;
  final Value<DateTime?> lastOkAt;
  final Value<String?> lastError;
  final Value<int?> lastLatencyMs;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const SitesCompanion({
    this.id = const Value.absent(),
    this.configId = const Value.absent(),
    this.pluginId = const Value.absent(),
    this.siteKey = const Value.absent(),
    this.name = const Value.absent(),
    this.typeCode = const Value.absent(),
    this.runtime = const Value.absent(),
    this.api = const Value.absent(),
    this.ext = const Value.absent(),
    this.searchable = const Value.absent(),
    this.quickSearch = const Value.absent(),
    this.filterable = const Value.absent(),
    this.enabled = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.failCount = const Value.absent(),
    this.lastOkAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.lastLatencyMs = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SitesCompanion.insert({
    this.id = const Value.absent(),
    this.configId = const Value.absent(),
    this.pluginId = const Value.absent(),
    required String siteKey,
    required String name,
    required int typeCode,
    required String runtime,
    required String api,
    this.ext = const Value.absent(),
    this.searchable = const Value.absent(),
    this.quickSearch = const Value.absent(),
    this.filterable = const Value.absent(),
    this.enabled = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.failCount = const Value.absent(),
    this.lastOkAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.lastLatencyMs = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : siteKey = Value(siteKey),
       name = Value(name),
       typeCode = Value(typeCode),
       runtime = Value(runtime),
       api = Value(api),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Site> custom({
    Expression<int>? id,
    Expression<int>? configId,
    Expression<String>? pluginId,
    Expression<String>? siteKey,
    Expression<String>? name,
    Expression<int>? typeCode,
    Expression<String>? runtime,
    Expression<String>? api,
    Expression<String>? ext,
    Expression<bool>? searchable,
    Expression<bool>? quickSearch,
    Expression<bool>? filterable,
    Expression<bool>? enabled,
    Expression<int>? priority,
    Expression<String>? status,
    Expression<int>? failCount,
    Expression<int>? lastOkAt,
    Expression<String>? lastError,
    Expression<int>? lastLatencyMs,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (configId != null) 'config_id': configId,
      if (pluginId != null) 'plugin_id': pluginId,
      if (siteKey != null) 'site_key': siteKey,
      if (name != null) 'name': name,
      if (typeCode != null) 'type_code': typeCode,
      if (runtime != null) 'runtime': runtime,
      if (api != null) 'api': api,
      if (ext != null) 'ext': ext,
      if (searchable != null) 'searchable': searchable,
      if (quickSearch != null) 'quick_search': quickSearch,
      if (filterable != null) 'filterable': filterable,
      if (enabled != null) 'enabled': enabled,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
      if (failCount != null) 'fail_count': failCount,
      if (lastOkAt != null) 'last_ok_at': lastOkAt,
      if (lastError != null) 'last_error': lastError,
      if (lastLatencyMs != null) 'last_latency_ms': lastLatencyMs,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SitesCompanion copyWith({
    Value<int>? id,
    Value<int?>? configId,
    Value<String?>? pluginId,
    Value<String>? siteKey,
    Value<String>? name,
    Value<int>? typeCode,
    Value<String>? runtime,
    Value<String>? api,
    Value<String?>? ext,
    Value<bool>? searchable,
    Value<bool>? quickSearch,
    Value<bool>? filterable,
    Value<bool>? enabled,
    Value<int>? priority,
    Value<String>? status,
    Value<int>? failCount,
    Value<DateTime?>? lastOkAt,
    Value<String?>? lastError,
    Value<int?>? lastLatencyMs,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return SitesCompanion(
      id: id ?? this.id,
      configId: configId ?? this.configId,
      pluginId: pluginId ?? this.pluginId,
      siteKey: siteKey ?? this.siteKey,
      name: name ?? this.name,
      typeCode: typeCode ?? this.typeCode,
      runtime: runtime ?? this.runtime,
      api: api ?? this.api,
      ext: ext ?? this.ext,
      searchable: searchable ?? this.searchable,
      quickSearch: quickSearch ?? this.quickSearch,
      filterable: filterable ?? this.filterable,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      failCount: failCount ?? this.failCount,
      lastOkAt: lastOkAt ?? this.lastOkAt,
      lastError: lastError ?? this.lastError,
      lastLatencyMs: lastLatencyMs ?? this.lastLatencyMs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (configId.present) {
      map['config_id'] = Variable<int>(configId.value);
    }
    if (pluginId.present) {
      map['plugin_id'] = Variable<String>(pluginId.value);
    }
    if (siteKey.present) {
      map['site_key'] = Variable<String>(siteKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (typeCode.present) {
      map['type_code'] = Variable<int>(typeCode.value);
    }
    if (runtime.present) {
      map['runtime'] = Variable<String>(runtime.value);
    }
    if (api.present) {
      map['api'] = Variable<String>(api.value);
    }
    if (ext.present) {
      map['ext'] = Variable<String>(ext.value);
    }
    if (searchable.present) {
      map['searchable'] = Variable<bool>(searchable.value);
    }
    if (quickSearch.present) {
      map['quick_search'] = Variable<bool>(quickSearch.value);
    }
    if (filterable.present) {
      map['filterable'] = Variable<bool>(filterable.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (failCount.present) {
      map['fail_count'] = Variable<int>(failCount.value);
    }
    if (lastOkAt.present) {
      map['last_ok_at'] = Variable<int>(
        $SitesTable.$converterlastOkAtn.toSql(lastOkAt.value),
      );
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (lastLatencyMs.present) {
      map['last_latency_ms'] = Variable<int>(lastLatencyMs.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $SitesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $SitesTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SitesCompanion(')
          ..write('id: $id, ')
          ..write('configId: $configId, ')
          ..write('pluginId: $pluginId, ')
          ..write('siteKey: $siteKey, ')
          ..write('name: $name, ')
          ..write('typeCode: $typeCode, ')
          ..write('runtime: $runtime, ')
          ..write('api: $api, ')
          ..write('ext: $ext, ')
          ..write('searchable: $searchable, ')
          ..write('quickSearch: $quickSearch, ')
          ..write('filterable: $filterable, ')
          ..write('enabled: $enabled, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('failCount: $failCount, ')
          ..write('lastOkAt: $lastOkAt, ')
          ..write('lastError: $lastError, ')
          ..write('lastLatencyMs: $lastLatencyMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $HistoriesTable extends Histories
    with TableInfo<$HistoriesTable, History> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _siteIdMeta = const VerificationMeta('siteId');
  @override
  late final GeneratedColumn<int> siteId = GeneratedColumn<int>(
    'site_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES site (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _vodIdMeta = const VerificationMeta('vodId');
  @override
  late final GeneratedColumn<String> vodId = GeneratedColumn<String>(
    'vod_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vodNameMeta = const VerificationMeta(
    'vodName',
  );
  @override
  late final GeneratedColumn<String> vodName = GeneratedColumn<String>(
    'vod_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vodPicMeta = const VerificationMeta('vodPic');
  @override
  late final GeneratedColumn<String> vodPic = GeneratedColumn<String>(
    'vod_pic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _flagMeta = const VerificationMeta('flag');
  @override
  late final GeneratedColumn<String> flag = GeneratedColumn<String>(
    'flag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeIndexMeta = const VerificationMeta(
    'episodeIndex',
  );
  @override
  late final GeneratedColumn<int> episodeIndex = GeneratedColumn<int>(
    'episode_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _episodeNameMeta = const VerificationMeta(
    'episodeName',
  );
  @override
  late final GeneratedColumn<String> episodeName = GeneratedColumn<String>(
    'episode_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _finishedMeta = const VerificationMeta(
    'finished',
  );
  @override
  late final GeneratedColumn<bool> finished = GeneratedColumn<bool>(
    'finished',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("finished" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _openingMsMeta = const VerificationMeta(
    'openingMs',
  );
  @override
  late final GeneratedColumn<int> openingMs = GeneratedColumn<int>(
    'opening_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endingMsMeta = const VerificationMeta(
    'endingMs',
  );
  @override
  late final GeneratedColumn<int> endingMs = GeneratedColumn<int>(
    'ending_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _playRateMeta = const VerificationMeta(
    'playRate',
  );
  @override
  late final GeneratedColumn<double> playRate = GeneratedColumn<double>(
    'play_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioTrackMeta = const VerificationMeta(
    'audioTrack',
  );
  @override
  late final GeneratedColumn<String> audioTrack = GeneratedColumn<String>(
    'audio_track',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subtitleTrackMeta = const VerificationMeta(
    'subtitleTrack',
  );
  @override
  late final GeneratedColumn<String> subtitleTrack = GeneratedColumn<String>(
    'subtitle_track',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> playedAt =
      GeneratedColumn<int>(
        'played_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($HistoriesTable.$converterplayedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($HistoriesTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    siteId,
    vodId,
    vodName,
    vodPic,
    flag,
    episodeIndex,
    episodeName,
    positionMs,
    durationMs,
    finished,
    openingMs,
    endingMs,
    playRate,
    audioTrack,
    subtitleTrack,
    playedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history';
  @override
  VerificationContext validateIntegrity(
    Insertable<History> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('site_id')) {
      context.handle(
        _siteIdMeta,
        siteId.isAcceptableOrUnknown(data['site_id']!, _siteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_siteIdMeta);
    }
    if (data.containsKey('vod_id')) {
      context.handle(
        _vodIdMeta,
        vodId.isAcceptableOrUnknown(data['vod_id']!, _vodIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vodIdMeta);
    }
    if (data.containsKey('vod_name')) {
      context.handle(
        _vodNameMeta,
        vodName.isAcceptableOrUnknown(data['vod_name']!, _vodNameMeta),
      );
    } else if (isInserting) {
      context.missing(_vodNameMeta);
    }
    if (data.containsKey('vod_pic')) {
      context.handle(
        _vodPicMeta,
        vodPic.isAcceptableOrUnknown(data['vod_pic']!, _vodPicMeta),
      );
    }
    if (data.containsKey('flag')) {
      context.handle(
        _flagMeta,
        flag.isAcceptableOrUnknown(data['flag']!, _flagMeta),
      );
    }
    if (data.containsKey('episode_index')) {
      context.handle(
        _episodeIndexMeta,
        episodeIndex.isAcceptableOrUnknown(
          data['episode_index']!,
          _episodeIndexMeta,
        ),
      );
    }
    if (data.containsKey('episode_name')) {
      context.handle(
        _episodeNameMeta,
        episodeName.isAcceptableOrUnknown(
          data['episode_name']!,
          _episodeNameMeta,
        ),
      );
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('finished')) {
      context.handle(
        _finishedMeta,
        finished.isAcceptableOrUnknown(data['finished']!, _finishedMeta),
      );
    }
    if (data.containsKey('opening_ms')) {
      context.handle(
        _openingMsMeta,
        openingMs.isAcceptableOrUnknown(data['opening_ms']!, _openingMsMeta),
      );
    }
    if (data.containsKey('ending_ms')) {
      context.handle(
        _endingMsMeta,
        endingMs.isAcceptableOrUnknown(data['ending_ms']!, _endingMsMeta),
      );
    }
    if (data.containsKey('play_rate')) {
      context.handle(
        _playRateMeta,
        playRate.isAcceptableOrUnknown(data['play_rate']!, _playRateMeta),
      );
    }
    if (data.containsKey('audio_track')) {
      context.handle(
        _audioTrackMeta,
        audioTrack.isAcceptableOrUnknown(data['audio_track']!, _audioTrackMeta),
      );
    }
    if (data.containsKey('subtitle_track')) {
      context.handle(
        _subtitleTrackMeta,
        subtitleTrack.isAcceptableOrUnknown(
          data['subtitle_track']!,
          _subtitleTrackMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  History map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return History(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      siteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}site_id'],
      )!,
      vodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vod_id'],
      )!,
      vodName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vod_name'],
      )!,
      vodPic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vod_pic'],
      ),
      flag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}flag'],
      ),
      episodeIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_index'],
      )!,
      episodeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_name'],
      ),
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      finished: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}finished'],
      )!,
      openingMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opening_ms'],
      ),
      endingMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ending_ms'],
      ),
      playRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}play_rate'],
      ),
      audioTrack: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_track'],
      ),
      subtitleTrack: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle_track'],
      ),
      playedAt: $HistoriesTable.$converterplayedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}played_at'],
        )!,
      ),
      createdAt: $HistoriesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $HistoriesTable createAlias(String alias) {
    return $HistoriesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterplayedAt = utcMillis;
  static TypeConverter<DateTime, int> $convertercreatedAt = utcMillis;
}

class History extends DataClass implements Insertable<History> {
  final int id;
  final int siteId;
  final String vodId;
  final String vodName;
  final String? vodPic;
  final String? flag;
  final int episodeIndex;
  final String? episodeName;
  final int positionMs;
  final int durationMs;
  final bool finished;
  final int? openingMs;
  final int? endingMs;
  final double? playRate;
  final String? audioTrack;
  final String? subtitleTrack;
  final DateTime playedAt;
  final DateTime createdAt;
  const History({
    required this.id,
    required this.siteId,
    required this.vodId,
    required this.vodName,
    this.vodPic,
    this.flag,
    required this.episodeIndex,
    this.episodeName,
    required this.positionMs,
    required this.durationMs,
    required this.finished,
    this.openingMs,
    this.endingMs,
    this.playRate,
    this.audioTrack,
    this.subtitleTrack,
    required this.playedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['site_id'] = Variable<int>(siteId);
    map['vod_id'] = Variable<String>(vodId);
    map['vod_name'] = Variable<String>(vodName);
    if (!nullToAbsent || vodPic != null) {
      map['vod_pic'] = Variable<String>(vodPic);
    }
    if (!nullToAbsent || flag != null) {
      map['flag'] = Variable<String>(flag);
    }
    map['episode_index'] = Variable<int>(episodeIndex);
    if (!nullToAbsent || episodeName != null) {
      map['episode_name'] = Variable<String>(episodeName);
    }
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['finished'] = Variable<bool>(finished);
    if (!nullToAbsent || openingMs != null) {
      map['opening_ms'] = Variable<int>(openingMs);
    }
    if (!nullToAbsent || endingMs != null) {
      map['ending_ms'] = Variable<int>(endingMs);
    }
    if (!nullToAbsent || playRate != null) {
      map['play_rate'] = Variable<double>(playRate);
    }
    if (!nullToAbsent || audioTrack != null) {
      map['audio_track'] = Variable<String>(audioTrack);
    }
    if (!nullToAbsent || subtitleTrack != null) {
      map['subtitle_track'] = Variable<String>(subtitleTrack);
    }
    {
      map['played_at'] = Variable<int>(
        $HistoriesTable.$converterplayedAt.toSql(playedAt),
      );
    }
    {
      map['created_at'] = Variable<int>(
        $HistoriesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  HistoriesCompanion toCompanion(bool nullToAbsent) {
    return HistoriesCompanion(
      id: Value(id),
      siteId: Value(siteId),
      vodId: Value(vodId),
      vodName: Value(vodName),
      vodPic: vodPic == null && nullToAbsent
          ? const Value.absent()
          : Value(vodPic),
      flag: flag == null && nullToAbsent ? const Value.absent() : Value(flag),
      episodeIndex: Value(episodeIndex),
      episodeName: episodeName == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeName),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      finished: Value(finished),
      openingMs: openingMs == null && nullToAbsent
          ? const Value.absent()
          : Value(openingMs),
      endingMs: endingMs == null && nullToAbsent
          ? const Value.absent()
          : Value(endingMs),
      playRate: playRate == null && nullToAbsent
          ? const Value.absent()
          : Value(playRate),
      audioTrack: audioTrack == null && nullToAbsent
          ? const Value.absent()
          : Value(audioTrack),
      subtitleTrack: subtitleTrack == null && nullToAbsent
          ? const Value.absent()
          : Value(subtitleTrack),
      playedAt: Value(playedAt),
      createdAt: Value(createdAt),
    );
  }

  factory History.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return History(
      id: serializer.fromJson<int>(json['id']),
      siteId: serializer.fromJson<int>(json['siteId']),
      vodId: serializer.fromJson<String>(json['vodId']),
      vodName: serializer.fromJson<String>(json['vodName']),
      vodPic: serializer.fromJson<String?>(json['vodPic']),
      flag: serializer.fromJson<String?>(json['flag']),
      episodeIndex: serializer.fromJson<int>(json['episodeIndex']),
      episodeName: serializer.fromJson<String?>(json['episodeName']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      finished: serializer.fromJson<bool>(json['finished']),
      openingMs: serializer.fromJson<int?>(json['openingMs']),
      endingMs: serializer.fromJson<int?>(json['endingMs']),
      playRate: serializer.fromJson<double?>(json['playRate']),
      audioTrack: serializer.fromJson<String?>(json['audioTrack']),
      subtitleTrack: serializer.fromJson<String?>(json['subtitleTrack']),
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'siteId': serializer.toJson<int>(siteId),
      'vodId': serializer.toJson<String>(vodId),
      'vodName': serializer.toJson<String>(vodName),
      'vodPic': serializer.toJson<String?>(vodPic),
      'flag': serializer.toJson<String?>(flag),
      'episodeIndex': serializer.toJson<int>(episodeIndex),
      'episodeName': serializer.toJson<String?>(episodeName),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'finished': serializer.toJson<bool>(finished),
      'openingMs': serializer.toJson<int?>(openingMs),
      'endingMs': serializer.toJson<int?>(endingMs),
      'playRate': serializer.toJson<double?>(playRate),
      'audioTrack': serializer.toJson<String?>(audioTrack),
      'subtitleTrack': serializer.toJson<String?>(subtitleTrack),
      'playedAt': serializer.toJson<DateTime>(playedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  History copyWith({
    int? id,
    int? siteId,
    String? vodId,
    String? vodName,
    Value<String?> vodPic = const Value.absent(),
    Value<String?> flag = const Value.absent(),
    int? episodeIndex,
    Value<String?> episodeName = const Value.absent(),
    int? positionMs,
    int? durationMs,
    bool? finished,
    Value<int?> openingMs = const Value.absent(),
    Value<int?> endingMs = const Value.absent(),
    Value<double?> playRate = const Value.absent(),
    Value<String?> audioTrack = const Value.absent(),
    Value<String?> subtitleTrack = const Value.absent(),
    DateTime? playedAt,
    DateTime? createdAt,
  }) => History(
    id: id ?? this.id,
    siteId: siteId ?? this.siteId,
    vodId: vodId ?? this.vodId,
    vodName: vodName ?? this.vodName,
    vodPic: vodPic.present ? vodPic.value : this.vodPic,
    flag: flag.present ? flag.value : this.flag,
    episodeIndex: episodeIndex ?? this.episodeIndex,
    episodeName: episodeName.present ? episodeName.value : this.episodeName,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    finished: finished ?? this.finished,
    openingMs: openingMs.present ? openingMs.value : this.openingMs,
    endingMs: endingMs.present ? endingMs.value : this.endingMs,
    playRate: playRate.present ? playRate.value : this.playRate,
    audioTrack: audioTrack.present ? audioTrack.value : this.audioTrack,
    subtitleTrack: subtitleTrack.present
        ? subtitleTrack.value
        : this.subtitleTrack,
    playedAt: playedAt ?? this.playedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  History copyWithCompanion(HistoriesCompanion data) {
    return History(
      id: data.id.present ? data.id.value : this.id,
      siteId: data.siteId.present ? data.siteId.value : this.siteId,
      vodId: data.vodId.present ? data.vodId.value : this.vodId,
      vodName: data.vodName.present ? data.vodName.value : this.vodName,
      vodPic: data.vodPic.present ? data.vodPic.value : this.vodPic,
      flag: data.flag.present ? data.flag.value : this.flag,
      episodeIndex: data.episodeIndex.present
          ? data.episodeIndex.value
          : this.episodeIndex,
      episodeName: data.episodeName.present
          ? data.episodeName.value
          : this.episodeName,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      finished: data.finished.present ? data.finished.value : this.finished,
      openingMs: data.openingMs.present ? data.openingMs.value : this.openingMs,
      endingMs: data.endingMs.present ? data.endingMs.value : this.endingMs,
      playRate: data.playRate.present ? data.playRate.value : this.playRate,
      audioTrack: data.audioTrack.present
          ? data.audioTrack.value
          : this.audioTrack,
      subtitleTrack: data.subtitleTrack.present
          ? data.subtitleTrack.value
          : this.subtitleTrack,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('History(')
          ..write('id: $id, ')
          ..write('siteId: $siteId, ')
          ..write('vodId: $vodId, ')
          ..write('vodName: $vodName, ')
          ..write('vodPic: $vodPic, ')
          ..write('flag: $flag, ')
          ..write('episodeIndex: $episodeIndex, ')
          ..write('episodeName: $episodeName, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('finished: $finished, ')
          ..write('openingMs: $openingMs, ')
          ..write('endingMs: $endingMs, ')
          ..write('playRate: $playRate, ')
          ..write('audioTrack: $audioTrack, ')
          ..write('subtitleTrack: $subtitleTrack, ')
          ..write('playedAt: $playedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    siteId,
    vodId,
    vodName,
    vodPic,
    flag,
    episodeIndex,
    episodeName,
    positionMs,
    durationMs,
    finished,
    openingMs,
    endingMs,
    playRate,
    audioTrack,
    subtitleTrack,
    playedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is History &&
          other.id == this.id &&
          other.siteId == this.siteId &&
          other.vodId == this.vodId &&
          other.vodName == this.vodName &&
          other.vodPic == this.vodPic &&
          other.flag == this.flag &&
          other.episodeIndex == this.episodeIndex &&
          other.episodeName == this.episodeName &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.finished == this.finished &&
          other.openingMs == this.openingMs &&
          other.endingMs == this.endingMs &&
          other.playRate == this.playRate &&
          other.audioTrack == this.audioTrack &&
          other.subtitleTrack == this.subtitleTrack &&
          other.playedAt == this.playedAt &&
          other.createdAt == this.createdAt);
}

class HistoriesCompanion extends UpdateCompanion<History> {
  final Value<int> id;
  final Value<int> siteId;
  final Value<String> vodId;
  final Value<String> vodName;
  final Value<String?> vodPic;
  final Value<String?> flag;
  final Value<int> episodeIndex;
  final Value<String?> episodeName;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<bool> finished;
  final Value<int?> openingMs;
  final Value<int?> endingMs;
  final Value<double?> playRate;
  final Value<String?> audioTrack;
  final Value<String?> subtitleTrack;
  final Value<DateTime> playedAt;
  final Value<DateTime> createdAt;
  const HistoriesCompanion({
    this.id = const Value.absent(),
    this.siteId = const Value.absent(),
    this.vodId = const Value.absent(),
    this.vodName = const Value.absent(),
    this.vodPic = const Value.absent(),
    this.flag = const Value.absent(),
    this.episodeIndex = const Value.absent(),
    this.episodeName = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.finished = const Value.absent(),
    this.openingMs = const Value.absent(),
    this.endingMs = const Value.absent(),
    this.playRate = const Value.absent(),
    this.audioTrack = const Value.absent(),
    this.subtitleTrack = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  HistoriesCompanion.insert({
    this.id = const Value.absent(),
    required int siteId,
    required String vodId,
    required String vodName,
    this.vodPic = const Value.absent(),
    this.flag = const Value.absent(),
    this.episodeIndex = const Value.absent(),
    this.episodeName = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.finished = const Value.absent(),
    this.openingMs = const Value.absent(),
    this.endingMs = const Value.absent(),
    this.playRate = const Value.absent(),
    this.audioTrack = const Value.absent(),
    this.subtitleTrack = const Value.absent(),
    required DateTime playedAt,
    required DateTime createdAt,
  }) : siteId = Value(siteId),
       vodId = Value(vodId),
       vodName = Value(vodName),
       playedAt = Value(playedAt),
       createdAt = Value(createdAt);
  static Insertable<History> custom({
    Expression<int>? id,
    Expression<int>? siteId,
    Expression<String>? vodId,
    Expression<String>? vodName,
    Expression<String>? vodPic,
    Expression<String>? flag,
    Expression<int>? episodeIndex,
    Expression<String>? episodeName,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<bool>? finished,
    Expression<int>? openingMs,
    Expression<int>? endingMs,
    Expression<double>? playRate,
    Expression<String>? audioTrack,
    Expression<String>? subtitleTrack,
    Expression<int>? playedAt,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (siteId != null) 'site_id': siteId,
      if (vodId != null) 'vod_id': vodId,
      if (vodName != null) 'vod_name': vodName,
      if (vodPic != null) 'vod_pic': vodPic,
      if (flag != null) 'flag': flag,
      if (episodeIndex != null) 'episode_index': episodeIndex,
      if (episodeName != null) 'episode_name': episodeName,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (finished != null) 'finished': finished,
      if (openingMs != null) 'opening_ms': openingMs,
      if (endingMs != null) 'ending_ms': endingMs,
      if (playRate != null) 'play_rate': playRate,
      if (audioTrack != null) 'audio_track': audioTrack,
      if (subtitleTrack != null) 'subtitle_track': subtitleTrack,
      if (playedAt != null) 'played_at': playedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  HistoriesCompanion copyWith({
    Value<int>? id,
    Value<int>? siteId,
    Value<String>? vodId,
    Value<String>? vodName,
    Value<String?>? vodPic,
    Value<String?>? flag,
    Value<int>? episodeIndex,
    Value<String?>? episodeName,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<bool>? finished,
    Value<int?>? openingMs,
    Value<int?>? endingMs,
    Value<double?>? playRate,
    Value<String?>? audioTrack,
    Value<String?>? subtitleTrack,
    Value<DateTime>? playedAt,
    Value<DateTime>? createdAt,
  }) {
    return HistoriesCompanion(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      vodId: vodId ?? this.vodId,
      vodName: vodName ?? this.vodName,
      vodPic: vodPic ?? this.vodPic,
      flag: flag ?? this.flag,
      episodeIndex: episodeIndex ?? this.episodeIndex,
      episodeName: episodeName ?? this.episodeName,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      finished: finished ?? this.finished,
      openingMs: openingMs ?? this.openingMs,
      endingMs: endingMs ?? this.endingMs,
      playRate: playRate ?? this.playRate,
      audioTrack: audioTrack ?? this.audioTrack,
      subtitleTrack: subtitleTrack ?? this.subtitleTrack,
      playedAt: playedAt ?? this.playedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (siteId.present) {
      map['site_id'] = Variable<int>(siteId.value);
    }
    if (vodId.present) {
      map['vod_id'] = Variable<String>(vodId.value);
    }
    if (vodName.present) {
      map['vod_name'] = Variable<String>(vodName.value);
    }
    if (vodPic.present) {
      map['vod_pic'] = Variable<String>(vodPic.value);
    }
    if (flag.present) {
      map['flag'] = Variable<String>(flag.value);
    }
    if (episodeIndex.present) {
      map['episode_index'] = Variable<int>(episodeIndex.value);
    }
    if (episodeName.present) {
      map['episode_name'] = Variable<String>(episodeName.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (finished.present) {
      map['finished'] = Variable<bool>(finished.value);
    }
    if (openingMs.present) {
      map['opening_ms'] = Variable<int>(openingMs.value);
    }
    if (endingMs.present) {
      map['ending_ms'] = Variable<int>(endingMs.value);
    }
    if (playRate.present) {
      map['play_rate'] = Variable<double>(playRate.value);
    }
    if (audioTrack.present) {
      map['audio_track'] = Variable<String>(audioTrack.value);
    }
    if (subtitleTrack.present) {
      map['subtitle_track'] = Variable<String>(subtitleTrack.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<int>(
        $HistoriesTable.$converterplayedAt.toSql(playedAt.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $HistoriesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoriesCompanion(')
          ..write('id: $id, ')
          ..write('siteId: $siteId, ')
          ..write('vodId: $vodId, ')
          ..write('vodName: $vodName, ')
          ..write('vodPic: $vodPic, ')
          ..write('flag: $flag, ')
          ..write('episodeIndex: $episodeIndex, ')
          ..write('episodeName: $episodeName, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('finished: $finished, ')
          ..write('openingMs: $openingMs, ')
          ..write('endingMs: $endingMs, ')
          ..write('playRate: $playRate, ')
          ..write('audioTrack: $audioTrack, ')
          ..write('subtitleTrack: $subtitleTrack, ')
          ..write('playedAt: $playedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, Favorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _siteIdMeta = const VerificationMeta('siteId');
  @override
  late final GeneratedColumn<int> siteId = GeneratedColumn<int>(
    'site_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES site (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _vodIdMeta = const VerificationMeta('vodId');
  @override
  late final GeneratedColumn<String> vodId = GeneratedColumn<String>(
    'vod_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vodNameMeta = const VerificationMeta(
    'vodName',
  );
  @override
  late final GeneratedColumn<String> vodName = GeneratedColumn<String>(
    'vod_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vodPicMeta = const VerificationMeta('vodPic');
  @override
  late final GeneratedColumn<String> vodPic = GeneratedColumn<String>(
    'vod_pic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vodRemarksMeta = const VerificationMeta(
    'vodRemarks',
  );
  @override
  late final GeneratedColumn<String> vodRemarks = GeneratedColumn<String>(
    'vod_remarks',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latestRemarksMeta = const VerificationMeta(
    'latestRemarks',
  );
  @override
  late final GeneratedColumn<String> latestRemarks = GeneratedColumn<String>(
    'latest_remarks',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderMeta = const VerificationMeta('folder');
  @override
  late final GeneratedColumn<String> folder = GeneratedColumn<String>(
    'folder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _notifyUpdateMeta = const VerificationMeta(
    'notifyUpdate',
  );
  @override
  late final GeneratedColumn<bool> notifyUpdate = GeneratedColumn<bool>(
    'notify_update',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notify_update" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastCheckAt =
      GeneratedColumn<int>(
        'last_check_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($FavoritesTable.$converterlastCheckAtn);
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($FavoritesTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    siteId,
    vodId,
    vodName,
    vodPic,
    vodRemarks,
    latestRemarks,
    folder,
    notifyUpdate,
    lastCheckAt,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite';
  @override
  VerificationContext validateIntegrity(
    Insertable<Favorite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('site_id')) {
      context.handle(
        _siteIdMeta,
        siteId.isAcceptableOrUnknown(data['site_id']!, _siteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_siteIdMeta);
    }
    if (data.containsKey('vod_id')) {
      context.handle(
        _vodIdMeta,
        vodId.isAcceptableOrUnknown(data['vod_id']!, _vodIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vodIdMeta);
    }
    if (data.containsKey('vod_name')) {
      context.handle(
        _vodNameMeta,
        vodName.isAcceptableOrUnknown(data['vod_name']!, _vodNameMeta),
      );
    } else if (isInserting) {
      context.missing(_vodNameMeta);
    }
    if (data.containsKey('vod_pic')) {
      context.handle(
        _vodPicMeta,
        vodPic.isAcceptableOrUnknown(data['vod_pic']!, _vodPicMeta),
      );
    }
    if (data.containsKey('vod_remarks')) {
      context.handle(
        _vodRemarksMeta,
        vodRemarks.isAcceptableOrUnknown(data['vod_remarks']!, _vodRemarksMeta),
      );
    }
    if (data.containsKey('latest_remarks')) {
      context.handle(
        _latestRemarksMeta,
        latestRemarks.isAcceptableOrUnknown(
          data['latest_remarks']!,
          _latestRemarksMeta,
        ),
      );
    }
    if (data.containsKey('folder')) {
      context.handle(
        _folderMeta,
        folder.isAcceptableOrUnknown(data['folder']!, _folderMeta),
      );
    }
    if (data.containsKey('notify_update')) {
      context.handle(
        _notifyUpdateMeta,
        notifyUpdate.isAcceptableOrUnknown(
          data['notify_update']!,
          _notifyUpdateMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Favorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Favorite(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      siteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}site_id'],
      )!,
      vodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vod_id'],
      )!,
      vodName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vod_name'],
      )!,
      vodPic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vod_pic'],
      ),
      vodRemarks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vod_remarks'],
      ),
      latestRemarks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}latest_remarks'],
      ),
      folder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder'],
      )!,
      notifyUpdate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notify_update'],
      )!,
      lastCheckAt: $FavoritesTable.$converterlastCheckAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_check_at'],
        ),
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: $FavoritesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterlastCheckAt = utcMillis;
  static TypeConverter<DateTime?, int?> $converterlastCheckAtn =
      NullAwareTypeConverter.wrap($converterlastCheckAt);
  static TypeConverter<DateTime, int> $convertercreatedAt = utcMillis;
}

class Favorite extends DataClass implements Insertable<Favorite> {
  final int id;
  final int siteId;
  final String vodId;
  final String vodName;
  final String? vodPic;
  final String? vodRemarks;
  final String? latestRemarks;
  final String folder;
  final bool notifyUpdate;
  final DateTime? lastCheckAt;
  final int sortOrder;
  final DateTime createdAt;
  const Favorite({
    required this.id,
    required this.siteId,
    required this.vodId,
    required this.vodName,
    this.vodPic,
    this.vodRemarks,
    this.latestRemarks,
    required this.folder,
    required this.notifyUpdate,
    this.lastCheckAt,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['site_id'] = Variable<int>(siteId);
    map['vod_id'] = Variable<String>(vodId);
    map['vod_name'] = Variable<String>(vodName);
    if (!nullToAbsent || vodPic != null) {
      map['vod_pic'] = Variable<String>(vodPic);
    }
    if (!nullToAbsent || vodRemarks != null) {
      map['vod_remarks'] = Variable<String>(vodRemarks);
    }
    if (!nullToAbsent || latestRemarks != null) {
      map['latest_remarks'] = Variable<String>(latestRemarks);
    }
    map['folder'] = Variable<String>(folder);
    map['notify_update'] = Variable<bool>(notifyUpdate);
    if (!nullToAbsent || lastCheckAt != null) {
      map['last_check_at'] = Variable<int>(
        $FavoritesTable.$converterlastCheckAtn.toSql(lastCheckAt),
      );
    }
    map['sort_order'] = Variable<int>(sortOrder);
    {
      map['created_at'] = Variable<int>(
        $FavoritesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(
      id: Value(id),
      siteId: Value(siteId),
      vodId: Value(vodId),
      vodName: Value(vodName),
      vodPic: vodPic == null && nullToAbsent
          ? const Value.absent()
          : Value(vodPic),
      vodRemarks: vodRemarks == null && nullToAbsent
          ? const Value.absent()
          : Value(vodRemarks),
      latestRemarks: latestRemarks == null && nullToAbsent
          ? const Value.absent()
          : Value(latestRemarks),
      folder: Value(folder),
      notifyUpdate: Value(notifyUpdate),
      lastCheckAt: lastCheckAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCheckAt),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory Favorite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Favorite(
      id: serializer.fromJson<int>(json['id']),
      siteId: serializer.fromJson<int>(json['siteId']),
      vodId: serializer.fromJson<String>(json['vodId']),
      vodName: serializer.fromJson<String>(json['vodName']),
      vodPic: serializer.fromJson<String?>(json['vodPic']),
      vodRemarks: serializer.fromJson<String?>(json['vodRemarks']),
      latestRemarks: serializer.fromJson<String?>(json['latestRemarks']),
      folder: serializer.fromJson<String>(json['folder']),
      notifyUpdate: serializer.fromJson<bool>(json['notifyUpdate']),
      lastCheckAt: serializer.fromJson<DateTime?>(json['lastCheckAt']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'siteId': serializer.toJson<int>(siteId),
      'vodId': serializer.toJson<String>(vodId),
      'vodName': serializer.toJson<String>(vodName),
      'vodPic': serializer.toJson<String?>(vodPic),
      'vodRemarks': serializer.toJson<String?>(vodRemarks),
      'latestRemarks': serializer.toJson<String?>(latestRemarks),
      'folder': serializer.toJson<String>(folder),
      'notifyUpdate': serializer.toJson<bool>(notifyUpdate),
      'lastCheckAt': serializer.toJson<DateTime?>(lastCheckAt),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Favorite copyWith({
    int? id,
    int? siteId,
    String? vodId,
    String? vodName,
    Value<String?> vodPic = const Value.absent(),
    Value<String?> vodRemarks = const Value.absent(),
    Value<String?> latestRemarks = const Value.absent(),
    String? folder,
    bool? notifyUpdate,
    Value<DateTime?> lastCheckAt = const Value.absent(),
    int? sortOrder,
    DateTime? createdAt,
  }) => Favorite(
    id: id ?? this.id,
    siteId: siteId ?? this.siteId,
    vodId: vodId ?? this.vodId,
    vodName: vodName ?? this.vodName,
    vodPic: vodPic.present ? vodPic.value : this.vodPic,
    vodRemarks: vodRemarks.present ? vodRemarks.value : this.vodRemarks,
    latestRemarks: latestRemarks.present
        ? latestRemarks.value
        : this.latestRemarks,
    folder: folder ?? this.folder,
    notifyUpdate: notifyUpdate ?? this.notifyUpdate,
    lastCheckAt: lastCheckAt.present ? lastCheckAt.value : this.lastCheckAt,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  Favorite copyWithCompanion(FavoritesCompanion data) {
    return Favorite(
      id: data.id.present ? data.id.value : this.id,
      siteId: data.siteId.present ? data.siteId.value : this.siteId,
      vodId: data.vodId.present ? data.vodId.value : this.vodId,
      vodName: data.vodName.present ? data.vodName.value : this.vodName,
      vodPic: data.vodPic.present ? data.vodPic.value : this.vodPic,
      vodRemarks: data.vodRemarks.present
          ? data.vodRemarks.value
          : this.vodRemarks,
      latestRemarks: data.latestRemarks.present
          ? data.latestRemarks.value
          : this.latestRemarks,
      folder: data.folder.present ? data.folder.value : this.folder,
      notifyUpdate: data.notifyUpdate.present
          ? data.notifyUpdate.value
          : this.notifyUpdate,
      lastCheckAt: data.lastCheckAt.present
          ? data.lastCheckAt.value
          : this.lastCheckAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Favorite(')
          ..write('id: $id, ')
          ..write('siteId: $siteId, ')
          ..write('vodId: $vodId, ')
          ..write('vodName: $vodName, ')
          ..write('vodPic: $vodPic, ')
          ..write('vodRemarks: $vodRemarks, ')
          ..write('latestRemarks: $latestRemarks, ')
          ..write('folder: $folder, ')
          ..write('notifyUpdate: $notifyUpdate, ')
          ..write('lastCheckAt: $lastCheckAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    siteId,
    vodId,
    vodName,
    vodPic,
    vodRemarks,
    latestRemarks,
    folder,
    notifyUpdate,
    lastCheckAt,
    sortOrder,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Favorite &&
          other.id == this.id &&
          other.siteId == this.siteId &&
          other.vodId == this.vodId &&
          other.vodName == this.vodName &&
          other.vodPic == this.vodPic &&
          other.vodRemarks == this.vodRemarks &&
          other.latestRemarks == this.latestRemarks &&
          other.folder == this.folder &&
          other.notifyUpdate == this.notifyUpdate &&
          other.lastCheckAt == this.lastCheckAt &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class FavoritesCompanion extends UpdateCompanion<Favorite> {
  final Value<int> id;
  final Value<int> siteId;
  final Value<String> vodId;
  final Value<String> vodName;
  final Value<String?> vodPic;
  final Value<String?> vodRemarks;
  final Value<String?> latestRemarks;
  final Value<String> folder;
  final Value<bool> notifyUpdate;
  final Value<DateTime?> lastCheckAt;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const FavoritesCompanion({
    this.id = const Value.absent(),
    this.siteId = const Value.absent(),
    this.vodId = const Value.absent(),
    this.vodName = const Value.absent(),
    this.vodPic = const Value.absent(),
    this.vodRemarks = const Value.absent(),
    this.latestRemarks = const Value.absent(),
    this.folder = const Value.absent(),
    this.notifyUpdate = const Value.absent(),
    this.lastCheckAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  FavoritesCompanion.insert({
    this.id = const Value.absent(),
    required int siteId,
    required String vodId,
    required String vodName,
    this.vodPic = const Value.absent(),
    this.vodRemarks = const Value.absent(),
    this.latestRemarks = const Value.absent(),
    this.folder = const Value.absent(),
    this.notifyUpdate = const Value.absent(),
    this.lastCheckAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
  }) : siteId = Value(siteId),
       vodId = Value(vodId),
       vodName = Value(vodName),
       createdAt = Value(createdAt);
  static Insertable<Favorite> custom({
    Expression<int>? id,
    Expression<int>? siteId,
    Expression<String>? vodId,
    Expression<String>? vodName,
    Expression<String>? vodPic,
    Expression<String>? vodRemarks,
    Expression<String>? latestRemarks,
    Expression<String>? folder,
    Expression<bool>? notifyUpdate,
    Expression<int>? lastCheckAt,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (siteId != null) 'site_id': siteId,
      if (vodId != null) 'vod_id': vodId,
      if (vodName != null) 'vod_name': vodName,
      if (vodPic != null) 'vod_pic': vodPic,
      if (vodRemarks != null) 'vod_remarks': vodRemarks,
      if (latestRemarks != null) 'latest_remarks': latestRemarks,
      if (folder != null) 'folder': folder,
      if (notifyUpdate != null) 'notify_update': notifyUpdate,
      if (lastCheckAt != null) 'last_check_at': lastCheckAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  FavoritesCompanion copyWith({
    Value<int>? id,
    Value<int>? siteId,
    Value<String>? vodId,
    Value<String>? vodName,
    Value<String?>? vodPic,
    Value<String?>? vodRemarks,
    Value<String?>? latestRemarks,
    Value<String>? folder,
    Value<bool>? notifyUpdate,
    Value<DateTime?>? lastCheckAt,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
  }) {
    return FavoritesCompanion(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      vodId: vodId ?? this.vodId,
      vodName: vodName ?? this.vodName,
      vodPic: vodPic ?? this.vodPic,
      vodRemarks: vodRemarks ?? this.vodRemarks,
      latestRemarks: latestRemarks ?? this.latestRemarks,
      folder: folder ?? this.folder,
      notifyUpdate: notifyUpdate ?? this.notifyUpdate,
      lastCheckAt: lastCheckAt ?? this.lastCheckAt,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (siteId.present) {
      map['site_id'] = Variable<int>(siteId.value);
    }
    if (vodId.present) {
      map['vod_id'] = Variable<String>(vodId.value);
    }
    if (vodName.present) {
      map['vod_name'] = Variable<String>(vodName.value);
    }
    if (vodPic.present) {
      map['vod_pic'] = Variable<String>(vodPic.value);
    }
    if (vodRemarks.present) {
      map['vod_remarks'] = Variable<String>(vodRemarks.value);
    }
    if (latestRemarks.present) {
      map['latest_remarks'] = Variable<String>(latestRemarks.value);
    }
    if (folder.present) {
      map['folder'] = Variable<String>(folder.value);
    }
    if (notifyUpdate.present) {
      map['notify_update'] = Variable<bool>(notifyUpdate.value);
    }
    if (lastCheckAt.present) {
      map['last_check_at'] = Variable<int>(
        $FavoritesTable.$converterlastCheckAtn.toSql(lastCheckAt.value),
      );
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $FavoritesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('id: $id, ')
          ..write('siteId: $siteId, ')
          ..write('vodId: $vodId, ')
          ..write('vodName: $vodName, ')
          ..write('vodPic: $vodPic, ')
          ..write('vodRemarks: $vodRemarks, ')
          ..write('latestRemarks: $latestRemarks, ')
          ..write('folder: $folder, ')
          ..write('notifyUpdate: $notifyUpdate, ')
          ..write('lastCheckAt: $lastCheckAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, Download> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _siteIdMeta = const VerificationMeta('siteId');
  @override
  late final GeneratedColumn<int> siteId = GeneratedColumn<int>(
    'site_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES site (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _vodIdMeta = const VerificationMeta('vodId');
  @override
  late final GeneratedColumn<String> vodId = GeneratedColumn<String>(
    'vod_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vodNameMeta = const VerificationMeta(
    'vodName',
  );
  @override
  late final GeneratedColumn<String> vodName = GeneratedColumn<String>(
    'vod_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeNameMeta = const VerificationMeta(
    'episodeName',
  );
  @override
  late final GeneratedColumn<String> episodeName = GeneratedColumn<String>(
    'episode_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _headersJsonMeta = const VerificationMeta(
    'headersJson',
  );
  @override
  late final GeneratedColumn<String> headersJson = GeneratedColumn<String>(
    'headers_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _doneBytesMeta = const VerificationMeta(
    'doneBytes',
  );
  @override
  late final GeneratedColumn<int> doneBytes = GeneratedColumn<int>(
    'done_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalSegmentsMeta = const VerificationMeta(
    'totalSegments',
  );
  @override
  late final GeneratedColumn<int> totalSegments = GeneratedColumn<int>(
    'total_segments',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _doneSegmentsMeta = const VerificationMeta(
    'doneSegments',
  );
  @override
  late final GeneratedColumn<int> doneSegments = GeneratedColumn<int>(
    'done_segments',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedBpsMeta = const VerificationMeta(
    'speedBps',
  );
  @override
  late final GeneratedColumn<int> speedBps = GeneratedColumn<int>(
    'speed_bps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($DownloadsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($DownloadsTable.$converterupdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> completedAt =
      GeneratedColumn<int>(
        'completed_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($DownloadsTable.$convertercompletedAtn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    siteId,
    vodId,
    vodName,
    episodeName,
    sourceUrl,
    headersJson,
    filePath,
    mediaType,
    totalBytes,
    doneBytes,
    totalSegments,
    doneSegments,
    status,
    error,
    speedBps,
    priority,
    createdAt,
    updatedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download';
  @override
  VerificationContext validateIntegrity(
    Insertable<Download> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('site_id')) {
      context.handle(
        _siteIdMeta,
        siteId.isAcceptableOrUnknown(data['site_id']!, _siteIdMeta),
      );
    }
    if (data.containsKey('vod_id')) {
      context.handle(
        _vodIdMeta,
        vodId.isAcceptableOrUnknown(data['vod_id']!, _vodIdMeta),
      );
    }
    if (data.containsKey('vod_name')) {
      context.handle(
        _vodNameMeta,
        vodName.isAcceptableOrUnknown(data['vod_name']!, _vodNameMeta),
      );
    } else if (isInserting) {
      context.missing(_vodNameMeta);
    }
    if (data.containsKey('episode_name')) {
      context.handle(
        _episodeNameMeta,
        episodeName.isAcceptableOrUnknown(
          data['episode_name']!,
          _episodeNameMeta,
        ),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('headers_json')) {
      context.handle(
        _headersJsonMeta,
        headersJson.isAcceptableOrUnknown(
          data['headers_json']!,
          _headersJsonMeta,
        ),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('done_bytes')) {
      context.handle(
        _doneBytesMeta,
        doneBytes.isAcceptableOrUnknown(data['done_bytes']!, _doneBytesMeta),
      );
    }
    if (data.containsKey('total_segments')) {
      context.handle(
        _totalSegmentsMeta,
        totalSegments.isAcceptableOrUnknown(
          data['total_segments']!,
          _totalSegmentsMeta,
        ),
      );
    }
    if (data.containsKey('done_segments')) {
      context.handle(
        _doneSegmentsMeta,
        doneSegments.isAcceptableOrUnknown(
          data['done_segments']!,
          _doneSegmentsMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('speed_bps')) {
      context.handle(
        _speedBpsMeta,
        speedBps.isAcceptableOrUnknown(data['speed_bps']!, _speedBpsMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Download map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Download(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      siteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}site_id'],
      ),
      vodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vod_id'],
      ),
      vodName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vod_name'],
      )!,
      episodeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_name'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      headersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headers_json'],
      ),
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      )!,
      doneBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}done_bytes'],
      )!,
      totalSegments: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_segments'],
      ),
      doneSegments: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}done_segments'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      speedBps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}speed_bps'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      createdAt: $DownloadsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $DownloadsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      completedAt: $DownloadsTable.$convertercompletedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}completed_at'],
        ),
      ),
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt = utcMillis;
  static TypeConverter<DateTime, int> $converterupdatedAt = utcMillis;
  static TypeConverter<DateTime, int> $convertercompletedAt = utcMillis;
  static TypeConverter<DateTime?, int?> $convertercompletedAtn =
      NullAwareTypeConverter.wrap($convertercompletedAt);
}

class Download extends DataClass implements Insertable<Download> {
  final int id;
  final int? siteId;
  final String? vodId;
  final String vodName;
  final String? episodeName;
  final String sourceUrl;
  final String? headersJson;
  final String filePath;
  final String mediaType;
  final int totalBytes;
  final int doneBytes;
  final int? totalSegments;
  final int? doneSegments;
  final String status;
  final String? error;
  final int? speedBps;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  const Download({
    required this.id,
    this.siteId,
    this.vodId,
    required this.vodName,
    this.episodeName,
    required this.sourceUrl,
    this.headersJson,
    required this.filePath,
    required this.mediaType,
    required this.totalBytes,
    required this.doneBytes,
    this.totalSegments,
    this.doneSegments,
    required this.status,
    this.error,
    this.speedBps,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || siteId != null) {
      map['site_id'] = Variable<int>(siteId);
    }
    if (!nullToAbsent || vodId != null) {
      map['vod_id'] = Variable<String>(vodId);
    }
    map['vod_name'] = Variable<String>(vodName);
    if (!nullToAbsent || episodeName != null) {
      map['episode_name'] = Variable<String>(episodeName);
    }
    map['source_url'] = Variable<String>(sourceUrl);
    if (!nullToAbsent || headersJson != null) {
      map['headers_json'] = Variable<String>(headersJson);
    }
    map['file_path'] = Variable<String>(filePath);
    map['media_type'] = Variable<String>(mediaType);
    map['total_bytes'] = Variable<int>(totalBytes);
    map['done_bytes'] = Variable<int>(doneBytes);
    if (!nullToAbsent || totalSegments != null) {
      map['total_segments'] = Variable<int>(totalSegments);
    }
    if (!nullToAbsent || doneSegments != null) {
      map['done_segments'] = Variable<int>(doneSegments);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    if (!nullToAbsent || speedBps != null) {
      map['speed_bps'] = Variable<int>(speedBps);
    }
    map['priority'] = Variable<int>(priority);
    {
      map['created_at'] = Variable<int>(
        $DownloadsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $DownloadsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(
        $DownloadsTable.$convertercompletedAtn.toSql(completedAt),
      );
    }
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      id: Value(id),
      siteId: siteId == null && nullToAbsent
          ? const Value.absent()
          : Value(siteId),
      vodId: vodId == null && nullToAbsent
          ? const Value.absent()
          : Value(vodId),
      vodName: Value(vodName),
      episodeName: episodeName == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeName),
      sourceUrl: Value(sourceUrl),
      headersJson: headersJson == null && nullToAbsent
          ? const Value.absent()
          : Value(headersJson),
      filePath: Value(filePath),
      mediaType: Value(mediaType),
      totalBytes: Value(totalBytes),
      doneBytes: Value(doneBytes),
      totalSegments: totalSegments == null && nullToAbsent
          ? const Value.absent()
          : Value(totalSegments),
      doneSegments: doneSegments == null && nullToAbsent
          ? const Value.absent()
          : Value(doneSegments),
      status: Value(status),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      speedBps: speedBps == null && nullToAbsent
          ? const Value.absent()
          : Value(speedBps),
      priority: Value(priority),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory Download.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Download(
      id: serializer.fromJson<int>(json['id']),
      siteId: serializer.fromJson<int?>(json['siteId']),
      vodId: serializer.fromJson<String?>(json['vodId']),
      vodName: serializer.fromJson<String>(json['vodName']),
      episodeName: serializer.fromJson<String?>(json['episodeName']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      headersJson: serializer.fromJson<String?>(json['headersJson']),
      filePath: serializer.fromJson<String>(json['filePath']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      totalBytes: serializer.fromJson<int>(json['totalBytes']),
      doneBytes: serializer.fromJson<int>(json['doneBytes']),
      totalSegments: serializer.fromJson<int?>(json['totalSegments']),
      doneSegments: serializer.fromJson<int?>(json['doneSegments']),
      status: serializer.fromJson<String>(json['status']),
      error: serializer.fromJson<String?>(json['error']),
      speedBps: serializer.fromJson<int?>(json['speedBps']),
      priority: serializer.fromJson<int>(json['priority']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'siteId': serializer.toJson<int?>(siteId),
      'vodId': serializer.toJson<String?>(vodId),
      'vodName': serializer.toJson<String>(vodName),
      'episodeName': serializer.toJson<String?>(episodeName),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'headersJson': serializer.toJson<String?>(headersJson),
      'filePath': serializer.toJson<String>(filePath),
      'mediaType': serializer.toJson<String>(mediaType),
      'totalBytes': serializer.toJson<int>(totalBytes),
      'doneBytes': serializer.toJson<int>(doneBytes),
      'totalSegments': serializer.toJson<int?>(totalSegments),
      'doneSegments': serializer.toJson<int?>(doneSegments),
      'status': serializer.toJson<String>(status),
      'error': serializer.toJson<String?>(error),
      'speedBps': serializer.toJson<int?>(speedBps),
      'priority': serializer.toJson<int>(priority),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  Download copyWith({
    int? id,
    Value<int?> siteId = const Value.absent(),
    Value<String?> vodId = const Value.absent(),
    String? vodName,
    Value<String?> episodeName = const Value.absent(),
    String? sourceUrl,
    Value<String?> headersJson = const Value.absent(),
    String? filePath,
    String? mediaType,
    int? totalBytes,
    int? doneBytes,
    Value<int?> totalSegments = const Value.absent(),
    Value<int?> doneSegments = const Value.absent(),
    String? status,
    Value<String?> error = const Value.absent(),
    Value<int?> speedBps = const Value.absent(),
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => Download(
    id: id ?? this.id,
    siteId: siteId.present ? siteId.value : this.siteId,
    vodId: vodId.present ? vodId.value : this.vodId,
    vodName: vodName ?? this.vodName,
    episodeName: episodeName.present ? episodeName.value : this.episodeName,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    headersJson: headersJson.present ? headersJson.value : this.headersJson,
    filePath: filePath ?? this.filePath,
    mediaType: mediaType ?? this.mediaType,
    totalBytes: totalBytes ?? this.totalBytes,
    doneBytes: doneBytes ?? this.doneBytes,
    totalSegments: totalSegments.present
        ? totalSegments.value
        : this.totalSegments,
    doneSegments: doneSegments.present ? doneSegments.value : this.doneSegments,
    status: status ?? this.status,
    error: error.present ? error.value : this.error,
    speedBps: speedBps.present ? speedBps.value : this.speedBps,
    priority: priority ?? this.priority,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  Download copyWithCompanion(DownloadsCompanion data) {
    return Download(
      id: data.id.present ? data.id.value : this.id,
      siteId: data.siteId.present ? data.siteId.value : this.siteId,
      vodId: data.vodId.present ? data.vodId.value : this.vodId,
      vodName: data.vodName.present ? data.vodName.value : this.vodName,
      episodeName: data.episodeName.present
          ? data.episodeName.value
          : this.episodeName,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      headersJson: data.headersJson.present
          ? data.headersJson.value
          : this.headersJson,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      doneBytes: data.doneBytes.present ? data.doneBytes.value : this.doneBytes,
      totalSegments: data.totalSegments.present
          ? data.totalSegments.value
          : this.totalSegments,
      doneSegments: data.doneSegments.present
          ? data.doneSegments.value
          : this.doneSegments,
      status: data.status.present ? data.status.value : this.status,
      error: data.error.present ? data.error.value : this.error,
      speedBps: data.speedBps.present ? data.speedBps.value : this.speedBps,
      priority: data.priority.present ? data.priority.value : this.priority,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Download(')
          ..write('id: $id, ')
          ..write('siteId: $siteId, ')
          ..write('vodId: $vodId, ')
          ..write('vodName: $vodName, ')
          ..write('episodeName: $episodeName, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('headersJson: $headersJson, ')
          ..write('filePath: $filePath, ')
          ..write('mediaType: $mediaType, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('doneBytes: $doneBytes, ')
          ..write('totalSegments: $totalSegments, ')
          ..write('doneSegments: $doneSegments, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('speedBps: $speedBps, ')
          ..write('priority: $priority, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    siteId,
    vodId,
    vodName,
    episodeName,
    sourceUrl,
    headersJson,
    filePath,
    mediaType,
    totalBytes,
    doneBytes,
    totalSegments,
    doneSegments,
    status,
    error,
    speedBps,
    priority,
    createdAt,
    updatedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Download &&
          other.id == this.id &&
          other.siteId == this.siteId &&
          other.vodId == this.vodId &&
          other.vodName == this.vodName &&
          other.episodeName == this.episodeName &&
          other.sourceUrl == this.sourceUrl &&
          other.headersJson == this.headersJson &&
          other.filePath == this.filePath &&
          other.mediaType == this.mediaType &&
          other.totalBytes == this.totalBytes &&
          other.doneBytes == this.doneBytes &&
          other.totalSegments == this.totalSegments &&
          other.doneSegments == this.doneSegments &&
          other.status == this.status &&
          other.error == this.error &&
          other.speedBps == this.speedBps &&
          other.priority == this.priority &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt);
}

class DownloadsCompanion extends UpdateCompanion<Download> {
  final Value<int> id;
  final Value<int?> siteId;
  final Value<String?> vodId;
  final Value<String> vodName;
  final Value<String?> episodeName;
  final Value<String> sourceUrl;
  final Value<String?> headersJson;
  final Value<String> filePath;
  final Value<String> mediaType;
  final Value<int> totalBytes;
  final Value<int> doneBytes;
  final Value<int?> totalSegments;
  final Value<int?> doneSegments;
  final Value<String> status;
  final Value<String?> error;
  final Value<int?> speedBps;
  final Value<int> priority;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> completedAt;
  const DownloadsCompanion({
    this.id = const Value.absent(),
    this.siteId = const Value.absent(),
    this.vodId = const Value.absent(),
    this.vodName = const Value.absent(),
    this.episodeName = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.headersJson = const Value.absent(),
    this.filePath = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.doneBytes = const Value.absent(),
    this.totalSegments = const Value.absent(),
    this.doneSegments = const Value.absent(),
    this.status = const Value.absent(),
    this.error = const Value.absent(),
    this.speedBps = const Value.absent(),
    this.priority = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  DownloadsCompanion.insert({
    this.id = const Value.absent(),
    this.siteId = const Value.absent(),
    this.vodId = const Value.absent(),
    required String vodName,
    this.episodeName = const Value.absent(),
    required String sourceUrl,
    this.headersJson = const Value.absent(),
    required String filePath,
    required String mediaType,
    this.totalBytes = const Value.absent(),
    this.doneBytes = const Value.absent(),
    this.totalSegments = const Value.absent(),
    this.doneSegments = const Value.absent(),
    required String status,
    this.error = const Value.absent(),
    this.speedBps = const Value.absent(),
    this.priority = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.completedAt = const Value.absent(),
  }) : vodName = Value(vodName),
       sourceUrl = Value(sourceUrl),
       filePath = Value(filePath),
       mediaType = Value(mediaType),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Download> custom({
    Expression<int>? id,
    Expression<int>? siteId,
    Expression<String>? vodId,
    Expression<String>? vodName,
    Expression<String>? episodeName,
    Expression<String>? sourceUrl,
    Expression<String>? headersJson,
    Expression<String>? filePath,
    Expression<String>? mediaType,
    Expression<int>? totalBytes,
    Expression<int>? doneBytes,
    Expression<int>? totalSegments,
    Expression<int>? doneSegments,
    Expression<String>? status,
    Expression<String>? error,
    Expression<int>? speedBps,
    Expression<int>? priority,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (siteId != null) 'site_id': siteId,
      if (vodId != null) 'vod_id': vodId,
      if (vodName != null) 'vod_name': vodName,
      if (episodeName != null) 'episode_name': episodeName,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (headersJson != null) 'headers_json': headersJson,
      if (filePath != null) 'file_path': filePath,
      if (mediaType != null) 'media_type': mediaType,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (doneBytes != null) 'done_bytes': doneBytes,
      if (totalSegments != null) 'total_segments': totalSegments,
      if (doneSegments != null) 'done_segments': doneSegments,
      if (status != null) 'status': status,
      if (error != null) 'error': error,
      if (speedBps != null) 'speed_bps': speedBps,
      if (priority != null) 'priority': priority,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  DownloadsCompanion copyWith({
    Value<int>? id,
    Value<int?>? siteId,
    Value<String?>? vodId,
    Value<String>? vodName,
    Value<String?>? episodeName,
    Value<String>? sourceUrl,
    Value<String?>? headersJson,
    Value<String>? filePath,
    Value<String>? mediaType,
    Value<int>? totalBytes,
    Value<int>? doneBytes,
    Value<int?>? totalSegments,
    Value<int?>? doneSegments,
    Value<String>? status,
    Value<String?>? error,
    Value<int?>? speedBps,
    Value<int>? priority,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? completedAt,
  }) {
    return DownloadsCompanion(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      vodId: vodId ?? this.vodId,
      vodName: vodName ?? this.vodName,
      episodeName: episodeName ?? this.episodeName,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      headersJson: headersJson ?? this.headersJson,
      filePath: filePath ?? this.filePath,
      mediaType: mediaType ?? this.mediaType,
      totalBytes: totalBytes ?? this.totalBytes,
      doneBytes: doneBytes ?? this.doneBytes,
      totalSegments: totalSegments ?? this.totalSegments,
      doneSegments: doneSegments ?? this.doneSegments,
      status: status ?? this.status,
      error: error ?? this.error,
      speedBps: speedBps ?? this.speedBps,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (siteId.present) {
      map['site_id'] = Variable<int>(siteId.value);
    }
    if (vodId.present) {
      map['vod_id'] = Variable<String>(vodId.value);
    }
    if (vodName.present) {
      map['vod_name'] = Variable<String>(vodName.value);
    }
    if (episodeName.present) {
      map['episode_name'] = Variable<String>(episodeName.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (headersJson.present) {
      map['headers_json'] = Variable<String>(headersJson.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (doneBytes.present) {
      map['done_bytes'] = Variable<int>(doneBytes.value);
    }
    if (totalSegments.present) {
      map['total_segments'] = Variable<int>(totalSegments.value);
    }
    if (doneSegments.present) {
      map['done_segments'] = Variable<int>(doneSegments.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (speedBps.present) {
      map['speed_bps'] = Variable<int>(speedBps.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $DownloadsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $DownloadsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(
        $DownloadsTable.$convertercompletedAtn.toSql(completedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('id: $id, ')
          ..write('siteId: $siteId, ')
          ..write('vodId: $vodId, ')
          ..write('vodName: $vodName, ')
          ..write('episodeName: $episodeName, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('headersJson: $headersJson, ')
          ..write('filePath: $filePath, ')
          ..write('mediaType: $mediaType, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('doneBytes: $doneBytes, ')
          ..write('totalSegments: $totalSegments, ')
          ..write('doneSegments: $doneSegments, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('speedBps: $speedBps, ')
          ..write('priority: $priority, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $DownloadSegmentsTable extends DownloadSegments
    with TableInfo<$DownloadSegmentsTable, DownloadSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _downloadIdMeta = const VerificationMeta(
    'downloadId',
  );
  @override
  late final GeneratedColumn<int> downloadId = GeneratedColumn<int>(
    'download_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES download (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [downloadId, seq, url, bytes, done];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_segment';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('download_id')) {
      context.handle(
        _downloadIdMeta,
        downloadId.isAcceptableOrUnknown(data['download_id']!, _downloadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_downloadIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {downloadId, seq};
  @override
  DownloadSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadSegment(
      downloadId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}download_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
    );
  }

  @override
  $DownloadSegmentsTable createAlias(String alias) {
    return $DownloadSegmentsTable(attachedDatabase, alias);
  }
}

class DownloadSegment extends DataClass implements Insertable<DownloadSegment> {
  final int downloadId;
  final int seq;
  final String url;
  final int bytes;
  final bool done;
  const DownloadSegment({
    required this.downloadId,
    required this.seq,
    required this.url,
    required this.bytes,
    required this.done,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['download_id'] = Variable<int>(downloadId);
    map['seq'] = Variable<int>(seq);
    map['url'] = Variable<String>(url);
    map['bytes'] = Variable<int>(bytes);
    map['done'] = Variable<bool>(done);
    return map;
  }

  DownloadSegmentsCompanion toCompanion(bool nullToAbsent) {
    return DownloadSegmentsCompanion(
      downloadId: Value(downloadId),
      seq: Value(seq),
      url: Value(url),
      bytes: Value(bytes),
      done: Value(done),
    );
  }

  factory DownloadSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadSegment(
      downloadId: serializer.fromJson<int>(json['downloadId']),
      seq: serializer.fromJson<int>(json['seq']),
      url: serializer.fromJson<String>(json['url']),
      bytes: serializer.fromJson<int>(json['bytes']),
      done: serializer.fromJson<bool>(json['done']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'downloadId': serializer.toJson<int>(downloadId),
      'seq': serializer.toJson<int>(seq),
      'url': serializer.toJson<String>(url),
      'bytes': serializer.toJson<int>(bytes),
      'done': serializer.toJson<bool>(done),
    };
  }

  DownloadSegment copyWith({
    int? downloadId,
    int? seq,
    String? url,
    int? bytes,
    bool? done,
  }) => DownloadSegment(
    downloadId: downloadId ?? this.downloadId,
    seq: seq ?? this.seq,
    url: url ?? this.url,
    bytes: bytes ?? this.bytes,
    done: done ?? this.done,
  );
  DownloadSegment copyWithCompanion(DownloadSegmentsCompanion data) {
    return DownloadSegment(
      downloadId: data.downloadId.present
          ? data.downloadId.value
          : this.downloadId,
      seq: data.seq.present ? data.seq.value : this.seq,
      url: data.url.present ? data.url.value : this.url,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      done: data.done.present ? data.done.value : this.done,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadSegment(')
          ..write('downloadId: $downloadId, ')
          ..write('seq: $seq, ')
          ..write('url: $url, ')
          ..write('bytes: $bytes, ')
          ..write('done: $done')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(downloadId, seq, url, bytes, done);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadSegment &&
          other.downloadId == this.downloadId &&
          other.seq == this.seq &&
          other.url == this.url &&
          other.bytes == this.bytes &&
          other.done == this.done);
}

class DownloadSegmentsCompanion extends UpdateCompanion<DownloadSegment> {
  final Value<int> downloadId;
  final Value<int> seq;
  final Value<String> url;
  final Value<int> bytes;
  final Value<bool> done;
  final Value<int> rowid;
  const DownloadSegmentsCompanion({
    this.downloadId = const Value.absent(),
    this.seq = const Value.absent(),
    this.url = const Value.absent(),
    this.bytes = const Value.absent(),
    this.done = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadSegmentsCompanion.insert({
    required int downloadId,
    required int seq,
    required String url,
    this.bytes = const Value.absent(),
    this.done = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : downloadId = Value(downloadId),
       seq = Value(seq),
       url = Value(url);
  static Insertable<DownloadSegment> custom({
    Expression<int>? downloadId,
    Expression<int>? seq,
    Expression<String>? url,
    Expression<int>? bytes,
    Expression<bool>? done,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (downloadId != null) 'download_id': downloadId,
      if (seq != null) 'seq': seq,
      if (url != null) 'url': url,
      if (bytes != null) 'bytes': bytes,
      if (done != null) 'done': done,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadSegmentsCompanion copyWith({
    Value<int>? downloadId,
    Value<int>? seq,
    Value<String>? url,
    Value<int>? bytes,
    Value<bool>? done,
    Value<int>? rowid,
  }) {
    return DownloadSegmentsCompanion(
      downloadId: downloadId ?? this.downloadId,
      seq: seq ?? this.seq,
      url: url ?? this.url,
      bytes: bytes ?? this.bytes,
      done: done ?? this.done,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (downloadId.present) {
      map['download_id'] = Variable<int>(downloadId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadSegmentsCompanion(')
          ..write('downloadId: $downloadId, ')
          ..write('seq: $seq, ')
          ..write('url: $url, ')
          ..write('bytes: $bytes, ')
          ..write('done: $done, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PluginSettingsTable extends PluginSettings
    with TableInfo<$PluginSettingsTable, PluginSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PluginSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pluginIdMeta = const VerificationMeta(
    'pluginId',
  );
  @override
  late final GeneratedColumn<String> pluginId = GeneratedColumn<String>(
    'plugin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES plugin (plugin_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [pluginId, key, valueJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plugin_setting';
  @override
  VerificationContext validateIntegrity(
    Insertable<PluginSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('plugin_id')) {
      context.handle(
        _pluginIdMeta,
        pluginId.isAcceptableOrUnknown(data['plugin_id']!, _pluginIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pluginIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pluginId, key};
  @override
  PluginSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PluginSetting(
      pluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
    );
  }

  @override
  $PluginSettingsTable createAlias(String alias) {
    return $PluginSettingsTable(attachedDatabase, alias);
  }
}

class PluginSetting extends DataClass implements Insertable<PluginSetting> {
  final String pluginId;
  final String key;
  final String valueJson;
  const PluginSetting({
    required this.pluginId,
    required this.key,
    required this.valueJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['plugin_id'] = Variable<String>(pluginId);
    map['key'] = Variable<String>(key);
    map['value_json'] = Variable<String>(valueJson);
    return map;
  }

  PluginSettingsCompanion toCompanion(bool nullToAbsent) {
    return PluginSettingsCompanion(
      pluginId: Value(pluginId),
      key: Value(key),
      valueJson: Value(valueJson),
    );
  }

  factory PluginSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PluginSetting(
      pluginId: serializer.fromJson<String>(json['pluginId']),
      key: serializer.fromJson<String>(json['key']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pluginId': serializer.toJson<String>(pluginId),
      'key': serializer.toJson<String>(key),
      'valueJson': serializer.toJson<String>(valueJson),
    };
  }

  PluginSetting copyWith({String? pluginId, String? key, String? valueJson}) =>
      PluginSetting(
        pluginId: pluginId ?? this.pluginId,
        key: key ?? this.key,
        valueJson: valueJson ?? this.valueJson,
      );
  PluginSetting copyWithCompanion(PluginSettingsCompanion data) {
    return PluginSetting(
      pluginId: data.pluginId.present ? data.pluginId.value : this.pluginId,
      key: data.key.present ? data.key.value : this.key,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PluginSetting(')
          ..write('pluginId: $pluginId, ')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(pluginId, key, valueJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PluginSetting &&
          other.pluginId == this.pluginId &&
          other.key == this.key &&
          other.valueJson == this.valueJson);
}

class PluginSettingsCompanion extends UpdateCompanion<PluginSetting> {
  final Value<String> pluginId;
  final Value<String> key;
  final Value<String> valueJson;
  final Value<int> rowid;
  const PluginSettingsCompanion({
    this.pluginId = const Value.absent(),
    this.key = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PluginSettingsCompanion.insert({
    required String pluginId,
    required String key,
    required String valueJson,
    this.rowid = const Value.absent(),
  }) : pluginId = Value(pluginId),
       key = Value(key),
       valueJson = Value(valueJson);
  static Insertable<PluginSetting> custom({
    Expression<String>? pluginId,
    Expression<String>? key,
    Expression<String>? valueJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pluginId != null) 'plugin_id': pluginId,
      if (key != null) 'key': key,
      if (valueJson != null) 'value_json': valueJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PluginSettingsCompanion copyWith({
    Value<String>? pluginId,
    Value<String>? key,
    Value<String>? valueJson,
    Value<int>? rowid,
  }) {
    return PluginSettingsCompanion(
      pluginId: pluginId ?? this.pluginId,
      key: key ?? this.key,
      valueJson: valueJson ?? this.valueJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pluginId.present) {
      map['plugin_id'] = Variable<String>(pluginId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PluginSettingsCompanion(')
          ..write('pluginId: $pluginId, ')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PluginStoragesTable extends PluginStorages
    with TableInfo<$PluginStoragesTable, PluginStorage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PluginStoragesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($PluginStoragesTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [owner, key, value, bytes, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plugin_storage';
  @override
  VerificationContext validateIntegrity(
    Insertable<PluginStorage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
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
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {owner, key};
  @override
  PluginStorage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PluginStorage(
      owner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      updatedAt: $PluginStoragesTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $PluginStoragesTable createAlias(String alias) {
    return $PluginStoragesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt = utcMillis;
}

class PluginStorage extends DataClass implements Insertable<PluginStorage> {
  final String owner;
  final String key;
  final String value;
  final int bytes;
  final DateTime updatedAt;
  const PluginStorage({
    required this.owner,
    required this.key,
    required this.value,
    required this.bytes,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner'] = Variable<String>(owner);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['bytes'] = Variable<int>(bytes);
    {
      map['updated_at'] = Variable<int>(
        $PluginStoragesTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  PluginStoragesCompanion toCompanion(bool nullToAbsent) {
    return PluginStoragesCompanion(
      owner: Value(owner),
      key: Value(key),
      value: Value(value),
      bytes: Value(bytes),
      updatedAt: Value(updatedAt),
    );
  }

  factory PluginStorage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PluginStorage(
      owner: serializer.fromJson<String>(json['owner']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      bytes: serializer.fromJson<int>(json['bytes']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'owner': serializer.toJson<String>(owner),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'bytes': serializer.toJson<int>(bytes),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PluginStorage copyWith({
    String? owner,
    String? key,
    String? value,
    int? bytes,
    DateTime? updatedAt,
  }) => PluginStorage(
    owner: owner ?? this.owner,
    key: key ?? this.key,
    value: value ?? this.value,
    bytes: bytes ?? this.bytes,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PluginStorage copyWithCompanion(PluginStoragesCompanion data) {
    return PluginStorage(
      owner: data.owner.present ? data.owner.value : this.owner,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PluginStorage(')
          ..write('owner: $owner, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('bytes: $bytes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(owner, key, value, bytes, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PluginStorage &&
          other.owner == this.owner &&
          other.key == this.key &&
          other.value == this.value &&
          other.bytes == this.bytes &&
          other.updatedAt == this.updatedAt);
}

class PluginStoragesCompanion extends UpdateCompanion<PluginStorage> {
  final Value<String> owner;
  final Value<String> key;
  final Value<String> value;
  final Value<int> bytes;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PluginStoragesCompanion({
    this.owner = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.bytes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PluginStoragesCompanion.insert({
    required String owner,
    required String key,
    required String value,
    required int bytes,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : owner = Value(owner),
       key = Value(key),
       value = Value(value),
       bytes = Value(bytes),
       updatedAt = Value(updatedAt);
  static Insertable<PluginStorage> custom({
    Expression<String>? owner,
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? bytes,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (owner != null) 'owner': owner,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (bytes != null) 'bytes': bytes,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PluginStoragesCompanion copyWith({
    Value<String>? owner,
    Value<String>? key,
    Value<String>? value,
    Value<int>? bytes,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PluginStoragesCompanion(
      owner: owner ?? this.owner,
      key: key ?? this.key,
      value: value ?? this.value,
      bytes: bytes ?? this.bytes,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $PluginStoragesTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PluginStoragesCompanion(')
          ..write('owner: $owner, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('bytes: $bytes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LiveGroupsTable extends LiveGroups
    with TableInfo<$LiveGroupsTable, LiveGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LiveGroupsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _configIdMeta = const VerificationMeta(
    'configId',
  );
  @override
  late final GeneratedColumn<int> configId = GeneratedColumn<int>(
    'config_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES config_source (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, configId, name, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'live_group';
  @override
  VerificationContext validateIntegrity(
    Insertable<LiveGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('config_id')) {
      context.handle(
        _configIdMeta,
        configId.isAcceptableOrUnknown(data['config_id']!, _configIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LiveGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LiveGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      configId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}config_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $LiveGroupsTable createAlias(String alias) {
    return $LiveGroupsTable(attachedDatabase, alias);
  }
}

class LiveGroup extends DataClass implements Insertable<LiveGroup> {
  final int id;
  final int? configId;
  final String name;
  final int sortOrder;
  const LiveGroup({
    required this.id,
    this.configId,
    required this.name,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || configId != null) {
      map['config_id'] = Variable<int>(configId);
    }
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  LiveGroupsCompanion toCompanion(bool nullToAbsent) {
    return LiveGroupsCompanion(
      id: Value(id),
      configId: configId == null && nullToAbsent
          ? const Value.absent()
          : Value(configId),
      name: Value(name),
      sortOrder: Value(sortOrder),
    );
  }

  factory LiveGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LiveGroup(
      id: serializer.fromJson<int>(json['id']),
      configId: serializer.fromJson<int?>(json['configId']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'configId': serializer.toJson<int?>(configId),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  LiveGroup copyWith({
    int? id,
    Value<int?> configId = const Value.absent(),
    String? name,
    int? sortOrder,
  }) => LiveGroup(
    id: id ?? this.id,
    configId: configId.present ? configId.value : this.configId,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  LiveGroup copyWithCompanion(LiveGroupsCompanion data) {
    return LiveGroup(
      id: data.id.present ? data.id.value : this.id,
      configId: data.configId.present ? data.configId.value : this.configId,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LiveGroup(')
          ..write('id: $id, ')
          ..write('configId: $configId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, configId, name, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LiveGroup &&
          other.id == this.id &&
          other.configId == this.configId &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder);
}

class LiveGroupsCompanion extends UpdateCompanion<LiveGroup> {
  final Value<int> id;
  final Value<int?> configId;
  final Value<String> name;
  final Value<int> sortOrder;
  const LiveGroupsCompanion({
    this.id = const Value.absent(),
    this.configId = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  LiveGroupsCompanion.insert({
    this.id = const Value.absent(),
    this.configId = const Value.absent(),
    required String name,
    this.sortOrder = const Value.absent(),
  }) : name = Value(name);
  static Insertable<LiveGroup> custom({
    Expression<int>? id,
    Expression<int>? configId,
    Expression<String>? name,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (configId != null) 'config_id': configId,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  LiveGroupsCompanion copyWith({
    Value<int>? id,
    Value<int?>? configId,
    Value<String>? name,
    Value<int>? sortOrder,
  }) {
    return LiveGroupsCompanion(
      id: id ?? this.id,
      configId: configId ?? this.configId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (configId.present) {
      map['config_id'] = Variable<int>(configId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LiveGroupsCompanion(')
          ..write('id: $id, ')
          ..write('configId: $configId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $LiveChannelsTable extends LiveChannels
    with TableInfo<$LiveChannelsTable, LiveChannel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LiveChannelsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES live_group (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _logoMeta = const VerificationMeta('logo');
  @override
  late final GeneratedColumn<String> logo = GeneratedColumn<String>(
    'logo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlsJsonMeta = const VerificationMeta(
    'urlsJson',
  );
  @override
  late final GeneratedColumn<String> urlsJson = GeneratedColumn<String>(
    'urls_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _epgIdMeta = const VerificationMeta('epgId');
  @override
  late final GeneratedColumn<String> epgId = GeneratedColumn<String>(
    'epg_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _headersJsonMeta = const VerificationMeta(
    'headersJson',
  );
  @override
  late final GeneratedColumn<String> headersJson = GeneratedColumn<String>(
    'headers_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _favoriteMeta = const VerificationMeta(
    'favorite',
  );
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
    'favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastPlayedAt =
      GeneratedColumn<int>(
        'last_played_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($LiveChannelsTable.$converterlastPlayedAtn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    name,
    logo,
    urlsJson,
    epgId,
    headersJson,
    sortOrder,
    favorite,
    lastPlayedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'live_channel';
  @override
  VerificationContext validateIntegrity(
    Insertable<LiveChannel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('logo')) {
      context.handle(
        _logoMeta,
        logo.isAcceptableOrUnknown(data['logo']!, _logoMeta),
      );
    }
    if (data.containsKey('urls_json')) {
      context.handle(
        _urlsJsonMeta,
        urlsJson.isAcceptableOrUnknown(data['urls_json']!, _urlsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_urlsJsonMeta);
    }
    if (data.containsKey('epg_id')) {
      context.handle(
        _epgIdMeta,
        epgId.isAcceptableOrUnknown(data['epg_id']!, _epgIdMeta),
      );
    }
    if (data.containsKey('headers_json')) {
      context.handle(
        _headersJsonMeta,
        headersJson.isAcceptableOrUnknown(
          data['headers_json']!,
          _headersJsonMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('favorite')) {
      context.handle(
        _favoriteMeta,
        favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LiveChannel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LiveChannel(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      logo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo'],
      ),
      urlsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}urls_json'],
      )!,
      epgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_id'],
      ),
      headersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headers_json'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      favorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}favorite'],
      )!,
      lastPlayedAt: $LiveChannelsTable.$converterlastPlayedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_played_at'],
        ),
      ),
    );
  }

  @override
  $LiveChannelsTable createAlias(String alias) {
    return $LiveChannelsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterlastPlayedAt = utcMillis;
  static TypeConverter<DateTime?, int?> $converterlastPlayedAtn =
      NullAwareTypeConverter.wrap($converterlastPlayedAt);
}

class LiveChannel extends DataClass implements Insertable<LiveChannel> {
  final int id;
  final int groupId;
  final String name;
  final String? logo;
  final String urlsJson;
  final String? epgId;
  final String? headersJson;
  final int sortOrder;
  final bool favorite;
  final DateTime? lastPlayedAt;
  const LiveChannel({
    required this.id,
    required this.groupId,
    required this.name,
    this.logo,
    required this.urlsJson,
    this.epgId,
    this.headersJson,
    required this.sortOrder,
    required this.favorite,
    this.lastPlayedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['group_id'] = Variable<int>(groupId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || logo != null) {
      map['logo'] = Variable<String>(logo);
    }
    map['urls_json'] = Variable<String>(urlsJson);
    if (!nullToAbsent || epgId != null) {
      map['epg_id'] = Variable<String>(epgId);
    }
    if (!nullToAbsent || headersJson != null) {
      map['headers_json'] = Variable<String>(headersJson);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['favorite'] = Variable<bool>(favorite);
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<int>(
        $LiveChannelsTable.$converterlastPlayedAtn.toSql(lastPlayedAt),
      );
    }
    return map;
  }

  LiveChannelsCompanion toCompanion(bool nullToAbsent) {
    return LiveChannelsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      name: Value(name),
      logo: logo == null && nullToAbsent ? const Value.absent() : Value(logo),
      urlsJson: Value(urlsJson),
      epgId: epgId == null && nullToAbsent
          ? const Value.absent()
          : Value(epgId),
      headersJson: headersJson == null && nullToAbsent
          ? const Value.absent()
          : Value(headersJson),
      sortOrder: Value(sortOrder),
      favorite: Value(favorite),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
    );
  }

  factory LiveChannel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LiveChannel(
      id: serializer.fromJson<int>(json['id']),
      groupId: serializer.fromJson<int>(json['groupId']),
      name: serializer.fromJson<String>(json['name']),
      logo: serializer.fromJson<String?>(json['logo']),
      urlsJson: serializer.fromJson<String>(json['urlsJson']),
      epgId: serializer.fromJson<String?>(json['epgId']),
      headersJson: serializer.fromJson<String?>(json['headersJson']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      favorite: serializer.fromJson<bool>(json['favorite']),
      lastPlayedAt: serializer.fromJson<DateTime?>(json['lastPlayedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'groupId': serializer.toJson<int>(groupId),
      'name': serializer.toJson<String>(name),
      'logo': serializer.toJson<String?>(logo),
      'urlsJson': serializer.toJson<String>(urlsJson),
      'epgId': serializer.toJson<String?>(epgId),
      'headersJson': serializer.toJson<String?>(headersJson),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'favorite': serializer.toJson<bool>(favorite),
      'lastPlayedAt': serializer.toJson<DateTime?>(lastPlayedAt),
    };
  }

  LiveChannel copyWith({
    int? id,
    int? groupId,
    String? name,
    Value<String?> logo = const Value.absent(),
    String? urlsJson,
    Value<String?> epgId = const Value.absent(),
    Value<String?> headersJson = const Value.absent(),
    int? sortOrder,
    bool? favorite,
    Value<DateTime?> lastPlayedAt = const Value.absent(),
  }) => LiveChannel(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    name: name ?? this.name,
    logo: logo.present ? logo.value : this.logo,
    urlsJson: urlsJson ?? this.urlsJson,
    epgId: epgId.present ? epgId.value : this.epgId,
    headersJson: headersJson.present ? headersJson.value : this.headersJson,
    sortOrder: sortOrder ?? this.sortOrder,
    favorite: favorite ?? this.favorite,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
  );
  LiveChannel copyWithCompanion(LiveChannelsCompanion data) {
    return LiveChannel(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      name: data.name.present ? data.name.value : this.name,
      logo: data.logo.present ? data.logo.value : this.logo,
      urlsJson: data.urlsJson.present ? data.urlsJson.value : this.urlsJson,
      epgId: data.epgId.present ? data.epgId.value : this.epgId,
      headersJson: data.headersJson.present
          ? data.headersJson.value
          : this.headersJson,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LiveChannel(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('logo: $logo, ')
          ..write('urlsJson: $urlsJson, ')
          ..write('epgId: $epgId, ')
          ..write('headersJson: $headersJson, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('favorite: $favorite, ')
          ..write('lastPlayedAt: $lastPlayedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    name,
    logo,
    urlsJson,
    epgId,
    headersJson,
    sortOrder,
    favorite,
    lastPlayedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LiveChannel &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.name == this.name &&
          other.logo == this.logo &&
          other.urlsJson == this.urlsJson &&
          other.epgId == this.epgId &&
          other.headersJson == this.headersJson &&
          other.sortOrder == this.sortOrder &&
          other.favorite == this.favorite &&
          other.lastPlayedAt == this.lastPlayedAt);
}

class LiveChannelsCompanion extends UpdateCompanion<LiveChannel> {
  final Value<int> id;
  final Value<int> groupId;
  final Value<String> name;
  final Value<String?> logo;
  final Value<String> urlsJson;
  final Value<String?> epgId;
  final Value<String?> headersJson;
  final Value<int> sortOrder;
  final Value<bool> favorite;
  final Value<DateTime?> lastPlayedAt;
  const LiveChannelsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.name = const Value.absent(),
    this.logo = const Value.absent(),
    this.urlsJson = const Value.absent(),
    this.epgId = const Value.absent(),
    this.headersJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.favorite = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
  });
  LiveChannelsCompanion.insert({
    this.id = const Value.absent(),
    required int groupId,
    required String name,
    this.logo = const Value.absent(),
    required String urlsJson,
    this.epgId = const Value.absent(),
    this.headersJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.favorite = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
  }) : groupId = Value(groupId),
       name = Value(name),
       urlsJson = Value(urlsJson);
  static Insertable<LiveChannel> custom({
    Expression<int>? id,
    Expression<int>? groupId,
    Expression<String>? name,
    Expression<String>? logo,
    Expression<String>? urlsJson,
    Expression<String>? epgId,
    Expression<String>? headersJson,
    Expression<int>? sortOrder,
    Expression<bool>? favorite,
    Expression<int>? lastPlayedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (name != null) 'name': name,
      if (logo != null) 'logo': logo,
      if (urlsJson != null) 'urls_json': urlsJson,
      if (epgId != null) 'epg_id': epgId,
      if (headersJson != null) 'headers_json': headersJson,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (favorite != null) 'favorite': favorite,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
    });
  }

  LiveChannelsCompanion copyWith({
    Value<int>? id,
    Value<int>? groupId,
    Value<String>? name,
    Value<String?>? logo,
    Value<String>? urlsJson,
    Value<String?>? epgId,
    Value<String?>? headersJson,
    Value<int>? sortOrder,
    Value<bool>? favorite,
    Value<DateTime?>? lastPlayedAt,
  }) {
    return LiveChannelsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      logo: logo ?? this.logo,
      urlsJson: urlsJson ?? this.urlsJson,
      epgId: epgId ?? this.epgId,
      headersJson: headersJson ?? this.headersJson,
      sortOrder: sortOrder ?? this.sortOrder,
      favorite: favorite ?? this.favorite,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (logo.present) {
      map['logo'] = Variable<String>(logo.value);
    }
    if (urlsJson.present) {
      map['urls_json'] = Variable<String>(urlsJson.value);
    }
    if (epgId.present) {
      map['epg_id'] = Variable<String>(epgId.value);
    }
    if (headersJson.present) {
      map['headers_json'] = Variable<String>(headersJson.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<int>(
        $LiveChannelsTable.$converterlastPlayedAtn.toSql(lastPlayedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LiveChannelsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('logo: $logo, ')
          ..write('urlsJson: $urlsJson, ')
          ..write('epgId: $epgId, ')
          ..write('headersJson: $headersJson, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('favorite: $favorite, ')
          ..write('lastPlayedAt: $lastPlayedAt')
          ..write(')'))
        .toString();
  }
}

class $ParseRulesTable extends ParseRules
    with TableInfo<$ParseRulesTable, ParseRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParseRulesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _configIdMeta = const VerificationMeta(
    'configId',
  );
  @override
  late final GeneratedColumn<int> configId = GeneratedColumn<int>(
    'config_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES config_source (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _typeCodeMeta = const VerificationMeta(
    'typeCode',
  );
  @override
  late final GeneratedColumn<int> typeCode = GeneratedColumn<int>(
    'type_code',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _extJsonMeta = const VerificationMeta(
    'extJson',
  );
  @override
  late final GeneratedColumn<String> extJson = GeneratedColumn<String>(
    'ext_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _flagsJsonMeta = const VerificationMeta(
    'flagsJson',
  );
  @override
  late final GeneratedColumn<String> flagsJson = GeneratedColumn<String>(
    'flags_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _successCountMeta = const VerificationMeta(
    'successCount',
  );
  @override
  late final GeneratedColumn<int> successCount = GeneratedColumn<int>(
    'success_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _failCountMeta = const VerificationMeta(
    'failCount',
  );
  @override
  late final GeneratedColumn<int> failCount = GeneratedColumn<int>(
    'fail_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _avgLatencyMsMeta = const VerificationMeta(
    'avgLatencyMs',
  );
  @override
  late final GeneratedColumn<int> avgLatencyMs = GeneratedColumn<int>(
    'avg_latency_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    configId,
    name,
    typeCode,
    url,
    extJson,
    flagsJson,
    enabled,
    priority,
    successCount,
    failCount,
    avgLatencyMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parse_rule';
  @override
  VerificationContext validateIntegrity(
    Insertable<ParseRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('config_id')) {
      context.handle(
        _configIdMeta,
        configId.isAcceptableOrUnknown(data['config_id']!, _configIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type_code')) {
      context.handle(
        _typeCodeMeta,
        typeCode.isAcceptableOrUnknown(data['type_code']!, _typeCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeCodeMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('ext_json')) {
      context.handle(
        _extJsonMeta,
        extJson.isAcceptableOrUnknown(data['ext_json']!, _extJsonMeta),
      );
    }
    if (data.containsKey('flags_json')) {
      context.handle(
        _flagsJsonMeta,
        flagsJson.isAcceptableOrUnknown(data['flags_json']!, _flagsJsonMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('success_count')) {
      context.handle(
        _successCountMeta,
        successCount.isAcceptableOrUnknown(
          data['success_count']!,
          _successCountMeta,
        ),
      );
    }
    if (data.containsKey('fail_count')) {
      context.handle(
        _failCountMeta,
        failCount.isAcceptableOrUnknown(data['fail_count']!, _failCountMeta),
      );
    }
    if (data.containsKey('avg_latency_ms')) {
      context.handle(
        _avgLatencyMsMeta,
        avgLatencyMs.isAcceptableOrUnknown(
          data['avg_latency_ms']!,
          _avgLatencyMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ParseRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ParseRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      configId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}config_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      typeCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_code'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      extJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ext_json'],
      ),
      flagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}flags_json'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      successCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}success_count'],
      )!,
      failCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fail_count'],
      )!,
      avgLatencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avg_latency_ms'],
      ),
    );
  }

  @override
  $ParseRulesTable createAlias(String alias) {
    return $ParseRulesTable(attachedDatabase, alias);
  }
}

class ParseRule extends DataClass implements Insertable<ParseRule> {
  final int id;
  final int? configId;
  final String name;
  final int typeCode;
  final String url;
  final String? extJson;
  final String? flagsJson;
  final bool enabled;
  final int priority;
  final int successCount;
  final int failCount;
  final int? avgLatencyMs;
  const ParseRule({
    required this.id,
    this.configId,
    required this.name,
    required this.typeCode,
    required this.url,
    this.extJson,
    this.flagsJson,
    required this.enabled,
    required this.priority,
    required this.successCount,
    required this.failCount,
    this.avgLatencyMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || configId != null) {
      map['config_id'] = Variable<int>(configId);
    }
    map['name'] = Variable<String>(name);
    map['type_code'] = Variable<int>(typeCode);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || extJson != null) {
      map['ext_json'] = Variable<String>(extJson);
    }
    if (!nullToAbsent || flagsJson != null) {
      map['flags_json'] = Variable<String>(flagsJson);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['priority'] = Variable<int>(priority);
    map['success_count'] = Variable<int>(successCount);
    map['fail_count'] = Variable<int>(failCount);
    if (!nullToAbsent || avgLatencyMs != null) {
      map['avg_latency_ms'] = Variable<int>(avgLatencyMs);
    }
    return map;
  }

  ParseRulesCompanion toCompanion(bool nullToAbsent) {
    return ParseRulesCompanion(
      id: Value(id),
      configId: configId == null && nullToAbsent
          ? const Value.absent()
          : Value(configId),
      name: Value(name),
      typeCode: Value(typeCode),
      url: Value(url),
      extJson: extJson == null && nullToAbsent
          ? const Value.absent()
          : Value(extJson),
      flagsJson: flagsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(flagsJson),
      enabled: Value(enabled),
      priority: Value(priority),
      successCount: Value(successCount),
      failCount: Value(failCount),
      avgLatencyMs: avgLatencyMs == null && nullToAbsent
          ? const Value.absent()
          : Value(avgLatencyMs),
    );
  }

  factory ParseRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ParseRule(
      id: serializer.fromJson<int>(json['id']),
      configId: serializer.fromJson<int?>(json['configId']),
      name: serializer.fromJson<String>(json['name']),
      typeCode: serializer.fromJson<int>(json['typeCode']),
      url: serializer.fromJson<String>(json['url']),
      extJson: serializer.fromJson<String?>(json['extJson']),
      flagsJson: serializer.fromJson<String?>(json['flagsJson']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      priority: serializer.fromJson<int>(json['priority']),
      successCount: serializer.fromJson<int>(json['successCount']),
      failCount: serializer.fromJson<int>(json['failCount']),
      avgLatencyMs: serializer.fromJson<int?>(json['avgLatencyMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'configId': serializer.toJson<int?>(configId),
      'name': serializer.toJson<String>(name),
      'typeCode': serializer.toJson<int>(typeCode),
      'url': serializer.toJson<String>(url),
      'extJson': serializer.toJson<String?>(extJson),
      'flagsJson': serializer.toJson<String?>(flagsJson),
      'enabled': serializer.toJson<bool>(enabled),
      'priority': serializer.toJson<int>(priority),
      'successCount': serializer.toJson<int>(successCount),
      'failCount': serializer.toJson<int>(failCount),
      'avgLatencyMs': serializer.toJson<int?>(avgLatencyMs),
    };
  }

  ParseRule copyWith({
    int? id,
    Value<int?> configId = const Value.absent(),
    String? name,
    int? typeCode,
    String? url,
    Value<String?> extJson = const Value.absent(),
    Value<String?> flagsJson = const Value.absent(),
    bool? enabled,
    int? priority,
    int? successCount,
    int? failCount,
    Value<int?> avgLatencyMs = const Value.absent(),
  }) => ParseRule(
    id: id ?? this.id,
    configId: configId.present ? configId.value : this.configId,
    name: name ?? this.name,
    typeCode: typeCode ?? this.typeCode,
    url: url ?? this.url,
    extJson: extJson.present ? extJson.value : this.extJson,
    flagsJson: flagsJson.present ? flagsJson.value : this.flagsJson,
    enabled: enabled ?? this.enabled,
    priority: priority ?? this.priority,
    successCount: successCount ?? this.successCount,
    failCount: failCount ?? this.failCount,
    avgLatencyMs: avgLatencyMs.present ? avgLatencyMs.value : this.avgLatencyMs,
  );
  ParseRule copyWithCompanion(ParseRulesCompanion data) {
    return ParseRule(
      id: data.id.present ? data.id.value : this.id,
      configId: data.configId.present ? data.configId.value : this.configId,
      name: data.name.present ? data.name.value : this.name,
      typeCode: data.typeCode.present ? data.typeCode.value : this.typeCode,
      url: data.url.present ? data.url.value : this.url,
      extJson: data.extJson.present ? data.extJson.value : this.extJson,
      flagsJson: data.flagsJson.present ? data.flagsJson.value : this.flagsJson,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      priority: data.priority.present ? data.priority.value : this.priority,
      successCount: data.successCount.present
          ? data.successCount.value
          : this.successCount,
      failCount: data.failCount.present ? data.failCount.value : this.failCount,
      avgLatencyMs: data.avgLatencyMs.present
          ? data.avgLatencyMs.value
          : this.avgLatencyMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ParseRule(')
          ..write('id: $id, ')
          ..write('configId: $configId, ')
          ..write('name: $name, ')
          ..write('typeCode: $typeCode, ')
          ..write('url: $url, ')
          ..write('extJson: $extJson, ')
          ..write('flagsJson: $flagsJson, ')
          ..write('enabled: $enabled, ')
          ..write('priority: $priority, ')
          ..write('successCount: $successCount, ')
          ..write('failCount: $failCount, ')
          ..write('avgLatencyMs: $avgLatencyMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    configId,
    name,
    typeCode,
    url,
    extJson,
    flagsJson,
    enabled,
    priority,
    successCount,
    failCount,
    avgLatencyMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParseRule &&
          other.id == this.id &&
          other.configId == this.configId &&
          other.name == this.name &&
          other.typeCode == this.typeCode &&
          other.url == this.url &&
          other.extJson == this.extJson &&
          other.flagsJson == this.flagsJson &&
          other.enabled == this.enabled &&
          other.priority == this.priority &&
          other.successCount == this.successCount &&
          other.failCount == this.failCount &&
          other.avgLatencyMs == this.avgLatencyMs);
}

class ParseRulesCompanion extends UpdateCompanion<ParseRule> {
  final Value<int> id;
  final Value<int?> configId;
  final Value<String> name;
  final Value<int> typeCode;
  final Value<String> url;
  final Value<String?> extJson;
  final Value<String?> flagsJson;
  final Value<bool> enabled;
  final Value<int> priority;
  final Value<int> successCount;
  final Value<int> failCount;
  final Value<int?> avgLatencyMs;
  const ParseRulesCompanion({
    this.id = const Value.absent(),
    this.configId = const Value.absent(),
    this.name = const Value.absent(),
    this.typeCode = const Value.absent(),
    this.url = const Value.absent(),
    this.extJson = const Value.absent(),
    this.flagsJson = const Value.absent(),
    this.enabled = const Value.absent(),
    this.priority = const Value.absent(),
    this.successCount = const Value.absent(),
    this.failCount = const Value.absent(),
    this.avgLatencyMs = const Value.absent(),
  });
  ParseRulesCompanion.insert({
    this.id = const Value.absent(),
    this.configId = const Value.absent(),
    required String name,
    required int typeCode,
    required String url,
    this.extJson = const Value.absent(),
    this.flagsJson = const Value.absent(),
    this.enabled = const Value.absent(),
    this.priority = const Value.absent(),
    this.successCount = const Value.absent(),
    this.failCount = const Value.absent(),
    this.avgLatencyMs = const Value.absent(),
  }) : name = Value(name),
       typeCode = Value(typeCode),
       url = Value(url);
  static Insertable<ParseRule> custom({
    Expression<int>? id,
    Expression<int>? configId,
    Expression<String>? name,
    Expression<int>? typeCode,
    Expression<String>? url,
    Expression<String>? extJson,
    Expression<String>? flagsJson,
    Expression<bool>? enabled,
    Expression<int>? priority,
    Expression<int>? successCount,
    Expression<int>? failCount,
    Expression<int>? avgLatencyMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (configId != null) 'config_id': configId,
      if (name != null) 'name': name,
      if (typeCode != null) 'type_code': typeCode,
      if (url != null) 'url': url,
      if (extJson != null) 'ext_json': extJson,
      if (flagsJson != null) 'flags_json': flagsJson,
      if (enabled != null) 'enabled': enabled,
      if (priority != null) 'priority': priority,
      if (successCount != null) 'success_count': successCount,
      if (failCount != null) 'fail_count': failCount,
      if (avgLatencyMs != null) 'avg_latency_ms': avgLatencyMs,
    });
  }

  ParseRulesCompanion copyWith({
    Value<int>? id,
    Value<int?>? configId,
    Value<String>? name,
    Value<int>? typeCode,
    Value<String>? url,
    Value<String?>? extJson,
    Value<String?>? flagsJson,
    Value<bool>? enabled,
    Value<int>? priority,
    Value<int>? successCount,
    Value<int>? failCount,
    Value<int?>? avgLatencyMs,
  }) {
    return ParseRulesCompanion(
      id: id ?? this.id,
      configId: configId ?? this.configId,
      name: name ?? this.name,
      typeCode: typeCode ?? this.typeCode,
      url: url ?? this.url,
      extJson: extJson ?? this.extJson,
      flagsJson: flagsJson ?? this.flagsJson,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      successCount: successCount ?? this.successCount,
      failCount: failCount ?? this.failCount,
      avgLatencyMs: avgLatencyMs ?? this.avgLatencyMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (configId.present) {
      map['config_id'] = Variable<int>(configId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (typeCode.present) {
      map['type_code'] = Variable<int>(typeCode.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (extJson.present) {
      map['ext_json'] = Variable<String>(extJson.value);
    }
    if (flagsJson.present) {
      map['flags_json'] = Variable<String>(flagsJson.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (successCount.present) {
      map['success_count'] = Variable<int>(successCount.value);
    }
    if (failCount.present) {
      map['fail_count'] = Variable<int>(failCount.value);
    }
    if (avgLatencyMs.present) {
      map['avg_latency_ms'] = Variable<int>(avgLatencyMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParseRulesCompanion(')
          ..write('id: $id, ')
          ..write('configId: $configId, ')
          ..write('name: $name, ')
          ..write('typeCode: $typeCode, ')
          ..write('url: $url, ')
          ..write('extJson: $extJson, ')
          ..write('flagsJson: $flagsJson, ')
          ..write('enabled: $enabled, ')
          ..write('priority: $priority, ')
          ..write('successCount: $successCount, ')
          ..write('failCount: $failCount, ')
          ..write('avgLatencyMs: $avgLatencyMs')
          ..write(')'))
        .toString();
  }
}

class $SiteCachesTable extends SiteCaches
    with TableInfo<$SiteCachesTable, SiteCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SiteCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _siteIdMeta = const VerificationMeta('siteId');
  @override
  late final GeneratedColumn<int> siteId = GeneratedColumn<int>(
    'site_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES site (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> expiresAt =
      GeneratedColumn<int>(
        'expires_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($SiteCachesTable.$converterexpiresAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($SiteCachesTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    siteId,
    method,
    payload,
    bytes,
    expiresAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'site_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<SiteCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('site_id')) {
      context.handle(
        _siteIdMeta,
        siteId.isAcceptableOrUnknown(data['site_id']!, _siteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_siteIdMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  SiteCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SiteCache(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      siteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}site_id'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}payload'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      expiresAt: $SiteCachesTable.$converterexpiresAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}expires_at'],
        )!,
      ),
      createdAt: $SiteCachesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $SiteCachesTable createAlias(String alias) {
    return $SiteCachesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterexpiresAt = utcMillis;
  static TypeConverter<DateTime, int> $convertercreatedAt = utcMillis;
}

class SiteCache extends DataClass implements Insertable<SiteCache> {
  final String cacheKey;
  final int siteId;
  final String method;
  final Uint8List payload;
  final int bytes;
  final DateTime expiresAt;
  final DateTime createdAt;
  const SiteCache({
    required this.cacheKey,
    required this.siteId,
    required this.method,
    required this.payload,
    required this.bytes,
    required this.expiresAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['site_id'] = Variable<int>(siteId);
    map['method'] = Variable<String>(method);
    map['payload'] = Variable<Uint8List>(payload);
    map['bytes'] = Variable<int>(bytes);
    {
      map['expires_at'] = Variable<int>(
        $SiteCachesTable.$converterexpiresAt.toSql(expiresAt),
      );
    }
    {
      map['created_at'] = Variable<int>(
        $SiteCachesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  SiteCachesCompanion toCompanion(bool nullToAbsent) {
    return SiteCachesCompanion(
      cacheKey: Value(cacheKey),
      siteId: Value(siteId),
      method: Value(method),
      payload: Value(payload),
      bytes: Value(bytes),
      expiresAt: Value(expiresAt),
      createdAt: Value(createdAt),
    );
  }

  factory SiteCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SiteCache(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      siteId: serializer.fromJson<int>(json['siteId']),
      method: serializer.fromJson<String>(json['method']),
      payload: serializer.fromJson<Uint8List>(json['payload']),
      bytes: serializer.fromJson<int>(json['bytes']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'siteId': serializer.toJson<int>(siteId),
      'method': serializer.toJson<String>(method),
      'payload': serializer.toJson<Uint8List>(payload),
      'bytes': serializer.toJson<int>(bytes),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SiteCache copyWith({
    String? cacheKey,
    int? siteId,
    String? method,
    Uint8List? payload,
    int? bytes,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) => SiteCache(
    cacheKey: cacheKey ?? this.cacheKey,
    siteId: siteId ?? this.siteId,
    method: method ?? this.method,
    payload: payload ?? this.payload,
    bytes: bytes ?? this.bytes,
    expiresAt: expiresAt ?? this.expiresAt,
    createdAt: createdAt ?? this.createdAt,
  );
  SiteCache copyWithCompanion(SiteCachesCompanion data) {
    return SiteCache(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      siteId: data.siteId.present ? data.siteId.value : this.siteId,
      method: data.method.present ? data.method.value : this.method,
      payload: data.payload.present ? data.payload.value : this.payload,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SiteCache(')
          ..write('cacheKey: $cacheKey, ')
          ..write('siteId: $siteId, ')
          ..write('method: $method, ')
          ..write('payload: $payload, ')
          ..write('bytes: $bytes, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cacheKey,
    siteId,
    method,
    $driftBlobEquality.hash(payload),
    bytes,
    expiresAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SiteCache &&
          other.cacheKey == this.cacheKey &&
          other.siteId == this.siteId &&
          other.method == this.method &&
          $driftBlobEquality.equals(other.payload, this.payload) &&
          other.bytes == this.bytes &&
          other.expiresAt == this.expiresAt &&
          other.createdAt == this.createdAt);
}

class SiteCachesCompanion extends UpdateCompanion<SiteCache> {
  final Value<String> cacheKey;
  final Value<int> siteId;
  final Value<String> method;
  final Value<Uint8List> payload;
  final Value<int> bytes;
  final Value<DateTime> expiresAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SiteCachesCompanion({
    this.cacheKey = const Value.absent(),
    this.siteId = const Value.absent(),
    this.method = const Value.absent(),
    this.payload = const Value.absent(),
    this.bytes = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SiteCachesCompanion.insert({
    required String cacheKey,
    required int siteId,
    required String method,
    required Uint8List payload,
    required int bytes,
    required DateTime expiresAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       siteId = Value(siteId),
       method = Value(method),
       payload = Value(payload),
       bytes = Value(bytes),
       expiresAt = Value(expiresAt),
       createdAt = Value(createdAt);
  static Insertable<SiteCache> custom({
    Expression<String>? cacheKey,
    Expression<int>? siteId,
    Expression<String>? method,
    Expression<Uint8List>? payload,
    Expression<int>? bytes,
    Expression<int>? expiresAt,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (siteId != null) 'site_id': siteId,
      if (method != null) 'method': method,
      if (payload != null) 'payload': payload,
      if (bytes != null) 'bytes': bytes,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SiteCachesCompanion copyWith({
    Value<String>? cacheKey,
    Value<int>? siteId,
    Value<String>? method,
    Value<Uint8List>? payload,
    Value<int>? bytes,
    Value<DateTime>? expiresAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SiteCachesCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      siteId: siteId ?? this.siteId,
      method: method ?? this.method,
      payload: payload ?? this.payload,
      bytes: bytes ?? this.bytes,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (siteId.present) {
      map['site_id'] = Variable<int>(siteId.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (payload.present) {
      map['payload'] = Variable<Uint8List>(payload.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(
        $SiteCachesTable.$converterexpiresAt.toSql(expiresAt.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $SiteCachesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SiteCachesCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('siteId: $siteId, ')
          ..write('method: $method, ')
          ..write('payload: $payload, ')
          ..write('bytes: $bytes, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($SettingsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [key, valueJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setting';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
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
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
      updatedAt: $SettingsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt = utcMillis;
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String valueJson;
  final DateTime updatedAt;
  const Setting({
    required this.key,
    required this.valueJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value_json'] = Variable<String>(valueJson);
    {
      map['updated_at'] = Variable<int>(
        $SettingsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      valueJson: Value(valueJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'valueJson': serializer.toJson<String>(valueJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Setting copyWith({String? key, String? valueJson, DateTime? updatedAt}) =>
      Setting(
        key: key ?? this.key,
        valueJson: valueJson ?? this.valueJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, valueJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.key == this.key &&
          other.valueJson == this.valueJson &&
          other.updatedAt == this.updatedAt);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> valueJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String valueJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       valueJson = Value(valueJson),
       updatedAt = Value(updatedAt);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? valueJson,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (valueJson != null) 'value_json': valueJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? valueJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      valueJson: valueJson ?? this.valueJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $SettingsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoriesTable extends SearchHistories
    with TableInfo<$SearchHistoriesTable, SearchHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keywordMeta = const VerificationMeta(
    'keyword',
  );
  @override
  late final GeneratedColumn<String> keyword = GeneratedColumn<String>(
    'keyword',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hitCountMeta = const VerificationMeta(
    'hitCount',
  );
  @override
  late final GeneratedColumn<int> hitCount = GeneratedColumn<int>(
    'hit_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> lastAt =
      GeneratedColumn<int>(
        'last_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($SearchHistoriesTable.$converterlastAt);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  @override
  List<GeneratedColumn> get $columns => [keyword, hitCount, lastAt, source];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('keyword')) {
      context.handle(
        _keywordMeta,
        keyword.isAcceptableOrUnknown(data['keyword']!, _keywordMeta),
      );
    } else if (isInserting) {
      context.missing(_keywordMeta);
    }
    if (data.containsKey('hit_count')) {
      context.handle(
        _hitCountMeta,
        hitCount.isAcceptableOrUnknown(data['hit_count']!, _hitCountMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {keyword};
  @override
  SearchHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistory(
      keyword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keyword'],
      )!,
      hitCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hit_count'],
      )!,
      lastAt: $SearchHistoriesTable.$converterlastAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_at'],
        )!,
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $SearchHistoriesTable createAlias(String alias) {
    return $SearchHistoriesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterlastAt = utcMillis;
}

class SearchHistory extends DataClass implements Insertable<SearchHistory> {
  final String keyword;
  final int hitCount;
  final DateTime lastAt;
  final String source;
  const SearchHistory({
    required this.keyword,
    required this.hitCount,
    required this.lastAt,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['keyword'] = Variable<String>(keyword);
    map['hit_count'] = Variable<int>(hitCount);
    {
      map['last_at'] = Variable<int>(
        $SearchHistoriesTable.$converterlastAt.toSql(lastAt),
      );
    }
    map['source'] = Variable<String>(source);
    return map;
  }

  SearchHistoriesCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoriesCompanion(
      keyword: Value(keyword),
      hitCount: Value(hitCount),
      lastAt: Value(lastAt),
      source: Value(source),
    );
  }

  factory SearchHistory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistory(
      keyword: serializer.fromJson<String>(json['keyword']),
      hitCount: serializer.fromJson<int>(json['hitCount']),
      lastAt: serializer.fromJson<DateTime>(json['lastAt']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'keyword': serializer.toJson<String>(keyword),
      'hitCount': serializer.toJson<int>(hitCount),
      'lastAt': serializer.toJson<DateTime>(lastAt),
      'source': serializer.toJson<String>(source),
    };
  }

  SearchHistory copyWith({
    String? keyword,
    int? hitCount,
    DateTime? lastAt,
    String? source,
  }) => SearchHistory(
    keyword: keyword ?? this.keyword,
    hitCount: hitCount ?? this.hitCount,
    lastAt: lastAt ?? this.lastAt,
    source: source ?? this.source,
  );
  SearchHistory copyWithCompanion(SearchHistoriesCompanion data) {
    return SearchHistory(
      keyword: data.keyword.present ? data.keyword.value : this.keyword,
      hitCount: data.hitCount.present ? data.hitCount.value : this.hitCount,
      lastAt: data.lastAt.present ? data.lastAt.value : this.lastAt,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistory(')
          ..write('keyword: $keyword, ')
          ..write('hitCount: $hitCount, ')
          ..write('lastAt: $lastAt, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(keyword, hitCount, lastAt, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistory &&
          other.keyword == this.keyword &&
          other.hitCount == this.hitCount &&
          other.lastAt == this.lastAt &&
          other.source == this.source);
}

class SearchHistoriesCompanion extends UpdateCompanion<SearchHistory> {
  final Value<String> keyword;
  final Value<int> hitCount;
  final Value<DateTime> lastAt;
  final Value<String> source;
  final Value<int> rowid;
  const SearchHistoriesCompanion({
    this.keyword = const Value.absent(),
    this.hitCount = const Value.absent(),
    this.lastAt = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchHistoriesCompanion.insert({
    required String keyword,
    this.hitCount = const Value.absent(),
    required DateTime lastAt,
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : keyword = Value(keyword),
       lastAt = Value(lastAt);
  static Insertable<SearchHistory> custom({
    Expression<String>? keyword,
    Expression<int>? hitCount,
    Expression<int>? lastAt,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (keyword != null) 'keyword': keyword,
      if (hitCount != null) 'hit_count': hitCount,
      if (lastAt != null) 'last_at': lastAt,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchHistoriesCompanion copyWith({
    Value<String>? keyword,
    Value<int>? hitCount,
    Value<DateTime>? lastAt,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return SearchHistoriesCompanion(
      keyword: keyword ?? this.keyword,
      hitCount: hitCount ?? this.hitCount,
      lastAt: lastAt ?? this.lastAt,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (keyword.present) {
      map['keyword'] = Variable<String>(keyword.value);
    }
    if (hitCount.present) {
      map['hit_count'] = Variable<int>(hitCount.value);
    }
    if (lastAt.present) {
      map['last_at'] = Variable<int>(
        $SearchHistoriesTable.$converterlastAt.toSql(lastAt.value),
      );
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoriesCompanion(')
          ..write('keyword: $keyword, ')
          ..write('hitCount: $hitCount, ')
          ..write('lastAt: $lastAt, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppEventsTable extends AppEvents
    with TableInfo<$AppEventsTable, AppEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppEventsTable(this.attachedDatabase, [this._alias]);
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
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> ts =
      GeneratedColumn<int>(
        'ts',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($AppEventsTable.$converterts);
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _siteIdMeta = const VerificationMeta('siteId');
  @override
  late final GeneratedColumn<int> siteId = GeneratedColumn<int>(
    'site_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailJsonMeta = const VerificationMeta(
    'detailJson',
  );
  @override
  late final GeneratedColumn<String> detailJson = GeneratedColumn<String>(
    'detail_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ts,
    level,
    scope,
    siteId,
    code,
    message,
    detailJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_event';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('site_id')) {
      context.handle(
        _siteIdMeta,
        siteId.isAcceptableOrUnknown(data['site_id']!, _siteIdMeta),
      );
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('detail_json')) {
      context.handle(
        _detailJsonMeta,
        detailJson.isAcceptableOrUnknown(data['detail_json']!, _detailJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ts: $AppEventsTable.$converterts.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}ts'],
        )!,
      ),
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      siteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}site_id'],
      ),
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      ),
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
      detailJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail_json'],
      ),
    );
  }

  @override
  $AppEventsTable createAlias(String alias) {
    return $AppEventsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterts = utcMillis;
}

class AppEvent extends DataClass implements Insertable<AppEvent> {
  final int id;
  final DateTime ts;
  final String level;
  final String scope;
  final int? siteId;
  final String? code;
  final String message;
  final String? detailJson;
  const AppEvent({
    required this.id,
    required this.ts,
    required this.level,
    required this.scope,
    this.siteId,
    this.code,
    required this.message,
    this.detailJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['ts'] = Variable<int>($AppEventsTable.$converterts.toSql(ts));
    }
    map['level'] = Variable<String>(level);
    map['scope'] = Variable<String>(scope);
    if (!nullToAbsent || siteId != null) {
      map['site_id'] = Variable<int>(siteId);
    }
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    map['message'] = Variable<String>(message);
    if (!nullToAbsent || detailJson != null) {
      map['detail_json'] = Variable<String>(detailJson);
    }
    return map;
  }

  AppEventsCompanion toCompanion(bool nullToAbsent) {
    return AppEventsCompanion(
      id: Value(id),
      ts: Value(ts),
      level: Value(level),
      scope: Value(scope),
      siteId: siteId == null && nullToAbsent
          ? const Value.absent()
          : Value(siteId),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      message: Value(message),
      detailJson: detailJson == null && nullToAbsent
          ? const Value.absent()
          : Value(detailJson),
    );
  }

  factory AppEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppEvent(
      id: serializer.fromJson<int>(json['id']),
      ts: serializer.fromJson<DateTime>(json['ts']),
      level: serializer.fromJson<String>(json['level']),
      scope: serializer.fromJson<String>(json['scope']),
      siteId: serializer.fromJson<int?>(json['siteId']),
      code: serializer.fromJson<String?>(json['code']),
      message: serializer.fromJson<String>(json['message']),
      detailJson: serializer.fromJson<String?>(json['detailJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ts': serializer.toJson<DateTime>(ts),
      'level': serializer.toJson<String>(level),
      'scope': serializer.toJson<String>(scope),
      'siteId': serializer.toJson<int?>(siteId),
      'code': serializer.toJson<String?>(code),
      'message': serializer.toJson<String>(message),
      'detailJson': serializer.toJson<String?>(detailJson),
    };
  }

  AppEvent copyWith({
    int? id,
    DateTime? ts,
    String? level,
    String? scope,
    Value<int?> siteId = const Value.absent(),
    Value<String?> code = const Value.absent(),
    String? message,
    Value<String?> detailJson = const Value.absent(),
  }) => AppEvent(
    id: id ?? this.id,
    ts: ts ?? this.ts,
    level: level ?? this.level,
    scope: scope ?? this.scope,
    siteId: siteId.present ? siteId.value : this.siteId,
    code: code.present ? code.value : this.code,
    message: message ?? this.message,
    detailJson: detailJson.present ? detailJson.value : this.detailJson,
  );
  AppEvent copyWithCompanion(AppEventsCompanion data) {
    return AppEvent(
      id: data.id.present ? data.id.value : this.id,
      ts: data.ts.present ? data.ts.value : this.ts,
      level: data.level.present ? data.level.value : this.level,
      scope: data.scope.present ? data.scope.value : this.scope,
      siteId: data.siteId.present ? data.siteId.value : this.siteId,
      code: data.code.present ? data.code.value : this.code,
      message: data.message.present ? data.message.value : this.message,
      detailJson: data.detailJson.present
          ? data.detailJson.value
          : this.detailJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppEvent(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('level: $level, ')
          ..write('scope: $scope, ')
          ..write('siteId: $siteId, ')
          ..write('code: $code, ')
          ..write('message: $message, ')
          ..write('detailJson: $detailJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, ts, level, scope, siteId, code, message, detailJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppEvent &&
          other.id == this.id &&
          other.ts == this.ts &&
          other.level == this.level &&
          other.scope == this.scope &&
          other.siteId == this.siteId &&
          other.code == this.code &&
          other.message == this.message &&
          other.detailJson == this.detailJson);
}

class AppEventsCompanion extends UpdateCompanion<AppEvent> {
  final Value<int> id;
  final Value<DateTime> ts;
  final Value<String> level;
  final Value<String> scope;
  final Value<int?> siteId;
  final Value<String?> code;
  final Value<String> message;
  final Value<String?> detailJson;
  const AppEventsCompanion({
    this.id = const Value.absent(),
    this.ts = const Value.absent(),
    this.level = const Value.absent(),
    this.scope = const Value.absent(),
    this.siteId = const Value.absent(),
    this.code = const Value.absent(),
    this.message = const Value.absent(),
    this.detailJson = const Value.absent(),
  });
  AppEventsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime ts,
    required String level,
    required String scope,
    this.siteId = const Value.absent(),
    this.code = const Value.absent(),
    required String message,
    this.detailJson = const Value.absent(),
  }) : ts = Value(ts),
       level = Value(level),
       scope = Value(scope),
       message = Value(message);
  static Insertable<AppEvent> custom({
    Expression<int>? id,
    Expression<int>? ts,
    Expression<String>? level,
    Expression<String>? scope,
    Expression<int>? siteId,
    Expression<String>? code,
    Expression<String>? message,
    Expression<String>? detailJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ts != null) 'ts': ts,
      if (level != null) 'level': level,
      if (scope != null) 'scope': scope,
      if (siteId != null) 'site_id': siteId,
      if (code != null) 'code': code,
      if (message != null) 'message': message,
      if (detailJson != null) 'detail_json': detailJson,
    });
  }

  AppEventsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? ts,
    Value<String>? level,
    Value<String>? scope,
    Value<int?>? siteId,
    Value<String?>? code,
    Value<String>? message,
    Value<String?>? detailJson,
  }) {
    return AppEventsCompanion(
      id: id ?? this.id,
      ts: ts ?? this.ts,
      level: level ?? this.level,
      scope: scope ?? this.scope,
      siteId: siteId ?? this.siteId,
      code: code ?? this.code,
      message: message ?? this.message,
      detailJson: detailJson ?? this.detailJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>($AppEventsTable.$converterts.toSql(ts.value));
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (siteId.present) {
      map['site_id'] = Variable<int>(siteId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (detailJson.present) {
      map['detail_json'] = Variable<String>(detailJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppEventsCompanion(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('level: $level, ')
          ..write('scope: $scope, ')
          ..write('siteId: $siteId, ')
          ..write('code: $code, ')
          ..write('message: $message, ')
          ..write('detailJson: $detailJson')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ConfigSourcesTable configSources = $ConfigSourcesTable(this);
  late final $PluginsTable plugins = $PluginsTable(this);
  late final $SitesTable sites = $SitesTable(this);
  late final $HistoriesTable histories = $HistoriesTable(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  late final $DownloadSegmentsTable downloadSegments = $DownloadSegmentsTable(
    this,
  );
  late final $PluginSettingsTable pluginSettings = $PluginSettingsTable(this);
  late final $PluginStoragesTable pluginStorages = $PluginStoragesTable(this);
  late final $LiveGroupsTable liveGroups = $LiveGroupsTable(this);
  late final $LiveChannelsTable liveChannels = $LiveChannelsTable(this);
  late final $ParseRulesTable parseRules = $ParseRulesTable(this);
  late final $SiteCachesTable siteCaches = $SiteCachesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $SearchHistoriesTable searchHistories = $SearchHistoriesTable(
    this,
  );
  late final $AppEventsTable appEvents = $AppEventsTable(this);
  late final Index uxConfigSourceUrl = Index(
    'ux_config_source_url',
    'CREATE UNIQUE INDEX ux_config_source_url ON config_source (url) WHERE url IS NOT NULL',
  );
  late final Index uxSiteScopeKey = Index(
    'ux_site_scope_key',
    'CREATE UNIQUE INDEX ux_site_scope_key ON site (COALESCE(config_id, -1), COALESCE(plugin_id, \'\'), site_key)',
  );
  late final Index ixSiteEnabled = Index(
    'ix_site_enabled',
    'CREATE INDEX ix_site_enabled ON site (enabled, priority)',
  );
  late final Index uxHistoryItem = Index(
    'ux_history_item',
    'CREATE UNIQUE INDEX ux_history_item ON history (site_id, vod_id)',
  );
  late final Index ixHistoryRecent = Index(
    'ix_history_recent',
    'CREATE INDEX ix_history_recent ON history (played_at)',
  );
  late final Index uxFavoriteItem = Index(
    'ux_favorite_item',
    'CREATE UNIQUE INDEX ux_favorite_item ON favorite (site_id, vod_id)',
  );
  late final Index ixFavoriteFolder = Index(
    'ix_favorite_folder',
    'CREATE INDEX ix_favorite_folder ON favorite (folder, sort_order)',
  );
  late final Index ixDownloadStatus = Index(
    'ix_download_status',
    'CREATE INDEX ix_download_status ON download (status, priority, created_at)',
  );
  late final Index ixPluginStorageOwner = Index(
    'ix_plugin_storage_owner',
    'CREATE INDEX ix_plugin_storage_owner ON plugin_storage (owner)',
  );
  late final Index ixLiveChannelGroup = Index(
    'ix_live_channel_group',
    'CREATE INDEX ix_live_channel_group ON live_channel (group_id, sort_order)',
  );
  late final Index ixLiveChannelName = Index(
    'ix_live_channel_name',
    'CREATE INDEX ix_live_channel_name ON live_channel (name)',
  );
  late final Index ixSiteCacheExpiry = Index(
    'ix_site_cache_expiry',
    'CREATE INDEX ix_site_cache_expiry ON site_cache (expires_at)',
  );
  late final Index ixAppEventTs = Index(
    'ix_app_event_ts',
    'CREATE INDEX ix_app_event_ts ON app_event (ts)',
  );
  late final Index ixAppEventScope = Index(
    'ix_app_event_scope',
    'CREATE INDEX ix_app_event_scope ON app_event (scope, ts)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    configSources,
    plugins,
    sites,
    histories,
    favorites,
    downloads,
    downloadSegments,
    pluginSettings,
    pluginStorages,
    liveGroups,
    liveChannels,
    parseRules,
    siteCaches,
    settings,
    searchHistories,
    appEvents,
    uxConfigSourceUrl,
    uxSiteScopeKey,
    ixSiteEnabled,
    uxHistoryItem,
    ixHistoryRecent,
    uxFavoriteItem,
    ixFavoriteFolder,
    ixDownloadStatus,
    ixPluginStorageOwner,
    ixLiveChannelGroup,
    ixLiveChannelName,
    ixSiteCacheExpiry,
    ixAppEventTs,
    ixAppEventScope,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'config_source',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('site', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'plugin',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('site', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'site',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('history', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'site',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('favorite', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'site',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('download', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'download',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('download_segment', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'plugin',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('plugin_setting', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'config_source',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('live_group', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'live_group',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('live_channel', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'config_source',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('parse_rule', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'site',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('site_cache', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ConfigSourcesTableCreateCompanionBuilder =
    ConfigSourcesCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> url,
      Value<String?> localPath,
      required String rawHash,
      Value<String?> spider,
      Value<String?> spiderMd5,
      required String format,
      Value<bool> autoUpdate,
      Value<int> updateIntervalH,
      Value<DateTime?> lastSyncAt,
      Value<String?> lastError,
      Value<int> sortOrder,
      Value<bool> enabled,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$ConfigSourcesTableUpdateCompanionBuilder =
    ConfigSourcesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> url,
      Value<String?> localPath,
      Value<String> rawHash,
      Value<String?> spider,
      Value<String?> spiderMd5,
      Value<String> format,
      Value<bool> autoUpdate,
      Value<int> updateIntervalH,
      Value<DateTime?> lastSyncAt,
      Value<String?> lastError,
      Value<int> sortOrder,
      Value<bool> enabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$ConfigSourcesTableReferences
    extends BaseReferences<_$AppDatabase, $ConfigSourcesTable, ConfigSource> {
  $$ConfigSourcesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$SitesTable, List<Site>> _sitesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.sites,
    aliasName: 'config_source__id__site__config_id',
  );

  $$SitesTableProcessedTableManager get sitesRefs {
    final manager = $$SitesTableTableManager(
      $_db,
      $_db.sites,
    ).filter((f) => f.configId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sitesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LiveGroupsTable, List<LiveGroup>>
  _liveGroupsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.liveGroups,
    aliasName: 'config_source__id__live_group__config_id',
  );

  $$LiveGroupsTableProcessedTableManager get liveGroupsRefs {
    final manager = $$LiveGroupsTableTableManager(
      $_db,
      $_db.liveGroups,
    ).filter((f) => f.configId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_liveGroupsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ParseRulesTable, List<ParseRule>>
  _parseRulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.parseRules,
    aliasName: 'config_source__id__parse_rule__config_id',
  );

  $$ParseRulesTableProcessedTableManager get parseRulesRefs {
    final manager = $$ParseRulesTableTableManager(
      $_db,
      $_db.parseRules,
    ).filter((f) => f.configId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_parseRulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ConfigSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $ConfigSourcesTable> {
  $$ConfigSourcesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawHash => $composableBuilder(
    column: $table.rawHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spider => $composableBuilder(
    column: $table.spider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spiderMd5 => $composableBuilder(
    column: $table.spiderMd5,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoUpdate => $composableBuilder(
    column: $table.autoUpdate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updateIntervalH => $composableBuilder(
    column: $table.updateIntervalH,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get lastSyncAt =>
      $composableBuilder(
        column: $table.lastSyncAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  Expression<bool> sitesRefs(
    Expression<bool> Function($$SitesTableFilterComposer f) f,
  ) {
    final $$SitesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sites,
      getReferencedColumn: (t) => t.configId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SitesTableFilterComposer(
            $db: $db,
            $table: $db.sites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> liveGroupsRefs(
    Expression<bool> Function($$LiveGroupsTableFilterComposer f) f,
  ) {
    final $$LiveGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.liveGroups,
      getReferencedColumn: (t) => t.configId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LiveGroupsTableFilterComposer(
            $db: $db,
            $table: $db.liveGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> parseRulesRefs(
    Expression<bool> Function($$ParseRulesTableFilterComposer f) f,
  ) {
    final $$ParseRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.parseRules,
      getReferencedColumn: (t) => t.configId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParseRulesTableFilterComposer(
            $db: $db,
            $table: $db.parseRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConfigSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $ConfigSourcesTable> {
  $$ConfigSourcesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawHash => $composableBuilder(
    column: $table.rawHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spider => $composableBuilder(
    column: $table.spider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spiderMd5 => $composableBuilder(
    column: $table.spiderMd5,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoUpdate => $composableBuilder(
    column: $table.autoUpdate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updateIntervalH => $composableBuilder(
    column: $table.updateIntervalH,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConfigSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConfigSourcesTable> {
  $$ConfigSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get rawHash =>
      $composableBuilder(column: $table.rawHash, builder: (column) => column);

  GeneratedColumn<String> get spider =>
      $composableBuilder(column: $table.spider, builder: (column) => column);

  GeneratedColumn<String> get spiderMd5 =>
      $composableBuilder(column: $table.spiderMd5, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<bool> get autoUpdate => $composableBuilder(
    column: $table.autoUpdate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updateIntervalH => $composableBuilder(
    column: $table.updateIntervalH,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastSyncAt =>
      $composableBuilder(
        column: $table.lastSyncAt,
        builder: (column) => column,
      );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> sitesRefs<T extends Object>(
    Expression<T> Function($$SitesTableAnnotationComposer a) f,
  ) {
    final $$SitesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sites,
      getReferencedColumn: (t) => t.configId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SitesTableAnnotationComposer(
            $db: $db,
            $table: $db.sites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> liveGroupsRefs<T extends Object>(
    Expression<T> Function($$LiveGroupsTableAnnotationComposer a) f,
  ) {
    final $$LiveGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.liveGroups,
      getReferencedColumn: (t) => t.configId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LiveGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.liveGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> parseRulesRefs<T extends Object>(
    Expression<T> Function($$ParseRulesTableAnnotationComposer a) f,
  ) {
    final $$ParseRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.parseRules,
      getReferencedColumn: (t) => t.configId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParseRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.parseRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConfigSourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConfigSourcesTable,
          ConfigSource,
          $$ConfigSourcesTableFilterComposer,
          $$ConfigSourcesTableOrderingComposer,
          $$ConfigSourcesTableAnnotationComposer,
          $$ConfigSourcesTableCreateCompanionBuilder,
          $$ConfigSourcesTableUpdateCompanionBuilder,
          (ConfigSource, $$ConfigSourcesTableReferences),
          ConfigSource,
          PrefetchHooks Function({
            bool sitesRefs,
            bool liveGroupsRefs,
            bool parseRulesRefs,
          })
        > {
  $$ConfigSourcesTableTableManager(_$AppDatabase db, $ConfigSourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConfigSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConfigSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConfigSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String> rawHash = const Value.absent(),
                Value<String?> spider = const Value.absent(),
                Value<String?> spiderMd5 = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<bool> autoUpdate = const Value.absent(),
                Value<int> updateIntervalH = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ConfigSourcesCompanion(
                id: id,
                name: name,
                url: url,
                localPath: localPath,
                rawHash: rawHash,
                spider: spider,
                spiderMd5: spiderMd5,
                format: format,
                autoUpdate: autoUpdate,
                updateIntervalH: updateIntervalH,
                lastSyncAt: lastSyncAt,
                lastError: lastError,
                sortOrder: sortOrder,
                enabled: enabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> url = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                required String rawHash,
                Value<String?> spider = const Value.absent(),
                Value<String?> spiderMd5 = const Value.absent(),
                required String format,
                Value<bool> autoUpdate = const Value.absent(),
                Value<int> updateIntervalH = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => ConfigSourcesCompanion.insert(
                id: id,
                name: name,
                url: url,
                localPath: localPath,
                rawHash: rawHash,
                spider: spider,
                spiderMd5: spiderMd5,
                format: format,
                autoUpdate: autoUpdate,
                updateIntervalH: updateIntervalH,
                lastSyncAt: lastSyncAt,
                lastError: lastError,
                sortOrder: sortOrder,
                enabled: enabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ConfigSourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sitesRefs = false,
                liveGroupsRefs = false,
                parseRulesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sitesRefs) db.sites,
                    if (liveGroupsRefs) db.liveGroups,
                    if (parseRulesRefs) db.parseRules,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sitesRefs)
                        await $_getPrefetchedData<
                          ConfigSource,
                          $ConfigSourcesTable,
                          Site
                        >(
                          currentTable: table,
                          referencedTable: $$ConfigSourcesTableReferences
                              ._sitesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConfigSourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).sitesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.configId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (liveGroupsRefs)
                        await $_getPrefetchedData<
                          ConfigSource,
                          $ConfigSourcesTable,
                          LiveGroup
                        >(
                          currentTable: table,
                          referencedTable: $$ConfigSourcesTableReferences
                              ._liveGroupsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConfigSourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).liveGroupsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.configId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (parseRulesRefs)
                        await $_getPrefetchedData<
                          ConfigSource,
                          $ConfigSourcesTable,
                          ParseRule
                        >(
                          currentTable: table,
                          referencedTable: $$ConfigSourcesTableReferences
                              ._parseRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConfigSourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).parseRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.configId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ConfigSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConfigSourcesTable,
      ConfigSource,
      $$ConfigSourcesTableFilterComposer,
      $$ConfigSourcesTableOrderingComposer,
      $$ConfigSourcesTableAnnotationComposer,
      $$ConfigSourcesTableCreateCompanionBuilder,
      $$ConfigSourcesTableUpdateCompanionBuilder,
      (ConfigSource, $$ConfigSourcesTableReferences),
      ConfigSource,
      PrefetchHooks Function({
        bool sitesRefs,
        bool liveGroupsRefs,
        bool parseRulesRefs,
      })
    >;
typedef $$PluginsTableCreateCompanionBuilder =
    PluginsCompanion Function({
      required String pluginId,
      required String name,
      required String version,
      Value<String?> prevVersion,
      required String type,
      Value<String?> runtime,
      required String installPath,
      Value<String?> sourceMarket,
      required String manifestJson,
      Value<String> grantedPermissions,
      required String integrityHash,
      Value<String> signatureStatus,
      Value<bool> enabled,
      required DateTime installedAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PluginsTableUpdateCompanionBuilder =
    PluginsCompanion Function({
      Value<String> pluginId,
      Value<String> name,
      Value<String> version,
      Value<String?> prevVersion,
      Value<String> type,
      Value<String?> runtime,
      Value<String> installPath,
      Value<String?> sourceMarket,
      Value<String> manifestJson,
      Value<String> grantedPermissions,
      Value<String> integrityHash,
      Value<String> signatureStatus,
      Value<bool> enabled,
      Value<DateTime> installedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PluginsTableReferences
    extends BaseReferences<_$AppDatabase, $PluginsTable, Plugin> {
  $$PluginsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SitesTable, List<Site>> _sitesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.sites,
    aliasName: 'plugin__plugin_id__site__plugin_id',
  );

  $$SitesTableProcessedTableManager get sitesRefs {
    final manager = $$SitesTableTableManager($_db, $_db.sites).filter(
      (f) => f.pluginId.pluginId.sqlEquals($_itemColumn<String>('plugin_id')!),
    );

    final cache = $_typedResult.readTableOrNull(_sitesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PluginSettingsTable, List<PluginSetting>>
  _pluginSettingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.pluginSettings,
    aliasName: 'plugin__plugin_id__plugin_setting__plugin_id',
  );

  $$PluginSettingsTableProcessedTableManager get pluginSettingsRefs {
    final manager = $$PluginSettingsTableTableManager($_db, $_db.pluginSettings)
        .filter(
          (f) =>
              f.pluginId.pluginId.sqlEquals($_itemColumn<String>('plugin_id')!),
        );

    final cache = $_typedResult.readTableOrNull(_pluginSettingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PluginsTableFilterComposer
    extends Composer<_$AppDatabase, $PluginsTable> {
  $$PluginsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prevVersion => $composableBuilder(
    column: $table.prevVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runtime => $composableBuilder(
    column: $table.runtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get installPath => $composableBuilder(
    column: $table.installPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceMarket => $composableBuilder(
    column: $table.sourceMarket,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grantedPermissions => $composableBuilder(
    column: $table.grantedPermissions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get integrityHash => $composableBuilder(
    column: $table.integrityHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signatureStatus => $composableBuilder(
    column: $table.signatureStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get installedAt =>
      $composableBuilder(
        column: $table.installedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  Expression<bool> sitesRefs(
    Expression<bool> Function($$SitesTableFilterComposer f) f,
  ) {
    final $$SitesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pluginId,
      referencedTable: $db.sites,
      getReferencedColumn: (t) => t.pluginId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SitesTableFilterComposer(
            $db: $db,
            $table: $db.sites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> pluginSettingsRefs(
    Expression<bool> Function($$PluginSettingsTableFilterComposer f) f,
  ) {
    final $$PluginSettingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pluginId,
      referencedTable: $db.pluginSettings,
      getReferencedColumn: (t) => t.pluginId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PluginSettingsTableFilterComposer(
            $db: $db,
            $table: $db.pluginSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PluginsTableOrderingComposer
    extends Composer<_$AppDatabase, $PluginsTable> {
  $$PluginsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prevVersion => $composableBuilder(
    column: $table.prevVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runtime => $composableBuilder(
    column: $table.runtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get installPath => $composableBuilder(
    column: $table.installPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceMarket => $composableBuilder(
    column: $table.sourceMarket,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grantedPermissions => $composableBuilder(
    column: $table.grantedPermissions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get integrityHash => $composableBuilder(
    column: $table.integrityHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signatureStatus => $composableBuilder(
    column: $table.signatureStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PluginsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PluginsTable> {
  $$PluginsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pluginId =>
      $composableBuilder(column: $table.pluginId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get prevVersion => $composableBuilder(
    column: $table.prevVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get runtime =>
      $composableBuilder(column: $table.runtime, builder: (column) => column);

  GeneratedColumn<String> get installPath => $composableBuilder(
    column: $table.installPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceMarket => $composableBuilder(
    column: $table.sourceMarket,
    builder: (column) => column,
  );

  GeneratedColumn<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get grantedPermissions => $composableBuilder(
    column: $table.grantedPermissions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get integrityHash => $composableBuilder(
    column: $table.integrityHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signatureStatus => $composableBuilder(
    column: $table.signatureStatus,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get installedAt =>
      $composableBuilder(
        column: $table.installedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> sitesRefs<T extends Object>(
    Expression<T> Function($$SitesTableAnnotationComposer a) f,
  ) {
    final $$SitesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pluginId,
      referencedTable: $db.sites,
      getReferencedColumn: (t) => t.pluginId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SitesTableAnnotationComposer(
            $db: $db,
            $table: $db.sites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> pluginSettingsRefs<T extends Object>(
    Expression<T> Function($$PluginSettingsTableAnnotationComposer a) f,
  ) {
    final $$PluginSettingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pluginId,
      referencedTable: $db.pluginSettings,
      getReferencedColumn: (t) => t.pluginId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PluginSettingsTableAnnotationComposer(
            $db: $db,
            $table: $db.pluginSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PluginsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PluginsTable,
          Plugin,
          $$PluginsTableFilterComposer,
          $$PluginsTableOrderingComposer,
          $$PluginsTableAnnotationComposer,
          $$PluginsTableCreateCompanionBuilder,
          $$PluginsTableUpdateCompanionBuilder,
          (Plugin, $$PluginsTableReferences),
          Plugin,
          PrefetchHooks Function({bool sitesRefs, bool pluginSettingsRefs})
        > {
  $$PluginsTableTableManager(_$AppDatabase db, $PluginsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PluginsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PluginsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PluginsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> pluginId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String?> prevVersion = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> runtime = const Value.absent(),
                Value<String> installPath = const Value.absent(),
                Value<String?> sourceMarket = const Value.absent(),
                Value<String> manifestJson = const Value.absent(),
                Value<String> grantedPermissions = const Value.absent(),
                Value<String> integrityHash = const Value.absent(),
                Value<String> signatureStatus = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PluginsCompanion(
                pluginId: pluginId,
                name: name,
                version: version,
                prevVersion: prevVersion,
                type: type,
                runtime: runtime,
                installPath: installPath,
                sourceMarket: sourceMarket,
                manifestJson: manifestJson,
                grantedPermissions: grantedPermissions,
                integrityHash: integrityHash,
                signatureStatus: signatureStatus,
                enabled: enabled,
                installedAt: installedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pluginId,
                required String name,
                required String version,
                Value<String?> prevVersion = const Value.absent(),
                required String type,
                Value<String?> runtime = const Value.absent(),
                required String installPath,
                Value<String?> sourceMarket = const Value.absent(),
                required String manifestJson,
                Value<String> grantedPermissions = const Value.absent(),
                required String integrityHash,
                Value<String> signatureStatus = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                required DateTime installedAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PluginsCompanion.insert(
                pluginId: pluginId,
                name: name,
                version: version,
                prevVersion: prevVersion,
                type: type,
                runtime: runtime,
                installPath: installPath,
                sourceMarket: sourceMarket,
                manifestJson: manifestJson,
                grantedPermissions: grantedPermissions,
                integrityHash: integrityHash,
                signatureStatus: signatureStatus,
                enabled: enabled,
                installedAt: installedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PluginsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sitesRefs = false, pluginSettingsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sitesRefs) db.sites,
                    if (pluginSettingsRefs) db.pluginSettings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sitesRefs)
                        await $_getPrefetchedData<Plugin, $PluginsTable, Site>(
                          currentTable: table,
                          referencedTable: $$PluginsTableReferences
                              ._sitesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PluginsTableReferences(db, table, p0).sitesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.pluginId == item.pluginId,
                              ),
                          typedResults: items,
                        ),
                      if (pluginSettingsRefs)
                        await $_getPrefetchedData<
                          Plugin,
                          $PluginsTable,
                          PluginSetting
                        >(
                          currentTable: table,
                          referencedTable: $$PluginsTableReferences
                              ._pluginSettingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PluginsTableReferences(
                                db,
                                table,
                                p0,
                              ).pluginSettingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.pluginId == item.pluginId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PluginsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PluginsTable,
      Plugin,
      $$PluginsTableFilterComposer,
      $$PluginsTableOrderingComposer,
      $$PluginsTableAnnotationComposer,
      $$PluginsTableCreateCompanionBuilder,
      $$PluginsTableUpdateCompanionBuilder,
      (Plugin, $$PluginsTableReferences),
      Plugin,
      PrefetchHooks Function({bool sitesRefs, bool pluginSettingsRefs})
    >;
typedef $$SitesTableCreateCompanionBuilder =
    SitesCompanion Function({
      Value<int> id,
      Value<int?> configId,
      Value<String?> pluginId,
      required String siteKey,
      required String name,
      required int typeCode,
      required String runtime,
      required String api,
      Value<String?> ext,
      Value<bool> searchable,
      Value<bool> quickSearch,
      Value<bool> filterable,
      Value<bool> enabled,
      Value<int> priority,
      Value<String> status,
      Value<int> failCount,
      Value<DateTime?> lastOkAt,
      Value<String?> lastError,
      Value<int?> lastLatencyMs,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$SitesTableUpdateCompanionBuilder =
    SitesCompanion Function({
      Value<int> id,
      Value<int?> configId,
      Value<String?> pluginId,
      Value<String> siteKey,
      Value<String> name,
      Value<int> typeCode,
      Value<String> runtime,
      Value<String> api,
      Value<String?> ext,
      Value<bool> searchable,
      Value<bool> quickSearch,
      Value<bool> filterable,
      Value<bool> enabled,
      Value<int> priority,
      Value<String> status,
      Value<int> failCount,
      Value<DateTime?> lastOkAt,
      Value<String?> lastError,
      Value<int?> lastLatencyMs,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$SitesTableReferences
    extends BaseReferences<_$AppDatabase, $SitesTable, Site> {
  $$SitesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConfigSourcesTable _configIdTable(_$AppDatabase db) =>
      db.configSources.createAlias('site__config_id__config_source__id');

  $$ConfigSourcesTableProcessedTableManager? get configId {
    final $_column = $_itemColumn<int>('config_id');
    if ($_column == null) return null;
    final manager = $$ConfigSourcesTableTableManager(
      $_db,
      $_db.configSources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_configIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PluginsTable _pluginIdTable(_$AppDatabase db) =>
      db.plugins.createAlias('site__plugin_id__plugin__plugin_id');

  $$PluginsTableProcessedTableManager? get pluginId {
    final $_column = $_itemColumn<String>('plugin_id');
    if ($_column == null) return null;
    final manager = $$PluginsTableTableManager(
      $_db,
      $_db.plugins,
    ).filter((f) => f.pluginId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pluginIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$HistoriesTable, List<History>>
  _historiesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.histories,
    aliasName: 'site__id__history__site_id',
  );

  $$HistoriesTableProcessedTableManager get historiesRefs {
    final manager = $$HistoriesTableTableManager(
      $_db,
      $_db.histories,
    ).filter((f) => f.siteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_historiesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FavoritesTable, List<Favorite>>
  _favoritesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.favorites,
    aliasName: 'site__id__favorite__site_id',
  );

  $$FavoritesTableProcessedTableManager get favoritesRefs {
    final manager = $$FavoritesTableTableManager(
      $_db,
      $_db.favorites,
    ).filter((f) => f.siteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_favoritesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DownloadsTable, List<Download>>
  _downloadsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.downloads,
    aliasName: 'site__id__download__site_id',
  );

  $$DownloadsTableProcessedTableManager get downloadsRefs {
    final manager = $$DownloadsTableTableManager(
      $_db,
      $_db.downloads,
    ).filter((f) => f.siteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_downloadsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SiteCachesTable, List<SiteCache>>
  _siteCachesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.siteCaches,
    aliasName: 'site__id__site_cache__site_id',
  );

  $$SiteCachesTableProcessedTableManager get siteCachesRefs {
    final manager = $$SiteCachesTableTableManager(
      $_db,
      $_db.siteCaches,
    ).filter((f) => f.siteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_siteCachesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SitesTableFilterComposer extends Composer<_$AppDatabase, $SitesTable> {
  $$SitesTableFilterComposer({
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

  ColumnFilters<String> get siteKey => $composableBuilder(
    column: $table.siteKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get typeCode => $composableBuilder(
    column: $table.typeCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runtime => $composableBuilder(
    column: $table.runtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get api => $composableBuilder(
    column: $table.api,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get searchable => $composableBuilder(
    column: $table.searchable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get quickSearch => $composableBuilder(
    column: $table.quickSearch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get filterable => $composableBuilder(
    column: $table.filterable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failCount => $composableBuilder(
    column: $table.failCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get lastOkAt =>
      $composableBuilder(
        column: $table.lastOkAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastLatencyMs => $composableBuilder(
    column: $table.lastLatencyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$ConfigSourcesTableFilterComposer get configId {
    final $$ConfigSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.configId,
      referencedTable: $db.configSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConfigSourcesTableFilterComposer(
            $db: $db,
            $table: $db.configSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PluginsTableFilterComposer get pluginId {
    final $$PluginsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pluginId,
      referencedTable: $db.plugins,
      getReferencedColumn: (t) => t.pluginId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PluginsTableFilterComposer(
            $db: $db,
            $table: $db.plugins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> historiesRefs(
    Expression<bool> Function($$HistoriesTableFilterComposer f) f,
  ) {
    final $$HistoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.histories,
      getReferencedColumn: (t) => t.siteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HistoriesTableFilterComposer(
            $db: $db,
            $table: $db.histories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> favoritesRefs(
    Expression<bool> Function($$FavoritesTableFilterComposer f) f,
  ) {
    final $$FavoritesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.siteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableFilterComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> downloadsRefs(
    Expression<bool> Function($$DownloadsTableFilterComposer f) f,
  ) {
    final $$DownloadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.siteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableFilterComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> siteCachesRefs(
    Expression<bool> Function($$SiteCachesTableFilterComposer f) f,
  ) {
    final $$SiteCachesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.siteCaches,
      getReferencedColumn: (t) => t.siteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SiteCachesTableFilterComposer(
            $db: $db,
            $table: $db.siteCaches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SitesTableOrderingComposer
    extends Composer<_$AppDatabase, $SitesTable> {
  $$SitesTableOrderingComposer({
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

  ColumnOrderings<String> get siteKey => $composableBuilder(
    column: $table.siteKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get typeCode => $composableBuilder(
    column: $table.typeCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runtime => $composableBuilder(
    column: $table.runtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get api => $composableBuilder(
    column: $table.api,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get searchable => $composableBuilder(
    column: $table.searchable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get quickSearch => $composableBuilder(
    column: $table.quickSearch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get filterable => $composableBuilder(
    column: $table.filterable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failCount => $composableBuilder(
    column: $table.failCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastOkAt => $composableBuilder(
    column: $table.lastOkAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastLatencyMs => $composableBuilder(
    column: $table.lastLatencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConfigSourcesTableOrderingComposer get configId {
    final $$ConfigSourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.configId,
      referencedTable: $db.configSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConfigSourcesTableOrderingComposer(
            $db: $db,
            $table: $db.configSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PluginsTableOrderingComposer get pluginId {
    final $$PluginsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pluginId,
      referencedTable: $db.plugins,
      getReferencedColumn: (t) => t.pluginId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PluginsTableOrderingComposer(
            $db: $db,
            $table: $db.plugins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SitesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SitesTable> {
  $$SitesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get siteKey =>
      $composableBuilder(column: $table.siteKey, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get typeCode =>
      $composableBuilder(column: $table.typeCode, builder: (column) => column);

  GeneratedColumn<String> get runtime =>
      $composableBuilder(column: $table.runtime, builder: (column) => column);

  GeneratedColumn<String> get api =>
      $composableBuilder(column: $table.api, builder: (column) => column);

  GeneratedColumn<String> get ext =>
      $composableBuilder(column: $table.ext, builder: (column) => column);

  GeneratedColumn<bool> get searchable => $composableBuilder(
    column: $table.searchable,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get quickSearch => $composableBuilder(
    column: $table.quickSearch,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get filterable => $composableBuilder(
    column: $table.filterable,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get failCount =>
      $composableBuilder(column: $table.failCount, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastOkAt =>
      $composableBuilder(column: $table.lastOkAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get lastLatencyMs => $composableBuilder(
    column: $table.lastLatencyMs,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ConfigSourcesTableAnnotationComposer get configId {
    final $$ConfigSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.configId,
      referencedTable: $db.configSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConfigSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.configSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PluginsTableAnnotationComposer get pluginId {
    final $$PluginsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pluginId,
      referencedTable: $db.plugins,
      getReferencedColumn: (t) => t.pluginId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PluginsTableAnnotationComposer(
            $db: $db,
            $table: $db.plugins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> historiesRefs<T extends Object>(
    Expression<T> Function($$HistoriesTableAnnotationComposer a) f,
  ) {
    final $$HistoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.histories,
      getReferencedColumn: (t) => t.siteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HistoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.histories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> favoritesRefs<T extends Object>(
    Expression<T> Function($$FavoritesTableAnnotationComposer a) f,
  ) {
    final $$FavoritesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.siteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableAnnotationComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> downloadsRefs<T extends Object>(
    Expression<T> Function($$DownloadsTableAnnotationComposer a) f,
  ) {
    final $$DownloadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.siteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableAnnotationComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> siteCachesRefs<T extends Object>(
    Expression<T> Function($$SiteCachesTableAnnotationComposer a) f,
  ) {
    final $$SiteCachesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.siteCaches,
      getReferencedColumn: (t) => t.siteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SiteCachesTableAnnotationComposer(
            $db: $db,
            $table: $db.siteCaches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SitesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SitesTable,
          Site,
          $$SitesTableFilterComposer,
          $$SitesTableOrderingComposer,
          $$SitesTableAnnotationComposer,
          $$SitesTableCreateCompanionBuilder,
          $$SitesTableUpdateCompanionBuilder,
          (Site, $$SitesTableReferences),
          Site,
          PrefetchHooks Function({
            bool configId,
            bool pluginId,
            bool historiesRefs,
            bool favoritesRefs,
            bool downloadsRefs,
            bool siteCachesRefs,
          })
        > {
  $$SitesTableTableManager(_$AppDatabase db, $SitesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SitesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SitesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SitesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> configId = const Value.absent(),
                Value<String?> pluginId = const Value.absent(),
                Value<String> siteKey = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> typeCode = const Value.absent(),
                Value<String> runtime = const Value.absent(),
                Value<String> api = const Value.absent(),
                Value<String?> ext = const Value.absent(),
                Value<bool> searchable = const Value.absent(),
                Value<bool> quickSearch = const Value.absent(),
                Value<bool> filterable = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> failCount = const Value.absent(),
                Value<DateTime?> lastOkAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int?> lastLatencyMs = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SitesCompanion(
                id: id,
                configId: configId,
                pluginId: pluginId,
                siteKey: siteKey,
                name: name,
                typeCode: typeCode,
                runtime: runtime,
                api: api,
                ext: ext,
                searchable: searchable,
                quickSearch: quickSearch,
                filterable: filterable,
                enabled: enabled,
                priority: priority,
                status: status,
                failCount: failCount,
                lastOkAt: lastOkAt,
                lastError: lastError,
                lastLatencyMs: lastLatencyMs,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> configId = const Value.absent(),
                Value<String?> pluginId = const Value.absent(),
                required String siteKey,
                required String name,
                required int typeCode,
                required String runtime,
                required String api,
                Value<String?> ext = const Value.absent(),
                Value<bool> searchable = const Value.absent(),
                Value<bool> quickSearch = const Value.absent(),
                Value<bool> filterable = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> failCount = const Value.absent(),
                Value<DateTime?> lastOkAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int?> lastLatencyMs = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => SitesCompanion.insert(
                id: id,
                configId: configId,
                pluginId: pluginId,
                siteKey: siteKey,
                name: name,
                typeCode: typeCode,
                runtime: runtime,
                api: api,
                ext: ext,
                searchable: searchable,
                quickSearch: quickSearch,
                filterable: filterable,
                enabled: enabled,
                priority: priority,
                status: status,
                failCount: failCount,
                lastOkAt: lastOkAt,
                lastError: lastError,
                lastLatencyMs: lastLatencyMs,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$SitesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                configId = false,
                pluginId = false,
                historiesRefs = false,
                favoritesRefs = false,
                downloadsRefs = false,
                siteCachesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (historiesRefs) db.histories,
                    if (favoritesRefs) db.favorites,
                    if (downloadsRefs) db.downloads,
                    if (siteCachesRefs) db.siteCaches,
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
                        if (configId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.configId,
                                    referencedTable: $$SitesTableReferences
                                        ._configIdTable(db),
                                    referencedColumn: $$SitesTableReferences
                                        ._configIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (pluginId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.pluginId,
                                    referencedTable: $$SitesTableReferences
                                        ._pluginIdTable(db),
                                    referencedColumn: $$SitesTableReferences
                                        ._pluginIdTable(db)
                                        .pluginId,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (historiesRefs)
                        await $_getPrefetchedData<Site, $SitesTable, History>(
                          currentTable: table,
                          referencedTable: $$SitesTableReferences
                              ._historiesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SitesTableReferences(
                                db,
                                table,
                                p0,
                              ).historiesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.siteId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (favoritesRefs)
                        await $_getPrefetchedData<Site, $SitesTable, Favorite>(
                          currentTable: table,
                          referencedTable: $$SitesTableReferences
                              ._favoritesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SitesTableReferences(
                                db,
                                table,
                                p0,
                              ).favoritesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.siteId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (downloadsRefs)
                        await $_getPrefetchedData<Site, $SitesTable, Download>(
                          currentTable: table,
                          referencedTable: $$SitesTableReferences
                              ._downloadsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SitesTableReferences(
                                db,
                                table,
                                p0,
                              ).downloadsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.siteId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (siteCachesRefs)
                        await $_getPrefetchedData<Site, $SitesTable, SiteCache>(
                          currentTable: table,
                          referencedTable: $$SitesTableReferences
                              ._siteCachesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SitesTableReferences(
                                db,
                                table,
                                p0,
                              ).siteCachesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.siteId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SitesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SitesTable,
      Site,
      $$SitesTableFilterComposer,
      $$SitesTableOrderingComposer,
      $$SitesTableAnnotationComposer,
      $$SitesTableCreateCompanionBuilder,
      $$SitesTableUpdateCompanionBuilder,
      (Site, $$SitesTableReferences),
      Site,
      PrefetchHooks Function({
        bool configId,
        bool pluginId,
        bool historiesRefs,
        bool favoritesRefs,
        bool downloadsRefs,
        bool siteCachesRefs,
      })
    >;
typedef $$HistoriesTableCreateCompanionBuilder =
    HistoriesCompanion Function({
      Value<int> id,
      required int siteId,
      required String vodId,
      required String vodName,
      Value<String?> vodPic,
      Value<String?> flag,
      Value<int> episodeIndex,
      Value<String?> episodeName,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<bool> finished,
      Value<int?> openingMs,
      Value<int?> endingMs,
      Value<double?> playRate,
      Value<String?> audioTrack,
      Value<String?> subtitleTrack,
      required DateTime playedAt,
      required DateTime createdAt,
    });
typedef $$HistoriesTableUpdateCompanionBuilder =
    HistoriesCompanion Function({
      Value<int> id,
      Value<int> siteId,
      Value<String> vodId,
      Value<String> vodName,
      Value<String?> vodPic,
      Value<String?> flag,
      Value<int> episodeIndex,
      Value<String?> episodeName,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<bool> finished,
      Value<int?> openingMs,
      Value<int?> endingMs,
      Value<double?> playRate,
      Value<String?> audioTrack,
      Value<String?> subtitleTrack,
      Value<DateTime> playedAt,
      Value<DateTime> createdAt,
    });

final class $$HistoriesTableReferences
    extends BaseReferences<_$AppDatabase, $HistoriesTable, History> {
  $$HistoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SitesTable _siteIdTable(_$AppDatabase db) =>
      db.sites.createAlias('history__site_id__site__id');

  $$SitesTableProcessedTableManager get siteId {
    final $_column = $_itemColumn<int>('site_id')!;

    final manager = $$SitesTableTableManager(
      $_db,
      $_db.sites,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_siteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $HistoriesTable> {
  $$HistoriesTableFilterComposer({
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

  ColumnFilters<String> get vodId => $composableBuilder(
    column: $table.vodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vodName => $composableBuilder(
    column: $table.vodName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vodPic => $composableBuilder(
    column: $table.vodPic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get flag => $composableBuilder(
    column: $table.flag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeIndex => $composableBuilder(
    column: $table.episodeIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeName => $composableBuilder(
    column: $table.episodeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get finished => $composableBuilder(
    column: $table.finished,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openingMs => $composableBuilder(
    column: $table.openingMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endingMs => $composableBuilder(
    column: $table.endingMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get playRate => $composableBuilder(
    column: $table.playRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioTrack => $composableBuilder(
    column: $table.audioTrack,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitleTrack => $composableBuilder(
    column: $table.subtitleTrack,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get playedAt =>
      $composableBuilder(
        column: $table.playedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$SitesTableFilterComposer get siteId {
    final $$SitesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.sites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SitesTableFilterComposer(
            $db: $db,
            $table: $db.sites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $HistoriesTable> {
  $$HistoriesTableOrderingComposer({
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

  ColumnOrderings<String> get vodId => $composableBuilder(
    column: $table.vodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vodName => $composableBuilder(
    column: $table.vodName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vodPic => $composableBuilder(
    column: $table.vodPic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flag => $composableBuilder(
    column: $table.flag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeIndex => $composableBuilder(
    column: $table.episodeIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeName => $composableBuilder(
    column: $table.episodeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get finished => $composableBuilder(
    column: $table.finished,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openingMs => $composableBuilder(
    column: $table.openingMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endingMs => $composableBuilder(
    column: $table.endingMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get playRate => $composableBuilder(
    column: $table.playRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioTrack => $composableBuilder(
    column: $table.audioTrack,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitleTrack => $composableBuilder(
    column: $table.subtitleTrack,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SitesTableOrderingComposer get siteId {
    final $$SitesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.sites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SitesTableOrderingComposer(
            $db: $db,
            $table: $db.sites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HistoriesTable> {
  $$HistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get vodId =>
      $composableBuilder(column: $table.vodId, builder: (column) => column);

  GeneratedColumn<String> get vodName =>
      $composableBuilder(column: $table.vodName, builder: (column) => column);

  GeneratedColumn<String> get vodPic =>
      $composableBuilder(column: $table.vodPic, builder: (column) => column);

  GeneratedColumn<String> get flag =>
      $composableBuilder(column: $table.flag, builder: (column) => column);

  GeneratedColumn<int> get episodeIndex => $composableBuilder(
    column: $table.episodeIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get episodeName => $composableBuilder(
    column: $table.episodeName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get finished =>
      $composableBuilder(column: $table.finished, builder: (column) => column);

  GeneratedColumn<int> get openingMs =>
      $composableBuilder(column: $table.openingMs, builder: (column) => column);

  GeneratedColumn<int> get endingMs =>
      $composableBuilder(column: $table.endingMs, builder: (column) => column);

  GeneratedColumn<double> get playRate =>
      $composableBuilder(column: $table.playRate, builder: (column) => column);

  GeneratedColumn<String> get audioTrack => $composableBuilder(
    column: $table.audioTrack,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subtitleTrack => $composableBuilder(
    column: $table.subtitleTrack,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SitesTableAnnotationComposer get siteId {
    final $$SitesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.sites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SitesTableAnnotationComposer(
            $db: $db,
            $table: $db.sites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HistoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HistoriesTable,
          History,
          $$HistoriesTableFilterComposer,
          $$HistoriesTableOrderingComposer,
          $$HistoriesTableAnnotationComposer,
          $$HistoriesTableCreateCompanionBuilder,
          $$HistoriesTableUpdateCompanionBuilder,
          (History, $$HistoriesTableReferences),
          History,
          PrefetchHooks Function({bool siteId})
        > {
  $$HistoriesTableTableManager(_$AppDatabase db, $HistoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> siteId = const Value.absent(),
                Value<String> vodId = const Value.absent(),
                Value<String> vodName = const Value.absent(),
                Value<String?> vodPic = const Value.absent(),
                Value<String?> flag = const Value.absent(),
                Value<int> episodeIndex = const Value.absent(),
                Value<String?> episodeName = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<bool> finished = const Value.absent(),
                Value<int?> openingMs = const Value.absent(),
                Value<int?> endingMs = const Value.absent(),
                Value<double?> playRate = const Value.absent(),
                Value<String?> audioTrack = const Value.absent(),
                Value<String?> subtitleTrack = const Value.absent(),
                Value<DateTime> playedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => HistoriesCompanion(
                id: id,
                siteId: siteId,
                vodId: vodId,
                vodName: vodName,
                vodPic: vodPic,
                flag: flag,
                episodeIndex: episodeIndex,
                episodeName: episodeName,
                positionMs: positionMs,
                durationMs: durationMs,
                finished: finished,
                openingMs: openingMs,
                endingMs: endingMs,
                playRate: playRate,
                audioTrack: audioTrack,
                subtitleTrack: subtitleTrack,
                playedAt: playedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int siteId,
                required String vodId,
                required String vodName,
                Value<String?> vodPic = const Value.absent(),
                Value<String?> flag = const Value.absent(),
                Value<int> episodeIndex = const Value.absent(),
                Value<String?> episodeName = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<bool> finished = const Value.absent(),
                Value<int?> openingMs = const Value.absent(),
                Value<int?> endingMs = const Value.absent(),
                Value<double?> playRate = const Value.absent(),
                Value<String?> audioTrack = const Value.absent(),
                Value<String?> subtitleTrack = const Value.absent(),
                required DateTime playedAt,
                required DateTime createdAt,
              }) => HistoriesCompanion.insert(
                id: id,
                siteId: siteId,
                vodId: vodId,
                vodName: vodName,
                vodPic: vodPic,
                flag: flag,
                episodeIndex: episodeIndex,
                episodeName: episodeName,
                positionMs: positionMs,
                durationMs: durationMs,
                finished: finished,
                openingMs: openingMs,
                endingMs: endingMs,
                playRate: playRate,
                audioTrack: audioTrack,
                subtitleTrack: subtitleTrack,
                playedAt: playedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HistoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({siteId = false}) {
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
                    if (siteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.siteId,
                                referencedTable: $$HistoriesTableReferences
                                    ._siteIdTable(db),
                                referencedColumn: $$HistoriesTableReferences
                                    ._siteIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$HistoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HistoriesTable,
      History,
      $$HistoriesTableFilterComposer,
      $$HistoriesTableOrderingComposer,
      $$HistoriesTableAnnotationComposer,
      $$HistoriesTableCreateCompanionBuilder,
      $$HistoriesTableUpdateCompanionBuilder,
      (History, $$HistoriesTableReferences),
      History,
      PrefetchHooks Function({bool siteId})
    >;
typedef $$FavoritesTableCreateCompanionBuilder =
    FavoritesCompanion Function({
      Value<int> id,
      required int siteId,
      required String vodId,
      required String vodName,
      Value<String?> vodPic,
      Value<String?> vodRemarks,
      Value<String?> latestRemarks,
      Value<String> folder,
      Value<bool> notifyUpdate,
      Value<DateTime?> lastCheckAt,
      Value<int> sortOrder,
      required DateTime createdAt,
    });
typedef $$FavoritesTableUpdateCompanionBuilder =
    FavoritesCompanion Function({
      Value<int> id,
      Value<int> siteId,
      Value<String> vodId,
      Value<String> vodName,
      Value<String?> vodPic,
      Value<String?> vodRemarks,
      Value<String?> latestRemarks,
      Value<String> folder,
      Value<bool> notifyUpdate,
      Value<DateTime?> lastCheckAt,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
    });

final class $$FavoritesTableReferences
    extends BaseReferences<_$AppDatabase, $FavoritesTable, Favorite> {
  $$FavoritesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SitesTable _siteIdTable(_$AppDatabase db) =>
      db.sites.createAlias('favorite__site_id__site__id');

  $$SitesTableProcessedTableManager get siteId {
    final $_column = $_itemColumn<int>('site_id')!;

    final manager = $$SitesTableTableManager(
      $_db,
      $_db.sites,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_siteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
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

  ColumnFilters<String> get vodId => $composableBuilder(
    column: $table.vodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vodName => $composableBuilder(
    column: $table.vodName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vodPic => $composableBuilder(
    column: $table.vodPic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vodRemarks => $composableBuilder(
    column: $table.vodRemarks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get latestRemarks => $composableBuilder(
    column: $table.latestRemarks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notifyUpdate => $composableBuilder(
    column: $table.notifyUpdate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get lastCheckAt =>
      $composableBuilder(
        column: $table.lastCheckAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$SitesTableFilterComposer get siteId {
    final $$SitesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.sites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SitesTableFilterComposer(
            $db: $db,
            $table: $db.sites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
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

  ColumnOrderings<String> get vodId => $composableBuilder(
    column: $table.vodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vodName => $composableBuilder(
    column: $table.vodName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vodPic => $composableBuilder(
    column: $table.vodPic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vodRemarks => $composableBuilder(
    column: $table.vodRemarks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get latestRemarks => $composableBuilder(
    column: $table.latestRemarks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notifyUpdate => $composableBuilder(
    column: $table.notifyUpdate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastCheckAt => $composableBuilder(
    column: $table.lastCheckAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SitesTableOrderingComposer get siteId {
    final $$SitesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.sites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SitesTableOrderingComposer(
            $db: $db,
            $table: $db.sites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get vodId =>
      $composableBuilder(column: $table.vodId, builder: (column) => column);

  GeneratedColumn<String> get vodName =>
      $composableBuilder(column: $table.vodName, builder: (column) => column);

  GeneratedColumn<String> get vodPic =>
      $composableBuilder(column: $table.vodPic, builder: (column) => column);

  GeneratedColumn<String> get vodRemarks => $composableBuilder(
    column: $table.vodRemarks,
    builder: (column) => column,
  );

  GeneratedColumn<String> get latestRemarks => $composableBuilder(
    column: $table.latestRemarks,
    builder: (column) => column,
  );

  GeneratedColumn<String> get folder =>
      $composableBuilder(column: $table.folder, builder: (column) => column);

  GeneratedColumn<bool> get notifyUpdate => $composableBuilder(
    column: $table.notifyUpdate,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastCheckAt =>
      $composableBuilder(
        column: $table.lastCheckAt,
        builder: (column) => column,
      );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SitesTableAnnotationComposer get siteId {
    final $$SitesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.sites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SitesTableAnnotationComposer(
            $db: $db,
            $table: $db.sites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTable,
          Favorite,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (Favorite, $$FavoritesTableReferences),
          Favorite,
          PrefetchHooks Function({bool siteId})
        > {
  $$FavoritesTableTableManager(_$AppDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> siteId = const Value.absent(),
                Value<String> vodId = const Value.absent(),
                Value<String> vodName = const Value.absent(),
                Value<String?> vodPic = const Value.absent(),
                Value<String?> vodRemarks = const Value.absent(),
                Value<String?> latestRemarks = const Value.absent(),
                Value<String> folder = const Value.absent(),
                Value<bool> notifyUpdate = const Value.absent(),
                Value<DateTime?> lastCheckAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FavoritesCompanion(
                id: id,
                siteId: siteId,
                vodId: vodId,
                vodName: vodName,
                vodPic: vodPic,
                vodRemarks: vodRemarks,
                latestRemarks: latestRemarks,
                folder: folder,
                notifyUpdate: notifyUpdate,
                lastCheckAt: lastCheckAt,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int siteId,
                required String vodId,
                required String vodName,
                Value<String?> vodPic = const Value.absent(),
                Value<String?> vodRemarks = const Value.absent(),
                Value<String?> latestRemarks = const Value.absent(),
                Value<String> folder = const Value.absent(),
                Value<bool> notifyUpdate = const Value.absent(),
                Value<DateTime?> lastCheckAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required DateTime createdAt,
              }) => FavoritesCompanion.insert(
                id: id,
                siteId: siteId,
                vodId: vodId,
                vodName: vodName,
                vodPic: vodPic,
                vodRemarks: vodRemarks,
                latestRemarks: latestRemarks,
                folder: folder,
                notifyUpdate: notifyUpdate,
                lastCheckAt: lastCheckAt,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FavoritesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({siteId = false}) {
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
                    if (siteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.siteId,
                                referencedTable: $$FavoritesTableReferences
                                    ._siteIdTable(db),
                                referencedColumn: $$FavoritesTableReferences
                                    ._siteIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTable,
      Favorite,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (Favorite, $$FavoritesTableReferences),
      Favorite,
      PrefetchHooks Function({bool siteId})
    >;
typedef $$DownloadsTableCreateCompanionBuilder =
    DownloadsCompanion Function({
      Value<int> id,
      Value<int?> siteId,
      Value<String?> vodId,
      required String vodName,
      Value<String?> episodeName,
      required String sourceUrl,
      Value<String?> headersJson,
      required String filePath,
      required String mediaType,
      Value<int> totalBytes,
      Value<int> doneBytes,
      Value<int?> totalSegments,
      Value<int?> doneSegments,
      required String status,
      Value<String?> error,
      Value<int?> speedBps,
      Value<int> priority,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> completedAt,
    });
typedef $$DownloadsTableUpdateCompanionBuilder =
    DownloadsCompanion Function({
      Value<int> id,
      Value<int?> siteId,
      Value<String?> vodId,
      Value<String> vodName,
      Value<String?> episodeName,
      Value<String> sourceUrl,
      Value<String?> headersJson,
      Value<String> filePath,
      Value<String> mediaType,
      Value<int> totalBytes,
      Value<int> doneBytes,
      Value<int?> totalSegments,
      Value<int?> doneSegments,
      Value<String> status,
      Value<String?> error,
      Value<int?> speedBps,
      Value<int> priority,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> completedAt,
    });

final class $$DownloadsTableReferences
    extends BaseReferences<_$AppDatabase, $DownloadsTable, Download> {
  $$DownloadsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SitesTable _siteIdTable(_$AppDatabase db) =>
      db.sites.createAlias('download__site_id__site__id');

  $$SitesTableProcessedTableManager? get siteId {
    final $_column = $_itemColumn<int>('site_id');
    if ($_column == null) return null;
    final manager = $$SitesTableTableManager(
      $_db,
      $_db.sites,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_siteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$DownloadSegmentsTable, List<DownloadSegment>>
  _downloadSegmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.downloadSegments,
    aliasName: 'download__id__download_segment__download_id',
  );

  $$DownloadSegmentsTableProcessedTableManager get downloadSegmentsRefs {
    final manager = $$DownloadSegmentsTableTableManager(
      $_db,
      $_db.downloadSegments,
    ).filter((f) => f.downloadId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _downloadSegmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DownloadsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
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

  ColumnFilters<String> get vodId => $composableBuilder(
    column: $table.vodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vodName => $composableBuilder(
    column: $table.vodName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeName => $composableBuilder(
    column: $table.episodeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get doneBytes => $composableBuilder(
    column: $table.doneBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalSegments => $composableBuilder(
    column: $table.totalSegments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get doneSegments => $composableBuilder(
    column: $table.doneSegments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get speedBps => $composableBuilder(
    column: $table.speedBps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get completedAt =>
      $composableBuilder(
        column: $table.completedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$SitesTableFilterComposer get siteId {
    final $$SitesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.sites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SitesTableFilterComposer(
            $db: $db,
            $table: $db.sites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> downloadSegmentsRefs(
    Expression<bool> Function($$DownloadSegmentsTableFilterComposer f) f,
  ) {
    final $$DownloadSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloadSegments,
      getReferencedColumn: (t) => t.downloadId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.downloadSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DownloadsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
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

  ColumnOrderings<String> get vodId => $composableBuilder(
    column: $table.vodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vodName => $composableBuilder(
    column: $table.vodName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeName => $composableBuilder(
    column: $table.episodeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get doneBytes => $composableBuilder(
    column: $table.doneBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalSegments => $composableBuilder(
    column: $table.totalSegments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get doneSegments => $composableBuilder(
    column: $table.doneSegments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get speedBps => $composableBuilder(
    column: $table.speedBps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SitesTableOrderingComposer get siteId {
    final $$SitesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.sites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SitesTableOrderingComposer(
            $db: $db,
            $table: $db.sites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get vodId =>
      $composableBuilder(column: $table.vodId, builder: (column) => column);

  GeneratedColumn<String> get vodName =>
      $composableBuilder(column: $table.vodName, builder: (column) => column);

  GeneratedColumn<String> get episodeName => $composableBuilder(
    column: $table.episodeName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get doneBytes =>
      $composableBuilder(column: $table.doneBytes, builder: (column) => column);

  GeneratedColumn<int> get totalSegments => $composableBuilder(
    column: $table.totalSegments,
    builder: (column) => column,
  );

  GeneratedColumn<int> get doneSegments => $composableBuilder(
    column: $table.doneSegments,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get speedBps =>
      $composableBuilder(column: $table.speedBps, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get completedAt =>
      $composableBuilder(
        column: $table.completedAt,
        builder: (column) => column,
      );

  $$SitesTableAnnotationComposer get siteId {
    final $$SitesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.sites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SitesTableAnnotationComposer(
            $db: $db,
            $table: $db.sites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> downloadSegmentsRefs<T extends Object>(
    Expression<T> Function($$DownloadSegmentsTableAnnotationComposer a) f,
  ) {
    final $$DownloadSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloadSegments,
      getReferencedColumn: (t) => t.downloadId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.downloadSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DownloadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadsTable,
          Download,
          $$DownloadsTableFilterComposer,
          $$DownloadsTableOrderingComposer,
          $$DownloadsTableAnnotationComposer,
          $$DownloadsTableCreateCompanionBuilder,
          $$DownloadsTableUpdateCompanionBuilder,
          (Download, $$DownloadsTableReferences),
          Download,
          PrefetchHooks Function({bool siteId, bool downloadSegmentsRefs})
        > {
  $$DownloadsTableTableManager(_$AppDatabase db, $DownloadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> siteId = const Value.absent(),
                Value<String?> vodId = const Value.absent(),
                Value<String> vodName = const Value.absent(),
                Value<String?> episodeName = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String?> headersJson = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<int> doneBytes = const Value.absent(),
                Value<int?> totalSegments = const Value.absent(),
                Value<int?> doneSegments = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int?> speedBps = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => DownloadsCompanion(
                id: id,
                siteId: siteId,
                vodId: vodId,
                vodName: vodName,
                episodeName: episodeName,
                sourceUrl: sourceUrl,
                headersJson: headersJson,
                filePath: filePath,
                mediaType: mediaType,
                totalBytes: totalBytes,
                doneBytes: doneBytes,
                totalSegments: totalSegments,
                doneSegments: doneSegments,
                status: status,
                error: error,
                speedBps: speedBps,
                priority: priority,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> siteId = const Value.absent(),
                Value<String?> vodId = const Value.absent(),
                required String vodName,
                Value<String?> episodeName = const Value.absent(),
                required String sourceUrl,
                Value<String?> headersJson = const Value.absent(),
                required String filePath,
                required String mediaType,
                Value<int> totalBytes = const Value.absent(),
                Value<int> doneBytes = const Value.absent(),
                Value<int?> totalSegments = const Value.absent(),
                Value<int?> doneSegments = const Value.absent(),
                required String status,
                Value<String?> error = const Value.absent(),
                Value<int?> speedBps = const Value.absent(),
                Value<int> priority = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> completedAt = const Value.absent(),
              }) => DownloadsCompanion.insert(
                id: id,
                siteId: siteId,
                vodId: vodId,
                vodName: vodName,
                episodeName: episodeName,
                sourceUrl: sourceUrl,
                headersJson: headersJson,
                filePath: filePath,
                mediaType: mediaType,
                totalBytes: totalBytes,
                doneBytes: doneBytes,
                totalSegments: totalSegments,
                doneSegments: doneSegments,
                status: status,
                error: error,
                speedBps: speedBps,
                priority: priority,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({siteId = false, downloadSegmentsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (downloadSegmentsRefs) db.downloadSegments,
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
                        if (siteId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.siteId,
                                    referencedTable: $$DownloadsTableReferences
                                        ._siteIdTable(db),
                                    referencedColumn: $$DownloadsTableReferences
                                        ._siteIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (downloadSegmentsRefs)
                        await $_getPrefetchedData<
                          Download,
                          $DownloadsTable,
                          DownloadSegment
                        >(
                          currentTable: table,
                          referencedTable: $$DownloadsTableReferences
                              ._downloadSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DownloadsTableReferences(
                                db,
                                table,
                                p0,
                              ).downloadSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.downloadId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadsTable,
      Download,
      $$DownloadsTableFilterComposer,
      $$DownloadsTableOrderingComposer,
      $$DownloadsTableAnnotationComposer,
      $$DownloadsTableCreateCompanionBuilder,
      $$DownloadsTableUpdateCompanionBuilder,
      (Download, $$DownloadsTableReferences),
      Download,
      PrefetchHooks Function({bool siteId, bool downloadSegmentsRefs})
    >;
typedef $$DownloadSegmentsTableCreateCompanionBuilder =
    DownloadSegmentsCompanion Function({
      required int downloadId,
      required int seq,
      required String url,
      Value<int> bytes,
      Value<bool> done,
      Value<int> rowid,
    });
typedef $$DownloadSegmentsTableUpdateCompanionBuilder =
    DownloadSegmentsCompanion Function({
      Value<int> downloadId,
      Value<int> seq,
      Value<String> url,
      Value<int> bytes,
      Value<bool> done,
      Value<int> rowid,
    });

final class $$DownloadSegmentsTableReferences
    extends
        BaseReferences<_$AppDatabase, $DownloadSegmentsTable, DownloadSegment> {
  $$DownloadSegmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DownloadsTable _downloadIdTable(_$AppDatabase db) =>
      db.downloads.createAlias('download_segment__download_id__download__id');

  $$DownloadsTableProcessedTableManager get downloadId {
    final $_column = $_itemColumn<int>('download_id')!;

    final manager = $$DownloadsTableTableManager(
      $_db,
      $_db.downloads,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_downloadIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DownloadSegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadSegmentsTable> {
  $$DownloadSegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  $$DownloadsTableFilterComposer get downloadId {
    final $$DownloadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.downloadId,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableFilterComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadSegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadSegmentsTable> {
  $$DownloadSegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  $$DownloadsTableOrderingComposer get downloadId {
    final $$DownloadsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.downloadId,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableOrderingComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadSegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadSegmentsTable> {
  $$DownloadSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  $$DownloadsTableAnnotationComposer get downloadId {
    final $$DownloadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.downloadId,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableAnnotationComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadSegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadSegmentsTable,
          DownloadSegment,
          $$DownloadSegmentsTableFilterComposer,
          $$DownloadSegmentsTableOrderingComposer,
          $$DownloadSegmentsTableAnnotationComposer,
          $$DownloadSegmentsTableCreateCompanionBuilder,
          $$DownloadSegmentsTableUpdateCompanionBuilder,
          (DownloadSegment, $$DownloadSegmentsTableReferences),
          DownloadSegment,
          PrefetchHooks Function({bool downloadId})
        > {
  $$DownloadSegmentsTableTableManager(
    _$AppDatabase db,
    $DownloadSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadSegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> downloadId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadSegmentsCompanion(
                downloadId: downloadId,
                seq: seq,
                url: url,
                bytes: bytes,
                done: done,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int downloadId,
                required int seq,
                required String url,
                Value<int> bytes = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadSegmentsCompanion.insert(
                downloadId: downloadId,
                seq: seq,
                url: url,
                bytes: bytes,
                done: done,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({downloadId = false}) {
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
                    if (downloadId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.downloadId,
                                referencedTable:
                                    $$DownloadSegmentsTableReferences
                                        ._downloadIdTable(db),
                                referencedColumn:
                                    $$DownloadSegmentsTableReferences
                                        ._downloadIdTable(db)
                                        .id,
                              )
                              as T;
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

typedef $$DownloadSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadSegmentsTable,
      DownloadSegment,
      $$DownloadSegmentsTableFilterComposer,
      $$DownloadSegmentsTableOrderingComposer,
      $$DownloadSegmentsTableAnnotationComposer,
      $$DownloadSegmentsTableCreateCompanionBuilder,
      $$DownloadSegmentsTableUpdateCompanionBuilder,
      (DownloadSegment, $$DownloadSegmentsTableReferences),
      DownloadSegment,
      PrefetchHooks Function({bool downloadId})
    >;
typedef $$PluginSettingsTableCreateCompanionBuilder =
    PluginSettingsCompanion Function({
      required String pluginId,
      required String key,
      required String valueJson,
      Value<int> rowid,
    });
typedef $$PluginSettingsTableUpdateCompanionBuilder =
    PluginSettingsCompanion Function({
      Value<String> pluginId,
      Value<String> key,
      Value<String> valueJson,
      Value<int> rowid,
    });

final class $$PluginSettingsTableReferences
    extends BaseReferences<_$AppDatabase, $PluginSettingsTable, PluginSetting> {
  $$PluginSettingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PluginsTable _pluginIdTable(_$AppDatabase db) =>
      db.plugins.createAlias('plugin_setting__plugin_id__plugin__plugin_id');

  $$PluginsTableProcessedTableManager get pluginId {
    final $_column = $_itemColumn<String>('plugin_id')!;

    final manager = $$PluginsTableTableManager(
      $_db,
      $_db.plugins,
    ).filter((f) => f.pluginId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pluginIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PluginSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $PluginSettingsTable> {
  $$PluginSettingsTableFilterComposer({
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

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  $$PluginsTableFilterComposer get pluginId {
    final $$PluginsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pluginId,
      referencedTable: $db.plugins,
      getReferencedColumn: (t) => t.pluginId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PluginsTableFilterComposer(
            $db: $db,
            $table: $db.plugins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PluginSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $PluginSettingsTable> {
  $$PluginSettingsTableOrderingComposer({
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

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$PluginsTableOrderingComposer get pluginId {
    final $$PluginsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pluginId,
      referencedTable: $db.plugins,
      getReferencedColumn: (t) => t.pluginId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PluginsTableOrderingComposer(
            $db: $db,
            $table: $db.plugins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PluginSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PluginSettingsTable> {
  $$PluginSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  $$PluginsTableAnnotationComposer get pluginId {
    final $$PluginsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pluginId,
      referencedTable: $db.plugins,
      getReferencedColumn: (t) => t.pluginId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PluginsTableAnnotationComposer(
            $db: $db,
            $table: $db.plugins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PluginSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PluginSettingsTable,
          PluginSetting,
          $$PluginSettingsTableFilterComposer,
          $$PluginSettingsTableOrderingComposer,
          $$PluginSettingsTableAnnotationComposer,
          $$PluginSettingsTableCreateCompanionBuilder,
          $$PluginSettingsTableUpdateCompanionBuilder,
          (PluginSetting, $$PluginSettingsTableReferences),
          PluginSetting,
          PrefetchHooks Function({bool pluginId})
        > {
  $$PluginSettingsTableTableManager(
    _$AppDatabase db,
    $PluginSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PluginSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PluginSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PluginSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> pluginId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PluginSettingsCompanion(
                pluginId: pluginId,
                key: key,
                valueJson: valueJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pluginId,
                required String key,
                required String valueJson,
                Value<int> rowid = const Value.absent(),
              }) => PluginSettingsCompanion.insert(
                pluginId: pluginId,
                key: key,
                valueJson: valueJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PluginSettingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({pluginId = false}) {
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
                    if (pluginId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.pluginId,
                                referencedTable: $$PluginSettingsTableReferences
                                    ._pluginIdTable(db),
                                referencedColumn:
                                    $$PluginSettingsTableReferences
                                        ._pluginIdTable(db)
                                        .pluginId,
                              )
                              as T;
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

typedef $$PluginSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PluginSettingsTable,
      PluginSetting,
      $$PluginSettingsTableFilterComposer,
      $$PluginSettingsTableOrderingComposer,
      $$PluginSettingsTableAnnotationComposer,
      $$PluginSettingsTableCreateCompanionBuilder,
      $$PluginSettingsTableUpdateCompanionBuilder,
      (PluginSetting, $$PluginSettingsTableReferences),
      PluginSetting,
      PrefetchHooks Function({bool pluginId})
    >;
typedef $$PluginStoragesTableCreateCompanionBuilder =
    PluginStoragesCompanion Function({
      required String owner,
      required String key,
      required String value,
      required int bytes,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PluginStoragesTableUpdateCompanionBuilder =
    PluginStoragesCompanion Function({
      Value<String> owner,
      Value<String> key,
      Value<String> value,
      Value<int> bytes,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PluginStoragesTableFilterComposer
    extends Composer<_$AppDatabase, $PluginStoragesTable> {
  $$PluginStoragesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$PluginStoragesTableOrderingComposer
    extends Composer<_$AppDatabase, $PluginStoragesTable> {
  $$PluginStoragesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PluginStoragesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PluginStoragesTable> {
  $$PluginStoragesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PluginStoragesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PluginStoragesTable,
          PluginStorage,
          $$PluginStoragesTableFilterComposer,
          $$PluginStoragesTableOrderingComposer,
          $$PluginStoragesTableAnnotationComposer,
          $$PluginStoragesTableCreateCompanionBuilder,
          $$PluginStoragesTableUpdateCompanionBuilder,
          (
            PluginStorage,
            BaseReferences<_$AppDatabase, $PluginStoragesTable, PluginStorage>,
          ),
          PluginStorage,
          PrefetchHooks Function()
        > {
  $$PluginStoragesTableTableManager(
    _$AppDatabase db,
    $PluginStoragesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PluginStoragesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PluginStoragesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PluginStoragesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> owner = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PluginStoragesCompanion(
                owner: owner,
                key: key,
                value: value,
                bytes: bytes,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String owner,
                required String key,
                required String value,
                required int bytes,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PluginStoragesCompanion.insert(
                owner: owner,
                key: key,
                value: value,
                bytes: bytes,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PluginStoragesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PluginStoragesTable,
      PluginStorage,
      $$PluginStoragesTableFilterComposer,
      $$PluginStoragesTableOrderingComposer,
      $$PluginStoragesTableAnnotationComposer,
      $$PluginStoragesTableCreateCompanionBuilder,
      $$PluginStoragesTableUpdateCompanionBuilder,
      (
        PluginStorage,
        BaseReferences<_$AppDatabase, $PluginStoragesTable, PluginStorage>,
      ),
      PluginStorage,
      PrefetchHooks Function()
    >;
typedef $$LiveGroupsTableCreateCompanionBuilder =
    LiveGroupsCompanion Function({
      Value<int> id,
      Value<int?> configId,
      required String name,
      Value<int> sortOrder,
    });
typedef $$LiveGroupsTableUpdateCompanionBuilder =
    LiveGroupsCompanion Function({
      Value<int> id,
      Value<int?> configId,
      Value<String> name,
      Value<int> sortOrder,
    });

final class $$LiveGroupsTableReferences
    extends BaseReferences<_$AppDatabase, $LiveGroupsTable, LiveGroup> {
  $$LiveGroupsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConfigSourcesTable _configIdTable(_$AppDatabase db) =>
      db.configSources.createAlias('live_group__config_id__config_source__id');

  $$ConfigSourcesTableProcessedTableManager? get configId {
    final $_column = $_itemColumn<int>('config_id');
    if ($_column == null) return null;
    final manager = $$ConfigSourcesTableTableManager(
      $_db,
      $_db.configSources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_configIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LiveChannelsTable, List<LiveChannel>>
  _liveChannelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.liveChannels,
    aliasName: 'live_group__id__live_channel__group_id',
  );

  $$LiveChannelsTableProcessedTableManager get liveChannelsRefs {
    final manager = $$LiveChannelsTableTableManager(
      $_db,
      $_db.liveChannels,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_liveChannelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LiveGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $LiveGroupsTable> {
  $$LiveGroupsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$ConfigSourcesTableFilterComposer get configId {
    final $$ConfigSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.configId,
      referencedTable: $db.configSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConfigSourcesTableFilterComposer(
            $db: $db,
            $table: $db.configSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> liveChannelsRefs(
    Expression<bool> Function($$LiveChannelsTableFilterComposer f) f,
  ) {
    final $$LiveChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.liveChannels,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LiveChannelsTableFilterComposer(
            $db: $db,
            $table: $db.liveChannels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LiveGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $LiveGroupsTable> {
  $$LiveGroupsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConfigSourcesTableOrderingComposer get configId {
    final $$ConfigSourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.configId,
      referencedTable: $db.configSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConfigSourcesTableOrderingComposer(
            $db: $db,
            $table: $db.configSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LiveGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LiveGroupsTable> {
  $$LiveGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$ConfigSourcesTableAnnotationComposer get configId {
    final $$ConfigSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.configId,
      referencedTable: $db.configSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConfigSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.configSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> liveChannelsRefs<T extends Object>(
    Expression<T> Function($$LiveChannelsTableAnnotationComposer a) f,
  ) {
    final $$LiveChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.liveChannels,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LiveChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.liveChannels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LiveGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LiveGroupsTable,
          LiveGroup,
          $$LiveGroupsTableFilterComposer,
          $$LiveGroupsTableOrderingComposer,
          $$LiveGroupsTableAnnotationComposer,
          $$LiveGroupsTableCreateCompanionBuilder,
          $$LiveGroupsTableUpdateCompanionBuilder,
          (LiveGroup, $$LiveGroupsTableReferences),
          LiveGroup,
          PrefetchHooks Function({bool configId, bool liveChannelsRefs})
        > {
  $$LiveGroupsTableTableManager(_$AppDatabase db, $LiveGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LiveGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LiveGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LiveGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> configId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => LiveGroupsCompanion(
                id: id,
                configId: configId,
                name: name,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> configId = const Value.absent(),
                required String name,
                Value<int> sortOrder = const Value.absent(),
              }) => LiveGroupsCompanion.insert(
                id: id,
                configId: configId,
                name: name,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LiveGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({configId = false, liveChannelsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (liveChannelsRefs) db.liveChannels,
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
                        if (configId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.configId,
                                    referencedTable: $$LiveGroupsTableReferences
                                        ._configIdTable(db),
                                    referencedColumn:
                                        $$LiveGroupsTableReferences
                                            ._configIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (liveChannelsRefs)
                        await $_getPrefetchedData<
                          LiveGroup,
                          $LiveGroupsTable,
                          LiveChannel
                        >(
                          currentTable: table,
                          referencedTable: $$LiveGroupsTableReferences
                              ._liveChannelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LiveGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).liveChannelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LiveGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LiveGroupsTable,
      LiveGroup,
      $$LiveGroupsTableFilterComposer,
      $$LiveGroupsTableOrderingComposer,
      $$LiveGroupsTableAnnotationComposer,
      $$LiveGroupsTableCreateCompanionBuilder,
      $$LiveGroupsTableUpdateCompanionBuilder,
      (LiveGroup, $$LiveGroupsTableReferences),
      LiveGroup,
      PrefetchHooks Function({bool configId, bool liveChannelsRefs})
    >;
typedef $$LiveChannelsTableCreateCompanionBuilder =
    LiveChannelsCompanion Function({
      Value<int> id,
      required int groupId,
      required String name,
      Value<String?> logo,
      required String urlsJson,
      Value<String?> epgId,
      Value<String?> headersJson,
      Value<int> sortOrder,
      Value<bool> favorite,
      Value<DateTime?> lastPlayedAt,
    });
typedef $$LiveChannelsTableUpdateCompanionBuilder =
    LiveChannelsCompanion Function({
      Value<int> id,
      Value<int> groupId,
      Value<String> name,
      Value<String?> logo,
      Value<String> urlsJson,
      Value<String?> epgId,
      Value<String?> headersJson,
      Value<int> sortOrder,
      Value<bool> favorite,
      Value<DateTime?> lastPlayedAt,
    });

final class $$LiveChannelsTableReferences
    extends BaseReferences<_$AppDatabase, $LiveChannelsTable, LiveChannel> {
  $$LiveChannelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LiveGroupsTable _groupIdTable(_$AppDatabase db) =>
      db.liveGroups.createAlias('live_channel__group_id__live_group__id');

  $$LiveGroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<int>('group_id')!;

    final manager = $$LiveGroupsTableTableManager(
      $_db,
      $_db.liveGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LiveChannelsTableFilterComposer
    extends Composer<_$AppDatabase, $LiveChannelsTable> {
  $$LiveChannelsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logo => $composableBuilder(
    column: $table.logo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get urlsJson => $composableBuilder(
    column: $table.urlsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgId => $composableBuilder(
    column: $table.epgId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get lastPlayedAt =>
      $composableBuilder(
        column: $table.lastPlayedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$LiveGroupsTableFilterComposer get groupId {
    final $$LiveGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.liveGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LiveGroupsTableFilterComposer(
            $db: $db,
            $table: $db.liveGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LiveChannelsTableOrderingComposer
    extends Composer<_$AppDatabase, $LiveChannelsTable> {
  $$LiveChannelsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logo => $composableBuilder(
    column: $table.logo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get urlsJson => $composableBuilder(
    column: $table.urlsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgId => $composableBuilder(
    column: $table.epgId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LiveGroupsTableOrderingComposer get groupId {
    final $$LiveGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.liveGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LiveGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.liveGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LiveChannelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LiveChannelsTable> {
  $$LiveChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get logo =>
      $composableBuilder(column: $table.logo, builder: (column) => column);

  GeneratedColumn<String> get urlsJson =>
      $composableBuilder(column: $table.urlsJson, builder: (column) => column);

  GeneratedColumn<String> get epgId =>
      $composableBuilder(column: $table.epgId, builder: (column) => column);

  GeneratedColumn<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastPlayedAt =>
      $composableBuilder(
        column: $table.lastPlayedAt,
        builder: (column) => column,
      );

  $$LiveGroupsTableAnnotationComposer get groupId {
    final $$LiveGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.liveGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LiveGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.liveGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LiveChannelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LiveChannelsTable,
          LiveChannel,
          $$LiveChannelsTableFilterComposer,
          $$LiveChannelsTableOrderingComposer,
          $$LiveChannelsTableAnnotationComposer,
          $$LiveChannelsTableCreateCompanionBuilder,
          $$LiveChannelsTableUpdateCompanionBuilder,
          (LiveChannel, $$LiveChannelsTableReferences),
          LiveChannel,
          PrefetchHooks Function({bool groupId})
        > {
  $$LiveChannelsTableTableManager(_$AppDatabase db, $LiveChannelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LiveChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LiveChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LiveChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> groupId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> logo = const Value.absent(),
                Value<String> urlsJson = const Value.absent(),
                Value<String?> epgId = const Value.absent(),
                Value<String?> headersJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
              }) => LiveChannelsCompanion(
                id: id,
                groupId: groupId,
                name: name,
                logo: logo,
                urlsJson: urlsJson,
                epgId: epgId,
                headersJson: headersJson,
                sortOrder: sortOrder,
                favorite: favorite,
                lastPlayedAt: lastPlayedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int groupId,
                required String name,
                Value<String?> logo = const Value.absent(),
                required String urlsJson,
                Value<String?> epgId = const Value.absent(),
                Value<String?> headersJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
              }) => LiveChannelsCompanion.insert(
                id: id,
                groupId: groupId,
                name: name,
                logo: logo,
                urlsJson: urlsJson,
                epgId: epgId,
                headersJson: headersJson,
                sortOrder: sortOrder,
                favorite: favorite,
                lastPlayedAt: lastPlayedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LiveChannelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
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
                    if (groupId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.groupId,
                                referencedTable: $$LiveChannelsTableReferences
                                    ._groupIdTable(db),
                                referencedColumn: $$LiveChannelsTableReferences
                                    ._groupIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$LiveChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LiveChannelsTable,
      LiveChannel,
      $$LiveChannelsTableFilterComposer,
      $$LiveChannelsTableOrderingComposer,
      $$LiveChannelsTableAnnotationComposer,
      $$LiveChannelsTableCreateCompanionBuilder,
      $$LiveChannelsTableUpdateCompanionBuilder,
      (LiveChannel, $$LiveChannelsTableReferences),
      LiveChannel,
      PrefetchHooks Function({bool groupId})
    >;
typedef $$ParseRulesTableCreateCompanionBuilder =
    ParseRulesCompanion Function({
      Value<int> id,
      Value<int?> configId,
      required String name,
      required int typeCode,
      required String url,
      Value<String?> extJson,
      Value<String?> flagsJson,
      Value<bool> enabled,
      Value<int> priority,
      Value<int> successCount,
      Value<int> failCount,
      Value<int?> avgLatencyMs,
    });
typedef $$ParseRulesTableUpdateCompanionBuilder =
    ParseRulesCompanion Function({
      Value<int> id,
      Value<int?> configId,
      Value<String> name,
      Value<int> typeCode,
      Value<String> url,
      Value<String?> extJson,
      Value<String?> flagsJson,
      Value<bool> enabled,
      Value<int> priority,
      Value<int> successCount,
      Value<int> failCount,
      Value<int?> avgLatencyMs,
    });

final class $$ParseRulesTableReferences
    extends BaseReferences<_$AppDatabase, $ParseRulesTable, ParseRule> {
  $$ParseRulesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConfigSourcesTable _configIdTable(_$AppDatabase db) =>
      db.configSources.createAlias('parse_rule__config_id__config_source__id');

  $$ConfigSourcesTableProcessedTableManager? get configId {
    final $_column = $_itemColumn<int>('config_id');
    if ($_column == null) return null;
    final manager = $$ConfigSourcesTableTableManager(
      $_db,
      $_db.configSources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_configIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ParseRulesTableFilterComposer
    extends Composer<_$AppDatabase, $ParseRulesTable> {
  $$ParseRulesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get typeCode => $composableBuilder(
    column: $table.typeCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extJson => $composableBuilder(
    column: $table.extJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get flagsJson => $composableBuilder(
    column: $table.flagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failCount => $composableBuilder(
    column: $table.failCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get avgLatencyMs => $composableBuilder(
    column: $table.avgLatencyMs,
    builder: (column) => ColumnFilters(column),
  );

  $$ConfigSourcesTableFilterComposer get configId {
    final $$ConfigSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.configId,
      referencedTable: $db.configSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConfigSourcesTableFilterComposer(
            $db: $db,
            $table: $db.configSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ParseRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $ParseRulesTable> {
  $$ParseRulesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get typeCode => $composableBuilder(
    column: $table.typeCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extJson => $composableBuilder(
    column: $table.extJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flagsJson => $composableBuilder(
    column: $table.flagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failCount => $composableBuilder(
    column: $table.failCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get avgLatencyMs => $composableBuilder(
    column: $table.avgLatencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConfigSourcesTableOrderingComposer get configId {
    final $$ConfigSourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.configId,
      referencedTable: $db.configSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConfigSourcesTableOrderingComposer(
            $db: $db,
            $table: $db.configSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ParseRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParseRulesTable> {
  $$ParseRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get typeCode =>
      $composableBuilder(column: $table.typeCode, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get extJson =>
      $composableBuilder(column: $table.extJson, builder: (column) => column);

  GeneratedColumn<String> get flagsJson =>
      $composableBuilder(column: $table.flagsJson, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get failCount =>
      $composableBuilder(column: $table.failCount, builder: (column) => column);

  GeneratedColumn<int> get avgLatencyMs => $composableBuilder(
    column: $table.avgLatencyMs,
    builder: (column) => column,
  );

  $$ConfigSourcesTableAnnotationComposer get configId {
    final $$ConfigSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.configId,
      referencedTable: $db.configSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConfigSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.configSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ParseRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ParseRulesTable,
          ParseRule,
          $$ParseRulesTableFilterComposer,
          $$ParseRulesTableOrderingComposer,
          $$ParseRulesTableAnnotationComposer,
          $$ParseRulesTableCreateCompanionBuilder,
          $$ParseRulesTableUpdateCompanionBuilder,
          (ParseRule, $$ParseRulesTableReferences),
          ParseRule,
          PrefetchHooks Function({bool configId})
        > {
  $$ParseRulesTableTableManager(_$AppDatabase db, $ParseRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParseRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParseRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParseRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> configId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> typeCode = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> extJson = const Value.absent(),
                Value<String?> flagsJson = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> successCount = const Value.absent(),
                Value<int> failCount = const Value.absent(),
                Value<int?> avgLatencyMs = const Value.absent(),
              }) => ParseRulesCompanion(
                id: id,
                configId: configId,
                name: name,
                typeCode: typeCode,
                url: url,
                extJson: extJson,
                flagsJson: flagsJson,
                enabled: enabled,
                priority: priority,
                successCount: successCount,
                failCount: failCount,
                avgLatencyMs: avgLatencyMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> configId = const Value.absent(),
                required String name,
                required int typeCode,
                required String url,
                Value<String?> extJson = const Value.absent(),
                Value<String?> flagsJson = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> successCount = const Value.absent(),
                Value<int> failCount = const Value.absent(),
                Value<int?> avgLatencyMs = const Value.absent(),
              }) => ParseRulesCompanion.insert(
                id: id,
                configId: configId,
                name: name,
                typeCode: typeCode,
                url: url,
                extJson: extJson,
                flagsJson: flagsJson,
                enabled: enabled,
                priority: priority,
                successCount: successCount,
                failCount: failCount,
                avgLatencyMs: avgLatencyMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ParseRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({configId = false}) {
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
                    if (configId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.configId,
                                referencedTable: $$ParseRulesTableReferences
                                    ._configIdTable(db),
                                referencedColumn: $$ParseRulesTableReferences
                                    ._configIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$ParseRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ParseRulesTable,
      ParseRule,
      $$ParseRulesTableFilterComposer,
      $$ParseRulesTableOrderingComposer,
      $$ParseRulesTableAnnotationComposer,
      $$ParseRulesTableCreateCompanionBuilder,
      $$ParseRulesTableUpdateCompanionBuilder,
      (ParseRule, $$ParseRulesTableReferences),
      ParseRule,
      PrefetchHooks Function({bool configId})
    >;
typedef $$SiteCachesTableCreateCompanionBuilder =
    SiteCachesCompanion Function({
      required String cacheKey,
      required int siteId,
      required String method,
      required Uint8List payload,
      required int bytes,
      required DateTime expiresAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SiteCachesTableUpdateCompanionBuilder =
    SiteCachesCompanion Function({
      Value<String> cacheKey,
      Value<int> siteId,
      Value<String> method,
      Value<Uint8List> payload,
      Value<int> bytes,
      Value<DateTime> expiresAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$SiteCachesTableReferences
    extends BaseReferences<_$AppDatabase, $SiteCachesTable, SiteCache> {
  $$SiteCachesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SitesTable _siteIdTable(_$AppDatabase db) =>
      db.sites.createAlias('site_cache__site_id__site__id');

  $$SitesTableProcessedTableManager get siteId {
    final $_column = $_itemColumn<int>('site_id')!;

    final manager = $$SitesTableTableManager(
      $_db,
      $_db.sites,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_siteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SiteCachesTableFilterComposer
    extends Composer<_$AppDatabase, $SiteCachesTable> {
  $$SiteCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get expiresAt =>
      $composableBuilder(
        column: $table.expiresAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$SitesTableFilterComposer get siteId {
    final $$SitesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.sites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SitesTableFilterComposer(
            $db: $db,
            $table: $db.sites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SiteCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $SiteCachesTable> {
  $$SiteCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SitesTableOrderingComposer get siteId {
    final $$SitesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.sites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SitesTableOrderingComposer(
            $db: $db,
            $table: $db.sites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SiteCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SiteCachesTable> {
  $$SiteCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<Uint8List> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SitesTableAnnotationComposer get siteId {
    final $$SitesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.siteId,
      referencedTable: $db.sites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SitesTableAnnotationComposer(
            $db: $db,
            $table: $db.sites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SiteCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SiteCachesTable,
          SiteCache,
          $$SiteCachesTableFilterComposer,
          $$SiteCachesTableOrderingComposer,
          $$SiteCachesTableAnnotationComposer,
          $$SiteCachesTableCreateCompanionBuilder,
          $$SiteCachesTableUpdateCompanionBuilder,
          (SiteCache, $$SiteCachesTableReferences),
          SiteCache,
          PrefetchHooks Function({bool siteId})
        > {
  $$SiteCachesTableTableManager(_$AppDatabase db, $SiteCachesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SiteCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SiteCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SiteCachesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<int> siteId = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<Uint8List> payload = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SiteCachesCompanion(
                cacheKey: cacheKey,
                siteId: siteId,
                method: method,
                payload: payload,
                bytes: bytes,
                expiresAt: expiresAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required int siteId,
                required String method,
                required Uint8List payload,
                required int bytes,
                required DateTime expiresAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SiteCachesCompanion.insert(
                cacheKey: cacheKey,
                siteId: siteId,
                method: method,
                payload: payload,
                bytes: bytes,
                expiresAt: expiresAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SiteCachesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({siteId = false}) {
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
                    if (siteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.siteId,
                                referencedTable: $$SiteCachesTableReferences
                                    ._siteIdTable(db),
                                referencedColumn: $$SiteCachesTableReferences
                                    ._siteIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$SiteCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SiteCachesTable,
      SiteCache,
      $$SiteCachesTableFilterComposer,
      $$SiteCachesTableOrderingComposer,
      $$SiteCachesTableAnnotationComposer,
      $$SiteCachesTableCreateCompanionBuilder,
      $$SiteCachesTableUpdateCompanionBuilder,
      (SiteCache, $$SiteCachesTableReferences),
      SiteCache,
      PrefetchHooks Function({bool siteId})
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String valueJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> valueJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
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

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
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

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(
                key: key,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String valueJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$SearchHistoriesTableCreateCompanionBuilder =
    SearchHistoriesCompanion Function({
      required String keyword,
      Value<int> hitCount,
      required DateTime lastAt,
      Value<String> source,
      Value<int> rowid,
    });
typedef $$SearchHistoriesTableUpdateCompanionBuilder =
    SearchHistoriesCompanion Function({
      Value<String> keyword,
      Value<int> hitCount,
      Value<DateTime> lastAt,
      Value<String> source,
      Value<int> rowid,
    });

class $$SearchHistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $SearchHistoriesTable> {
  $$SearchHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get keyword => $composableBuilder(
    column: $table.keyword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hitCount => $composableBuilder(
    column: $table.hitCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get lastAt =>
      $composableBuilder(
        column: $table.lastAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchHistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchHistoriesTable> {
  $$SearchHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get keyword => $composableBuilder(
    column: $table.keyword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hitCount => $composableBuilder(
    column: $table.hitCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAt => $composableBuilder(
    column: $table.lastAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchHistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchHistoriesTable> {
  $$SearchHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get keyword =>
      $composableBuilder(column: $table.keyword, builder: (column) => column);

  GeneratedColumn<int> get hitCount =>
      $composableBuilder(column: $table.hitCount, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get lastAt =>
      $composableBuilder(column: $table.lastAt, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$SearchHistoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchHistoriesTable,
          SearchHistory,
          $$SearchHistoriesTableFilterComposer,
          $$SearchHistoriesTableOrderingComposer,
          $$SearchHistoriesTableAnnotationComposer,
          $$SearchHistoriesTableCreateCompanionBuilder,
          $$SearchHistoriesTableUpdateCompanionBuilder,
          (
            SearchHistory,
            BaseReferences<_$AppDatabase, $SearchHistoriesTable, SearchHistory>,
          ),
          SearchHistory,
          PrefetchHooks Function()
        > {
  $$SearchHistoriesTableTableManager(
    _$AppDatabase db,
    $SearchHistoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchHistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchHistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchHistoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> keyword = const Value.absent(),
                Value<int> hitCount = const Value.absent(),
                Value<DateTime> lastAt = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoriesCompanion(
                keyword: keyword,
                hitCount: hitCount,
                lastAt: lastAt,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String keyword,
                Value<int> hitCount = const Value.absent(),
                required DateTime lastAt,
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoriesCompanion.insert(
                keyword: keyword,
                hitCount: hitCount,
                lastAt: lastAt,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchHistoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchHistoriesTable,
      SearchHistory,
      $$SearchHistoriesTableFilterComposer,
      $$SearchHistoriesTableOrderingComposer,
      $$SearchHistoriesTableAnnotationComposer,
      $$SearchHistoriesTableCreateCompanionBuilder,
      $$SearchHistoriesTableUpdateCompanionBuilder,
      (
        SearchHistory,
        BaseReferences<_$AppDatabase, $SearchHistoriesTable, SearchHistory>,
      ),
      SearchHistory,
      PrefetchHooks Function()
    >;
typedef $$AppEventsTableCreateCompanionBuilder =
    AppEventsCompanion Function({
      Value<int> id,
      required DateTime ts,
      required String level,
      required String scope,
      Value<int?> siteId,
      Value<String?> code,
      required String message,
      Value<String?> detailJson,
    });
typedef $$AppEventsTableUpdateCompanionBuilder =
    AppEventsCompanion Function({
      Value<int> id,
      Value<DateTime> ts,
      Value<String> level,
      Value<String> scope,
      Value<int?> siteId,
      Value<String?> code,
      Value<String> message,
      Value<String?> detailJson,
    });

class $$AppEventsTableFilterComposer
    extends Composer<_$AppDatabase, $AppEventsTable> {
  $$AppEventsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get ts =>
      $composableBuilder(
        column: $table.ts,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get siteId => $composableBuilder(
    column: $table.siteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppEventsTable> {
  $$AppEventsTableOrderingComposer({
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

  ColumnOrderings<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get siteId => $composableBuilder(
    column: $table.siteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppEventsTable> {
  $$AppEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<int> get siteId =>
      $composableBuilder(column: $table.siteId, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => column,
  );
}

class $$AppEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppEventsTable,
          AppEvent,
          $$AppEventsTableFilterComposer,
          $$AppEventsTableOrderingComposer,
          $$AppEventsTableAnnotationComposer,
          $$AppEventsTableCreateCompanionBuilder,
          $$AppEventsTableUpdateCompanionBuilder,
          (AppEvent, BaseReferences<_$AppDatabase, $AppEventsTable, AppEvent>),
          AppEvent,
          PrefetchHooks Function()
        > {
  $$AppEventsTableTableManager(_$AppDatabase db, $AppEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> ts = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<int?> siteId = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<String> message = const Value.absent(),
                Value<String?> detailJson = const Value.absent(),
              }) => AppEventsCompanion(
                id: id,
                ts: ts,
                level: level,
                scope: scope,
                siteId: siteId,
                code: code,
                message: message,
                detailJson: detailJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime ts,
                required String level,
                required String scope,
                Value<int?> siteId = const Value.absent(),
                Value<String?> code = const Value.absent(),
                required String message,
                Value<String?> detailJson = const Value.absent(),
              }) => AppEventsCompanion.insert(
                id: id,
                ts: ts,
                level: level,
                scope: scope,
                siteId: siteId,
                code: code,
                message: message,
                detailJson: detailJson,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppEventsTable,
      AppEvent,
      $$AppEventsTableFilterComposer,
      $$AppEventsTableOrderingComposer,
      $$AppEventsTableAnnotationComposer,
      $$AppEventsTableCreateCompanionBuilder,
      $$AppEventsTableUpdateCompanionBuilder,
      (AppEvent, BaseReferences<_$AppDatabase, $AppEventsTable, AppEvent>),
      AppEvent,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ConfigSourcesTableTableManager get configSources =>
      $$ConfigSourcesTableTableManager(_db, _db.configSources);
  $$PluginsTableTableManager get plugins =>
      $$PluginsTableTableManager(_db, _db.plugins);
  $$SitesTableTableManager get sites =>
      $$SitesTableTableManager(_db, _db.sites);
  $$HistoriesTableTableManager get histories =>
      $$HistoriesTableTableManager(_db, _db.histories);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db, _db.downloads);
  $$DownloadSegmentsTableTableManager get downloadSegments =>
      $$DownloadSegmentsTableTableManager(_db, _db.downloadSegments);
  $$PluginSettingsTableTableManager get pluginSettings =>
      $$PluginSettingsTableTableManager(_db, _db.pluginSettings);
  $$PluginStoragesTableTableManager get pluginStorages =>
      $$PluginStoragesTableTableManager(_db, _db.pluginStorages);
  $$LiveGroupsTableTableManager get liveGroups =>
      $$LiveGroupsTableTableManager(_db, _db.liveGroups);
  $$LiveChannelsTableTableManager get liveChannels =>
      $$LiveChannelsTableTableManager(_db, _db.liveChannels);
  $$ParseRulesTableTableManager get parseRules =>
      $$ParseRulesTableTableManager(_db, _db.parseRules);
  $$SiteCachesTableTableManager get siteCaches =>
      $$SiteCachesTableTableManager(_db, _db.siteCaches);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$SearchHistoriesTableTableManager get searchHistories =>
      $$SearchHistoriesTableTableManager(_db, _db.searchHistories);
  $$AppEventsTableTableManager get appEvents =>
      $$AppEventsTableTableManager(_db, _db.appEvents);
}
