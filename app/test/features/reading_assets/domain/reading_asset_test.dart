import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const anchor = TextAnchor(
    id: 'anchor-1',
    assetId: 'asset-1',
    articleId: 'article-1',
    startBlockId: 'block-1',
    endBlockId: 'block-1',
    startUtf16Offset: 0,
    endUtf16Offset: 8,
    selectedText: 'Highlight',
    contentChecksum: 'sha256:test',
  );

  test('derives reading asset kind from anchor and note content', () {
    expect(
      deriveReadingAssetKind(anchor: anchor, noteContent: null),
      ReadingAssetKind.highlightOnly,
    );
    expect(
      deriveReadingAssetKind(
        anchor: anchor,
        noteContent: 'Continue researching',
      ),
      ReadingAssetKind.linkedNote,
    );
    expect(
      deriveReadingAssetKind(anchor: null, noteContent: 'Standalone thought'),
      ReadingAssetKind.standaloneNote,
    );
  });

  test('repository writes use only the declared asset RPCs', () async {
    final dataSource = _RecordingReadingAssetDataSource();
    final repository = SupabaseReadingAssetRepository.forDataSource(dataSource);

    await repository.createHighlightAsset(
      articleId: 'article-1',
      startBlockId: 'block-1',
      endBlockId: 'block-1',
      startUtf16Offset: 0,
      endUtf16Offset: 8,
      selectedText: 'Highlight',
      contentChecksum: 'sha256:test',
    );
    await repository.createStandaloneNote(noteContent: 'Standalone thought');
    await repository.updateReadingAsset(
      assetId: 'asset-1',
      noteContent: 'Linked note',
    );
    await repository.saveReadingAsset(
      assetId: 'asset-1',
      noteContent: 'Linked note with tags',
      tagIds: ['tag-1'],
    );
    await repository.createStandaloneNoteWithTags(
      noteContent: 'Standalone thought with tags',
      tagIds: ['tag-1'],
    );
    await repository.setAssetTags(assetId: 'asset-1', tagIds: ['tag-1']);
    await repository.deleteReadingAsset('asset-1');
    await repository.upsertReadingProgress(
      articleId: 'article-1',
      blockId: 'block-1',
      utf16Offset: 8,
    );

    expect(dataSource.rpcNames, [
      'create_highlight_asset',
      'create_standalone_note',
      'update_reading_asset',
      'save_reading_asset',
      'create_standalone_note_with_tags',
      'set_asset_tags',
      'delete_reading_asset',
      'upsert_reading_progress',
    ]);
  });

  test(
    'repository creates a typed user tag through the create_tag RPC',
    () async {
      final dataSource = _RecordingReadingAssetDataSource();
      final repository = SupabaseReadingAssetRepository.forDataSource(
        dataSource,
      );

      final tag = await repository.createTag(name: 'New tag');

      expect(tag.id, 'tag-1');
      expect(tag.name, 'Tag');
      expect(dataSource.rpcNames, ['create_tag']);
    },
  );
}

class _RecordingReadingAssetDataSource implements ReadingAssetRemoteDataSource {
  final rpcNames = <String>[];

  @override
  Future<dynamic> callRpc(
    String functionName, {
    required Map<String, dynamic> parameters,
  }) async {
    rpcNames.add(functionName);
    return switch (functionName) {
      'create_highlight_asset' ||
      'create_standalone_note' ||
      'update_reading_asset' ||
      'save_reading_asset' ||
      'create_standalone_note_with_tags' => 'asset-1',
      'create_tag' => 'tag-1',
      'upsert_reading_progress' => 'progress-1',
      _ => null,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> readRows(String table) async {
    return switch (table) {
      'reading_assets' => [
        {'id': 'asset-1', 'owner_id': 'owner-1', 'note_content': 'Linked note'},
      ],
      'asset_anchors' => [
        {
          'id': 'anchor-1',
          'asset_id': 'asset-1',
          'article_id': 'article-1',
          'start_block_id': 'block-1',
          'end_block_id': 'block-1',
          'start_utf16_offset': 0,
          'end_utf16_offset': 8,
          'selected_text': 'Highlight',
          'content_checksum': 'sha256:test',
        },
      ],
      'tags' => [
        {
          'id': 'tag-1',
          'owner_id': 'owner-1',
          'name': 'Tag',
          'is_system': false,
        },
      ],
      'asset_tags' => [
        {'asset_id': 'asset-1', 'tag_id': 'tag-1'},
      ],
      _ => throw ArgumentError.value(table, 'table'),
    };
  }
}
