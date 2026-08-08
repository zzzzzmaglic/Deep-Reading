import 'package:app/features/reader/domain/article.dart';
import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:flutter/material.dart';

import 'selection_to_anchor.dart';

export 'selection_to_anchor.dart';

abstract interface class ReaderSelectionAdapter {
  Widget wrap({
    required Article article,
    required Widget child,
    required ValueChanged<ReaderSelection?> onSelectionChanged,
    required SelectableRegionContextMenuBuilder contextMenuBuilder,
  });
}

class FlutterReaderSelectionAdapter implements ReaderSelectionAdapter {
  const FlutterReaderSelectionAdapter();

  @override
  Widget wrap({
    required Article article,
    required Widget child,
    required ValueChanged<ReaderSelection?> onSelectionChanged,
    required SelectableRegionContextMenuBuilder contextMenuBuilder,
  }) {
    return SelectionArea(
      contextMenuBuilder: contextMenuBuilder,
      onSelectionChanged: (content) {
        onSelectionChanged(
          content == null
              ? null
              : readerSelectionFromPlainText(article, content.plainText),
        );
      },
      child: child,
    );
  }
}

abstract interface class IosNativeSelectionAdapter
    implements ReaderSelectionAdapter {}

class ReaderSelectionController {
  ReaderSelectionController({
    required this.article,
    required this.repository,
    required this.onAssetsChanged,
  });

  final Article article;
  final ReadingAssetRepository repository;
  final ValueChanged<List<ReadingAsset>> onAssetsChanged;

  Future<void> highlight(ReaderSelection selection) async {
    final anchor = selectionToAnchor(article, selection);
    await repository.createHighlightAsset(
      articleId: anchor.articleId,
      startBlockId: anchor.startBlockId,
      endBlockId: anchor.endBlockId,
      startUtf16Offset: anchor.startUtf16Offset,
      endUtf16Offset: anchor.endUtf16Offset,
      selectedText: anchor.selectedText,
      contentChecksum: anchor.contentChecksum,
    );
    final assets = await repository.readAssets(articleId: article.id);
    onAssetsChanged(assets);
  }
}

class ReaderAssetCardRequest {
  const ReaderAssetCardRequest({
    required this.articleId,
    required this.selection,
  });

  final String articleId;
  final ReaderSelection selection;
}

class ReaderAiExplanationRequest {
  const ReaderAiExplanationRequest({
    required this.articleId,
    required this.selection,
  });

  final String articleId;
  final ReaderSelection selection;
}

class ReaderStandaloneNoteDraftRequest {
  const ReaderStandaloneNoteDraftRequest({required this.articleId});

  final String articleId;
}
