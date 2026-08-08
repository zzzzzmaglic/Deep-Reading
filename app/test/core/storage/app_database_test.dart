import 'package:app/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  test('cache replaces expired content after a successful refresh', () async {
    final cached = _article(
      version: 1,
      expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      content: 'Cached block',
    );
    final refreshed = _article(
      version: 2,
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      content: 'Refreshed block',
    );
    await database.replaceArticle(cached);

    final values = await ArticleCache(
      database,
      (_) async => refreshed,
    ).readThenRefresh(cached.articleId).toList();

    expect(cached.isExpired, isTrue);
    expect(values.map((article) => article.cacheVersion), [1, 2]);
    final stored = await database.readArticle(cached.articleId);
    expect(stored?.cacheVersion, 2);
    expect(stored?.blocks.single.content, 'Refreshed block');
  });

  test('cached missing article is evicted and reported explicitly', () async {
    final cached = _article(version: 1);
    await database.replaceArticle(cached);

    await expectLater(
      ArticleCache(
        database,
        (_) async => null,
      ).readThenRefresh(cached.articleId),
      emitsInOrder([
        isA<CachedArticle>().having(
          (article) => article.cacheVersion,
          'cache version',
          1,
        ),
        emitsError(_isArticleNotFound),
      ]),
    );

    expect(await database.readArticle(cached.articleId), isNull);
  });

  test('uncached missing article is reported explicitly', () async {
    await expectLater(
      ArticleCache(database, (_) async => null).readThenRefresh('missing'),
      emitsError(_isArticleNotFound),
    );

    expect(await database.readArticle('missing'), isNull);
  });

  test('refresh failure keeps cached content available', () async {
    final cached = _article(version: 1);
    await database.replaceArticle(cached);

    final values = await ArticleCache(
      database,
      (_) async => throw StateError('offline'),
    ).readThenRefresh(cached.articleId).toList();

    expect(values.single.cacheVersion, 1);
    expect((await database.readArticle(cached.articleId))?.cacheVersion, 1);
  });

  test('database contains only article cache tables', () {
    expect(
      database.allTables.map((table) => table.actualTableName),
      unorderedEquals(['cached_articles', 'cached_article_blocks']),
    );
  });
}

bool _isArticleNotFound(Object error) {
  return error.toString().contains('Article was not found');
}

CachedArticle _article({
  required int version,
  DateTime? expiresAt,
  String content = 'Block',
}) {
  return CachedArticle(
    articleId: 'article-1',
    title: 'Article',
    sourceName: 'Source',
    contentChecksum: 'checksum-$version',
    cacheVersion: version,
    expiresAt:
        expiresAt ?? DateTime.now().toUtc().add(const Duration(hours: 1)),
    blocks: [
      CachedArticleBlock(
        blockId: 'block-$version',
        articleId: 'article-1',
        position: 1,
        content: content,
      ),
    ],
  );
}
