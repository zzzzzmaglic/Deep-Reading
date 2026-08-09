import 'package:app/features/reader/domain/article.dart';
import 'package:app/features/reader/presentation/selection/reader_context_menu.dart';
import 'package:app/features/reader/presentation/selection/reader_selection_adapter.dart';
import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('context menu exposes the four reader actions', (tester) async {
    final actions = <ReaderContextAction>[];
    await tester.pumpWidget(_menuHarness(onAction: actions.add));

    expect(find.text('划线'), findsOneWidget);
    expect(find.text('打开阅读资产卡片'), findsOneWidget);
    expect(find.text('AI释义'), findsOneWidget);
    expect(find.text('拷贝'), findsOneWidget);

    await tester.tap(find.text('划线'));
    await tester.pump();
    await tester.tap(find.text('打开阅读资产卡片'));
    await tester.pump();
    await tester.tap(find.text('AI释义'));
    await tester.pump();
    expect(actions, [
      ReaderContextAction.highlight,
      ReaderContextAction.openAssetCard,
      ReaderContextAction.explainWithAi,
    ]);
  });

  testWidgets('copy action writes selected text to the system clipboard', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String? copiedText;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String;
      }
      return null;
    });
    addTearDown(() async {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(_menuHarness(onAction: (_) {}));
    await tester.tap(find.text('拷贝'));
    await tester.pump();

    expect(copiedText, 'selected text');
  });

  test(
    'highlight controller creates an asset and refreshes persisted assets',
    () async {
      final repository = _FakeReadingAssetRepository();
      final controller = ReaderSelectionController(
        article: _article,
        repository: repository,
      );

      await controller.createHighlight(_selection);
      final refreshed = await controller.refreshAssets();

      expect(repository.createdAnchors, hasLength(1));
      expect(repository.createdAnchors.single.startBlockId, 'b-1');
      expect(refreshed, hasLength(1));
      expect(refreshed.single.anchor?.selectedText, 'Article block');
    },
  );
}

Widget _menuHarness({required ValueChanged<ReaderContextAction> onAction}) {
  return MaterialApp(
    home: Scaffold(
      body: ReaderContextMenu(
        selection: _selection,
        anchors: const TextSelectionToolbarAnchors(
          primaryAnchor: Offset(20, 20),
        ),
        onAction: onAction,
      ),
    ),
  );
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
      content: 'Article block 1',
    ),
  ],
);

const _selection = ReaderSelection(
  start: ReaderSelectionPoint(blockId: 'b-1', utf16Offset: 0),
  end: ReaderSelectionPoint(blockId: 'b-1', utf16Offset: 13),
  selectedText: 'selected text',
);

class _FakeReadingAssetRepository implements ReadingAssetRepository {
  final List<TextAnchor> createdAnchors = <TextAnchor>[];

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
    final anchor = TextAnchor(
      id: 'anchor-1',
      assetId: 'asset-1',
      articleId: articleId,
      startBlockId: startBlockId,
      endBlockId: endBlockId,
      startUtf16Offset: startUtf16Offset,
      endUtf16Offset: endUtf16Offset,
      selectedText: selectedText,
      contentChecksum: contentChecksum,
    );
    createdAnchors.add(anchor);
    return ReadingAsset(
      id: 'asset-1',
      ownerId: 'owner-1',
      anchor: anchor,
      noteContent: null,
      tags: const [],
    );
  }

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
  Future<void> deleteReadingAsset(String assetId) => throw UnimplementedError();

  @override
  Future<void> upsertReadingProgress({
    required String articleId,
    required String? blockId,
    required int utf16Offset,
  }) => throw UnimplementedError();

  @override
  Future<List<ReadingAsset>> readAssets({String? articleId}) async {
    return createdAnchors
        .map(
          (anchor) => ReadingAsset(
            id: anchor.assetId,
            ownerId: 'owner-1',
            anchor: anchor,
            noteContent: null,
            tags: const [],
          ),
        )
        .toList(growable: false);
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
    String? articleId,
  }) => throw UnimplementedError();
}
