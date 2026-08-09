import 'package:app/features/reader/domain/article.dart';
import 'package:app/features/reader/presentation/selection/reader_selection_adapter.dart';
import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:app/features/reading_assets/presentation/asset_editor_controller.dart';
import 'package:app/features/reading_assets/presentation/reading_asset_card.dart';
import 'package:app/features/reading_assets/presentation/tag_management_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const locked = Tag(
    id: 'locked',
    ownerId: 'owner',
    name: '摘录与思考',
    isSystem: true,
  );
  const work = Tag(id: 'work', ownerId: 'owner', name: 'Work', isSystem: false);
  const article = Article(
    id: 'article-1',
    title: 'Article',
    sourceName: 'Source',
    contentChecksum: 'sha256:article',
    blocks: [
      ArticleBlock(
        id: 'block-1',
        articleId: 'article-1',
        position: 0,
        content: 'Selected text',
      ),
    ],
  );
  const selection = ReaderSelection(
    start: ReaderSelectionPoint(blockId: 'block-1', utf16Offset: 0),
    end: ReaderSelectionPoint(blockId: 'block-1', utf16Offset: 8),
    selectedText: 'Selected',
  );

  ReadingAsset highlight({List<Tag> tags = const [locked]}) => ReadingAsset(
    id: 'asset-1',
    ownerId: 'owner',
    anchor: const TextAnchor(
      id: 'anchor-1',
      assetId: 'asset-1',
      articleId: 'article-1',
      startBlockId: 'block-1',
      endBlockId: 'block-1',
      startUtf16Offset: 0,
      endUtf16Offset: 8,
      selectedText: 'Selected',
      contentChecksum: 'sha256:article',
    ),
    noteContent: null,
    tags: tags,
  );

  test(
    'existing draft uses one atomic RPC and retains its draft on failure',
    () async {
      final repository = _ReviewRepository(tags: const [locked, work])
        ..failAtomicSave = true;
      final controller = AssetEditorController(
        repository: repository,
        draft: AssetEditorDraft.fromAsset(highlight()),
      )..setNoteContent('Draft note');

      await expectLater(controller.save(), throwsStateError);

      expect(repository.atomicSaveCalls, ['asset-1:Draft note:locked']);
      expect(repository.legacyUpdateCalls, isEmpty);
      expect(repository.legacyTagCalls, isEmpty);
      expect(controller.draft.noteContent, 'Draft note');
    },
  );

  testWidgets(
    'standalone reader request opens a draft and creates it on completion',
    (tester) async {
      final repository = _ReviewRepository(tags: const [locked, work]);
      final presenter = ReadingAssetCardRequestPresenter(
        repository: repository,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () => presenter.presentStandaloneNoteRequest(
                context,
                request: const ReaderStandaloneNoteDraftRequest(
                  articleId: 'article-1',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('asset-note-input')),
        'Standalone',
      );
      await tester.tap(find.byTooltip('完成编辑'));
      await tester.pumpAndSettle();

      expect(repository.createStandaloneWithTagsCalls, [
        'Standalone:locked:article-1',
      ]);
    },
  );

  testWidgets('save failures are visible and retain a retryable editor draft', (
    tester,
  ) async {
    final repository = _ReviewRepository(tags: const [locked, work])
      ..failAtomicSave = true;
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingAssetCard(
          asset: highlight(),
          repository: repository,
          startInEditing: true,
          onClosed: () => closed++,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('asset-note-input')),
      'Retry this note',
    );
    await tester.tap(find.byTooltip('完成编辑'));
    await tester.pumpAndSettle();

    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(find.text('Retry this note'), findsOneWidget);
    expect(closed, 0);

    repository.failAtomicSave = false;
    await tester.tap(find.byTooltip('完成编辑'));
    await tester.pumpAndSettle();
    expect(repository.atomicSaveCalls, [
      'asset-1:Retry this note:locked',
      'asset-1:Retry this note:locked',
    ]);
    expect(closed, 1);
  });

  testWidgets(
    'linked reader request refreshes reader assets only after delete succeeds',
    (tester) async {
      final repository = _ReviewRepository(tags: const [locked, work]);
      final presenter = ReadingAssetCardRequestPresenter(
        repository: repository,
      );
      var refreshes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () => presenter.presentAssetRequest(
                context,
                request: const ReaderAssetCardRequest(
                  articleId: 'article-1',
                  selection: selection,
                ),
                article: article,
                onReaderAssetsRefresh: (_) async => refreshes++,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('删除'));
      await tester.pump();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(repository.deletedIds, ['asset-1']);
      expect(refreshes, 1);
    },
  );

  testWidgets('card loads all tags and remembers immediately saved view tags', (
    tester,
  ) async {
    final repository = _ReviewRepository(tags: const [locked, work]);
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingAssetCard(asset: highlight(), repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('#标签'));
    await tester.pumpAndSettle();
    expect(find.text('Work'), findsOneWidget);
    await tester.tap(find.text('Work'));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#标签'));
    await tester.pumpAndSettle();

    final workTile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Work'),
    );
    expect(workTile.value, true);
  });

  testWidgets('view-mode tag saves also update the later editor draft', (
    tester,
  ) async {
    final repository = _ReviewRepository(tags: const [locked, work]);
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingAssetCard(asset: highlight(), repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('#标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work'));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('编辑'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('asset-note-input')),
      'Keep saved tags',
    );
    await tester.tap(find.byTooltip('完成编辑'));
    await tester.pumpAndSettle();

    expect(repository.atomicSaveCalls, ['asset-1:Keep saved tags:locked,work']);
  });

  testWidgets(
    'post-delete refresh failure closes without a delete failure message',
    (tester) async {
      final repository = _ReviewRepository(tags: const [locked, work]);
      final presenter = ReadingAssetCardRequestPresenter(
        repository: repository,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () => presenter.presentAssetRequest(
                context,
                request: const ReaderAssetCardRequest(
                  articleId: 'article-1',
                  selection: selection,
                ),
                article: article,
                onReaderAssetsRefresh: (_) async => throw StateError('refresh'),
              ),
              child: const Text('open refresh failure'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open refresh failure'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('删除'));
      await tester.pump();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(repository.deletedIds, ['asset-1']);
      expect(find.byKey(const ValueKey('asset-note-input')), findsNothing);
      expect(find.text('删除失败，请重试'), findsNothing);
    },
  );

  testWidgets(
    'delete cancellation and failure keep the card open without callbacks',
    (tester) async {
      final repository = _ReviewRepository(tags: const [locked, work]);
      var callbacks = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ReadingAssetCard(
            asset: highlight(),
            repository: repository,
            onDeleted: (_) async => callbacks++,
          ),
        ),
      );

      await tester.tap(find.byTooltip('删除'));
      await tester.pump();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(repository.deletedIds, isEmpty);
      expect(callbacks, 0);

      repository.failDelete = true;
      await tester.tap(find.byTooltip('删除'));
      await tester.pump();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(find.text('删除失败，请重试'), findsOneWidget);
      expect(callbacks, 0);
      expect(find.text('Selected'), findsOneWidget);
    },
  );

  testWidgets(
    'downward header drag and outside close discard dirty drafts through confirmation',
    (tester) async {
      var closed = 0;
      final repository = _ReviewRepository(tags: const [locked, work]);
      await tester.pumpWidget(
        MaterialApp(
          home: ReadingAssetCard(
            asset: highlight(),
            repository: repository,
            onClosed: () => closed++,
          ),
        ),
      );

      await tester.fling(
        find.byKey(const ValueKey('asset-card-drag-handle')),
        const Offset(0, 240),
        1200,
      );
      await tester.pumpAndSettle();
      expect(closed, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingAssetCard(
            asset: highlight(),
            repository: repository,
            onClosed: () => closed++,
          ),
        ),
      );
      await tester.tap(find.byTooltip('编辑'));
      await tester.pump();
      final input = tester.widget<TextField>(
        find.byKey(const ValueKey('asset-note-input')),
      );
      expect(input.focusNode!.hasFocus, true);
      await tester.enterText(
        find.byKey(const ValueKey('asset-note-input')),
        'Draft',
      );
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(input.focusNode!.hasFocus, false);
      await tester.tap(find.text('继续编辑'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('asset-note-input')))
            .focusNode!
            .hasFocus,
        true,
      );
    },
  );

  testWidgets('duplicate tag errors stay visible in the inline creation row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TagManagementSheet(
            tags: const [locked],
            selectedTagIds: const {'locked'},
            lockedTagIds: const {'locked'},
            onConfirm: (_) {},
            onCreateTag: (_) async =>
                throw StateError('tag name already exists'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('＋ 新建标签'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('new-tag-input')), 'Work');
    await tester.tap(find.byTooltip('创建标签'));
    await tester.pumpAndSettle();

    expect(find.text('标签已存在'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-tag-input')), findsOneWidget);
  });

  testWidgets(
    'invalid new tag names are visible and do not call the repository',
    (tester) async {
      var createCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagManagementSheet(
              tags: const [locked],
              selectedTagIds: const {'locked'},
              lockedTagIds: const {'locked'},
              onConfirm: (_) {},
              onCreateTag: (_) async {
                createCalls++;
                return work;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('＋ 新建标签'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('new-tag-input')),
        'x' * 49,
      );
      await tester.tap(find.byTooltip('创建标签'));
      await tester.pump();

      expect(find.text('标签名称最多 48 个字符'), findsOneWidget);
      expect(createCalls, 0);
    },
  );
}

class _ReviewRepository implements ReadingAssetRepository {
  _ReviewRepository({required this.tags});

  final List<Tag> tags;
  final atomicSaveCalls = <String>[];
  final createStandaloneWithTagsCalls = <String>[];
  final legacyUpdateCalls = <String>[];
  final legacyTagCalls = <String>[];
  final deletedIds = <String>[];
  bool failAtomicSave = false;
  bool failDelete = false;

  @override
  Future<ReadingAsset> saveReadingAsset({
    required String assetId,
    required String? noteContent,
    required List<String> tagIds,
  }) async {
    atomicSaveCalls.add('$assetId:${noteContent ?? ''}:${tagIds.join(',')}');
    if (failAtomicSave) throw StateError('save failed');
    return _asset(noteContent: noteContent, tagIds: tagIds);
  }

  @override
  Future<ReadingAsset> createStandaloneNoteWithTags({
    required String noteContent,
    required List<String> tagIds,
    String? articleId,
  }) async {
    createStandaloneWithTagsCalls.add(
      '$noteContent:${tagIds.join(',')}:${articleId ?? ''}',
    );
    return ReadingAsset(
      id: 'standalone-1',
      ownerId: 'owner',
      anchor: null,
      noteContent: noteContent,
      tags: tags.where((tag) => tagIds.contains(tag.id)).toList(),
    );
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
  }) async => _asset();
  @override
  Future<void> deleteReadingAsset(String assetId) async {
    if (failDelete) throw StateError('delete failed');
    deletedIds.add(assetId);
  }

  @override
  Future<List<Tag>> readTags() async => tags;
  @override
  Future<void> setAssetTags({
    required String assetId,
    required List<String> tagIds,
  }) async => legacyTagCalls.add(assetId);
  @override
  Future<ReadingAsset> updateReadingAsset({
    required String assetId,
    required String? noteContent,
  }) async {
    legacyUpdateCalls.add(assetId);
    return _asset(noteContent: noteContent);
  }

  @override
  Future<ReadingAsset> createStandaloneNote({
    required String noteContent,
    String? articleId,
  }) => throw UnimplementedError();
  @override
  Future<Tag> createTag({required String name}) => throw UnimplementedError();
  @override
  Future<List<ReadingAsset>> readAssets({String? articleId}) =>
      throw UnimplementedError();
  @override
  Future<void> upsertReadingProgress({
    required String articleId,
    required String? blockId,
    required int utf16Offset,
  }) => throw UnimplementedError();

  ReadingAsset _asset({
    String? noteContent,
    List<String> tagIds = const ['locked'],
  }) => ReadingAsset(
    id: 'asset-1',
    ownerId: 'owner',
    anchor: const TextAnchor(
      id: 'anchor-1',
      assetId: 'asset-1',
      articleId: 'article-1',
      startBlockId: 'block-1',
      endBlockId: 'block-1',
      startUtf16Offset: 0,
      endUtf16Offset: 8,
      selectedText: 'Selected',
      contentChecksum: 'sha256:article',
    ),
    noteContent: noteContent,
    tags: tags.where((tag) => tagIds.contains(tag.id)).toList(),
  );
}
