import { type ArticleAnchor, type ArticleBlock, buildArticleContext } from "./context.ts";

const ALLOWED_REQUEST_TYPES = new Set(
  [
    "question",
    "selection_explain",
    "highlight_explain",
    "preset_term_explain",
  ] as const,
);
const DEEPSEEK_URL = "https://api.deepseek.com/chat/completions";
const MAX_BODY_CHARS = 32_000;
const MAX_QUESTION_CHARS = 2_000;
const DEFAULT_MAX_OUTPUT_TOKENS = 800;
const MAX_OUTPUT_TOKEN_CEILING = 4_096;
const DEFAULT_REQUESTS_PER_HOUR = 20;
const MAX_REQUESTS_PER_HOUR = 1_000;
const HOUR_MS = 60 * 60 * 1_000;

type RequestType =
  | "question"
  | "selection_explain"
  | "highlight_explain"
  | "preset_term_explain";

interface CompanionRequest {
  articleId: string;
  requestType: RequestType;
  question: string;
  anchor?: ArticleAnchor;
}

interface AuthUser {
  id: string;
  is_anonymous?: boolean;
}

interface RateWindow {
  count: number;
  startedAt: number;
}

interface UpstreamChunk {
  choices?: Array<{
    delta?: { content?: string | null; reasoning_content?: string | null };
    finish_reason?: string | null;
  }>;
  usage?: { completion_tokens?: number } | null;
}

class GatewayError extends Error {
  constructor(
    readonly code: string,
    readonly status: number,
    readonly budgetEvent: string,
  ) {
    super(code);
  }
}

const rateWindows = new Map<string, RateWindow>();
const encoder = new TextEncoder();

const corsHeaders = {
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Origin": "*",
};

const streamHeaders = {
  ...corsHeaders,
  "Cache-Control": "no-cache, no-transform",
  "Connection": "keep-alive",
  "Content-Type": "text/event-stream; charset=utf-8",
  "X-Accel-Buffering": "no",
};

function readBoundedInteger(
  name: string,
  fallback: number,
  ceiling: number,
): number {
  const parsed = Number.parseInt(Deno.env.get(name) ?? "", 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }
  return Math.min(parsed, ceiling);
}

function sseEvent(event: "started" | "delta" | "completed" | "error", data: unknown) {
  return encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

function errorResponse(error: GatewayError, requestId: string): Response {
  return new Response(sseEvent("error", { code: error.code, requestId }), {
    status: error.status,
    headers: streamHeaders,
  });
}

function logRequest(
  requestId: string,
  status: string,
  errorCode: string | null,
  startedAt: number,
  tokenCount: number,
  budgetEvent: string,
) {
  console.log(JSON.stringify({
    requestId,
    status,
    errorCode,
    elapsedMs: Date.now() - startedAt,
    tokenCount,
    budgetEvent,
  }));
}

function requireEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new GatewayError("server_misconfigured", 503, `missing_${name.toLowerCase()}`);
  }
  return value;
}

async function parseRequest(request: Request): Promise<CompanionRequest> {
  const bodyText = await request.text();
  if (bodyText.length > MAX_BODY_CHARS) {
    throw new GatewayError("request_too_large", 413, "request_rejected");
  }

  let body: Record<string, unknown>;
  try {
    const parsed = JSON.parse(bodyText);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("request body must be an object");
    }
    body = parsed as Record<string, unknown>;
  } catch {
    throw new GatewayError("invalid_json", 400, "request_rejected");
  }

  const articleId = typeof body.articleId === "string" ? body.articleId.trim() : "";
  const requestType = typeof body.requestType === "string" ? body.requestType : "";
  const question = typeof body.question === "string" ? body.question.trim() : "";
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(articleId)
  ) {
    throw new GatewayError("invalid_article_id", 400, "request_rejected");
  }
  if (!ALLOWED_REQUEST_TYPES.has(requestType as RequestType)) {
    throw new GatewayError("invalid_request_type", 400, "request_rejected");
  }
  if (!question || question.length > MAX_QUESTION_CHARS) {
    throw new GatewayError("invalid_question", 400, "request_rejected");
  }

  let anchor: ArticleAnchor | undefined;
  if (body.anchor !== undefined) {
    if (!body.anchor || typeof body.anchor !== "object" || Array.isArray(body.anchor)) {
      throw new GatewayError("invalid_anchor", 400, "request_rejected");
    }
    const rawAnchor = body.anchor as Record<string, unknown>;
    anchor = {
      blockId: typeof rawAnchor.blockId === "string" ? rawAnchor.blockId : undefined,
      startBlockId: typeof rawAnchor.startBlockId === "string" ? rawAnchor.startBlockId : undefined,
      endBlockId: typeof rawAnchor.endBlockId === "string" ? rawAnchor.endBlockId : undefined,
    };
    if (
      (!anchor.blockId && !anchor.startBlockId) ||
      (anchor.endBlockId && !anchor.startBlockId)
    ) {
      throw new GatewayError("invalid_anchor", 400, "request_rejected");
    }
  }

  return { articleId, requestType: requestType as RequestType, question, anchor };
}

async function authenticate(
  request: Request,
  supabaseUrl: string,
  serviceRoleKey: string,
): Promise<AuthUser> {
  const authorization = request.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ") || authorization.length <= 7) {
    throw new GatewayError("unauthorized", 401, "auth_rejected");
  }

  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      apikey: serviceRoleKey,
      Authorization: authorization,
    },
    signal: request.signal,
  });
  if (!response.ok) {
    throw new GatewayError("unauthorized", 401, "auth_rejected");
  }

  const user = await response.json() as AuthUser;
  if (!user.id) {
    throw new GatewayError("unauthorized", 401, "auth_rejected");
  }
  return user;
}

function consumeRateLimit(userId: string, requestsPerHour: number) {
  const now = Date.now();
  const current = rateWindows.get(userId);
  if (!current || now - current.startedAt >= HOUR_MS) {
    rateWindows.set(userId, { count: 1, startedAt: now });
    return;
  }
  if (current.count >= requestsPerHour) {
    throw new GatewayError("rate_limit_exceeded", 429, "hourly_limit_reached");
  }
  current.count += 1;
}

async function loadArticleBlocks(
  articleId: string,
  supabaseUrl: string,
  serviceRoleKey: string,
  signal: AbortSignal,
): Promise<ArticleBlock[]> {
  const url = new URL(`${supabaseUrl}/rest/v1/article_blocks`);
  url.searchParams.set("select", "id,position,content");
  url.searchParams.set("article_id", `eq.${articleId}`);
  url.searchParams.set("order", "position.asc");
  const response = await fetch(url, {
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
    },
    signal,
  });
  if (!response.ok) {
    throw new GatewayError("article_load_failed", 502, "article_lookup_failed");
  }
  const blocks = await response.json() as ArticleBlock[];
  if (blocks.length === 0) {
    throw new GatewayError("article_not_found", 404, "article_lookup_empty");
  }
  return blocks;
}

async function* upstreamData(body: ReadableStream<Uint8Array>) {
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  try {
    while (true) {
      const { done, value } = await reader.read();
      buffer += decoder.decode(value, { stream: !done });
      const events = buffer.split(/\r?\n\r?\n/);
      buffer = events.pop() ?? "";
      for (const event of events) {
        const data = event.split(/\r?\n/)
          .filter((line) => line.startsWith("data:"))
          .map((line) => line.slice(5).trimStart())
          .join("\n");
        if (data) {
          yield data;
        }
      }
      if (done) {
        if (buffer.startsWith("data:")) {
          yield buffer.slice(5).trim();
        }
        break;
      }
    }
  } finally {
    reader.releaseLock();
  }
}

function companionPrompt(request: CompanionRequest, articleContext: string): string {
  return [
    `Request type: ${request.requestType}`,
    `Question: ${request.question}`,
    "Current article context:",
    articleContext,
  ].join("\n\n");
}

async function handleRequest(request: Request): Promise<Response> {
  const requestId = crypto.randomUUID();
  const startedAt = Date.now();
  let tokenCount = 0;

  try {
    if (request.method !== "POST") {
      throw new GatewayError("method_not_allowed", 405, "request_rejected");
    }

    const supabaseUrl = requireEnvironment("SUPABASE_URL");
    const serviceRoleKey = requireEnvironment("SUPABASE_SERVICE_ROLE_KEY");
    if (Deno.env.get("AI_ENABLED")?.toLowerCase() !== "true") {
      throw new GatewayError("ai_disabled", 503, "feature_switch_disabled");
    }
    const deepSeekApiKey = requireEnvironment("DEEPSEEK_API_KEY");

    const companionRequest = await parseRequest(request);
    const user = await authenticate(request, supabaseUrl, serviceRoleKey);
    const requestsPerHour = readBoundedInteger(
      "AI_REQUESTS_PER_HOUR",
      DEFAULT_REQUESTS_PER_HOUR,
      MAX_REQUESTS_PER_HOUR,
    );
    consumeRateLimit(user.id, requestsPerHour);

    const articleBlocks = await loadArticleBlocks(
      companionRequest.articleId,
      supabaseUrl,
      serviceRoleKey,
      request.signal,
    );
    let articleContext: string;
    try {
      articleContext = buildArticleContext(articleBlocks, companionRequest.anchor);
    } catch {
      throw new GatewayError("invalid_anchor", 400, "request_rejected");
    }

    const maxOutputTokens = readBoundedInteger(
      "AI_MAX_OUTPUT_TOKENS",
      DEFAULT_MAX_OUTPUT_TOKENS,
      MAX_OUTPUT_TOKEN_CEILING,
    );
    const upstreamAbort = new AbortController();
    const abortUpstream = () => upstreamAbort.abort();
    request.signal.addEventListener("abort", abortUpstream, { once: true });

    const stream = new ReadableStream<Uint8Array>({
      async start(controller) {
        let completed = false;
        const enqueue = (event: "started" | "delta" | "completed" | "error", data: unknown) => {
          try {
            controller.enqueue(sseEvent(event, data));
            return true;
          } catch {
            upstreamAbort.abort();
            return false;
          }
        };

        enqueue("started", { requestId });
        try {
          const upstream = await fetch(DEEPSEEK_URL, {
            method: "POST",
            headers: {
              Authorization: `Bearer ${deepSeekApiKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              model: Deno.env.get("DEEPSEEK_MODEL")?.trim() || "DeepSeek-V4-Pro",
              stream: true,
              stream_options: { include_usage: true },
              thinking: { type: "disabled" },
              max_tokens: maxOutputTokens,
              messages: [
                {
                  role: "system",
                  content:
                    "Answer only from the supplied current-article context. Do not use internet or global knowledge. If the context is insufficient, say so briefly. Return only the answer, never hidden reasoning.",
                },
                {
                  role: "user",
                  content: companionPrompt(companionRequest, articleContext),
                },
              ],
            }),
            signal: upstreamAbort.signal,
          });
          if (!upstream.ok || !upstream.body) {
            throw new GatewayError(
              upstream.status === 429 ? "upstream_rate_limited" : "upstream_error",
              upstream.status === 429 ? 429 : 502,
              "upstream_rejected",
            );
          }

          for await (const data of upstreamData(upstream.body)) {
            if (data === "[DONE]") {
              break;
            }
            let chunk: UpstreamChunk;
            try {
              chunk = JSON.parse(data);
            } catch {
              throw new GatewayError("upstream_invalid_stream", 502, "upstream_parse_error");
            }
            tokenCount = chunk.usage?.completion_tokens ?? tokenCount;
            const content = chunk.choices?.[0]?.delta?.content;
            if (content && !enqueue("delta", { content })) {
              return;
            }
          }

          completed = enqueue("completed", { requestId, tokenCount });
          logRequest(requestId, "completed", null, startedAt, tokenCount, "within_limit");
        } catch (error) {
          const gatewayError = error instanceof GatewayError ? error : new GatewayError(
            upstreamAbort.signal.aborted ? "cancelled" : "upstream_error",
            upstreamAbort.signal.aborted ? 499 : 502,
            upstreamAbort.signal.aborted ? "cancelled" : "upstream_failed",
          );
          enqueue("error", { code: gatewayError.code, requestId });
          logRequest(
            requestId,
            "error",
            gatewayError.code,
            startedAt,
            tokenCount,
            gatewayError.budgetEvent,
          );
        } finally {
          request.signal.removeEventListener("abort", abortUpstream);
          if (completed || !request.signal.aborted) {
            try {
              controller.close();
            } catch {
              // The client may have already cancelled the stream.
            }
          }
        }
      },
      cancel() {
        upstreamAbort.abort();
        request.signal.removeEventListener("abort", abortUpstream);
      },
    });

    return new Response(stream, { headers: streamHeaders });
  } catch (error) {
    const gatewayError = error instanceof GatewayError
      ? error
      : new GatewayError("internal_error", 500, "request_failed");
    logRequest(
      requestId,
      "error",
      gatewayError.code,
      startedAt,
      tokenCount,
      gatewayError.budgetEvent,
    );
    return errorResponse(gatewayError, requestId);
  }
}

Deno.serve((request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  return handleRequest(request);
});
