import 'package:app/core/router/app_router.dart';
import 'package:app/features/reader/data/article_repository.dart';
import 'package:app/features/reader/domain/article.dart';
import 'package:app/features/reader/presentation/reader_controller.dart';
import 'package:app/features/reader/presentation/reader_screen.dart';
import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loaded reader block exposes the requested anchor key', (
    tester,
  ) async {
    await _pumpReader(tester, anchorId: 'anchor-2');

    expect(find.text('Article block 2'), findsOneWidget);
    expect(find.byKey(const Key('reader-anchor-anchor-2')), findsOneWidget);
  });

  testWidgets('unknown requested anchor shows a retryable anchor error', (
    tester,
  ) async {
    await _pumpReader(tester, anchorId: 'missing-anchor', assets: const []);

    expect(find.byKey(const Key('reader-anchor-error')), findsOneWidget);
    expect(
      find.text('Requested reading anchor is unavailable.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reader-anchor-missing-anchor')), findsNothing);
  });

  testWidgets(
    'requested anchor is positioned and takes precedence over saved progress',
    (tester) async {
      var savedProgressReads = 0;
      await _pumpReader(
        tester,
        article: longArticle(),
        anchorId: 'anchor-2',
        savedProgress: const ProgressPosition(
          blockId: 'block-3',
          utf16Offset: 12,
        ),
        onSavedProgressRead: () => savedProgressReads++,
      );

      final viewport = tester.getRect(find.byType(CustomScrollView));
      final anchor = tester.getRect(
        find.byKey(const Key('reader-anchor-anchor-2')),
      );
      expect(anchor.top, greaterThanOrEqualTo(viewport.top));
      expect(anchor.top, lessThan(viewport.bottom));
      expect(savedProgressReads, 0);
    },
  );

  testWidgets('unknown anchor leaves the initial scroll position unchanged', (
    tester,
  ) async {
    await _pumpReader(
      tester,
      article: longArticle(),
      anchorId: 'missing-anchor',
      assets: const [],
    );

    final scrollView = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    expect(scrollView.controller!.offset, 0);
  });

  testWidgets(
    'anchor lookup failure leaves the article visible with a retryable error',
    (tester) async {
      await _pumpReader(
        tester,
        article: longArticle(),
        anchorId: 'anchor-2',
        failAssetRead: true,
      );

      expect(find.textContaining('Article block 1'), findsOneWidget);
      expect(find.byKey(const Key('reader-anchor-error')), findsOneWidget);
      expect(
        find.text('Unable to resolve the requested reading anchor.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('reader body taps toggle the reader controls', (tester) async {
    await _pumpReader(tester);

    expect(
      tester
          .widget<AnimatedOpacity>(find.byKey(const Key('reader-controls')))
          .opacity,
      1,
    );
    await tester.tap(find.text('Article block 1'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedOpacity>(find.byKey(const Key('reader-controls')))
          .opacity,
      0,
    );
    await tester.tap(find.text('Article block 1'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedOpacity>(find.byKey(const Key('reader-controls')))
          .opacity,
      1,
    );
  });

  testWidgets('persisted highlights render across block boundaries', (
    tester,
  ) async {
    final article = Article(
      id: 'article-1',
      title: 'Reader article',
      sourceName: 'Deep Reading',
      contentChecksum: 'checksum-1',
      blocks: const [
        ArticleBlock(
          id: 'block-1',
          articleId: 'article-1',
          position: 1,
          content: 'First block',
        ),
        ArticleBlock(
          id: 'block-2',
          articleId: 'article-1',
          position: 2,
          content: 'Second block',
        ),
      ],
    );
    final anchor = TextAnchor(
      id: 'cross-anchor',
      assetId: 'cross-asset',
      articleId: article.id,
      startBlockId: 'block-1',
      endBlockId: 'block-2',
      startUtf16Offset: 2,
      endUtf16Offset: 4,
      selectedText: 'rst blockSeco',
      contentChecksum: article.contentChecksum,
    );

    await _pumpReader(
      tester,
      article: article,
      assets: [
        ReadingAsset(
          id: anchor.assetId,
          ownerId: 'owner-1',
          anchor: anchor,
          noteContent: null,
          tags: const [],
        ),
      ],
    );

    expect(find.byKey(const Key('highlighted-block-block-1')), findsOneWidget);
    expect(find.byKey(const Key('highlighted-block-block-2')), findsOneWidget);
  });

  testWidgets(
    'reader scrolling writes a rendered non-zero UTF-16 progress position',
    (tester) async {
      final harness = await _pumpReader(
        tester,
        article: longArticle(),
        progressDebounceDuration: const Duration(milliseconds: 1),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(
        tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!
            .offset,
        greaterThan(0),
      );
      expect(harness.assets.progressWrites, isNotEmpty);
      expect(harness.assets.progressWrites.last.blockId, isNotNull);
      expect(harness.assets.progressWrites.last.utf16Offset, greaterThan(0));
    },
  );
}

Future<_ReaderHarness> _pumpReader(
  WidgetTester tester, {
  String? anchorId,
  List<ReadingAsset>? assets,
  Article? article,
  ProgressPosition? savedProgress,
  VoidCallback? onSavedProgressRead,
  bool failAssetRead = false,
  Duration progressDebounceDuration = const Duration(milliseconds: 350),
}) async {
  final readerArticle =
      article ??
      Article(
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
    articleId: readerArticle.id,
    startBlockId: 'anchor-2',
    endBlockId: 'anchor-2',
    startUtf16Offset: 3,
    endUtf16Offset: 8,
    selectedText: 'Article',
    contentChecksum: readerArticle.contentChecksum,
  );
  final assetRepository = _FakeReadingAssetRepository(
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
    failReadAssets: failAssetRead,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: ReaderScreen(
        articleId: readerArticle.id,
        routeContext: ReaderRouteContext(
          origin: ReaderOrigin.feed,
          anchorId: anchorId,
        ),
        articleRepository: _FakeArticleRepository(readerArticle),
        readingAssetRepository: assetRepository,
        progressReader: savedProgress == null
            ? null
            : (_) async {
                onSavedProgressRead?.call();
                return savedProgress;
              },
        connectivity: _FakeConnectivity(),
        progressDebounceDuration: progressDebounceDuration,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _ReaderHarness(assetRepository);
}

class _FakeReadingAssetRepository implements ReadingAssetRepository {
  _FakeReadingAssetRepository(this.assets, {this.failReadAssets = false});

  final List<ReadingAsset> assets;
  final bool failReadAssets;
  final List<_ProgressWrite> progressWrites = <_ProgressWrite>[];

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
  }) async {
    progressWrites.add(
      _ProgressWrite(blockId: blockId, utf16Offset: utf16Offset),
    );
  }

  @override
  Future<List<ReadingAsset>> readAssets({String? articleId}) async {
    if (failReadAssets) {
      throw StateError('asset read failed');
    }
    return assets;
  }

  @override
  Future<List<Tag>> readTags() => throw UnimplementedError();

  @override
  Future<Tag> createTag({required String name}) => throw UnimplementedError();

  @override
  Future<ReadingAsset> saveReadingAsset({
    required String assetId,
    required String? noteContent,
    required List<String> tagIds,
  }) => throw UnimplementedError();

  @override
  Future<ReadingAsset> createStandaloneNoteWithTags({
    required String noteContent,
    required List<String> tagIds,
  }) => throw UnimplementedError();
}

class _FakeArticleRepository implements ArticleRepository {
  _FakeArticleRepository(this.article);

  final Article article;

  @override
  Future<Article> readArticle(String articleId) async => article;
}

class _FakeConnectivity implements ReaderConnectivityPort {
  @override
  Future<bool> get isOnline async => true;
}

class _ReaderHarness {
  const _ReaderHarness(this.assets);

  final _FakeReadingAssetRepository assets;
}

class _ProgressWrite {
  const _ProgressWrite({required this.blockId, required this.utf16Offset});

  final String? blockId;
  final int utf16Offset;
}

Article longArticle() {
  final longContent = List<String>.filled(
    90,
    'Article block 1 rendered text for progress tracking.',
  ).join(' ');
  return Article(
    id: 'article-1',
    title: 'Reader article',
    sourceName: 'Deep Reading',
    contentChecksum: 'checksum-1',
    blocks: [
      ArticleBlock(
        id: 'block-1',
        articleId: 'article-1',
        position: 1,
        content: longContent,
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
}
