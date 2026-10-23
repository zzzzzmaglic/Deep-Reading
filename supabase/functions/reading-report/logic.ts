export interface ReadingAssetRow {
  id: string;
  article_id: string | null;
  note_content: string | null;
  updated_at: string;
}

export interface AssetAnchorRow {
  asset_id: string;
  article_id: string;
}

export interface SelectedNote {
  assetId: string;
  content: string;
  characterCount: number;
  updatedAt: string;
}

const graphemeSegmenter = typeof Intl.Segmenter === "function"
  ? new Intl.Segmenter("zh", { granularity: "grapheme" })
  : null;

export function visibleCharacterCount(value: string): number {
  const trimmed = value.trim();
  if (!trimmed) return 0;
  return graphemeSegmenter
    ? [...graphemeSegmenter.segment(trimmed)].length
    : Array.from(trimmed).length;
}

export function selectLongestArticleNote(
  assets: ReadingAssetRow[],
  anchors: AssetAnchorRow[],
  articleId: string,
): SelectedNote | null {
  const anchoredArticleByAsset = new Map(
    anchors.map((anchor) => [anchor.asset_id, anchor.article_id]),
  );

  const candidates = assets.flatMap((asset): SelectedNote[] => {
    const associatedArticleId = asset.article_id ?? anchoredArticleByAsset.get(asset.id);
    const content = asset.note_content?.trim() ?? "";
    const characterCount = visibleCharacterCount(content);
    if (associatedArticleId !== articleId || characterCount === 0) return [];
    return [{
      assetId: asset.id,
      content,
      characterCount,
      updatedAt: asset.updated_at,
    }];
  });

  candidates.sort((lhs, rhs) => {
    if (lhs.characterCount !== rhs.characterCount) {
      return rhs.characterCount - lhs.characterCount;
    }
    const updatedOrder = Date.parse(rhs.updatedAt) - Date.parse(lhs.updatedAt);
    if (updatedOrder !== 0) return updatedOrder;
    return lhs.assetId.localeCompare(rhs.assetId);
  });
  return candidates[0] ?? null;
}
