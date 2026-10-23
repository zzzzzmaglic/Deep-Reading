export interface ArticleBlock {
  id: string;
  position: number;
  content: string;
}

export interface ArticleAnchor {
  blockId?: string;
  startBlockId?: string;
  endBlockId?: string;
}

function formatBlock(block: ArticleBlock): string {
  return `[Block ${block.position} | ${block.id}]\n${block.content.trim()}`;
}

/// AI 伴读的 Demo 合同要求每次请求都携带当前文章全文。锚点仍由
/// 网关校验，作为释义对象的结构化定位信息，但不再用于裁剪正文。
export function buildArticleContext(
  articleBlocks: ArticleBlock[],
  anchor?: ArticleAnchor,
): string {
  const blocks = [...articleBlocks].sort((left, right) => left.position - right.position);
  if (blocks.length === 0) return "";

  const referencedIds = [anchor?.blockId, anchor?.startBlockId, anchor?.endBlockId]
    .filter((id): id is string => Boolean(id));
  for (const id of referencedIds) {
    if (!blocks.some((block) => block.id === id)) {
      throw new Error("anchor blocks must belong to the current article");
    }
  }

  return blocks.map(formatBlock).join("\n\n");
}
