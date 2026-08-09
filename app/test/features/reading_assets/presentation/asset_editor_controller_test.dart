import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:app/features/reading_assets/presentation/asset_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  ReadingAsset asset({String? note, TextAnchor? assetAnchor = anchor}) {
    return ReadingAsset(
      id: 'asset-1',
      ownerId: 'owner-1',
      anchor: assetAnchor,
      noteContent: note,
      tags: const [lockedTag, userTag],
    );
  }

  test('adding note content converts a highlight in the same draft asset', () {
    final draft = AssetEditorDraft.fromAsset(asset());

    final updated = draft.withNote('A useful thought');

    expect(updated.assetId, 'asset-1');
    expect(updated.kind, ReadingAssetKind.linkedNote);
    expect(updated.originalAsset?.anchor?.id, 'anchor-1');
  });

  test('clearing a linked note converts it back to a highlight', () {
    final draft = AssetEditorDraft.fromAsset(asset(note: 'Existing note'));

    expect(draft.withNote('   ').kind, ReadingAssetKind.highlightOnly);
  });

  test('editing an existing asset performs no writes before save', () async {
    final repository = _FakeRepository(asset());
    final controller = AssetEditorController(
      repository: repository,
      draft: AssetEditorDraft.fromAsset(asset()),
    );

    controller.setNoteContent('A note');

    expect(repository.calls, isEmpty);
    await controller.save();

    expect(repository.calls, ['save:asset-1:A note:locked,tag-1']);
  });

  test(
    'saving a standalone note creates it and then persists its tags',
    () async {
      final created = ReadingAsset(
        id: 'created-1',
        ownerId: 'owner-1',
        anchor: null,
        noteContent: 'Standalone thought',
        tags: const [lockedTag],
      );
      final repository = _FakeRepository(created);
      final controller = AssetEditorController(
        repository: repository,
        draft: AssetEditorDraft.newStandalone(initialTagIds: const {'locked'}),
      );

      controller.setNoteContent('Standalone thought');
      controller.setSelectedTagIds(const {'locked', 'tag-1'});
      final result = await controller.save();

      expect(result.id, 'created-1');
      expect(result.kind, ReadingAssetKind.standaloneNote);
      expect(repository.calls, [
        'create-with-tags:Standalone thought:locked,tag-1',
      ]);
    },
  );
}

class _FakeRepository implements ReadingAssetRepository {
  _FakeRepository(this.assetToReturn);

  final ReadingAsset assetToReturn;
  final calls = <String>[];

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
  }) async {
    calls.add('create:$noteContent');
    return assetToReturn;
  }

  @override
  Future<ReadingAsset> updateReadingAsset({
    required String assetId,
    required String? noteContent,
  }) async {
    calls.add('update:$assetId:$noteContent');
    return assetToReturn;
  }

  @override
  Future<void> setAssetTags({
    required String assetId,
    required List<String> tagIds,
  }) async {
    calls.add('tags:$assetId:${tagIds.join(',')}');
  }

  @override
  Future<void> deleteReadingAsset(String assetId) => throw UnimplementedError();

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
  Future<List<Tag>> readTags() => throw UnimplementedError();

  @override
  Future<Tag> createTag({required String name}) => throw UnimplementedError();

  @override
  Future<ReadingAsset> saveReadingAsset({
    required String assetId,
    required String? noteContent,
    required List<String> tagIds,
  }) async {
    calls.add('save:$assetId:$noteContent:${tagIds.join(',')}');
    return assetToReturn;
  }

  @override
  Future<ReadingAsset> createStandaloneNoteWithTags({
    required String noteContent,
    required List<String> tagIds,
    String? articleId,
  }) async {
    calls.add('create-with-tags:$noteContent:${tagIds.join(',')}');
    return assetToReturn;
  }
}
