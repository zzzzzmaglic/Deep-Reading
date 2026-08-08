import { buildArticleContext } from "./context.ts";

function assert(condition: unknown, message = "Assertion failed"): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

function blocksOf(count: number) {
  return Array.from({ length: count }, (_, index) => ({
    id: `id-${index}`,
    position: index + 1,
    content: `block-${index}`,
  }));
}

function anchorAt(index: number) {
  return {
    startBlockId: `id-${index}`,
    endBlockId: `id-${index}`,
  };
}

Deno.test(
  "long article context contains the selected block and neighbours only",
  () => {
    const context = buildArticleContext(blocksOf(20), anchorAt(10));

    assert(context.includes("block-9"));
    assert(context.includes("block-10"));
    assert(context.includes("block-11"));
    assert(!context.includes("block-0"));
  },
);
