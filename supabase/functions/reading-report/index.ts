import { selectLongestArticleNote, type AssetAnchorRow, type ReadingAssetRow } from "./logic.ts";
import {
  ANALYSIS_MAX_TOKENS,
  buildAnalysisSystem,
  buildAnalysisUser,
  buildWritingRequest,
  chooseAnalysisOptions,
  DEEPSEEK_MODEL,
  parseAndValidateAnalysis,
  RESERVED_OUTPUT_TOKENS,
  shanghaiProfile,
  validateReportBody,
  WRITING_MAX_TOKENS,
} from "./pipeline.ts";

const DEEPSEEK_URL = "https://api.deepseek.com/chat/completions";
const NO_NOTE_MESSAGE = "当前没有可用于生成阅读报告的笔记。";
const BODY_LIMIT = 4_096;
const REQUEST_TIMEOUT_MS = 120_000;
const USAGE_LIMITS_ENV = "READING_REPORT_USAGE_LIMITS_ENABLED";
const WRITING_PROMPT_CAPTURE_ENV = "READING_REPORT_CAPTURE_WRITING_PROMPT";

const articleFiles: Record<string, string> = {
  "10000000-0000-0000-0000-000000000001": "10000000-0000-0000-0000-000000000001.txt",
  "10000000-0000-0000-0000-000000000004": "10000000-0000-0000-0000-000000000004.txt",
  "10000000-0000-0000-0000-000000000005": "10000000-0000-0000-0000-000000000005.txt",
  "10000000-0000-0000-0000-000000000006": "10000000-0000-0000-0000-000000000006.txt",
};

const focusMinutes: Record<string, number> = {
  "10000000-0000-0000-0000-000000000001": 40,
  "10000000-0000-0000-0000-000000000004": 20,
  "10000000-0000-0000-0000-000000000005": 10,
  "10000000-0000-0000-0000-000000000006": 36,
};

interface AuthUser { id: string; is_anonymous?: boolean }
interface ArticleRow { id: string; title: string }
interface Reservation {
  reservation_id: string;
  requests_per_hour: number;
  daily_token_budget: number;
  weekly_token_budget: number;
}
interface ChatResponse {
  choices?: Array<{ message?: { content?: string | null }; finish_reason?: string | null }>;
  usage?: { completion_tokens?: number | null };
  error?: { message?: string };
}

type Outcome = "completed" | "cancelled" | "upstream_error";

export interface ReadingReportDependencies {
  env(name: string): string | undefined;
  fetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response>;
  now(): Date;
  random(): number;
  readArticle(articleId: string): Promise<string>;
  log(fields: Record<string, unknown>): void;
}

class ReportError extends Error {
  constructor(readonly code: string, readonly status: number) { super(code); }
}

const corsHeaders = {
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Origin": "*",
  "Content-Type": "application/json; charset=utf-8",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

function requireEnv(dependencies: ReadingReportDependencies, name: string): string {
  const value = dependencies.env(name)?.trim();
  if (!value) throw new ReportError("server_misconfigured", 503);
  return value;
}

function shouldCaptureWritingPrompt(dependencies: ReadingReportDependencies): boolean {
  const configured = dependencies.env(WRITING_PROMPT_CAPTURE_ENV)?.trim().toLowerCase();
  if (configured !== undefined) return configured === "true";
  try {
    const hostname = new URL(dependencies.env("SUPABASE_URL") ?? "").hostname;
    return hostname === "kong" || hostname === "localhost" || hostname === "127.0.0.1";
  } catch {
    return false;
  }
}

function captureWritingPrompt(
  dependencies: ReadingReportDependencies,
  articleId: string,
  captureId: string,
  system: string,
  user: string,
): void {
  if (!shouldCaptureWritingPrompt(dependencies)) return;
  dependencies.log({
    event: "reading_report_writing_prompt_capture",
    capturedAt: dependencies.now().toISOString(),
    captureId,
    articleId,
    request: {
      model: DEEPSEEK_MODEL,
      stream: false,
      thinking: { type: "disabled" },
      temperature: 0.85,
      max_tokens: WRITING_MAX_TOKENS,
      messages: [{ role: "system", content: system }, { role: "user", content: user }],
    },
  });
}

async function parseArticleId(request: Request): Promise<string> {
  const text = await request.text();
  if (text.length > BODY_LIMIT) throw new ReportError("request_too_large", 413);
  let value: unknown;
  try { value = JSON.parse(text); } catch { throw new ReportError("invalid_json", 400); }
  const articleId = value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>).articleId
    : undefined;
  if (typeof articleId !== "string" || !articleFiles[articleId]) {
    throw new ReportError("invalid_article_id", 400);
  }
  return articleId;
}

async function readJson<T>(response: Response, code: string): Promise<T> {
  if (!response.ok) throw new ReportError(code, response.status >= 400 && response.status < 500 ? response.status : 502);
  return await response.json() as T;
}

async function chat(
  dependencies: ReadingReportDependencies,
  apiKey: string,
  system: string,
  user: string,
  temperature: number,
  maxTokens: number,
): Promise<{ content: string; outputTokens: number }> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await dependencies.fetch(DEEPSEEK_URL, {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: DEEPSEEK_MODEL,
        stream: false,
        thinking: { type: "disabled" },
        temperature,
        max_tokens: maxTokens,
        messages: [{ role: "system", content: system }, { role: "user", content: user }],
      }),
      signal: controller.signal,
    });
    const payload = await response.json().catch(() => ({})) as ChatResponse;
    if (!response.ok) throw new ReportError(response.status === 429 ? "upstream_rate_limited" : "upstream_error", response.status === 429 ? 429 : 502);
    const content = payload.choices?.[0]?.message?.content?.trim();
    if (!content || payload.choices?.[0]?.finish_reason === "length") throw new ReportError("upstream_invalid_output", 502);
    return { content, outputTokens: payload.usage?.completion_tokens ?? maxTokens };
  } catch (error) {
    if (error instanceof ReportError) throw error;
    if (controller.signal.aborted) throw new ReportError("upstream_timeout", 504);
    throw new ReportError("upstream_error", 502);
  } finally {
    clearTimeout(timeout);
  }
}

export function createReadingReportHandler(
  overrides: Partial<ReadingReportDependencies> = {},
): (request: Request) => Promise<Response> {
  const hasArticleOverride = overrides.readArticle !== undefined;
  const dependencies: ReadingReportDependencies = {
    env: (name) => Deno.env.get(name),
    fetch: (input, init) => fetch(input, init),
    now: () => new Date(),
    random: () => Math.random(),
    readArticle: async () => { throw new ReportError("full_article_unavailable", 503); },
    log: (fields) => console.log(JSON.stringify(fields)),
    ...overrides,
  };

  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (request.method !== "POST") return jsonResponse({ code: "method_not_allowed" }, 405);
    const startedAt = Date.now();
    const promptCaptureId = crypto.randomUUID();
    let reservationId: string | null = null;
    let actualOutputTokens = 0;
    let authorization = "";
    let rpcHeaders: Record<string, string> | null = null;

    const settle = async (outcome: Outcome) => {
      if (!reservationId || !rpcHeaders) return;
      await dependencies.fetch(`${requireEnv(dependencies, "SUPABASE_URL")}/rest/v1/rpc/settle_ai_companion_usage`, {
        method: "POST",
        headers: rpcHeaders,
        body: JSON.stringify({
          p_reservation_id: reservationId,
          p_actual_output_tokens: Math.min(actualOutputTokens, RESERVED_OUTPUT_TOKENS),
          p_outcome: outcome,
        }),
      });
    };

    try {
      const articleId = await parseArticleId(request);
      authorization = request.headers.get("Authorization")?.trim() ?? "";
      if (!/^Bearer\s+\S+$/i.test(authorization)) throw new ReportError("unauthorized", 401);
      const supabaseUrl = requireEnv(dependencies, "SUPABASE_URL");
      const serviceRoleKey = requireEnv(dependencies, "SUPABASE_SERVICE_ROLE_KEY");
      // Keep the caller JWT in Authorization so PostgREST evaluates the same
      // owner-scoped RLS rules as the app. The server key is only the gateway
      // apikey; this also supports Supabase's newer non-JWT secret keys.
      const serviceHeaders = { apikey: serviceRoleKey, Authorization: authorization };
      rpcHeaders = { apikey: serviceRoleKey, Authorization: authorization, "Content-Type": "application/json" };

      const user = await readJson<AuthUser>(await dependencies.fetch(`${supabaseUrl}/auth/v1/user`, {
        headers: { apikey: serviceRoleKey, Authorization: authorization },
        signal: request.signal,
      }), "unauthorized");
      if (!user.id) throw new ReportError("unauthorized", 401);
      if (user.is_anonymous !== true) throw new ReportError("anonymous_auth_required", 403);

      const articleUrl = new URL(`${supabaseUrl}/rest/v1/articles`);
      articleUrl.searchParams.set("select", "id,title");
      articleUrl.searchParams.set("id", `eq.${articleId}`);
      const articles = await readJson<ArticleRow[]>(await dependencies.fetch(articleUrl, { headers: serviceHeaders, signal: request.signal }), "article_load_failed");
      if (!articles[0]) throw new ReportError("article_not_found", 404);

      const assetsUrl = new URL(`${supabaseUrl}/rest/v1/reading_assets`);
      assetsUrl.searchParams.set("select", "id,article_id,note_content,updated_at");
      assetsUrl.searchParams.set("owner_id", `eq.${user.id}`);
      const anchorsUrl = new URL(`${supabaseUrl}/rest/v1/asset_anchors`);
      anchorsUrl.searchParams.set("select", "asset_id,article_id");
      anchorsUrl.searchParams.set("owner_id", `eq.${user.id}`);
      const [assets, anchors] = await Promise.all([
        readJson<ReadingAssetRow[]>(await dependencies.fetch(assetsUrl, { headers: serviceHeaders, signal: request.signal }), "asset_load_failed"),
        readJson<AssetAnchorRow[]>(await dependencies.fetch(anchorsUrl, { headers: serviceHeaders, signal: request.signal }), "anchor_load_failed"),
      ]);
      const note = selectLongestArticleNote(assets, anchors, articleId);
      if (!note) {
        return jsonResponse({ status: "unavailable", message: NO_NOTE_MESSAGE });
      }

      let articleBody: string;
      if (hasArticleOverride) {
        articleBody = await dependencies.readArticle(articleId);
      } else {
        const fullTextUrl = new URL(`${supabaseUrl}/rest/v1/article_full_texts`);
        fullTextUrl.searchParams.set("select", "content");
        fullTextUrl.searchParams.set("article_id", `eq.${articleId}`);
        const rows = await readJson<Array<{ content: string }>>(
          await dependencies.fetch(fullTextUrl, { headers: serviceHeaders, signal: request.signal }),
          "full_article_load_failed",
        );
        articleBody = rows[0]?.content ?? "";
      }
      if (!articleBody.trim()) throw new ReportError("full_article_unavailable", 503);
      const apiKey = requireEnv(dependencies, "DEEPSEEK_API_KEY");

      // The current prototype is intentionally unlimited. Commercial builds can
      // opt back into the existing hourly/daily/weekly accounting explicitly.
      if (dependencies.env(USAGE_LIMITS_ENV)?.trim().toLowerCase() === "true") {
        const reserve = await dependencies.fetch(`${supabaseUrl}/rest/v1/rpc/reserve_ai_companion_usage`, {
          method: "POST",
          headers: rpcHeaders,
          body: JSON.stringify({ p_estimated_output_tokens: RESERVED_OUTPUT_TOKENS }),
          signal: request.signal,
        });
        if (!reserve.ok) {
          const failure = await reserve.json().catch(() => ({})) as { code?: string };
          const mapped: Record<string, [string, number]> = {
            PRA01: ["anonymous_auth_required", 403], PRA02: ["hourly_request_limit", 429],
            PRA03: ["global_daily_budget", 429], PRA04: ["global_weekly_budget", 429],
          };
          const [code, status] = mapped[failure.code ?? ""] ?? ["usage_reservation_failed", 502];
          throw new ReportError(code, status);
        }
        const reservationPayload = await reserve.json() as Reservation[] | Reservation;
        const reservation = Array.isArray(reservationPayload) ? reservationPayload[0] : reservationPayload;
        if (!reservation?.reservation_id) throw new ReportError("usage_reservation_failed", 502);
        reservationId = reservation.reservation_id;
      }

      const options = chooseAnalysisOptions(dependencies.random);
      const analysisSystem = buildAnalysisSystem();
      const analysisUser = buildAnalysisUser(articles[0].title, articleBody, note.content, options);
      const analysisChat = await chat(
        dependencies, apiKey, analysisSystem,
        analysisUser,
        0.2, ANALYSIS_MAX_TOKENS,
      );
      actualOutputTokens += analysisChat.outputTokens;
      let analysis: ReturnType<typeof parseAndValidateAnalysis>;
      try {
        analysis = parseAndValidateAnalysis(analysisChat.content, options);
      } catch (firstError) {
        dependencies.log({
          event: "reading_report_analysis_retry",
          attempt: 1,
          validation: firstError instanceof Error ? firstError.message : "unknown",
        });
        const retryChat = await chat(
          dependencies, apiKey, analysisSystem,
          analysisUser,
          0.2, ANALYSIS_MAX_TOKENS,
        );
        actualOutputTokens += retryChat.outputTokens;
        try {
          analysis = parseAndValidateAnalysis(retryChat.content, options);
        } catch (secondError) {
          dependencies.log({
            event: "reading_report_analysis_contract_failed",
            attempt: 2,
            validation: secondError instanceof Error ? secondError.message : "unknown",
          });
          throw new ReportError("analysis_contract_failed", 502);
        }
      }

      const writingRequest = buildWritingRequest(
        articles[0].title,
        articleBody,
        analysis,
        shanghaiProfile(focusMinutes[articleId] ?? 40, dependencies.now()),
        dependencies.random,
      );
      captureWritingPrompt(
        dependencies,
        articleId,
        promptCaptureId,
        writingRequest.system,
        writingRequest.user,
      );
      const writingChat = await chat(
        dependencies, apiKey, writingRequest.system,
        writingRequest.user,
        0.85, WRITING_MAX_TOKENS,
      );
      actualOutputTokens += writingChat.outputTokens;
      let body: string;
      try { body = validateReportBody(writingChat.content); }
      catch (error) {
        dependencies.log({
          event: "reading_report_contract_failed",
          stage: "writing",
          validation: error instanceof Error ? error.message : "unknown",
        });
        throw new ReportError("writing_contract_failed", 502);
      }
      await settle("completed");
      reservationId = null;
      dependencies.log({ event: "reading_report_completed", articleId, model: DEEPSEEK_MODEL, elapsedMs: Date.now() - startedAt, outputTokens: actualOutputTokens });
      return jsonResponse({ status: "generated", body });
    } catch (error) {
      try { await settle(request.signal.aborted ? "cancelled" : "upstream_error"); } catch { /* keep original failure */ }
      const reportError = error instanceof ReportError ? error : new ReportError("internal_error", 500);
      dependencies.log({ event: "reading_report_failed", code: reportError.code, elapsedMs: Date.now() - startedAt });
      return jsonResponse({ code: reportError.code }, reportError.status);
    }
  };
}

if (import.meta.main) Deno.serve(createReadingReportHandler());
