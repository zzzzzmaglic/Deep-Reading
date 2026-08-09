import 'package:app/core/router/app_router.dart';
import 'package:app/features/reader/presentation/article_asset_summary_controller.dart';
import 'package:app/features/reader/presentation/article_asset_summary_screen.dart';
import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'delete selected assets refreshes after every deletion succeeds',
    () async {
      final repository = _FakeSummaryRepository(
        assets: [_standaloneAsset('a1'), _standaloneAsset('a2')],
      );
      final controller = ArticleAssetSummaryController(
        articleId: 'article-1',
        repository: repository,
      );

      await controller.load();
      await controller.deleteSelectedAssets({'a1', 'a2'});

      expect(repository.deletedIds, containsAll(<String>['a1', 'a2']));
      expect(repository.readCalls, 2);
      expect(controller.assets, isEmpty);
    },
  );

  test('failed selected deletion does not refresh the summary', () async {
    final repository = _FakeSummaryRepository(
      assets: [_standaloneAsset('a1'), _standaloneAsset('a2')],
    )..failOnDelete = 'a2';
    final controller = ArticleAssetSummaryController(
      articleId: 'article-1',
      repository: repository,
    );

    await controller.load();
    await expectLater(
      controller.deleteSelectedAssets({'a1', 'a2'}),
      throwsStateError,
    );

    expect(repository.readCalls, 1);
  });

  testWidgets('show in article replaces summary and navigates to the anchor', (
    tester,
  ) async {
    final repository = _FakeSummaryRepository(assets: [_anchoredAsset()]);
    ReaderRouteContext? readerContext;
    final router = createAppRouter(
      initialLocation: '/reader/article-1/summary',
      readingAssetRepository: repository,
      readerScreenBuilder: ({required articleId, required routeContext}) {
        readerContext = routeContext;
        return const Scaffold(body: Text('reader'));
      },
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('在文中显示'));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/reader/article-1',
    );
    expect(readerContext?.anchorId, 'anchor-1');
    expect(readerContext?.origin, ReaderOrigin.feed);
  });

  testWidgets('right swipe selects an asset and exposes destructive action', (
    tester,
  ) async {
    final repository = _FakeSummaryRepository(assets: [_standaloneAsset('a1')]);
    await tester.pumpWidget(
      MaterialApp(
        home: ArticleAssetSummaryScreen(
          articleId: 'article-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.fling(
      find.byKey(const ValueKey('summary-asset-a1')),
      const Offset(600, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('article-summary-delete')), findsOneWidget);
  });

  testWidgets('selected deletion requires permanent-delete confirmation', (
    tester,
  ) async {
    final repository = _FakeSummaryRepository(assets: [_standaloneAsset('a1')]);
    await tester.pumpWidget(
      MaterialApp(
        home: ArticleAssetSummaryScreen(
          articleId: 'article-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.fling(
      find.byKey(const ValueKey('summary-asset-a1')),
      const Offset(600, 0),
      1000,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('article-summary-delete')));
    await tester.pumpAndSettle();

    expect(find.text('删除后将永久移除该阅读资产，且无法恢复。'), findsOneWidget);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, ['a1']);
    expect(find.byKey(const ValueKey('summary-asset-a1')), findsNothing);
  });
}

ReadingAsset _anchoredAsset() => const ReadingAsset(
  id: 'a1',
  ownerId: 'owner-1',
  anchor: TextAnchor(
    id: 'anchor-1',
    assetId: 'a1',
    articleId: 'article-1',
    startBlockId: 'block-1',
    endBlockId: 'block-1',
    startUtf16Offset: 0,
    endUtf16Offset: 8,
    selectedText: 'Selected text',
    contentChecksum: 'sha256:test',
  ),
  noteContent: null,
  tags: [],
);

ReadingAsset _standaloneAsset(String id) => ReadingAsset(
  id: id,
  ownerId: 'owner-1',
  articleId: 'article-1',
  anchor: null,
  noteContent: 'Standalone $id',
  tags: const [],
);

class _FakeSummaryRepository implements ReadingAssetRepository {
  _FakeSummaryRepository({required this.assets});

  final List<ReadingAsset> assets;
  final List<String> deletedIds = [];
  int readCalls = 0;
  String? failOnDelete;

  @override
  Future<List<ReadingAsset>> readAssets({String? articleId}) async {
    readCalls++;
    return List<ReadingAsset>.of(assets);
  }

  @override
  Future<void> deleteReadingAsset(String assetId) async {
    if (assetId == failOnDelete) throw StateError('delete failed');
    deletedIds.add(assetId);
    assets.removeWhere((asset) => asset.id == assetId);
  }

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
  Future<ReadingAsset> createStandaloneNote({
    required String noteContent,
    String? articleId,
  }) => throw UnimplementedError();

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
  Future<void> upsertReadingProgress({
    required String articleId,
    required String? blockId,
    required int utf16Offset,
  }) => throw UnimplementedError();

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
    String? articleId,
  }) => throw UnimplementedError();
}
