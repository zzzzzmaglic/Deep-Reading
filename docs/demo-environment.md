# Demo environment

## Anonymous authentication

The Demo uses Supabase anonymous users and accepts AI requests only when Supabase Auth returns
`is_anonymous = true`. Local anonymous sign-ins are enabled in `supabase/config.toml`. Enable the
same project setting in every hosted Demo environment.

Anonymous sign-in is not sufficient abuse protection on its own. Configure Supabase Auth CAPTCHA
with Cloudflare Turnstile (or another supported CAPTCHA provider) for the public Demo, keep the Auth
anonymous-user IP rate limit enabled, and verify the challenge on anonymous sign-in. The durable AI
limits described below apply after authentication.

## Server-only AI configuration

The `ai-companion` Edge Function requires these server-side values:

| Variable | Purpose | Demo example |
| --- | --- | --- |
| `SUPABASE_URL` | Supabase project URL; supplied automatically when hosted | `http://127.0.0.1:54321` |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-only article block reads and Auth validation | Local CLI service-role key |
| `DEEPSEEK_API_KEY` | Server-only DeepSeek credential | Set through function secrets |
| `DEEPSEEK_MODEL` | Streaming model name | `DeepSeek-V4-Pro` |
| `AI_ENABLED` | Deployment feature switch | `true` or `false` |
| `AI_MAX_OUTPUT_TOKENS` | Tokens reserved before each model call; maximum 4096 | `100` |
| `AI_REQUESTS_PER_HOUR` | Per-anonymous-user hourly request limit | `20` |
| `AI_GLOBAL_DAILY_TOKEN_BUDGET` | Shared daily completion-token budget | `10000` |
| `AI_GLOBAL_WEEKLY_TOKEN_BUDGET` | Shared weekly completion-token budget | `20000` |

Never place `SUPABASE_SERVICE_ROLE_KEY` or `DEEPSEEK_API_KEY` in Flutter defines, Appetize build
configuration, source control, screenshots, or client logs. Hosted values belong in Supabase Edge
Function secrets. Local values belong in `supabase/.env.local`, which is ignored by the tracked root
`.gitignore`.

## Durable quota policy

PostgreSQL is the source of truth for abuse control. `reserve_ai_companion_usage` atomically locks
the global week, global day, and anonymous-user hour counters in that stable order, checks all three
limits, and reserves the configured maximum output before DeepSeek is called.
`settle_ai_companion_usage` records known output usage and releases the unused reservation. When
usage is unavailable after cancellation or upstream failure, settlement charges the reserved
maximum conservatively.

The singleton `public.ai_usage_policy` row defaults to the Demo example values above. Update that row
through an administrator-only migration or SQL deployment step when changing quotas, and update the
three matching Edge Function environment variables in the same release. The gateway rejects a
reservation when database and environment quota values differ, preventing unnoticed configuration
drift. Do not grant clients access to the policy or usage-control tables.

Usage-control records contain only anonymous user ID, window boundaries, counters,
reservation/settlement outcome, and timestamps. They never contain article, question, note, prompt,
or model-response text. The migration schedules `ai-companion-usage-cleanup-daily` through `pg_cron`
at 03:17 UTC; it deletes only use-control records older than 30 days.

## Local verification

Create the untracked `supabase/.env.local`, then run:

```powershell
$env:Path = "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin;$env:Path"
.tools\supabase\supabase.exe start --ignore-health-check
.tools\supabase\supabase.exe db reset
.tools\supabase\supabase.exe test db
npx.cmd --yes deno test supabase/functions/ai-companion/context_test.ts
.tools\supabase\supabase.exe functions serve --no-verify-jwt --env-file supabase/.env.local
```

Use `--ignore-health-check` only when Vector's Windows health check blocks startup; database, Auth,
API, and Edge Runtime must still be available. `--no-verify-jwt` bypasses only the local Edge Runtime
pre-check. The function independently validates the bearer token and anonymous identity.

Send only `articleId`, `requestType`, `question`, and an optional block-ID anchor. Selection and
highlight explanations require an anchor. Any client article text is ignored. An accepted response
uses only `started`, `delta`, `completed`, and typed `error` SSE events. `completed` is emitted only
after DeepSeek's validated `[DONE]`; cancellation, malformed data, in-band errors, and plain EOF are
settled and end with `error` or a disconnected client. The function persists no AI session or
history.

Set `AI_ENABLED=false` to reject new model requests without rebuilding the client. Before a public
Demo release, test anonymous rejection, hourly rejection, cross-user day/week exhaustion, stop and
retry settlement, missing `[DONE]`, cleanup retention, and the global disable switch.
