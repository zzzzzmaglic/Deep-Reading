import 'package:app/core/router/app_router.dart';
import 'package:app/features/reader/data/article_repository.dart';
import 'package:app/features/reader/domain/article.dart';
import 'package:app/features/reader/presentation/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reader scrolls the requested anchor into view', (tester) async {
    await pumpReader(tester, anchorId: 'anchor-2');

    expect(find.byKey(const Key('reader-anchor-anchor-2')), findsOneWidget);
  });
}

Future<void> pumpReader(WidgetTester tester, {String? anchorId}) async {
  final article = Article(
    id: 'article-1',
    title: 'Reader article',
    sourceName: 'Deep Reading',
    contentChecksum: 'checksum-1',
    blocks: List<ArticleBlock>.generate(
      4,
      (index) => ArticleBlock(
        id: 'anchor-${index + 1}',
        articleId: 'article-1',
        position: index + 1,
        content: 'Article block ${index + 1}',
      ),
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: ReaderScreen(
        articleId: article.id,
        routeContext: ReaderRouteContext(
          origin: ReaderOrigin.feed,
          anchorId: anchorId,
        ),
        articleRepository: _FakeArticleRepository(article),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeArticleRepository implements ArticleRepository {
  _FakeArticleRepository(this.article);

  final Article article;

  @override
  Future<Article> readArticle(String articleId) async => article;
}
