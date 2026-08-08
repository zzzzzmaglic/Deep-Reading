import { buildArticleContext } from "./context.ts";
import { createAiCompanionHandler } from "./index.ts";

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

function assertEquals(actual: unknown, expected: unknown, message = "Values differ") {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  assert(actualJson === expectedJson, `${message}: ${actualJson} !== ${expectedJson}`);
}

const articleId = "10000000-0000-0000-0000-000000000001";
const userId = "66666666-6666-4666-8666-666666666666";

interface GatewayFixture {
  anonymous?: boolean;
  deepSeekStream?: string;
  reserveStatus?: number;
  reserveErrorCode?: string;
}

function gatewayFixture(fixture: GatewayFixture = {}) {
  const calls: Array<{
    url: string;
    authorization: string | null;
    body?: Record<string, unknown>;
  }> = [];
  const environment: Record<string, string> = {
    AI_ENABLED: "true",
    AI_GLOBAL_DAILY_TOKEN_BUDGET: "10000",
    AI_GLOBAL_WEEKLY_TOKEN_BUDGET: "20000",
    AI_MAX_OUTPUT_TOKENS: "100",
    AI_REQUESTS_PER_HOUR: "20",
    DEEPSEEK_API_KEY: "server-test-key",
    DEEPSEEK_MODEL: "DeepSeek-V4-Pro",
    SUPABASE_SERVICE_ROLE_KEY: "server-test-role",
    SUPABASE_URL: "http://supabase.test",
  };
  const handler = createAiCompanionHandler({
    env(name: string) {
      return environment[name];
    },
    fetch: async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      const body = typeof init?.body === "string"
        ? JSON.parse(init.body) as Record<string, unknown>
        : undefined;
      calls.push({
        url,
        authorization: new Headers(init?.headers).get("Authorization"),
        body,
      });

      if (url.endsWith("/auth/v1/user")) {
        return Response.json({
          id: userId,
          is_anonymous: fixture.anonymous ?? true,
        });
      }
      if (url.endsWith("/rest/v1/rpc/reserve_ai_companion_usage")) {
        if (fixture.reserveStatus) {
          return Response.json(
            { code: fixture.reserveErrorCode ?? "PRA03" },
            { status: fixture.reserveStatus },
          );
        }
        return Response.json([{
          reservation_id: "99999999-9999-4999-8999-999999999999",
          requests_per_hour: 20,
          daily_token_budget: 10000,
          weekly_token_budget: 20000,
        }]);
      }
      if (url.includes("/rest/v1/article_blocks")) {
        return Response.json(blocksOf(20));
      }
      if (url === "https://api.deepseek.com/chat/completions") {
        return new Response(fixture.deepSeekStream ?? "data: [DONE]\n\n", {
          headers: { "Content-Type": "text/event-stream" },
        });
      }
      if (url.endsWith("/rest/v1/rpc/settle_ai_companion_usage")) {
        return Response.json([{ outcome: body?.p_outcome ?? null }]);
      }
      throw new Error(`Unexpected fetch: ${url}`);
    },
    log() {},
    now: () => 1_700_000_000_000,
    randomUUID: () => "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
  });
  return { calls, handler };
}

function companionRequest(
  requestType = "question",
  anchor?: Record<string, string>,
) {
  return new Request("http://localhost/functions/v1/ai-companion", {
    method: "POST",
    headers: {
      Authorization: "Bearer anonymous-jwt",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ articleId, requestType, question: "Explain this", anchor }),
  });
}

async function responseEvents(response: Response) {
  const text = await response.text();
  return text.trim().split(/\r?\n\r?\n/).filter(Boolean).map((event) => {
    const lines = event.split(/\r?\n/);
    return {
      event: lines.find((line) => line.startsWith("event:"))?.slice(6).trim(),
      data: JSON.parse(lines.find((line) => line.startsWith("data:"))?.slice(5) ?? "null"),
    };
  });
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

Deno.test("large multi-block context preserves both anchor edges and neighbours", () => {
  const blocks = blocksOf(20).map((block) => ({
    ...block,
    content: `${block.content}:${"x".repeat(3_000)}`,
  }));
  const context = buildArticleContext(blocks, {
    startBlockId: "id-8",
    endBlockId: "id-12",
  });

  for (const index of [7, 8, 12, 13]) {
    assert(context.includes(`block-${index}:`), `context omitted block-${index}`);
  }
  assert(!context.includes("block-6:"));
  assert(!context.includes("block-14:"));
  assert(context.length <= 12_000);
});

Deno.test("selection explanations reject a missing anchor before external calls", async () => {
  const { calls, handler } = gatewayFixture();
  const events = await responseEvents(await handler(companionRequest("selection_explain")));

  assertEquals(events.map((event) => event.event), ["error"]);
  assertEquals(events[0].data.code, "invalid_anchor");
  assertEquals(calls, []);
});

Deno.test("non-anonymous callers are rejected before reservation and model calls", async () => {
  const { calls, handler } = gatewayFixture({ anonymous: false });
  const events = await responseEvents(await handler(companionRequest()));

  assertEquals(events.map((event) => event.event), ["error"]);
  assertEquals(events[0].data.code, "anonymous_auth_required");
  assert(!calls.some((call) => call.url.includes("reserve_ai_companion_usage")));
  assert(!calls.some((call) => call.url.includes("api.deepseek.com")));
});

Deno.test("upstream EOF without DONE emits error and settles unknown usage", async () => {
  const { calls, handler } = gatewayFixture({
    deepSeekStream: 'data: {"choices":[{"delta":{"content":"partial"}}]}\n\n',
  });
  const events = await responseEvents(await handler(companionRequest()));

  assertEquals(events.map((event) => event.event), ["started", "delta", "error"]);
  assertEquals(events.at(-1)?.data.code, "upstream_incomplete_stream");
  const settlement = calls.find((call) => call.url.includes("settle_ai_companion_usage"));
  assertEquals(settlement?.body?.p_actual_output_tokens, null);
  assertEquals(settlement?.body?.p_outcome, "upstream_error");
});

Deno.test("malformed and in-band upstream errors never emit completed", async () => {
  const streams = [
    "data: not-json\n\n",
    'data: {"error":{"message":"provider failed"}}\n\n',
  ];
  for (const deepSeekStream of streams) {
    const { handler } = gatewayFixture({ deepSeekStream });
    const events = await responseEvents(await handler(companionRequest()));
    assert(!events.some((event) => event.event === "completed"));
    assertEquals(events.at(-1)?.event, "error");
  }
});

Deno.test("validated DONE emits completed and settles known usage", async () => {
  const { calls, handler } = gatewayFixture({
    deepSeekStream: [
      'data: {"choices":[{"delta":{"content":"answer"}}]}',
      'data: {"choices":[],"usage":{"completion_tokens":7}}',
      "data: [DONE]",
      "",
    ].join("\n\n"),
  });
  const events = await responseEvents(await handler(companionRequest()));

  assertEquals(events.map((event) => event.event), ["started", "delta", "completed"]);
  const settlement = calls.find((call) => call.url.includes("settle_ai_companion_usage"));
  assertEquals(settlement?.body?.p_actual_output_tokens, 7);
  assertEquals(settlement?.body?.p_outcome, "completed");
});

Deno.test("a rejected durable reservation never calls DeepSeek", async () => {
  const { calls, handler } = gatewayFixture({
    reserveStatus: 400,
    reserveErrorCode: "PRA03",
  });
  const events = await responseEvents(await handler(companionRequest()));

  assertEquals(events.map((event) => event.event), ["error"]);
  assertEquals(events[0].data.code, "global_daily_budget");
  assert(!calls.some((call) => call.url.includes("api.deepseek.com")));
});

Deno.test("server-side article loading keeps the caller JWT as bearer auth", async () => {
  const { calls, handler } = gatewayFixture();
  await responseEvents(await handler(companionRequest()));

  const articleCall = calls.find((call) => call.url.includes("/rest/v1/article_blocks"));
  assertEquals(articleCall?.authorization, "Bearer anonymous-jwt");
});
