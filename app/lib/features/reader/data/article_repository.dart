import 'package:app/core/storage/app_database.dart';
import 'package:app/features/reader/domain/article.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class ArticleRepository {
  Future<Article> readArticle(String articleId);
}

class CachedArticleRepository implements ArticleRepository {
  const CachedArticleRepository(this.cache);

  final ArticleCache cache;

  @override
  Future<Article> readArticle(String articleId) async {
    Article? latest;
    try {
      await for (final cached in cache.readThenRefresh(articleId)) {
        latest = Article.fromCachedArticle(cached);
      }
    } catch (_) {
      if (latest == null) {
        rethrow;
      }
    }

    return latest ?? (throw ArticleNotFoundException(articleId));
  }
}

class SupabaseArticleRepository implements ArticleRepository {
  SupabaseArticleRepository(
    SupabaseClient client, {
    AppDatabase? database,
    Duration cacheTtl = const Duration(hours: 1),
  }) : _repository = CachedArticleRepository(
         ArticleCache.fromSupabase(
           database ?? AppDatabase(),
           client,
           cacheTtl: cacheTtl,
         ),
       );

  final CachedArticleRepository _repository;

  @override
  Future<Article> readArticle(String articleId) {
    return _repository.readArticle(articleId);
  }
}

class DemoArticleRepository implements ArticleRepository {
  const DemoArticleRepository();

  @override
  Future<Article> readArticle(String articleId) async {
    return Article(
      id: articleId,
      title: 'Deep Reading',
      sourceName: 'Deep Reading',
      contentChecksum: 'demo',
      blocks: [
        ArticleBlock(
          id: '$articleId-block-1',
          articleId: articleId,
          position: 1,
          content: 'Begin reading to leave a trace worth returning to.',
        ),
      ],
    );
  }
}
