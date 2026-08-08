import 'package:app/features/reader/domain/article.dart';
import 'package:app/features/reader/presentation/selection/reader_selection_adapter.dart';
import 'package:app/features/reader/presentation/selection/selection_to_anchor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selection offsets stay in Dart UTF-16 units for surrogate pairs', () {
    final article = _article([
      const ArticleBlock(
        id: 'b-1',
        articleId: 'article-1',
        position: 1,
        content: 'A😀BC',
      ),
    ]);

    final anchor = selectionToAnchor(
      article,
      const ReaderSelection(
        start: ReaderSelectionPoint(blockId: 'b-1', utf16Offset: 1),
        end: ReaderSelectionPoint(blockId: 'b-1', utf16Offset: 3),
        selectedText: '😀',
      ),
    );

    expect(anchor.startBlockId, 'b-1');
    expect(anchor.endBlockId, 'b-1');
    expect(anchor.startUtf16Offset, 1);
    expect(anchor.endUtf16Offset, 3);
    expect(anchor.selectedText, '😀');
  });

  test('cross-block selection produces stable block endpoints', () {
    final article = _article([
      const ArticleBlock(
        id: 'b-1',
        articleId: 'article-1',
        position: 1,
        content: 'First block',
      ),
      const ArticleBlock(
        id: 'b-2',
        articleId: 'article-1',
        position: 2,
        content: 'Second block',
      ),
    ]);

    final anchor = selectionToAnchor(
      article,
      const ReaderSelection(
        start: ReaderSelectionPoint(blockId: 'b-1', utf16Offset: 2),
        end: ReaderSelectionPoint(blockId: 'b-2', utf16Offset: 4),
        selectedText: 'rst blockSeco',
      ),
    );

    expect(anchor.startBlockId, 'b-1');
    expect(anchor.endBlockId, 'b-2');
    expect(anchor.startUtf16Offset, 2);
    expect(anchor.endUtf16Offset, 4);
    expect(anchor.contentChecksum, 'checksum-1');
  });

  test('block selection endpoints preserve a later repeated selection', () {
    final article = _article([
      const ArticleBlock(
        id: 'b-1',
        articleId: 'article-1',
        position: 1,
        content: 'same text',
      ),
      const ArticleBlock(
        id: 'b-2',
        articleId: 'article-1',
        position: 2,
        content: 'same text',
      ),
    ]);

    final selection = readerSelectionFromBlockRanges(article, const [
      ReaderBlockSelectionRange(
        blockId: 'b-2',
        startUtf16Offset: 0,
        endUtf16Offset: 4,
      ),
    ]);
    final anchor = selectionToAnchor(article, selection!);

    expect(anchor.startBlockId, 'b-2');
    expect(anchor.endBlockId, 'b-2');
    expect(anchor.startUtf16Offset, 0);
    expect(anchor.endUtf16Offset, 4);
    expect(anchor.selectedText, 'same');
  });

  test('block selection ranges preserve cross-block UTF-16 endpoints', () {
    final article = _article([
      const ArticleBlock(
        id: 'b-1',
        articleId: 'article-1',
        position: 1,
        content: 'A😀BC',
      ),
      const ArticleBlock(
        id: 'b-2',
        articleId: 'article-1',
        position: 2,
        content: 'D😀EF',
      ),
    ]);

    final selection = readerSelectionFromBlockRanges(article, const [
      ReaderBlockSelectionRange(
        blockId: 'b-1',
        startUtf16Offset: 1,
        endUtf16Offset: 5,
      ),
      ReaderBlockSelectionRange(
        blockId: 'b-2',
        startUtf16Offset: 0,
        endUtf16Offset: 3,
      ),
    ]);
    final anchor = selectionToAnchor(article, selection!);

    expect(anchor.startBlockId, 'b-1');
    expect(anchor.startUtf16Offset, 1);
    expect(anchor.endBlockId, 'b-2');
    expect(anchor.endUtf16Offset, 3);
    expect(anchor.selectedText, '😀BCD😀');
  });
}

Article _article(List<ArticleBlock> blocks) {
  return Article(
    id: 'article-1',
    title: 'Reader article',
    sourceName: 'Deep Reading',
    contentChecksum: 'checksum-1',
    blocks: blocks,
  );
}
