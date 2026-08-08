import 'package:app/features/reader/domain/article.dart';
import 'package:app/features/reading_assets/domain/reading_asset.dart';

class ReaderSelectionPoint {
  const ReaderSelectionPoint({
    required this.blockId,
    required this.utf16Offset,
  });

  final String blockId;
  final int utf16Offset;

  @override
  bool operator ==(Object other) {
    return other is ReaderSelectionPoint &&
        other.blockId == blockId &&
        other.utf16Offset == utf16Offset;
  }

  @override
  int get hashCode => Object.hash(blockId, utf16Offset);
}

class ReaderSelection {
  const ReaderSelection({
    required this.start,
    required this.end,
    required this.selectedText,
  });

  final ReaderSelectionPoint start;
  final ReaderSelectionPoint end;
  final String selectedText;
}

TextAnchor selectionToAnchor(Article article, ReaderSelection selection) {
  final startBlock = _blockById(article, selection.start.blockId);
  final endBlock = _blockById(article, selection.end.blockId);
  _validateOffset(startBlock, selection.start.utf16Offset);
  _validateOffset(endBlock, selection.end.utf16Offset);

  final startPosition = article.blocks.indexOf(startBlock);
  final endPosition = article.blocks.indexOf(endBlock);
  if (startPosition > endPosition ||
      (startPosition == endPosition &&
          selection.start.utf16Offset > selection.end.utf16Offset)) {
    throw ArgumentError('Reader selections must be in document order.');
  }

  return TextAnchor(
    id: '',
    assetId: '',
    articleId: article.id,
    startBlockId: selection.start.blockId,
    endBlockId: selection.end.blockId,
    startUtf16Offset: selection.start.utf16Offset,
    endUtf16Offset: selection.end.utf16Offset,
    selectedText: selection.selectedText,
    contentChecksum: article.contentChecksum,
  );
}

ReaderSelection? readerSelectionFromPlainText(
  Article article,
  String selectedText,
) {
  if (selectedText.isEmpty) {
    return null;
  }

  for (var startIndex = 0; startIndex < article.blocks.length; startIndex++) {
    final startBlock = article.blocks[startIndex];
    for (
      var startOffset = 0;
      startOffset <= startBlock.content.length;
      startOffset++
    ) {
      for (
        var endIndex = startIndex;
        endIndex < article.blocks.length;
        endIndex++
      ) {
        final endBlock = article.blocks[endIndex];
        final endOffsetStart = endIndex == startIndex ? startOffset + 1 : 0;
        for (
          var endOffset = endOffsetStart;
          endOffset <= endBlock.content.length;
          endOffset++
        ) {
          final candidate = _selectionText(
            article,
            startIndex: startIndex,
            startOffset: startOffset,
            endIndex: endIndex,
            endOffset: endOffset,
          );
          if (candidate == selectedText) {
            return ReaderSelection(
              start: ReaderSelectionPoint(
                blockId: startBlock.id,
                utf16Offset: startOffset,
              ),
              end: ReaderSelectionPoint(
                blockId: endBlock.id,
                utf16Offset: endOffset,
              ),
              selectedText: selectedText,
            );
          }
        }
      }
    }
  }
  return null;
}

String _selectionText(
  Article article, {
  required int startIndex,
  required int startOffset,
  required int endIndex,
  required int endOffset,
}) {
  if (startIndex == endIndex) {
    return article.blocks[startIndex].content.substring(startOffset, endOffset);
  }
  final buffer = StringBuffer(
    article.blocks[startIndex].content.substring(startOffset),
  );
  for (var index = startIndex + 1; index < endIndex; index++) {
    buffer.write(article.blocks[index].content);
  }
  buffer.write(article.blocks[endIndex].content.substring(0, endOffset));
  return buffer.toString();
}

ArticleBlock _blockById(Article article, String blockId) {
  return article.blocks.firstWhere(
    (block) => block.id == blockId,
    orElse: () => throw ArgumentError('Unknown article block: $blockId'),
  );
}

void _validateOffset(ArticleBlock block, int offset) {
  if (offset < 0 || offset > block.content.length) {
    throw RangeError.range(offset, 0, block.content.length, 'utf16Offset');
  }
}
