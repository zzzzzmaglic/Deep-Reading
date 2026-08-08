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
const PRIORITY_CONTENT_CHARS = 64;

function formatHeader(block: ArticleBlock): string {
  return `[Block ${block.position} | ${block.id}]\n`;
}

function formatBlock(block: ArticleBlock): string {
  return `${formatHeader(block)}${block.content.trim()}`;
}

function joinWithinLimit(blocks: ArticleBlock[], priorityBlockIds: string[] = []): string {
  const formatted = blocks.map(formatBlock);
  const context = formatted.join("\n\n");
  if (context.length <= MAX_CONTEXT_CHARS) {
    return context;
  }

  const orderedPriorityIds = [...new Set(priorityBlockIds)];
  const priorityIds = new Set(orderedPriorityIds);
  const priorityBlocks = orderedPriorityIds
    .map((id) => blocks.find((block) => block.id === id))
    .filter((block): block is ArticleBlock => block !== undefined);
  const candidates = [
    ...priorityBlocks,
    ...blocks.filter((block) => !priorityIds.has(block.id)),
  ];
  const selected: ArticleBlock[] = [];
  let structuralChars = 0;
  let priorityContentChars = 0;

  for (const block of candidates) {
    const headerChars = formatHeader(block).length + (selected.length === 0 ? 0 : 2);
    const reservedContentChars = priorityIds.has(block.id)
      ? Math.min(PRIORITY_CONTENT_CHARS, block.content.trim().length)
      : 0;
    if (
      structuralChars + headerChars + priorityContentChars + reservedContentChars <=
        MAX_CONTEXT_CHARS
    ) {
      selected.push(block);
      structuralChars += headerChars;
      priorityContentChars += reservedContentChars;
    }
  }

  if (selected.length === 0) {
    return formatBlock(candidates[0]).slice(0, MAX_CONTEXT_CHARS);
  }

  selected.sort((left, right) => left.position - right.position);
  const allowances = new Map<string, number>();
  for (const block of selected) {
    allowances.set(
      block.id,
      priorityIds.has(block.id) ? Math.min(PRIORITY_CONTENT_CHARS, block.content.trim().length) : 0,
    );
  }

  let remaining = MAX_CONTEXT_CHARS - structuralChars - priorityContentChars;
  while (remaining > 0) {
    const expandable = selected.filter((block) =>
      (allowances.get(block.id) ?? 0) < block.content.trim().length
    );
    if (expandable.length === 0) {
      break;
    }
    const share = Math.max(1, Math.floor(remaining / expandable.length));
    let added = 0;
    for (const block of expandable) {
      const current = allowances.get(block.id) ?? 0;
      const increase = Math.min(share, block.content.trim().length - current, remaining - added);
      allowances.set(block.id, current + increase);
      added += increase;
      if (added === remaining) {
        break;
      }
    }
    if (added === 0) {
      break;
    }
    remaining -= added;
  }

  return selected.map((block) =>
    `${formatHeader(block)}${block.content.trim().slice(0, allowances.get(block.id) ?? 0)}`
  ).join("\n\n").slice(0, MAX_CONTEXT_CHARS);
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
    const neighbourhood = blocks.slice(
      Math.max(0, lowerIndex - NEIGHBOUR_BLOCKS),
      Math.min(blocks.length, upperIndex + NEIGHBOUR_BLOCKS + 1),
    );
    const priorityBlockIds = [
      blocks[lowerIndex]?.id,
      blocks[upperIndex]?.id,
      blocks[lowerIndex - NEIGHBOUR_BLOCKS]?.id,
      blocks[upperIndex + NEIGHBOUR_BLOCKS]?.id,
    ].filter((id): id is string => id !== undefined);
    return joinWithinLimit(neighbourhood, priorityBlockIds);
  }

  return joinWithinLimit(blocks.slice(0, MAX_FULL_ARTICLE_BLOCKS));
}
