import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'app_database.g.dart';

@DataClassName('CachedArticleRow')
class CachedArticles extends Table {
  TextColumn get articleId => text()();

  TextColumn get title => text()();

  TextColumn get sourceName => text()();

  TextColumn get contentChecksum => text()();

  IntColumn get cacheVersion => integer()();

  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {articleId};
}

@DataClassName('CachedArticleBlockRow')
class CachedArticleBlocks extends Table {
  TextColumn get blockId => text()();

  TextColumn get articleId => text()();

  IntColumn get position => integer()();

  TextColumn get content => text()();

  @override
  Set<Column<Object>> get primaryKey => {blockId};
}

class CachedArticle {
  const CachedArticle({
    required this.articleId,
    required this.title,
    required this.sourceName,
    required this.contentChecksum,
    required this.cacheVersion,
    required this.expiresAt,
    required this.blocks,
  });

  final String articleId;
  final String title;
  final String sourceName;
  final String contentChecksum;
  final int cacheVersion;
  final DateTime expiresAt;
  final List<CachedArticleBlock> blocks;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());
}

class CachedArticleBlock {
  const CachedArticleBlock({
    required this.blockId,
    required this.articleId,
    required this.position,
    required this.content,
  });

  final String blockId;
  final String articleId;
  final int position;
  final String content;
}

@DriftDatabase(tables: [CachedArticles, CachedArticleBlocks])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  factory AppDatabase.inMemory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
  );

  Future<CachedArticle?> readArticle(String articleId) async {
    final article = await (select(
      cachedArticles,
    )..where((row) => row.articleId.equals(articleId))).getSingleOrNull();
    if (article == null) {
      return null;
    }

    final blocks =
        await (select(cachedArticleBlocks)
              ..where((row) => row.articleId.equals(articleId))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();

    return CachedArticle(
      articleId: article.articleId,
      title: article.title,
      sourceName: article.sourceName,
      contentChecksum: article.contentChecksum,
      cacheVersion: article.cacheVersion,
      expiresAt: article.expiresAt,
      blocks: List.unmodifiable(
        blocks.map(
          (block) => CachedArticleBlock(
            blockId: block.blockId,
            articleId: block.articleId,
            position: block.position,
            content: block.content,
          ),
        ),
      ),
    );
  }

  Future<void> replaceArticle(CachedArticle article) {
    return transaction(() async {
      await (delete(
        cachedArticleBlocks,
      )..where((row) => row.articleId.equals(article.articleId))).go();
      await into(cachedArticles).insertOnConflictUpdate(
        CachedArticlesCompanion.insert(
          articleId: article.articleId,
          title: article.title,
          sourceName: article.sourceName,
          contentChecksum: article.contentChecksum,
          cacheVersion: article.cacheVersion,
          expiresAt: article.expiresAt,
        ),
      );
      await batch((batch) {
        batch.insertAll(
          cachedArticleBlocks,
          article.blocks
              .map(
                (block) => CachedArticleBlocksCompanion.insert(
                  blockId: block.blockId,
                  articleId: block.articleId,
                  position: block.position,
                  content: block.content,
                ),
              )
              .toList(growable: false),
        );
      });
    });
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'deep_reading_cache');
}

typedef ArticleFetcher = Future<CachedArticle?> Function(String articleId);

class ArticleCache {
  const ArticleCache(this.database, this.fetchArticle);

  final AppDatabase database;
  final ArticleFetcher fetchArticle;

  Stream<CachedArticle> readThenRefresh(String articleId) async* {
    final cached = await database.readArticle(articleId);
    if (cached != null) {
      yield cached;
    }

    try {
      final refreshed = await fetchArticle(articleId);
      if (refreshed != null) {
        await database.replaceArticle(refreshed);
        yield refreshed;
      }
    } catch (_) {
      if (cached == null) {
        rethrow;
      }
    }
  }

  factory ArticleCache.fromSupabase(
    AppDatabase database,
    SupabaseClient client, {
    Duration cacheTtl = const Duration(hours: 1),
  }) {
    return ArticleCache(
      database,
      SupabaseArticleFetcher(client, cacheTtl: cacheTtl).fetch,
    );
  }
}

class SupabaseArticleFetcher {
  SupabaseArticleFetcher(
    this._client, {
    this.cacheTtl = const Duration(hours: 1),
  });

  final SupabaseClient _client;
  final Duration cacheTtl;

  Future<CachedArticle?> fetch(String articleId) async {
    final articleRow = await _client
        .from('articles')
        .select('id, title, source_name, content_checksum, updated_at')
        .eq('id', articleId)
        .maybeSingle();
    if (articleRow == null) {
      return null;
    }

    final blockRows = await _client
        .from('article_blocks')
        .select('id, article_id, position, content')
        .eq('article_id', articleId)
        .order('position');
    final updatedAt = DateTime.parse(articleRow['updated_at'] as String);

    return CachedArticle(
      articleId: articleRow['id'] as String,
      title: articleRow['title'] as String,
      sourceName: articleRow['source_name'] as String,
      contentChecksum: articleRow['content_checksum'] as String,
      cacheVersion: updatedAt.millisecondsSinceEpoch,
      expiresAt: DateTime.now().toUtc().add(cacheTtl),
      blocks: List.unmodifiable(
        (blockRows as List<dynamic>).map((row) {
          final block = Map<String, dynamic>.from(row as Map);
          return CachedArticleBlock(
            blockId: block['id'] as String,
            articleId: block['article_id'] as String,
            position: block['position'] as int,
            content: block['content'] as String,
          );
        }),
      ),
    );
  }
}
