import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'article-scoped reads include only matching anchors and standalone notes',
    () async {
      final repository = SupabaseReadingAssetRepository.forDataSource(
        _ScopedAssetDataSource(),
      );

      final assets = await repository.readAssets(articleId: 'article-1');

      expect(assets.map((asset) => asset.id), ['anchored-1', 'note-1']);
    },
  );

  test(
    'reader standalone creation sends its nullable article association',
    () async {
      final dataSource = _ScopedAssetDataSource();
      final repository = SupabaseReadingAssetRepository.forDataSource(
        dataSource,
      );

      await repository.createStandaloneNoteWithTags(
        articleId: 'article-1',
        noteContent: 'Reader note',
        tagIds: const [],
      );
      await repository.createStandaloneNoteWithTags(
        noteContent: 'Global note',
        tagIds: const [],
      );

      expect(dataSource.calls, [
        ('create_standalone_note_with_tags', 'article-1'),
        ('create_standalone_note_with_tags', null),
      ]);
    },
  );
}

class _ScopedAssetDataSource implements ReadingAssetRemoteDataSource {
  final List<(String, String?)> calls = [];

  @override
  Future<dynamic> callRpc(
    String functionName, {
    required Map<String, dynamic> parameters,
  }) async {
    calls.add((functionName, parameters['p_article_id'] as String?));
    return 'note-1';
  }

  @override
  Future<List<Map<String, dynamic>>> readRows(String table) async {
    return switch (table) {
      'reading_assets' => [
        {
          'id': 'anchored-1',
          'owner_id': 'owner-1',
          'article_id': null,
          'note_content': null,
        },
        {
          'id': 'note-1',
          'owner_id': 'owner-1',
          'article_id': 'article-1',
          'note_content': 'Reader note',
        },
        {
          'id': 'global-1',
          'owner_id': 'owner-1',
          'article_id': null,
          'note_content': 'Global note',
        },
        {
          'id': 'note-2',
          'owner_id': 'owner-1',
          'article_id': 'article-2',
          'note_content': 'Other article note',
        },
      ],
      'asset_anchors' => [
        {
          'id': 'anchor-1',
          'asset_id': 'anchored-1',
          'article_id': 'article-1',
          'start_block_id': 'block-1',
          'end_block_id': 'block-1',
          'start_utf16_offset': 0,
          'end_utf16_offset': 8,
          'selected_text': 'Selected',
          'content_checksum': 'sha256:test',
        },
        {
          'id': 'anchor-2',
          'asset_id': 'note-2',
          'article_id': 'article-2',
          'start_block_id': 'block-2',
          'end_block_id': 'block-2',
          'start_utf16_offset': 0,
          'end_utf16_offset': 8,
          'selected_text': 'Other',
          'content_checksum': 'sha256:test',
        },
      ],
      'tags' => const [],
      'asset_tags' => const [],
      _ => throw ArgumentError.value(table, 'table'),
    };
  }
}
