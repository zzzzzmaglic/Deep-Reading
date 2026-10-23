import {
  selectLongestArticleNote,
  visibleCharacterCount,
} from "./logic.ts";

const assertEquals = (actual: unknown, expected: unknown) => {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
};

Deno.test("counts trimmed user-visible characters including internal whitespace and punctuation", () => {
  assertEquals(visibleCharacterCount("  想法 A。\n  "), 6);
  assertEquals(visibleCharacterCount("  \n\t"), 0);
  assertEquals(visibleCharacterCount("👨‍👩‍👧‍👦"), 1);
});

Deno.test("selects the longest non-empty note and ignores highlight text", () => {
  const selected = selectLongestArticleNote(
    [
      {
        id: "asset-highlight",
        article_id: null,
        note_content: null,
        updated_at: "2026-10-22T10:00:00Z",
      },
      {
        id: "asset-linked-short",
        article_id: null,
        note_content: "短笔记",
        updated_at: "2026-10-22T10:00:00Z",
      },
      {
        id: "asset-standalone-long",
        article_id: "article-a",
        note_content: "这是字符数更多的一条独立型笔记。",
        updated_at: "2026-10-22T09:00:00Z",
      },
    ],
    [
      { asset_id: "asset-highlight", article_id: "article-a" },
      { asset_id: "asset-linked-short", article_id: "article-a" },
    ],
    "article-a",
  );

  assertEquals(selected?.assetId, "asset-standalone-long");
  assertEquals(selected?.content, "这是字符数更多的一条独立型笔记。");
});

Deno.test("ties choose the most recently edited note then stable asset id", () => {
  const selected = selectLongestArticleNote(
    [
      {
        id: "asset-b",
        article_id: "article-a",
        note_content: "同样长",
        updated_at: "2026-10-22T11:00:00Z",
      },
      {
        id: "asset-c",
        article_id: "article-a",
        note_content: "同样长",
        updated_at: "2026-10-22T12:00:00Z",
      },
      {
        id: "asset-a",
        article_id: "article-a",
        note_content: "同样长",
        updated_at: "2026-10-22T12:00:00Z",
      },
    ],
    [],
    "article-a",
  );

  assertEquals(selected?.assetId, "asset-a");
});
