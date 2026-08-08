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
  bool operator ==(Object other) =>
      other is ReaderSelectionPoint &&
      other.blockId == blockId &&
      other.utf16Offset == utf16Offset;

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

class ReaderBlockSelectionRange {
  const ReaderBlockSelectionRange({
    required this.blockId,
    required this.startUtf16Offset,
    required this.endUtf16Offset,
  });

  final String blockId;
  final int startUtf16Offset;
  final int endUtf16Offset;
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
    selectedText: _selectionText(
      article,
      startIndex: startPosition,
      startOffset: selection.start.utf16Offset,
      endIndex: endPosition,
      endOffset: selection.end.utf16Offset,
    ),
    contentChecksum: article.contentChecksum,
  );
}

ReaderSelection? readerSelectionFromBlockRanges(
  Article article,
  Iterable<ReaderBlockSelectionRange> ranges,
) {
  final rangedBlocks = <_RangedBlock>[];
  for (final range in ranges) {
    final block = _blockById(article, range.blockId);
    _validateOffset(block, range.startUtf16Offset);
    _validateOffset(block, range.endUtf16Offset);
    final startOffset = range.startUtf16Offset < range.endUtf16Offset
        ? range.startUtf16Offset
        : range.endUtf16Offset;
    final endOffset = range.startUtf16Offset < range.endUtf16Offset
        ? range.endUtf16Offset
        : range.startUtf16Offset;
    if (startOffset != endOffset) {
      rangedBlocks.add(
        _RangedBlock(
          block: block,
          startOffset: startOffset,
          endOffset: endOffset,
        ),
      );
    }
  }
  if (rangedBlocks.isEmpty) {
    return null;
  }

  rangedBlocks.sort(
    (a, b) => article.blocks
        .indexOf(a.block)
        .compareTo(article.blocks.indexOf(b.block)),
  );
  final first = rangedBlocks.first;
  final last = rangedBlocks.last;
  final startIndex = article.blocks.indexOf(first.block);
  final endIndex = article.blocks.indexOf(last.block);
  return ReaderSelection(
    start: ReaderSelectionPoint(
      blockId: first.block.id,
      utf16Offset: first.startOffset,
    ),
    end: ReaderSelectionPoint(
      blockId: last.block.id,
      utf16Offset: last.endOffset,
    ),
    selectedText: _selectionText(
      article,
      startIndex: startIndex,
      startOffset: first.startOffset,
      endIndex: endIndex,
      endOffset: last.endOffset,
    ),
  );
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

class _RangedBlock {
  const _RangedBlock({
    required this.block,
    required this.startOffset,
    required this.endOffset,
  });

  final ArticleBlock block;
  final int startOffset;
  final int endOffset;
}
