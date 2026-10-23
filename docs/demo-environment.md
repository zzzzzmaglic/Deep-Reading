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
| `AI_ENABLED` | Deployment feature switch | `true` or `false` |
| `AI_REQUESTS_PER_HOUR` | Per-anonymous-user hourly request limit | `20` |
| `AI_GLOBAL_DAILY_TOKEN_BUDGET` | Shared daily completion-token budget | `10000` |
| `AI_GLOBAL_WEEKLY_TOKEN_BUDGET` | Shared weekly completion-token budget | `20000` |

Never place `SUPABASE_SERVICE_ROLE_KEY` or `DEEPSEEK_API_KEY` in Flutter defines, Appetize build
configuration, source control, screenshots, or client logs. Hosted values belong in Supabase Edge
Function secrets. Local values belong in `supabase/.env.local`, which is ignored by the tracked root
`.gitignore`.

### AI companion function

`ai-companion` always uses `deepseek-flash`. It does not read `DEEPSEEK_MODEL`, upgrade to a Pro
model, or fall back to one. For every accepted request, the function loads the article title and all
ordered article blocks from Supabase and supplies the complete article to DeepSeek; it does not
truncate the article or trust article text supplied by the client.

The Demo does not send `max_tokens` to DeepSeek, so it does not impose an application-level output
length cap. A fixed internal reservation is still used for durable usage accounting; it does not
truncate the generated response.

The native Demo keeps the current conversation in memory while the reader remains open. Each
request may include `quotedText`, an optional block-ID `anchor`, and up to 20 recent `history`
messages. Selection and existing-highlight explanations require both a quote and an anchor. The
microphone icon is visual only and the Demo neither requests microphone permission nor performs
speech recognition. Dynamic recommended questions are intentionally outside the current Demo
scope.

### Reading report function

`reading-report` has a separate, fixed model contract: it always uses `deepseek-flash` and never
reads `DEEPSEEK_MODEL`, upgrades to a Pro model, or falls back to one. The function loads the full
article and the caller's assets server-side. It sends DeepSeek the full article plus exactly one
non-empty note selected by visible note-body character count; linked-asset highlight text is not
part of that count or the model evidence. When no valid note exists, it returns an unavailable
result without contacting DeepSeek.

The current prototype leaves reading-report usage accounting disabled, so report generation is not
blocked by the shared hourly, daily, or weekly AI budgets. Set the server-only Edge Function value
`READING_REPORT_USAGE_LIMITS_ENABLED=true` to opt this function back into the existing durable
reservation and settlement policy. This switch does not change `ai-companion` limits. When enabled,
the reservation covers up to two analysis calls (one protocol retry) and one writing call.

The Demo owner has approved this transfer for the four bundled articles and their selected note.
Do not extend that approval to additional notes, raw highlights, other articles, or unrelated user
data. Store production credentials only as Supabase function secrets. For local verification,
inject the credential into the function process environment without committing the value or a
credential file.

For local report inspection, the function emits a `reading_report_writing_prompt_capture` JSON log
immediately before the second DeepSeek call. Local loopback/Kong runtimes enable this automatically;
hosted deployments do not. Set `READING_REPORT_CAPTURE_WRITING_PROMPT=true` to enable it explicitly
or `false` to disable it. The capture contains the exact model parameters and final two-message
request sent to `deepseek-flash`: the fully assembled system prompt plus the user prompt. It does not
contain the API key. Because the user prompt intentionally contains the authorized full article and
selected note, keep captures local and never commit them.

Run `supabase/scripts/export-reading-report-writing-prompts.sh` while using the Simulator. It follows
the current local Edge Runtime container and automatically extracts only the final assembled system
message of the second call into a readable `*_writing-system-prompt.md` file under
`supabase/.debug/reading-report/`. The Markdown contains no JSON envelope, request metadata, user
message, quoting, or escaped newlines. The exporter reconnects when the Edge Runtime container
restarts. Use the `--once` argument to export prompts already present in the current container log
and exit.

## Durable quota policy

PostgreSQL is the source of truth for abuse control. `reserve_ai_companion_usage` atomically locks
the global week, global day, and anonymous-user hour counters in that stable order, checks all three
limits, and reserves the configured maximum output before DeepSeek is called.
`settle_ai_companion_usage` records known output usage and releases the unused reservation. When
usage is unavailable after cancellation or upstream failure, settlement charges the reserved
maximum conservatively. Settlement cannot charge more than its reservation estimate. Anonymous
account deletion does not erase pseudonymous usage-control rows or strand reserved global tokens.

The singleton `public.ai_usage_policy` row defaults to the Demo example values above. Update that row
through an administrator-only migration or SQL deployment step when changing quotas, and update the
three matching Edge Function environment variables in the same release. The gateway rejects a
reservation when database and environment quota values differ, preventing unnoticed configuration
drift. Do not grant clients access to the policy or usage-control tables.

Usage-control records contain only anonymous user ID, window boundaries, counters,
reservation/settlement outcome, and timestamps. They never contain article, question, note, prompt,
or model-response text. The migration schedules `ai-companion-usage-cleanup-daily` through `pg_cron`
at 03:17 UTC. Cleanup locks global week rows, global day rows, then reservations; it conservatively
settles reservations still unresolved after one day, skips any row locked by in-flight work, and
deletes only use-control records older than 30 days.

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

Send `articleId`, `requestType`, `question`, optional `quotedText`, optional block-ID `anchor`, and
the bounded recent `history`. Selection and highlight explanations require a quote and an anchor.
Any client article text is ignored. An accepted response uses only `started`, `delta`, `completed`,
and typed `error` SSE events. `completed` is emitted only after DeepSeek's validated `[DONE]`;
cancellation, malformed data, in-band errors, and plain EOF are settled and end with `error` or a
disconnected client. The function persists no AI session or history.

Set `AI_ENABLED=false` to reject new model requests without rebuilding the client. Before a public
Demo release, test anonymous rejection, hourly rejection, cross-user day/week exhaustion, stop and
retry settlement, missing `[DONE]`, cleanup retention, and the global disable switch.
