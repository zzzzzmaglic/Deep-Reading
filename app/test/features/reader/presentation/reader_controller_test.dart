import 'package:app/features/reader/presentation/reader_controller.dart';
import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'debounces progress writes and keeps the latest UTF-16 offset',
    () async {
      final repository = _RecordingReadingAssetRepository();
      final controller = ReaderController(
        articleId: 'article-1',
        repository: repository,
        connectivity: _FakeConnectivity(true),
        debounceDuration: const Duration(milliseconds: 5),
      );

      controller.updateProgress('block-1', 2);
      controller.updateProgress('block-2', 7);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repository.progressWrites, [
        const ProgressWrite(
          articleId: 'article-1',
          blockId: 'block-2',
          offset: 7,
        ),
      ]);
      controller.dispose();
    },
  );

  test(
    'offline progress is not queued and retry writes after connectivity returns',
    () async {
      final repository = _RecordingReadingAssetRepository();
      final connectivity = _FakeConnectivity(false);
      final controller = ReaderController(
        articleId: 'article-1',
        repository: repository,
        connectivity: connectivity,
        debounceDuration: const Duration(milliseconds: 5),
      );

      controller.updateProgress('block-1', 4);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repository.progressWrites, isEmpty);
      expect(controller.progressError, isA<ReaderOfflineProgressException>());

      connectivity.online = true;
      controller.retryProgress();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repository.progressWrites.single.offset, 4);
      expect(controller.progressError, isNull);
      controller.dispose();
    },
  );

  test(
    'failed online write exposes retryable error and retries the same position',
    () async {
      final repository = _RecordingReadingAssetRepository()
        ..failNextWrite = true;
      final controller = ReaderController(
        articleId: 'article-1',
        repository: repository,
        connectivity: _FakeConnectivity(true),
        debounceDuration: const Duration(milliseconds: 5),
      );

      controller.updateProgress('block-1', 9);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.progressError, isA<StateError>());

      controller.retryProgress();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repository.progressWrites.single.offset, 9);
      expect(controller.progressError, isNull);
      controller.dispose();
    },
  );

  test('route anchor position takes precedence over saved progress', () {
    final position = restoreReaderPosition(
      routeAnchor: const ProgressPosition(
        blockId: 'anchor-block',
        utf16Offset: 6,
      ),
      savedProgress: const ProgressPosition(
        blockId: 'saved-block',
        utf16Offset: 18,
      ),
    );

    expect(
      position,
      const ProgressPosition(blockId: 'anchor-block', utf16Offset: 6),
    );
  });

  test('saved progress preserves both block and UTF-16 offset', () {
    final position = restoreReaderPosition(
      routeAnchor: null,
      savedProgress: const ProgressPosition(
        blockId: 'saved-block',
        utf16Offset: 18,
      ),
    );

    expect(
      position,
      const ProgressPosition(blockId: 'saved-block', utf16Offset: 18),
    );
  });
}

class _FakeConnectivity implements ReaderConnectivityPort {
  _FakeConnectivity(this.online);

  bool online;

  @override
  Future<bool> get isOnline async => online;
}

class _RecordingReadingAssetRepository implements ReadingAssetRepository {
  final progressWrites = <ProgressWrite>[];
  bool failNextWrite = false;

  @override
  Future<void> upsertReadingProgress({
    required String articleId,
    required String? blockId,
    required int utf16Offset,
  }) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('temporary RPC failure');
    }
    progressWrites.add(
      ProgressWrite(
        articleId: articleId,
        blockId: blockId,
        offset: utf16Offset,
      ),
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
  Future<void> deleteReadingAsset(String assetId) => throw UnimplementedError();

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
  }) => throw UnimplementedError();

  @override
  Future<ReadingAsset> createStandaloneNoteWithTags({
    required String noteContent,
    required List<String> tagIds,
    String? articleId,
  }) => throw UnimplementedError();
}

class ProgressWrite {
  const ProgressWrite({
    required this.articleId,
    required this.blockId,
    required this.offset,
  });

  final String articleId;
  final String? blockId;
  final int offset;

  @override
  bool operator ==(Object other) {
    return other is ProgressWrite &&
        other.articleId == articleId &&
        other.blockId == blockId &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(articleId, blockId, offset);
}
