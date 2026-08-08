// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedArticlesTable extends CachedArticles
    with TableInfo<$CachedArticlesTable, CachedArticleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedArticlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _articleIdMeta = const VerificationMeta(
    'articleId',
  );
  @override
  late final GeneratedColumn<String> articleId = GeneratedColumn<String>(
    'article_id',
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
  static const VerificationMeta _sourceNameMeta = const VerificationMeta(
    'sourceName',
  );
  @override
  late final GeneratedColumn<String> sourceName = GeneratedColumn<String>(
    'source_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentChecksumMeta = const VerificationMeta(
    'contentChecksum',
  );
  @override
  late final GeneratedColumn<String> contentChecksum = GeneratedColumn<String>(
    'content_checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cacheVersionMeta = const VerificationMeta(
    'cacheVersion',
  );
  @override
  late final GeneratedColumn<int> cacheVersion = GeneratedColumn<int>(
    'cache_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    articleId,
    title,
    sourceName,
    contentChecksum,
    cacheVersion,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_articles';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedArticleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('article_id')) {
      context.handle(
        _articleIdMeta,
        articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_articleIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('source_name')) {
      context.handle(
        _sourceNameMeta,
        sourceName.isAcceptableOrUnknown(data['source_name']!, _sourceNameMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceNameMeta);
    }
    if (data.containsKey('content_checksum')) {
      context.handle(
        _contentChecksumMeta,
        contentChecksum.isAcceptableOrUnknown(
          data['content_checksum']!,
          _contentChecksumMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentChecksumMeta);
    }
    if (data.containsKey('cache_version')) {
      context.handle(
        _cacheVersionMeta,
        cacheVersion.isAcceptableOrUnknown(
          data['cache_version']!,
          _cacheVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cacheVersionMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {articleId};
  @override
  CachedArticleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedArticleRow(
      articleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      sourceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_name'],
      )!,
      contentChecksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_checksum'],
      )!,
      cacheVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cache_version'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $CachedArticlesTable createAlias(String alias) {
    return $CachedArticlesTable(attachedDatabase, alias);
  }
}

class CachedArticleRow extends DataClass
    implements Insertable<CachedArticleRow> {
  final String articleId;
  final String title;
  final String sourceName;
  final String contentChecksum;
  final int cacheVersion;
  final DateTime expiresAt;
  const CachedArticleRow({
    required this.articleId,
    required this.title,
    required this.sourceName,
    required this.contentChecksum,
    required this.cacheVersion,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['article_id'] = Variable<String>(articleId);
    map['title'] = Variable<String>(title);
    map['source_name'] = Variable<String>(sourceName);
    map['content_checksum'] = Variable<String>(contentChecksum);
    map['cache_version'] = Variable<int>(cacheVersion);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  CachedArticlesCompanion toCompanion(bool nullToAbsent) {
    return CachedArticlesCompanion(
      articleId: Value(articleId),
      title: Value(title),
      sourceName: Value(sourceName),
      contentChecksum: Value(contentChecksum),
      cacheVersion: Value(cacheVersion),
      expiresAt: Value(expiresAt),
    );
  }

  factory CachedArticleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedArticleRow(
      articleId: serializer.fromJson<String>(json['articleId']),
      title: serializer.fromJson<String>(json['title']),
      sourceName: serializer.fromJson<String>(json['sourceName']),
      contentChecksum: serializer.fromJson<String>(json['contentChecksum']),
      cacheVersion: serializer.fromJson<int>(json['cacheVersion']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'articleId': serializer.toJson<String>(articleId),
      'title': serializer.toJson<String>(title),
      'sourceName': serializer.toJson<String>(sourceName),
      'contentChecksum': serializer.toJson<String>(contentChecksum),
      'cacheVersion': serializer.toJson<int>(cacheVersion),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  CachedArticleRow copyWith({
    String? articleId,
    String? title,
    String? sourceName,
    String? contentChecksum,
    int? cacheVersion,
    DateTime? expiresAt,
  }) => CachedArticleRow(
    articleId: articleId ?? this.articleId,
    title: title ?? this.title,
    sourceName: sourceName ?? this.sourceName,
    contentChecksum: contentChecksum ?? this.contentChecksum,
    cacheVersion: cacheVersion ?? this.cacheVersion,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  CachedArticleRow copyWithCompanion(CachedArticlesCompanion data) {
    return CachedArticleRow(
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      title: data.title.present ? data.title.value : this.title,
      sourceName: data.sourceName.present
          ? data.sourceName.value
          : this.sourceName,
      contentChecksum: data.contentChecksum.present
          ? data.contentChecksum.value
          : this.contentChecksum,
      cacheVersion: data.cacheVersion.present
          ? data.cacheVersion.value
          : this.cacheVersion,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedArticleRow(')
          ..write('articleId: $articleId, ')
          ..write('title: $title, ')
          ..write('sourceName: $sourceName, ')
          ..write('contentChecksum: $contentChecksum, ')
          ..write('cacheVersion: $cacheVersion, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    articleId,
    title,
    sourceName,
    contentChecksum,
    cacheVersion,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedArticleRow &&
          other.articleId == this.articleId &&
          other.title == this.title &&
          other.sourceName == this.sourceName &&
          other.contentChecksum == this.contentChecksum &&
          other.cacheVersion == this.cacheVersion &&
          other.expiresAt == this.expiresAt);
}

class CachedArticlesCompanion extends UpdateCompanion<CachedArticleRow> {
  final Value<String> articleId;
  final Value<String> title;
  final Value<String> sourceName;
  final Value<String> contentChecksum;
  final Value<int> cacheVersion;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const CachedArticlesCompanion({
    this.articleId = const Value.absent(),
    this.title = const Value.absent(),
    this.sourceName = const Value.absent(),
    this.contentChecksum = const Value.absent(),
    this.cacheVersion = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedArticlesCompanion.insert({
    required String articleId,
    required String title,
    required String sourceName,
    required String contentChecksum,
    required int cacheVersion,
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  }) : articleId = Value(articleId),
       title = Value(title),
       sourceName = Value(sourceName),
       contentChecksum = Value(contentChecksum),
       cacheVersion = Value(cacheVersion),
       expiresAt = Value(expiresAt);
  static Insertable<CachedArticleRow> custom({
    Expression<String>? articleId,
    Expression<String>? title,
    Expression<String>? sourceName,
    Expression<String>? contentChecksum,
    Expression<int>? cacheVersion,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (articleId != null) 'article_id': articleId,
      if (title != null) 'title': title,
      if (sourceName != null) 'source_name': sourceName,
      if (contentChecksum != null) 'content_checksum': contentChecksum,
      if (cacheVersion != null) 'cache_version': cacheVersion,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedArticlesCompanion copyWith({
    Value<String>? articleId,
    Value<String>? title,
    Value<String>? sourceName,
    Value<String>? contentChecksum,
    Value<int>? cacheVersion,
    Value<DateTime>? expiresAt,
    Value<int>? rowid,
  }) {
    return CachedArticlesCompanion(
      articleId: articleId ?? this.articleId,
      title: title ?? this.title,
      sourceName: sourceName ?? this.sourceName,
      contentChecksum: contentChecksum ?? this.contentChecksum,
      cacheVersion: cacheVersion ?? this.cacheVersion,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (articleId.present) {
      map['article_id'] = Variable<String>(articleId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sourceName.present) {
      map['source_name'] = Variable<String>(sourceName.value);
    }
    if (contentChecksum.present) {
      map['content_checksum'] = Variable<String>(contentChecksum.value);
    }
    if (cacheVersion.present) {
      map['cache_version'] = Variable<int>(cacheVersion.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedArticlesCompanion(')
          ..write('articleId: $articleId, ')
          ..write('title: $title, ')
          ..write('sourceName: $sourceName, ')
          ..write('contentChecksum: $contentChecksum, ')
          ..write('cacheVersion: $cacheVersion, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedArticleBlocksTable extends CachedArticleBlocks
    with TableInfo<$CachedArticleBlocksTable, CachedArticleBlockRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedArticleBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _blockIdMeta = const VerificationMeta(
    'blockId',
  );
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
    'block_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _articleIdMeta = const VerificationMeta(
    'articleId',
  );
  @override
  late final GeneratedColumn<String> articleId = GeneratedColumn<String>(
    'article_id',
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
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [blockId, articleId, position, content];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_article_blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedArticleBlockRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('block_id')) {
      context.handle(
        _blockIdMeta,
        blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blockIdMeta);
    }
    if (data.containsKey('article_id')) {
      context.handle(
        _articleIdMeta,
        articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_articleIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {blockId};
  @override
  CachedArticleBlockRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedArticleBlockRow(
      blockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_id'],
      )!,
      articleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
    );
  }

  @override
  $CachedArticleBlocksTable createAlias(String alias) {
    return $CachedArticleBlocksTable(attachedDatabase, alias);
  }
}

class CachedArticleBlockRow extends DataClass
    implements Insertable<CachedArticleBlockRow> {
  final String blockId;
  final String articleId;
  final int position;
  final String content;
  const CachedArticleBlockRow({
    required this.blockId,
    required this.articleId,
    required this.position,
    required this.content,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['block_id'] = Variable<String>(blockId);
    map['article_id'] = Variable<String>(articleId);
    map['position'] = Variable<int>(position);
    map['content'] = Variable<String>(content);
    return map;
  }

  CachedArticleBlocksCompanion toCompanion(bool nullToAbsent) {
    return CachedArticleBlocksCompanion(
      blockId: Value(blockId),
      articleId: Value(articleId),
      position: Value(position),
      content: Value(content),
    );
  }

  factory CachedArticleBlockRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedArticleBlockRow(
      blockId: serializer.fromJson<String>(json['blockId']),
      articleId: serializer.fromJson<String>(json['articleId']),
      position: serializer.fromJson<int>(json['position']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'blockId': serializer.toJson<String>(blockId),
      'articleId': serializer.toJson<String>(articleId),
      'position': serializer.toJson<int>(position),
      'content': serializer.toJson<String>(content),
    };
  }

  CachedArticleBlockRow copyWith({
    String? blockId,
    String? articleId,
    int? position,
    String? content,
  }) => CachedArticleBlockRow(
    blockId: blockId ?? this.blockId,
    articleId: articleId ?? this.articleId,
    position: position ?? this.position,
    content: content ?? this.content,
  );
  CachedArticleBlockRow copyWithCompanion(CachedArticleBlocksCompanion data) {
    return CachedArticleBlockRow(
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      position: data.position.present ? data.position.value : this.position,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedArticleBlockRow(')
          ..write('blockId: $blockId, ')
          ..write('articleId: $articleId, ')
          ..write('position: $position, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(blockId, articleId, position, content);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedArticleBlockRow &&
          other.blockId == this.blockId &&
          other.articleId == this.articleId &&
          other.position == this.position &&
          other.content == this.content);
}

class CachedArticleBlocksCompanion
    extends UpdateCompanion<CachedArticleBlockRow> {
  final Value<String> blockId;
  final Value<String> articleId;
  final Value<int> position;
  final Value<String> content;
  final Value<int> rowid;
  const CachedArticleBlocksCompanion({
    this.blockId = const Value.absent(),
    this.articleId = const Value.absent(),
    this.position = const Value.absent(),
    this.content = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedArticleBlocksCompanion.insert({
    required String blockId,
    required String articleId,
    required int position,
    required String content,
    this.rowid = const Value.absent(),
  }) : blockId = Value(blockId),
       articleId = Value(articleId),
       position = Value(position),
       content = Value(content);
  static Insertable<CachedArticleBlockRow> custom({
    Expression<String>? blockId,
    Expression<String>? articleId,
    Expression<int>? position,
    Expression<String>? content,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (blockId != null) 'block_id': blockId,
      if (articleId != null) 'article_id': articleId,
      if (position != null) 'position': position,
      if (content != null) 'content': content,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedArticleBlocksCompanion copyWith({
    Value<String>? blockId,
    Value<String>? articleId,
    Value<int>? position,
    Value<String>? content,
    Value<int>? rowid,
  }) {
    return CachedArticleBlocksCompanion(
      blockId: blockId ?? this.blockId,
      articleId: articleId ?? this.articleId,
      position: position ?? this.position,
      content: content ?? this.content,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (articleId.present) {
      map['article_id'] = Variable<String>(articleId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedArticleBlocksCompanion(')
          ..write('blockId: $blockId, ')
          ..write('articleId: $articleId, ')
          ..write('position: $position, ')
          ..write('content: $content, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedArticlesTable cachedArticles = $CachedArticlesTable(this);
  late final $CachedArticleBlocksTable cachedArticleBlocks =
      $CachedArticleBlocksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedArticles,
    cachedArticleBlocks,
  ];
}

typedef $$CachedArticlesTableCreateCompanionBuilder =
    CachedArticlesCompanion Function({
      required String articleId,
      required String title,
      required String sourceName,
      required String contentChecksum,
      required int cacheVersion,
      required DateTime expiresAt,
      Value<int> rowid,
    });
typedef $$CachedArticlesTableUpdateCompanionBuilder =
    CachedArticlesCompanion Function({
      Value<String> articleId,
      Value<String> title,
      Value<String> sourceName,
      Value<String> contentChecksum,
      Value<int> cacheVersion,
      Value<DateTime> expiresAt,
      Value<int> rowid,
    });

class $$CachedArticlesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedArticlesTable> {
  $$CachedArticlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get articleId => $composableBuilder(
    column: $table.articleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentChecksum => $composableBuilder(
    column: $table.contentChecksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cacheVersion => $composableBuilder(
    column: $table.cacheVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedArticlesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedArticlesTable> {
  $$CachedArticlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get articleId => $composableBuilder(
    column: $table.articleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentChecksum => $composableBuilder(
    column: $table.contentChecksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cacheVersion => $composableBuilder(
    column: $table.cacheVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedArticlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedArticlesTable> {
  $$CachedArticlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get articleId =>
      $composableBuilder(column: $table.articleId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentChecksum => $composableBuilder(
    column: $table.contentChecksum,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cacheVersion => $composableBuilder(
    column: $table.cacheVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$CachedArticlesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedArticlesTable,
          CachedArticleRow,
          $$CachedArticlesTableFilterComposer,
          $$CachedArticlesTableOrderingComposer,
          $$CachedArticlesTableAnnotationComposer,
          $$CachedArticlesTableCreateCompanionBuilder,
          $$CachedArticlesTableUpdateCompanionBuilder,
          (
            CachedArticleRow,
            BaseReferences<
              _$AppDatabase,
              $CachedArticlesTable,
              CachedArticleRow
            >,
          ),
          CachedArticleRow,
          PrefetchHooks Function()
        > {
  $$CachedArticlesTableTableManager(
    _$AppDatabase db,
    $CachedArticlesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedArticlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedArticlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedArticlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> articleId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> sourceName = const Value.absent(),
                Value<String> contentChecksum = const Value.absent(),
                Value<int> cacheVersion = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedArticlesCompanion(
                articleId: articleId,
                title: title,
                sourceName: sourceName,
                contentChecksum: contentChecksum,
                cacheVersion: cacheVersion,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String articleId,
                required String title,
                required String sourceName,
                required String contentChecksum,
                required int cacheVersion,
                required DateTime expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedArticlesCompanion.insert(
                articleId: articleId,
                title: title,
                sourceName: sourceName,
                contentChecksum: contentChecksum,
                cacheVersion: cacheVersion,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedArticlesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedArticlesTable,
      CachedArticleRow,
      $$CachedArticlesTableFilterComposer,
      $$CachedArticlesTableOrderingComposer,
      $$CachedArticlesTableAnnotationComposer,
      $$CachedArticlesTableCreateCompanionBuilder,
      $$CachedArticlesTableUpdateCompanionBuilder,
      (
        CachedArticleRow,
        BaseReferences<_$AppDatabase, $CachedArticlesTable, CachedArticleRow>,
      ),
      CachedArticleRow,
      PrefetchHooks Function()
    >;
typedef $$CachedArticleBlocksTableCreateCompanionBuilder =
    CachedArticleBlocksCompanion Function({
      required String blockId,
      required String articleId,
      required int position,
      required String content,
      Value<int> rowid,
    });
typedef $$CachedArticleBlocksTableUpdateCompanionBuilder =
    CachedArticleBlocksCompanion Function({
      Value<String> blockId,
      Value<String> articleId,
      Value<int> position,
      Value<String> content,
      Value<int> rowid,
    });

class $$CachedArticleBlocksTableFilterComposer
    extends Composer<_$AppDatabase, $CachedArticleBlocksTable> {
  $$CachedArticleBlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get articleId => $composableBuilder(
    column: $table.articleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedArticleBlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedArticleBlocksTable> {
  $$CachedArticleBlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get articleId => $composableBuilder(
    column: $table.articleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedArticleBlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedArticleBlocksTable> {
  $$CachedArticleBlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get blockId =>
      $composableBuilder(column: $table.blockId, builder: (column) => column);

  GeneratedColumn<String> get articleId =>
      $composableBuilder(column: $table.articleId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);
}

class $$CachedArticleBlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedArticleBlocksTable,
          CachedArticleBlockRow,
          $$CachedArticleBlocksTableFilterComposer,
          $$CachedArticleBlocksTableOrderingComposer,
          $$CachedArticleBlocksTableAnnotationComposer,
          $$CachedArticleBlocksTableCreateCompanionBuilder,
          $$CachedArticleBlocksTableUpdateCompanionBuilder,
          (
            CachedArticleBlockRow,
            BaseReferences<
              _$AppDatabase,
              $CachedArticleBlocksTable,
              CachedArticleBlockRow
            >,
          ),
          CachedArticleBlockRow,
          PrefetchHooks Function()
        > {
  $$CachedArticleBlocksTableTableManager(
    _$AppDatabase db,
    $CachedArticleBlocksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedArticleBlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedArticleBlocksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedArticleBlocksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> blockId = const Value.absent(),
                Value<String> articleId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedArticleBlocksCompanion(
                blockId: blockId,
                articleId: articleId,
                position: position,
                content: content,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String blockId,
                required String articleId,
                required int position,
                required String content,
                Value<int> rowid = const Value.absent(),
              }) => CachedArticleBlocksCompanion.insert(
                blockId: blockId,
                articleId: articleId,
                position: position,
                content: content,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedArticleBlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedArticleBlocksTable,
      CachedArticleBlockRow,
      $$CachedArticleBlocksTableFilterComposer,
      $$CachedArticleBlocksTableOrderingComposer,
      $$CachedArticleBlocksTableAnnotationComposer,
      $$CachedArticleBlocksTableCreateCompanionBuilder,
      $$CachedArticleBlocksTableUpdateCompanionBuilder,
      (
        CachedArticleBlockRow,
        BaseReferences<
          _$AppDatabase,
          $CachedArticleBlocksTable,
          CachedArticleBlockRow
        >,
      ),
      CachedArticleBlockRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedArticlesTableTableManager get cachedArticles =>
      $$CachedArticlesTableTableManager(_db, _db.cachedArticles);
  $$CachedArticleBlocksTableTableManager get cachedArticleBlocks =>
      $$CachedArticleBlocksTableTableManager(_db, _db.cachedArticleBlocks);
}
