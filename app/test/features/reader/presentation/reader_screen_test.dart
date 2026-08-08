import 'package:app/core/router/app_router.dart';
import 'package:app/features/reader/domain/article.dart';
import 'package:app/features/reader/data/article_repository.dart';
import 'package:app/features/reader/presentation/reader_screen.dart';
import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loaded reader block exposes the requested anchor key', (
    tester,
  ) async {
    await pumpReader(tester, anchorId: 'anchor-2');

    expect(find.text('Article block 2'), findsOneWidget);
    expect(find.byKey(const Key('reader-anchor-anchor-2')), findsOneWidget);
  });

  testWidgets('unknown requested anchor shows a retryable anchor error', (
    tester,
  ) async {
    await pumpReader(tester, anchorId: 'missing-anchor', assets: const []);

    expect(find.byKey(const Key('reader-anchor-error')), findsOneWidget);
    expect(
      find.text('Requested reading anchor is unavailable.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reader-anchor-missing-anchor')), findsNothing);
  });
}

Future<void> pumpReader(
  WidgetTester tester, {
  String? anchorId,
  List<ReadingAsset>? assets,
}) async {
  final article = Article(
    id: 'article-1',
    title: 'Reader article',
    sourceName: 'Deep Reading',
    contentChecksum: 'checksum-1',
    blocks: [
      const ArticleBlock(
        id: 'block-1',
        articleId: 'article-1',
        position: 1,
        content: 'Article block 1',
      ),
      const ArticleBlock(
        id: 'anchor-2',
        articleId: 'article-1',
        position: 2,
        content: 'Article block 2',
      ),
      const ArticleBlock(
        id: 'block-3',
        articleId: 'article-1',
        position: 3,
        content: 'Article block 3',
      ),
    ],
  );
  final anchor = TextAnchor(
    id: 'anchor-2',
    assetId: 'asset-1',
    articleId: article.id,
    startBlockId: 'anchor-2',
    endBlockId: 'anchor-2',
    startUtf16Offset: 3,
    endUtf16Offset: 8,
    selectedText: 'Article',
    contentChecksum: article.contentChecksum,
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
        readingAssetRepository: _FakeReadingAssetRepository(
          assets ??
              [
                ReadingAsset(
                  id: anchor.assetId,
                  ownerId: 'owner-1',
                  anchor: anchor,
                  noteContent: null,
                  tags: const [],
                ),
              ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeReadingAssetRepository implements ReadingAssetRepository {
  _FakeReadingAssetRepository(this.assets);

  final List<ReadingAsset> assets;

  @override
  Future<ReadingAsset> createHighlightAsset({
    required String articleId,
    required String startBlockId,
    required String endBlockId,
    required int startUtf16Offset,
    required int endUtf16Offset,
    required String selectedText,
    required String contentChecksum,
  }) => throw UnimplementedError();

  @override
  Future<ReadingAsset> createStandaloneNote({required String noteContent}) =>
      throw UnimplementedError();

  @override
  Future<ReadingAsset> updateReadingAsset({
    required String assetId,
    required String? noteContent,
  }) => throw UnimplementedError();

  @override
  Future<void> setAssetTags({
    required String assetId,
    required List<String> tagIds,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteReadingAsset(String assetId) => throw UnimplementedError();

  @override
  Future<void> upsertReadingProgress({
    required String articleId,
    required String? blockId,
    required int utf16Offset,
  }) => throw UnimplementedError();

  @override
  Future<List<ReadingAsset>> readAssets({String? articleId}) async => assets;

  @override
  Future<List<Tag>> readTags() => throw UnimplementedError();
}

class _FakeArticleRepository implements ArticleRepository {
  _FakeArticleRepository(this.article);

  final Article article;

  @override
  Future<Article> readArticle(String articleId) async => article;
}
