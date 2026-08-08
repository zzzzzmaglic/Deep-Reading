import { type ArticleAnchor, type ArticleBlock, buildArticleContext } from "./context.ts";

const ALLOWED_REQUEST_TYPES = new Set(
  [
    "question",
    "selection_explain",
    "highlight_explain",
    "preset_term_explain",
  ] as const,
);
const ANCHOR_REQUIRED_TYPES = new Set(["selection_explain", "highlight_explain"]);
const DEEPSEEK_URL = "https://api.deepseek.com/chat/completions";
const MAX_BODY_CHARS = 32_000;
const MAX_QUESTION_CHARS = 2_000;
const MAX_OUTPUT_TOKEN_CEILING = 4_096;

type RequestType =
  | "question"
  | "selection_explain"
  | "highlight_explain"
  | "preset_term_explain";
type SseEvent = "started" | "delta" | "completed" | "error";
type SettlementOutcome = "completed" | "cancelled" | "upstream_error";

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

interface Reservation {
  reservation_id: string;
  requests_per_hour: number;
  daily_token_budget: number;
  weekly_token_budget: number;
}

interface UpstreamChunk {
  choices?: Array<{ delta?: { content?: string | null; reasoning_content?: string | null } }>;
  usage?: { completion_tokens?: number } | null;
  error?: unknown;
}

interface GatewayLog {
  requestId: string;
  status: string;
  errorCode: string | null;
  elapsedMs: number;
  tokenCount: number | null;
  budgetEvent: string;
}

export interface GatewayDependencies {
  env(name: string): string | undefined;
  fetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response>;
  log(fields: GatewayLog): void;
  now(): number;
  randomUUID(): string;
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

function sseEvent(event: SseEvent, data: unknown) {
  return encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

function errorResponse(error: GatewayError, requestId: string): Response {
  return new Response(sseEvent("error", { code: error.code, requestId }), {
    status: error.status,
    headers: streamHeaders,
  });
}

function parsePositiveInteger(value: string | undefined, name: string, ceiling?: number): number {
  const parsed = Number.parseInt(value ?? "", 10);
  if (!Number.isSafeInteger(parsed) || parsed <= 0 || (ceiling !== undefined && parsed > ceiling)) {
    throw new GatewayError("server_misconfigured", 503, `invalid_${name.toLowerCase()}`);
  }
  return parsed;
}

function requireEnvironment(env: GatewayDependencies["env"], name: string): string {
  const value = env(name)?.trim();
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
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
      .test(articleId)
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
    if ((!anchor.blockId && !anchor.startBlockId) || (anchor.endBlockId && !anchor.startBlockId)) {
      throw new GatewayError("invalid_anchor", 400, "request_rejected");
    }
  }
  if (ANCHOR_REQUIRED_TYPES.has(requestType) && !anchor) {
    throw new GatewayError("invalid_anchor", 400, "request_rejected");
  }

  return { articleId, requestType: requestType as RequestType, question, anchor };
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

export function createAiCompanionHandler(
  overrides: Partial<GatewayDependencies> = {},
): (request: Request) => Promise<Response> {
  const dependencies: GatewayDependencies = {
    env: (name) => Deno.env.get(name),
    fetch: (input, init) => fetch(input, init),
    log: (fields) => console.log(JSON.stringify(fields)),
    now: () => Date.now(),
    randomUUID: () => crypto.randomUUID(),
    ...overrides,
  };

  return async function handleRequest(request: Request): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    const requestId = dependencies.randomUUID();
    const startedAt = dependencies.now();
    let tokenCount: number | null = null;
    const log = (status: string, errorCode: string | null, budgetEvent: string) => {
      dependencies.log({
        requestId,
        status,
        errorCode,
        elapsedMs: dependencies.now() - startedAt,
        tokenCount,
        budgetEvent,
      });
    };

    try {
      if (request.method !== "POST") {
        throw new GatewayError("method_not_allowed", 405, "request_rejected");
      }
      if (dependencies.env("AI_ENABLED")?.toLowerCase() !== "true") {
        throw new GatewayError("ai_disabled", 503, "feature_switch_disabled");
      }

      const supabaseUrl = requireEnvironment(dependencies.env, "SUPABASE_URL");
      const serviceRoleKey = requireEnvironment(dependencies.env, "SUPABASE_SERVICE_ROLE_KEY");
      const deepSeekApiKey = requireEnvironment(dependencies.env, "DEEPSEEK_API_KEY");
      const maxOutputTokens = parsePositiveInteger(
        dependencies.env("AI_MAX_OUTPUT_TOKENS"),
        "AI_MAX_OUTPUT_TOKENS",
        MAX_OUTPUT_TOKEN_CEILING,
      );
      const configuredRequestsPerHour = parsePositiveInteger(
        dependencies.env("AI_REQUESTS_PER_HOUR"),
        "AI_REQUESTS_PER_HOUR",
      );
      const configuredDailyBudget = parsePositiveInteger(
        dependencies.env("AI_GLOBAL_DAILY_TOKEN_BUDGET"),
        "AI_GLOBAL_DAILY_TOKEN_BUDGET",
      );
      const configuredWeeklyBudget = parsePositiveInteger(
        dependencies.env("AI_GLOBAL_WEEKLY_TOKEN_BUDGET"),
        "AI_GLOBAL_WEEKLY_TOKEN_BUDGET",
      );
      const companionRequest = await parseRequest(request);
      const authorization = request.headers.get("Authorization") ?? "";
      if (!authorization.startsWith("Bearer ") || authorization.length <= 7) {
        throw new GatewayError("unauthorized", 401, "auth_rejected");
      }

      const authResponse = await dependencies.fetch(`${supabaseUrl}/auth/v1/user`, {
        headers: { apikey: serviceRoleKey, Authorization: authorization },
        signal: request.signal,
      });
      if (!authResponse.ok) {
        throw new GatewayError("unauthorized", 401, "auth_rejected");
      }
      const user = await authResponse.json() as AuthUser;
      if (!user.id) {
        throw new GatewayError("unauthorized", 401, "auth_rejected");
      }
      if (user.is_anonymous !== true) {
        throw new GatewayError("anonymous_auth_required", 403, "auth_rejected");
      }

      const blocksUrl = new URL(`${supabaseUrl}/rest/v1/article_blocks`);
      blocksUrl.searchParams.set("select", "id,position,content");
      blocksUrl.searchParams.set("article_id", `eq.${companionRequest.articleId}`);
      blocksUrl.searchParams.set("order", "position.asc");
      const blocksResponse = await dependencies.fetch(blocksUrl, {
        headers: {
          apikey: serviceRoleKey,
          Authorization: authorization,
        },
        signal: request.signal,
      });
      if (!blocksResponse.ok) {
        throw new GatewayError("article_load_failed", 502, "article_lookup_failed");
      }
      const articleBlocks = await blocksResponse.json() as ArticleBlock[];
      if (articleBlocks.length === 0) {
        throw new GatewayError("article_not_found", 404, "article_lookup_empty");
      }
      let articleContext: string;
      try {
        articleContext = buildArticleContext(articleBlocks, companionRequest.anchor);
      } catch {
        throw new GatewayError("invalid_anchor", 400, "request_rejected");
      }

      const rpcHeaders = {
        apikey: serviceRoleKey,
        Authorization: authorization,
        "Content-Type": "application/json",
      };
      const reserveResponse = await dependencies.fetch(
        `${supabaseUrl}/rest/v1/rpc/reserve_ai_companion_usage`,
        {
          method: "POST",
          headers: rpcHeaders,
          body: JSON.stringify({ p_estimated_output_tokens: maxOutputTokens }),
          signal: request.signal,
        },
      );
      if (!reserveResponse.ok) {
        const failure = await reserveResponse.json().catch(() => ({})) as { code?: string };
        const mapped = {
          PRA01: ["anonymous_auth_required", "auth_rejected"],
          PRA02: ["hourly_request_limit", "hourly_limit_reached"],
          PRA03: ["global_daily_budget", "daily_budget_exhausted"],
          PRA04: ["global_weekly_budget", "weekly_budget_exhausted"],
        }[failure.code ?? ""];
        throw new GatewayError(
          mapped?.[0] ?? "usage_reservation_failed",
          429,
          mapped?.[1] ?? "reservation_failed",
        );
      }
      const reservationPayload = await reserveResponse.json() as Reservation[] | Reservation;
      const reservation = Array.isArray(reservationPayload)
        ? reservationPayload[0]
        : reservationPayload;
      if (!reservation?.reservation_id) {
        throw new GatewayError("usage_reservation_failed", 502, "reservation_invalid");
      }

      const settle = async (actualOutputTokens: number | null, outcome: SettlementOutcome) => {
        const response = await dependencies.fetch(
          `${supabaseUrl}/rest/v1/rpc/settle_ai_companion_usage`,
          {
            method: "POST",
            headers: rpcHeaders,
            body: JSON.stringify({
              p_reservation_id: reservation.reservation_id,
              p_actual_output_tokens: actualOutputTokens,
              p_outcome: outcome,
            }),
          },
        );
        if (!response.ok) {
          throw new GatewayError("usage_settlement_failed", 502, "settlement_failed");
        }
      };

      if (
        reservation.requests_per_hour !== configuredRequestsPerHour ||
        reservation.daily_token_budget !== configuredDailyBudget ||
        reservation.weekly_token_budget !== configuredWeeklyBudget
      ) {
        await settle(0, "upstream_error");
        throw new GatewayError("quota_config_mismatch", 503, "quota_config_mismatch");
      }

      const upstreamAbort = new AbortController();
      const abortUpstream = () => upstreamAbort.abort();
      request.signal.addEventListener("abort", abortUpstream, { once: true });
      const stream = new ReadableStream<Uint8Array>({
        async start(controller) {
          const enqueue = (event: SseEvent, data: unknown) => {
            try {
              controller.enqueue(sseEvent(event, data));
              return true;
            } catch {
              upstreamAbort.abort();
              return false;
            }
          };
          let outcome: SettlementOutcome = "upstream_error";
          let streamError: GatewayError | null = null;
          let sawDone = false;

          enqueue("started", { requestId });
          try {
            const upstream = await dependencies.fetch(DEEPSEEK_URL, {
              method: "POST",
              headers: {
                Authorization: `Bearer ${deepSeekApiKey}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                model: dependencies.env("DEEPSEEK_MODEL")?.trim() || "DeepSeek-V4-Pro",
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
                sawDone = true;
                break;
              }
              let chunk: UpstreamChunk;
              try {
                chunk = JSON.parse(data);
              } catch {
                throw new GatewayError("upstream_invalid_stream", 502, "upstream_parse_error");
              }
              if (chunk.error !== undefined) {
                throw new GatewayError("upstream_error", 502, "upstream_in_band_error");
              }
              tokenCount = chunk.usage?.completion_tokens ?? tokenCount;
              const content = chunk.choices?.[0]?.delta?.content;
              if (content && !enqueue("delta", { content })) {
                throw new GatewayError("cancelled", 499, "cancelled");
              }
            }
            if (!sawDone) {
              throw new GatewayError("upstream_incomplete_stream", 502, "upstream_missing_done");
            }
            outcome = "completed";
          } catch (error) {
            streamError = error instanceof GatewayError ? error : new GatewayError(
              upstreamAbort.signal.aborted ? "cancelled" : "upstream_error",
              upstreamAbort.signal.aborted ? 499 : 502,
              upstreamAbort.signal.aborted ? "cancelled" : "upstream_failed",
            );
            outcome = streamError.code === "cancelled" ? "cancelled" : "upstream_error";
          }

          try {
            await settle(tokenCount, outcome);
          } catch (error) {
            streamError = error instanceof GatewayError
              ? error
              : new GatewayError("usage_settlement_failed", 502, "settlement_failed");
          }

          if (streamError) {
            enqueue("error", { code: streamError.code, requestId });
            log("error", streamError.code, streamError.budgetEvent);
          } else if (sawDone) {
            enqueue("completed", { requestId, tokenCount });
            log("completed", null, "within_limit");
          }

          request.signal.removeEventListener("abort", abortUpstream);
          try {
            controller.close();
          } catch {
            // The client may have already cancelled the stream.
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
      log("error", gatewayError.code, gatewayError.budgetEvent);
      return errorResponse(gatewayError, requestId);
    }
  };
}

if (import.meta.main) {
  Deno.serve(createAiCompanionHandler());
}
