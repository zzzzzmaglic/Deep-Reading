import 'dart:async';

import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReaderController extends ChangeNotifier {
  ReaderController({
    required this.articleId,
    ReadingAssetRepository? repository,
    bool Function()? isOnline,
    this.debounceDuration = const Duration(milliseconds: 350),
  }) : _repository = repository,
       _isOnline = isOnline ?? (() => false);

  final String articleId;
  final ReadingAssetRepository? _repository;
  final bool Function() _isOnline;
  final Duration debounceDuration;

  Timer? _progressTimer;
  ProgressPosition? _lastPosition;
  Object? _progressError;

  Object? get progressError => _progressError;
  bool get hasProgressError => _progressError != null;

  void updateProgress(String? blockId, int utf16Offset) {
    _lastPosition = ProgressPosition(
      blockId: blockId,
      utf16Offset: utf16Offset,
    );
    _progressTimer?.cancel();
    _progressTimer = Timer(debounceDuration, () {
      unawaited(_flushProgress());
    });
  }

  void retryProgress() {
    if (_lastPosition == null) {
      return;
    }
    _progressTimer?.cancel();
    _progressTimer = Timer(Duration.zero, () {
      unawaited(_flushProgress());
    });
  }

  Future<void> _flushProgress() async {
    final position = _lastPosition;
    final repository = _repository;
    if (position == null || repository == null) {
      return;
    }
    if (!_isOnline()) {
      _progressError = const ReaderOfflineProgressException();
      notifyListeners();
      return;
    }

    try {
      await repository.upsertReadingProgress(
        articleId: articleId,
        blockId: position.blockId,
        utf16Offset: position.utf16Offset,
      );
      _progressError = null;
      notifyListeners();
    } catch (error) {
      _progressError = error;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }
}

class ProgressPosition {
  const ProgressPosition({required this.blockId, required this.utf16Offset});

  final String? blockId;
  final int utf16Offset;
}

class SupabaseReaderProgressReader {
  const SupabaseReaderProgressReader(this.client);

  final SupabaseClient client;

  Future<ProgressPosition?> read(String articleId) async {
    final row = await client
        .from('reading_progress')
        .select('block_id, utf16_offset')
        .eq('article_id', articleId)
        .maybeSingle();
    if (row == null) {
      return null;
    }
    return ProgressPosition(
      blockId: row['block_id'] as String?,
      utf16Offset: row['utf16_offset'] as int,
    );
  }
}

class ReaderOfflineProgressException implements Exception {
  const ReaderOfflineProgressException();

  @override
  String toString() => 'Reading progress is waiting for a network connection.';
}
