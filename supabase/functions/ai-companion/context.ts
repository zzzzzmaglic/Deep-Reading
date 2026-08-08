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

const MAX_FULL_ARTICLE_BLOCKS = 12;
const MAX_CONTEXT_CHARS = 12_000;
const NEIGHBOUR_BLOCKS = 1;

function formatBlock(block: ArticleBlock): string {
  return `[Block ${block.position} | ${block.id}]\n${block.content.trim()}`;
}

function joinWithinLimit(blocks: ArticleBlock[]): string {
  const context = blocks.map(formatBlock).join("\n\n");
  return context.length <= MAX_CONTEXT_CHARS
    ? context
    : `${context.slice(0, MAX_CONTEXT_CHARS - 16)}\n[Context capped]`;
}

export function buildArticleContext(
  articleBlocks: ArticleBlock[],
  anchor?: ArticleAnchor,
): string {
  const blocks = [...articleBlocks].sort((left, right) => left.position - right.position);
  if (blocks.length === 0) {
    return "";
  }

  const fullContext = blocks.map(formatBlock).join("\n\n");
  if (
    blocks.length <= MAX_FULL_ARTICLE_BLOCKS &&
    fullContext.length <= MAX_CONTEXT_CHARS
  ) {
    return fullContext;
  }

  const startBlockId = anchor?.startBlockId ?? anchor?.blockId;
  const endBlockId = anchor?.endBlockId ?? startBlockId;
  if (startBlockId && endBlockId) {
    const startIndex = blocks.findIndex((block) => block.id === startBlockId);
    const endIndex = blocks.findIndex((block) => block.id === endBlockId);
    if (startIndex < 0 || endIndex < 0) {
      throw new Error("anchor blocks must belong to the current article");
    }

    const lowerIndex = Math.min(startIndex, endIndex);
    const upperIndex = Math.max(startIndex, endIndex);
    return joinWithinLimit(
      blocks.slice(
        Math.max(0, lowerIndex - NEIGHBOUR_BLOCKS),
        Math.min(blocks.length, upperIndex + NEIGHBOUR_BLOCKS + 1),
      ),
    );
  }

  return joinWithinLimit(blocks.slice(0, MAX_FULL_ARTICLE_BLOCKS));
}
