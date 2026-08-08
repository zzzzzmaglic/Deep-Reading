import 'dart:async';

import 'package:app/core/router/app_router.dart';
import 'package:app/features/reader/data/article_repository.dart';
import 'package:app/features/reader/domain/article.dart';
import 'package:app/features/reader/presentation/reader_controller.dart';
import 'package:app/features/reader/presentation/reader_screen.dart';
import 'package:app/features/reader/presentation/selection/reader_selection_adapter.dart';
import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'highlight action closes selection, submits once, and restores body taps',
    (tester) async {
      final adapter = _TestSelectionAdapter(_selection);
      final repository = _FakeReadingAssetRepository()
        ..pendingCreate = Completer<void>();
      await _pumpReader(tester, adapter: adapter, repository: repository);

      await tester.tap(find.text('Selected article body'));
      await tester.pumpAndSettle();
      expect(_controlsOpacity(tester), 1);

      await tester.tap(find.text('划线'));
      await tester.tap(find.text('划线'), warnIfMissed: false);
      await tester.pump();

      expect(repository.createHighlightCalls, 1);
      expect(adapter.session.clearCalls, greaterThanOrEqualTo(1));
      expect(find.text('划线'), findsNothing);

      repository.pendingCreate!.complete();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Selected article body'));
      await tester.pumpAndSettle();
      expect(_controlsOpacity(tester), 0);
    },
  );

  testWidgets('failed highlight creation is visible and retryable', (
    tester,
  ) async {
    final adapter = _TestSelectionAdapter(_selection);
    final repository = _FakeReadingAssetRepository(createFailuresRemaining: 1);
    await _pumpReader(tester, adapter: adapter, repository: repository);

    await tester.tap(find.text('划线'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reader-highlight-error')), findsOneWidget);
    expect(find.byKey(const Key('reader-highlight-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reader-highlight-retry')));
    await tester.pumpAndSettle();

    expect(repository.createHighlightCalls, 2);
    expect(find.byKey(const Key('reader-highlight-error')), findsNothing);
    expect(find.byKey(const Key('highlighted-block-b-1')), findsOneWidget);
  });

  testWidgets('failed highlight refresh retries without creating a duplicate', (
    tester,
  ) async {
    final adapter = _TestSelectionAdapter(_selection);
    final repository = _FakeReadingAssetRepository();
    await _pumpReader(tester, adapter: adapter, repository: repository);
    repository.assetReadFailuresRemaining = 1;

    await tester.tap(find.text('划线'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader-highlight-error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reader-highlight-retry')));
    await tester.pumpAndSettle();

    expect(repository.createHighlightCalls, 1);
    expect(find.byKey(const Key('highlighted-block-b-1')), findsOneWidget);
  });

  testWidgets('initial highlight read failure stays visible and can retry', (
    tester,
  ) async {
    final repository = _FakeReadingAssetRepository(
      assetReadFailuresRemaining: 1,
    )..assets.add(_assetForSelection());
    await _pumpReader(
      tester,
      adapter: _TestSelectionAdapter(_selection),
      repository: repository,
    );

    expect(find.text('Selected article body'), findsOneWidget);
    expect(find.byKey(const Key('reader-assets-error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reader-assets-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reader-assets-error')), findsNothing);
    expect(find.byKey(const Key('highlighted-block-b-1')), findsOneWidget);
  });

  testWidgets('highlight failures are contained after the reader is disposed', (
    tester,
  ) async {
    final adapter = _TestSelectionAdapter(_selection);
    final repository = _FakeReadingAssetRepository()
      ..pendingCreate = Completer<void>();
    await _pumpReader(tester, adapter: adapter, repository: repository);

    await tester.tap(find.text('划线'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    repository.pendingCreate!.completeError(StateError('offline'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

double _controlsOpacity(WidgetTester tester) {
  return tester
      .widget<AnimatedOpacity>(find.byKey(const Key('reader-controls')))
      .opacity;
}

Future<void> _pumpReader(
  WidgetTester tester, {
  required _TestSelectionAdapter adapter,
  required _FakeReadingAssetRepository repository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ReaderScreen(
        articleId: _article.id,
        routeContext: const ReaderRouteContext(origin: ReaderOrigin.feed),
        articleRepository: _FakeArticleRepository(_article),
        readingAssetRepository: repository,
        connectivity: _FakeConnectivity(),
        selectionAdapter: adapter,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _article = Article(
  id: 'article-1',
  title: 'Reader article',
  sourceName: 'Deep Reading',
  contentChecksum: 'checksum-1',
  blocks: const [
    ArticleBlock(
      id: 'b-1',
      articleId: 'article-1',
      position: 1,
      content: 'Selected article body',
    ),
  ],
);

const _selection = ReaderSelection(
  start: ReaderSelectionPoint(blockId: 'b-1', utf16Offset: 0),
  end: ReaderSelectionPoint(blockId: 'b-1', utf16Offset: 8),
  selectedText: 'Selected',
);

ReadingAsset _assetForSelection() {
  return ReadingAsset(
    id: 'asset-${DateTime.now().microsecondsSinceEpoch}',
    ownerId: 'owner-1',
    anchor: selectionToAnchor(_article, _selection),
    noteContent: null,
    tags: const [],
  );
}

class _TestSelectionAdapter implements ReaderSelectionAdapter {
  _TestSelectionAdapter(this.selection);

  final ReaderSelection selection;
  late _TestSelectionSession session;

  @override
  ReaderSelectionSession createSession({
    required Article article,
    required ValueChanged<ReaderSelection?> onSelectionChanged,
  }) {
    return session = _TestSelectionSession(selection, onSelectionChanged);
  }
}

class _TestSelectionSession implements ReaderSelectionSession {
  _TestSelectionSession(this.selection, this._onSelectionChanged);

  final ReaderSelection selection;
  final ValueChanged<ReaderSelection?> _onSelectionChanged;
  final ValueNotifier<bool> _menuVisible = ValueNotifier<bool>(true);
  var _announcedSelection = false;
  var clearCalls = 0;

  @override
  Widget wrap({
    required Widget child,
    required ReaderSelectionMenuBuilder contextMenuBuilder,
  }) {
    if (!_announcedSelection) {
      _announcedSelection = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onSelectionChanged(selection);
      });
    }
    return ValueListenableBuilder<bool>(
      valueListenable: _menuVisible,
      builder: (context, visible, _) => Stack(
        children: [
          child,
          if (visible)
            Positioned.fill(
              child: contextMenuBuilder(
                context,
                selection,
                const TextSelectionToolbarAnchors(
                  primaryAnchor: Offset(20, 20),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget wrapBlock({required ArticleBlock block, required Widget child}) =>
      child;

  @override
  void clearSelection() {
    clearCalls++;
    _menuVisible.value = false;
    _onSelectionChanged(null);
  }

  @override
  void dispose() => _menuVisible.dispose();
}

class _FakeReadingAssetRepository implements ReadingAssetRepository {
  _FakeReadingAssetRepository({
    this.createFailuresRemaining = 0,
    this.assetReadFailuresRemaining = 0,
  });

  final List<ReadingAsset> assets = <ReadingAsset>[];
  int createFailuresRemaining;
  int assetReadFailuresRemaining;
  int createHighlightCalls = 0;
  Completer<void>? pendingCreate;

  @override
  Future<ReadingAsset> createHighlightAsset({
    required String articleId,
    required String startBlockId,
    required String endBlockId,
    required int startUtf16Offset,
    required int endUtf16Offset,
    required String selectedText,
    required String contentChecksum,
  }) async {
    createHighlightCalls++;
    await pendingCreate?.future;
    if (createFailuresRemaining > 0) {
      createFailuresRemaining--;
      throw StateError('highlight create failed');
    }
    final asset = ReadingAsset(
      id: 'asset-$createHighlightCalls',
      ownerId: 'owner-1',
      anchor: TextAnchor(
        id: 'anchor-$createHighlightCalls',
        assetId: 'asset-$createHighlightCalls',
        articleId: articleId,
        startBlockId: startBlockId,
        endBlockId: endBlockId,
        startUtf16Offset: startUtf16Offset,
        endUtf16Offset: endUtf16Offset,
        selectedText: selectedText,
        contentChecksum: contentChecksum,
      ),
      noteContent: null,
      tags: const [],
    );
    assets.add(asset);
    return asset;
  }

  @override
  Future<List<ReadingAsset>> readAssets({String? articleId}) async {
    if (assetReadFailuresRemaining > 0) {
      assetReadFailuresRemaining--;
      throw StateError('asset read failed');
    }
    return List<ReadingAsset>.of(assets);
  }

  @override
  Future<ReadingAsset> createStandaloneNote({required String noteContent}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteReadingAsset(String assetId) => throw UnimplementedError();

  @override
  Future<List<Tag>> readTags() => throw UnimplementedError();

  @override
  Future<void> setAssetTags({
    required String assetId,
    required List<String> tagIds,
  }) => throw UnimplementedError();

  @override
  Future<ReadingAsset> updateReadingAsset({
    required String assetId,
    required String? noteContent,
  }) => throw UnimplementedError();

  @override
  Future<void> upsertReadingProgress({
    required String articleId,
    required String? blockId,
    required int utf16Offset,
  }) async {}
}

class _FakeArticleRepository implements ArticleRepository {
  const _FakeArticleRepository(this.article);

  final Article article;

  @override
  Future<Article> readArticle(String articleId) async => article;
}

class _FakeConnectivity implements ReaderConnectivityPort {
  @override
  Future<bool> get isOnline async => true;
}
