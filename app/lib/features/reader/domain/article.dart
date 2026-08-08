import 'package:app/core/storage/app_database.dart';

class Article {
  const Article({
    String? id,
    String? articleId,
    required this.title,
    required this.sourceName,
    required this.contentChecksum,
    required this.blocks,
  }) : id = id ?? articleId ?? '';

  factory Article.fromCachedArticle(CachedArticle article) {
    return Article(
      id: article.articleId,
      title: article.title,
      sourceName: article.sourceName,
      contentChecksum: article.contentChecksum,
      blocks: article.blocks
          .map(ArticleBlock.fromCachedBlock)
          .toList(growable: false),
    );
  }

  final String id;
  String get articleId => id;
  final String title;
  final String sourceName;
  final String contentChecksum;
  final List<ArticleBlock> blocks;
}

class ArticleBlock {
  const ArticleBlock({
    String? id,
    String? blockId,
    String? articleId,
    required this.position,
    required this.content,
  }) : id = id ?? blockId ?? '',
       articleId = articleId ?? '';

  factory ArticleBlock.fromCachedBlock(CachedArticleBlock block) {
    return ArticleBlock(
      id: block.blockId,
      articleId: block.articleId,
      position: block.position,
      content: block.content,
    );
  }

  final String id;
  final String articleId;
  String get blockId => id;
  final int position;
  final String content;
}
