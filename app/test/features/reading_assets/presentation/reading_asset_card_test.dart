import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:app/features/reading_assets/presentation/reading_asset_card.dart';
import 'package:app/features/reading_assets/presentation/tag_management_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lockedTag = Tag(
    id: 'locked',
    ownerId: 'owner-1',
    name: '摘录与思考',
    isSystem: true,
  );
  const userTag = Tag(
    id: 'tag-1',
    ownerId: 'owner-1',
    name: 'Work',
    isSystem: false,
  );
  const anchor = TextAnchor(
    id: 'anchor-1',
    assetId: 'asset-1',
    articleId: 'article-1',
    startBlockId: 'block-1',
    endBlockId: 'block-1',
    startUtf16Offset: 0,
    endUtf16Offset: 12,
    selectedText: 'A highlighted passage',
    contentChecksum: 'sha256:test',
  );

  ReadingAsset asset({TextAnchor? assetAnchor = anchor, String? note}) {
    return ReadingAsset(
      id: 'asset-1',
      ownerId: 'owner-1',
      anchor: assetAnchor,
      noteContent: note,
      tags: const [lockedTag, userTag],
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required ReadingAsset readingAsset,
    required _FakeRepository repository,
    VoidCallback? onClosed,
    ValueChanged<ReadingAsset>? onHighlightRemoved,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingAssetCard(
          asset: readingAsset,
          repository: repository,
          onClosed: onClosed,
          onHighlightRemoved: onHighlightRemoved,
        ),
      ),
    );
  }

  testWidgets('renders highlight, linked note, and standalone note forms', (
    tester,
  ) async {
    final repository = _FakeRepository(asset());
    await pumpCard(tester, readingAsset: asset(), repository: repository);
    expect(find.text('A highlighted passage'), findsOneWidget);
    expect(find.text('添加笔记内容'), findsOneWidget);

    await pumpCard(
      tester,
      readingAsset: asset(note: 'A linked note'),
      repository: repository,
    );
    expect(find.text('A linked note'), findsOneWidget);

    await pumpCard(
      tester,
      readingAsset: asset(assetAnchor: null, note: 'A standalone note'),
      repository: repository,
    );
    expect(find.text('A standalone note'), findsOneWidget);
    expect(find.text('A highlighted passage'), findsNothing);
  });

  testWidgets('long highlights expose an internal full-content detail view', (
    tester,
  ) async {
    final longText = List.filled(30, 'long').join(' ');
    final readingAsset = ReadingAsset(
      id: 'asset-1',
      ownerId: 'owner-1',
      anchor: TextAnchor(
        id: 'anchor-1',
        assetId: 'asset-1',
        articleId: 'article-1',
        startBlockId: 'block-1',
        endBlockId: 'block-1',
        startUtf16Offset: 0,
        endUtf16Offset: 150,
        selectedText: longText,
        contentChecksum: 'sha256:test',
      ),
      noteContent: null,
      tags: const [lockedTag],
    );
    await pumpCard(
      tester,
      readingAsset: readingAsset,
      repository: _FakeRepository(readingAsset),
    );

    expect(find.text('查看完整划线'), findsOneWidget);
    await tester.tap(find.text('查看完整划线'));
    await tester.pumpAndSettle();
    expect(find.text(longText), findsOneWidget);
  });

  testWidgets('locked tags cannot be deselected', (tester) async {
    var selected = <String>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TagManagementSheet(
            tags: const [lockedTag, userTag],
            selectedTagIds: const {'locked', 'tag-1'},
            lockedTagIds: const {'locked'},
            onConfirm: (ids) => selected = ids,
          ),
        ),
      ),
    );

    await tester.tap(find.text('摘录与思考'));
    await tester.tap(find.text('完成'));

    expect(selected, contains('locked'));
  });

  testWidgets('view-mode tag confirmation saves immediately', (tester) async {
    final repository = _FakeRepository(asset());
    await pumpCard(tester, readingAsset: asset(), repository: repository);

    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work'));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(repository.setTagCalls.single, 'asset-1:locked');
  });

  testWidgets('edit-mode tag changes wait for completing the card', (
    tester,
  ) async {
    final repository = _FakeRepository(asset());
    await pumpCard(tester, readingAsset: asset(), repository: repository);

    await tester.tap(find.text('编辑'));
    await tester.pump();
    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work'));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(repository.setTagCalls, isEmpty);
    await tester.tap(find.text('完成编辑'));
    await tester.pumpAndSettle();

    expect(repository.setTagCalls, ['asset-1:locked']);
  });

  testWidgets(
    'dirty outside close asks for discard and clean outside close closes',
    (tester) async {
      var closed = 0;
      final repository = _FakeRepository(asset());
      await pumpCard(
        tester,
        readingAsset: asset(),
        repository: repository,
        onClosed: () => closed++,
      );
      await tester.tapAt(const Offset(2, 2));
      expect(closed, 1);

      await pumpCard(
        tester,
        readingAsset: asset(),
        repository: repository,
        onClosed: () => closed++,
      );
      await tester.tap(find.text('编辑'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Draft');
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.text('放弃编辑'), findsNWidgets(2));
      expect(closed, 1);
    },
  );

  testWidgets(
    'delete confirmation removes the reader highlight after success',
    (tester) async {
      ReadingAsset? removed;
      final repository = _FakeRepository(asset());
      await pumpCard(
        tester,
        readingAsset: asset(),
        repository: repository,
        onHighlightRemoved: (value) => removed = value,
      );

      await tester.tap(find.byTooltip('删除'));
      await tester.pumpAndSettle();
      expect(find.text('确认删除'), findsOneWidget);
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(repository.deletedIds, ['asset-1']);
      expect(removed?.id, 'asset-1');
    },
  );

  testWidgets('new tag is selected after creation', (tester) async {
    var selected = <String>{};
    const newTag = Tag(
      id: 'tag-new',
      ownerId: 'owner-1',
      name: 'New tag',
      isSystem: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TagManagementSheet(
            tags: const [lockedTag],
            selectedTagIds: const {'locked'},
            lockedTagIds: const {'locked'},
            onConfirm: (ids) => selected = ids,
            onCreateTag: (name) async => newTag,
          ),
        ),
      ),
    );

    await tester.tap(find.text('＋ 新建标签'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'New tag');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));

    expect(selected, contains('tag-new'));
  });
}

class _FakeRepository implements ReadingAssetRepository {
  _FakeRepository(this.assetToReturn);

  final ReadingAsset assetToReturn;
  final setTagCalls = <String>[];
  final deletedIds = <String>[];

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
      Future.value(assetToReturn);

  @override
  Future<ReadingAsset> updateReadingAsset({
    required String assetId,
    required String? noteContent,
  }) => Future.value(assetToReturn);

  @override
  Future<void> setAssetTags({
    required String assetId,
    required List<String> tagIds,
  }) async {
    setTagCalls.add('$assetId:${tagIds.join(',')}');
  }

  @override
  Future<void> deleteReadingAsset(String assetId) async {
    deletedIds.add(assetId);
  }

  @override
  Future<void> upsertReadingProgress({
    required String articleId,
    required String? blockId,
    required int utf16Offset,
  }) => throw UnimplementedError();

  @override
  Future<List<ReadingAsset>> readAssets({String? articleId}) =>
      throw UnimplementedError();

  @override
  Future<List<Tag>> readTags() => Future.value(const []);

  @override
  Future<Tag> createTag({required String name}) => throw UnimplementedError();
}
