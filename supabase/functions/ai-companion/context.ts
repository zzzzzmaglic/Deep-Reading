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
  const formatted = blocks.map(formatBlock);
  const context = formatted.join("\n\n");
  if (context.length <= MAX_CONTEXT_CHARS) {
    return context;
  }

  const headers = blocks.map((block) => `[Block ${block.position} | ${block.id}]\n`);
  const separatorChars = Math.max(0, blocks.length - 1) * 2;
  const availableContentChars = Math.max(
    0,
    MAX_CONTEXT_CHARS - separatorChars - headers.reduce((sum, header) => sum + header.length, 0),
  );
  const baseShare = Math.floor(availableContentChars / blocks.length);
  let remainder = availableContentChars % blocks.length;
  const boundedBlocks = blocks.map((block, index) => {
    const allowance = baseShare + (remainder-- > 0 ? 1 : 0);
    const content = block.content.trim();
    return `${headers[index]}${content.slice(0, allowance)}`;
  });
  return boundedBlocks.join("\n\n");
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
