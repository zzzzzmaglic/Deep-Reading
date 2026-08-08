import 'package:app/features/reader/domain/article.dart';
import 'package:app/features/reading_assets/data/reading_asset_repository.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'selection_to_anchor.dart';

export 'selection_to_anchor.dart';

abstract interface class ReaderSelectionAdapter {
  ReaderSelectionSession createSession({
    required Article article,
    required ValueChanged<ReaderSelection?> onSelectionChanged,
  });
}

typedef ReaderSelectionMenuBuilder =
    Widget Function(
      BuildContext context,
      ReaderSelection selection,
      TextSelectionToolbarAnchors anchors,
    );

abstract interface class ReaderSelectionSession {
  Widget wrap({
    required Widget child,
    required ReaderSelectionMenuBuilder contextMenuBuilder,
  });

  Widget wrapBlock({required ArticleBlock block, required Widget child});

  void clearSelection();

  void dispose();
}

class FlutterReaderSelectionAdapter implements ReaderSelectionAdapter {
  const FlutterReaderSelectionAdapter();

  @override
  ReaderSelectionSession createSession({
    required Article article,
    required ValueChanged<ReaderSelection?> onSelectionChanged,
  }) => _FlutterReaderSelectionSession(
    article: article,
    onSelectionChanged: onSelectionChanged,
  );
}

class _FlutterReaderSelectionSession implements ReaderSelectionSession {
  _FlutterReaderSelectionSession({
    required this.article,
    required this.onSelectionChanged,
  }) : _notifiers = {
         for (final block in article.blocks)
           block.id: SelectionListenerNotifier(),
       } {
    for (final notifier in _notifiers.values) {
      notifier.addListener(_emitSelection);
    }
  }

  final Article article;
  final ValueChanged<ReaderSelection?> onSelectionChanged;
  final GlobalKey<SelectionAreaState> _selectionAreaKey =
      GlobalKey<SelectionAreaState>();
  final Map<String, SelectionListenerNotifier> _notifiers;

  @override
  Widget wrap({
    required Widget child,
    required ReaderSelectionMenuBuilder contextMenuBuilder,
  }) {
    return SelectionArea(
      key: _selectionAreaKey,
      contextMenuBuilder: (context, selectableRegionState) {
        final selection = _currentSelection();
        if (selection == null) {
          return const SizedBox.shrink();
        }
        return contextMenuBuilder(
          context,
          selection,
          selectableRegionState.contextMenuAnchors,
        );
      },
      onSelectionChanged: (_) => _emitSelection(),
      child: child,
    );
  }

  @override
  Widget wrapBlock({required ArticleBlock block, required Widget child}) {
    final notifier = _notifiers[block.id];
    return notifier == null
        ? child
        : SelectionListener(selectionNotifier: notifier, child: child);
  }

  @override
  void clearSelection() {
    ContextMenuController.removeAny();
    final state = _selectionAreaKey.currentState;
    if (state != null) {
      state.selectableRegion.clearSelection();
    }
    onSelectionChanged(null);
  }

  @override
  void dispose() {
    for (final notifier in _notifiers.values) {
      notifier
        ..removeListener(_emitSelection)
        ..dispose();
    }
  }

  void _emitSelection() => onSelectionChanged(_currentSelection());

  ReaderSelection? _currentSelection() {
    final ranges = <ReaderBlockSelectionRange>[];
    for (final block in article.blocks) {
      final notifier = _notifiers[block.id]!;
      if (!notifier.registered ||
          notifier.selection.status != SelectionStatus.uncollapsed) {
        continue;
      }
      final range = notifier.selection.range;
      if (range != null) {
        ranges.add(
          ReaderBlockSelectionRange(
            blockId: block.id,
            startUtf16Offset: range.startOffset,
            endUtf16Offset: range.endOffset,
          ),
        );
      }
    }
    return readerSelectionFromBlockRanges(article, ranges);
  }
}

abstract interface class IosNativeSelectionAdapter
    implements ReaderSelectionAdapter {}

class ReaderSelectionController {
  ReaderSelectionController({required this.article, required this.repository});

  final Article article;
  final ReadingAssetRepository repository;

  Future<ReadingAsset> createHighlight(ReaderSelection selection) async {
    final anchor = selectionToAnchor(article, selection);
    return repository.createHighlightAsset(
      articleId: anchor.articleId,
      startBlockId: anchor.startBlockId,
      endBlockId: anchor.endBlockId,
      startUtf16Offset: anchor.startUtf16Offset,
      endUtf16Offset: anchor.endUtf16Offset,
      selectedText: anchor.selectedText,
      contentChecksum: anchor.contentChecksum,
    );
  }

  Future<List<ReadingAsset>> refreshAssets() =>
      repository.readAssets(articleId: article.id);
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
