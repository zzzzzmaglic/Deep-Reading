import 'package:app/core/storage/app_database.dart';
import 'package:app/features/reader/data/article_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'maps the existing cache boundary into immutable reader content',
    () async {
      final database = AppDatabase.inMemory();
      final cached = CachedArticle(
        articleId: 'article-1',
        title: 'Cached title',
        sourceName: 'Cached source',
        contentChecksum: 'checksum-1',
        cacheVersion: 1,
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        blocks: const [
          CachedArticleBlock(
            blockId: 'block-1',
            articleId: 'article-1',
            position: 1,
            content: 'Cached content',
          ),
        ],
      );
      await database.replaceArticle(cached);

      final article = await CachedArticleRepository(
        ArticleCache(database, (_) async => null),
      ).readArticle('article-1');

      expect(article.id, 'article-1');
      expect(article.blocks.single.content, 'Cached content');
      await database.close();
    },
  );

  test('surfaces a cache miss as an article-not-found error', () async {
    final database = AppDatabase.inMemory();

    await expectLater(
      CachedArticleRepository(
        ArticleCache(database, (_) async => null),
      ).readArticle('missing'),
      throwsA(isA<ArticleNotFoundException>()),
    );
    await database.close();
  });
}
