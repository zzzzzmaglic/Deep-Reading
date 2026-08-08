import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class ReadingAssetRepository {
  Future<ReadingAsset> createHighlightAsset({
    required String articleId,
    required String startBlockId,
    required String endBlockId,
    required int startUtf16Offset,
    required int endUtf16Offset,
    required String selectedText,
    required String contentChecksum,
  });

  Future<ReadingAsset> createStandaloneNote({required String noteContent});

  Future<ReadingAsset> updateReadingAsset({
    required String assetId,
    required String? noteContent,
  });

  Future<void> setAssetTags({
    required String assetId,
    required List<String> tagIds,
  });

  Future<void> deleteReadingAsset(String assetId);

  Future<void> upsertReadingProgress({
    required String articleId,
    required String? blockId,
    required int utf16Offset,
  });

  Future<List<ReadingAsset>> readAssets({String? articleId});

  Future<List<Tag>> readTags();

  Future<Tag> createTag({required String name});
}

abstract interface class ReadingAssetRemoteDataSource {
  Future<dynamic> callRpc(
    String functionName, {
    required Map<String, dynamic> parameters,
  });

  Future<List<Map<String, dynamic>>> readRows(String table);
}

class SupabaseReadingAssetRepository implements ReadingAssetRepository {
  SupabaseReadingAssetRepository(SupabaseClient client)
    : this._(_SupabaseReadingAssetRemoteDataSource(client));

  SupabaseReadingAssetRepository.forDataSource(
    ReadingAssetRemoteDataSource dataSource,
  ) : this._(dataSource);

  SupabaseReadingAssetRepository._(this._dataSource);

  final ReadingAssetRemoteDataSource _dataSource;

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
    final assetId =
        await _dataSource.callRpc(
              'create_highlight_asset',
              parameters: {
                'p_article_id': articleId,
                'p_start_block_id': startBlockId,
                'p_end_block_id': endBlockId,
                'p_start_utf16_offset': startUtf16Offset,
                'p_end_utf16_offset': endUtf16Offset,
                'p_selected_text': selectedText,
                'p_content_checksum': contentChecksum,
              },
            )
            as String;

    return _readAsset(assetId);
  }

  @override
  Future<ReadingAsset> createStandaloneNote({
    required String noteContent,
  }) async {
    final assetId =
        await _dataSource.callRpc(
              'create_standalone_note',
              parameters: {'p_note_content': noteContent},
            )
            as String;

    return _readAsset(assetId);
  }

  @override
  Future<ReadingAsset> updateReadingAsset({
    required String assetId,
    required String? noteContent,
  }) async {
    final updatedAssetId =
        await _dataSource.callRpc(
              'update_reading_asset',
              parameters: {
                'p_asset_id': assetId,
                'p_note_content': noteContent,
              },
            )
            as String;

    return _readAsset(updatedAssetId);
  }

  @override
  Future<void> setAssetTags({
    required String assetId,
    required List<String> tagIds,
  }) {
    return _dataSource.callRpc(
      'set_asset_tags',
      parameters: {'p_asset_id': assetId, 'p_tag_ids': tagIds},
    );
  }

  @override
  Future<void> deleteReadingAsset(String assetId) {
    return _dataSource.callRpc(
      'delete_reading_asset',
      parameters: {'p_asset_id': assetId},
    );
  }

  @override
  Future<void> upsertReadingProgress({
    required String articleId,
    required String? blockId,
    required int utf16Offset,
  }) {
    return _dataSource.callRpc(
      'upsert_reading_progress',
      parameters: {
        'p_article_id': articleId,
        'p_block_id': blockId,
        'p_utf16_offset': utf16Offset,
      },
    );
  }

  @override
  Future<List<ReadingAsset>> readAssets({String? articleId}) async {
    final assetRows = await _dataSource.readRows('reading_assets');
    final anchorRows = await _dataSource.readRows('asset_anchors');
    final tagRows = await _dataSource.readRows('tags');
    final assetTagRows = await _dataSource.readRows('asset_tags');

    final anchorsByAssetId = {
      for (final row in anchorRows)
        row['asset_id'] as String: _anchorFromJson(row),
    };
    final tagsById = {
      for (final row in tagRows) row['id'] as String: _tagFromJson(row),
    };
    final tagsByAssetId = <String, List<Tag>>{};
    for (final row in assetTagRows) {
      final tag = tagsById[row['tag_id'] as String];
      if (tag != null) {
        tagsByAssetId.putIfAbsent(row['asset_id'] as String, () => []).add(tag);
      }
    }

    return assetRows
        .map(
          (row) => _assetFromJson(
            row,
            anchor: anchorsByAssetId[row['id'] as String],
            tags: tagsByAssetId[row['id'] as String] ?? const [],
          ),
        )
        .where(
          (asset) => articleId == null || asset.anchor?.articleId == articleId,
        )
        .toList(growable: false);
  }

  @override
  Future<List<Tag>> readTags() async {
    final rows = await _dataSource.readRows('tags');
    return rows.map(_tagFromJson).toList(growable: false);
  }

  @override
  Future<Tag> createTag({required String name}) async {
    final tagId =
        await _dataSource.callRpc('create_tag', parameters: {'p_name': name})
            as String;
    final tags = await readTags();
    return tags.firstWhere(
      (tag) => tag.id == tagId,
      orElse: () => throw StateError('RPC returned an unreadable tag.'),
    );
  }

  Future<ReadingAsset> _readAsset(String assetId) async {
    final assets = await readAssets();
    return assets.firstWhere(
      (asset) => asset.id == assetId,
      orElse: () => throw StateError('RPC returned an unreadable asset.'),
    );
  }

  TextAnchor _anchorFromJson(Map<String, dynamic> json) {
    return TextAnchor(
      id: json['id'] as String,
      assetId: json['asset_id'] as String,
      articleId: json['article_id'] as String,
      startBlockId: json['start_block_id'] as String,
      endBlockId: json['end_block_id'] as String,
      startUtf16Offset: json['start_utf16_offset'] as int,
      endUtf16Offset: json['end_utf16_offset'] as int,
      selectedText: json['selected_text'] as String,
      contentChecksum: json['content_checksum'] as String,
    );
  }

  Tag _tagFromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      isSystem: json['is_system'] as bool,
    );
  }

  ReadingAsset _assetFromJson(
    Map<String, dynamic> json, {
    required TextAnchor? anchor,
    required List<Tag> tags,
  }) {
    return ReadingAsset(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      anchor: anchor,
      noteContent: json['note_content'] as String?,
      tags: List.unmodifiable(tags),
    );
  }
}

class _SupabaseReadingAssetRemoteDataSource
    implements ReadingAssetRemoteDataSource {
  _SupabaseReadingAssetRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<dynamic> callRpc(
    String functionName, {
    required Map<String, dynamic> parameters,
  }) {
    return _client.rpc(functionName, params: parameters);
  }

  @override
  Future<List<Map<String, dynamic>>> readRows(String table) async {
    final response = await _client.from(table).select();
    return (response as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }
}
