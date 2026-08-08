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
}
