import { createReadingReportHandler } from "./index.ts";

const articleId = "10000000-0000-0000-0000-000000000001";

function response(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), { status, headers: { "Content-Type": "application/json" } });
}

Deno.test("no non-empty note returns unavailable without calling DeepSeek", async () => {
  let calledDeepSeek = false;
  const handler = createReadingReportHandler({
    env: (name) => ({ SUPABASE_URL: "http://supabase.test", SUPABASE_SERVICE_ROLE_KEY: "service", DEEPSEEK_API_KEY: "secret" })[name],
    readArticle: async () => { throw new Error("must not load article"); },
    fetch: async (input) => {
      const url = String(input);
      if (url.includes("api.deepseek.com")) calledDeepSeek = true;
      if (url.endsWith("/auth/v1/user")) return response({ id: "user-1", is_anonymous: true });
      if (url.includes("/articles")) return response([{ id: articleId, title: "文章" }]);
      if (url.includes("/reading_assets")) return response([{ id: "asset-1", article_id: articleId, note_content: "  ", updated_at: "2026-10-22T00:00:00Z" }]);
      if (url.includes("/asset_anchors")) return response([]);
      throw new Error(`unexpected request ${url}`);
    },
    log: () => {},
  });
  const result = await handler(new Request("http://local/reading-report", {
    method: "POST",
    headers: { Authorization: "Bearer token" },
    body: JSON.stringify({ articleId }),
  }));
  const body = await result.json();
  if (result.status !== 200 || body.status !== "unavailable" || calledDeepSeek) {
    throw new Error("no-note path must not invoke the model");
  }
});

Deno.test("both calls are pinned to deepseek-flash and receive the full article", async () => {
  const chatBodies: Array<Record<string, unknown>> = [];
  let settled = false;
  const handler = createReadingReportHandler({
    env: (name) => ({
      SUPABASE_URL: "http://supabase.test",
      SUPABASE_SERVICE_ROLE_KEY: "service",
      DEEPSEEK_API_KEY: "secret",
      READING_REPORT_USAGE_LIMITS_ENABLED: "true",
    })[name],
    now: () => new Date("2026-10-22T04:00:00Z"),
    random: () => 0.9,
    readArticle: async () => "这是服务端保存的完整文章原文。",
    fetch: async (input, init) => {
      const url = String(input);
      if (url.includes("api.deepseek.com")) {
        const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
        chatBodies.push(body);
        if (chatBodies.length === 1) return response({ choices: [{ message: { content: JSON.stringify({
          level: 2, action: "理解",
          traces: [{ source: "用户笔记", content: "我重新理解了这个机制。" }],
          content_components: [
            { category: "认知结果", component: "改变结果", summary: "修正了原有判断。" },
            { category: "认知价值", component: "对认知成长方向的认可", summary: "让后续判断多了一个检查角度。" },
          ],
          认知展开: { 论述组织: { 切入对象: "改变结果", 认可方式: "跨度或变化体现分量" } },
        }) } }], usage: { completion_tokens: 120 } });
        return response({ choices: [{ message: { content: "你没有停在文章给出的结论上，而是把其中的机制放回自己的判断中重新检查。这个修正让原本笼统的认识多了一个可以核对的角度，也为以后面对相似问题时留下了更清楚的判断依据。" } }], usage: { completion_tokens: 80 } });
      }
      if (url.endsWith("/auth/v1/user")) return response({ id: "user-1", is_anonymous: true });
      if (url.includes("/articles")) return response([{ id: articleId, title: "文章" }]);
      if (url.includes("/reading_assets")) return response([{ id: "asset-1", article_id: articleId, note_content: "我重新理解了这个机制。", updated_at: "2026-10-22T00:00:00Z" }]);
      if (url.includes("/asset_anchors")) return response([]);
      if (url.includes("reserve_ai_companion_usage")) return response({ reservation_id: "reservation-1" });
      if (url.includes("settle_ai_companion_usage")) { settled = true; return response({}); }
      throw new Error(`unexpected request ${url}`);
    },
    log: () => {},
  });
  const result = await handler(new Request("http://local/reading-report", {
    method: "POST", headers: { Authorization: "Bearer token" }, body: JSON.stringify({ articleId }),
  }));
  const body = await result.json();
  if (body.status !== "generated" || chatBodies.length !== 2 || !settled) throw new Error(JSON.stringify(body));
  for (const chatBody of chatBodies) {
    if (chatBody.model !== "deepseek-flash") throw new Error("model is not pinned to deepseek-flash");
    const messages = chatBody.messages as Array<{ content: string }>;
    if (!messages[1].content.includes("这是服务端保存的完整文章原文。")) throw new Error("full article missing");
  }
  const analysisMessages = chatBodies[0].messages as Array<{ content: string }>;
  if (!analysisMessages[0].content.includes("## 单条笔记可识别的认知动作")) {
    throw new Error("original handoff analysis prompt was not used");
  }
  const writingMessages = chatBodies[1].messages as Array<{ content: string }>;
  if (
    writingMessages[1].content.includes('"traces"') ||
    /\{\{(?:REPORT_OPENING|COGNITIVE_ORGANIZATION|COGNITIVE_COMPONENTS)\}\}/.test(writingMessages[0].content)
  ) {
    throw new Error("handoff writing prompt was not fully assembled");
  }
});

Deno.test("invalid first analysis response is retried once with the same request", async () => {
  const chatBodies: Array<Record<string, unknown>> = [];
  const logs: Array<Record<string, unknown>> = [];
  let usageRpcCalled = false;
  const validAnalysis = JSON.stringify({
    level: 2,
    action: "理解",
    traces: [{ source: "用户笔记", content: "我重新理解了这个机制。" }],
    content_components: [
      { category: "认知结果", component: "改变结果", summary: "修正了原有判断。" },
      { category: "认知价值", component: "对认知成长方向的认可", summary: "让后续判断多了一个检查角度。" },
    ],
    认知展开: { 论述组织: { 切入对象: "改变结果", 认可方式: "跨度或变化体现分量" } },
  });
  const handler = createReadingReportHandler({
    env: (name) => ({
      SUPABASE_URL: "http://supabase.test",
      SUPABASE_SERVICE_ROLE_KEY: "service",
      DEEPSEEK_API_KEY: "secret",
      READING_REPORT_CAPTURE_WRITING_PROMPT: "true",
    })[name],
    now: () => new Date("2026-10-22T04:00:00Z"),
    random: () => 0.9,
    readArticle: async () => "这是服务端保存的完整文章原文。",
    fetch: async (input, init) => {
      const url = String(input);
      if (url.includes("api.deepseek.com")) {
        chatBodies.push(JSON.parse(String(init?.body)) as Record<string, unknown>);
        if (chatBodies.length === 1) {
          return response({ choices: [{ message: { content: "这不是 JSON" } }], usage: { completion_tokens: 6 } });
        }
        if (chatBodies.length === 2) {
          return response({ choices: [{ message: { content: validAnalysis } }], usage: { completion_tokens: 120 } });
        }
        return response({
          choices: [{ message: { content: "你重新检查了文章中的机制。\n原有判断因此得到修正。\n这为后续判断留下了清楚的核对角度。" } }],
          usage: { completion_tokens: 40 },
        });
      }
      if (url.endsWith("/auth/v1/user")) return response({ id: "user-1", is_anonymous: true });
      if (url.includes("/articles")) return response([{ id: articleId, title: "文章" }]);
      if (url.includes("/reading_assets")) return response([{ id: "asset-1", article_id: articleId, note_content: "我重新理解了这个机制。", updated_at: "2026-10-22T00:00:00Z" }]);
      if (url.includes("/asset_anchors")) return response([]);
      if (url.includes("_ai_companion_usage")) { usageRpcCalled = true; return response({}); }
      throw new Error(`unexpected request ${url}`);
    },
    log: (fields) => logs.push(fields),
  });

  const result = await handler(new Request("http://local/reading-report", {
    method: "POST",
    headers: { Authorization: "Bearer token" },
    body: JSON.stringify({ articleId }),
  }));
  const body = await result.json();
  if (result.status !== 200 || body.status !== "generated") throw new Error(JSON.stringify(body));
  if (chatBodies.length !== 3) throw new Error(`expected analysis retry plus writing call, got ${chatBodies.length}`);
  if (usageRpcCalled) throw new Error("prototype must not reserve or settle usage by default");

  const firstAnalysis = chatBodies[0];
  const retriedAnalysis = chatBodies[1];
  if (firstAnalysis.model !== "deepseek-flash" || retriedAnalysis.model !== "deepseek-flash") {
    throw new Error("analysis retry must remain pinned to deepseek-flash");
  }
  if (JSON.stringify(firstAnalysis.messages) !== JSON.stringify(retriedAnalysis.messages)) {
    throw new Error("analysis retry must reuse the exact same assembled prompt");
  }
  const captures = logs.filter((fields) => fields.event === "reading_report_writing_prompt_capture");
  if (captures.length !== 1) throw new Error(`expected one final writing prompt capture, got ${captures.length}`);
  const capturedRequest = captures[0].request as Record<string, unknown>;
  const capturedMessages = capturedRequest.messages as Array<{ role: string; content: string }>;
  if (capturedRequest.model !== "deepseek-flash" || capturedMessages.length !== 2) {
    throw new Error("the exact second-call request was not captured");
  }
  if (!capturedMessages[0].content.includes("正文恰好三段") || capturedMessages[0].content.includes("{{COGNITIVE_COMPONENTS}}")) {
    throw new Error("captured system prompt is not the final assembled writing prompt");
  }
  if (!capturedMessages[1].content.includes("这是服务端保存的完整文章原文。")) {
    throw new Error("captured user prompt does not contain the actual second-call input");
  }
});
