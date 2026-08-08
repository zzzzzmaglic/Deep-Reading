# Demo environment

## Required local and deployment configuration

The Demo uses a Supabase anonymous user session. Anonymous sign-ins must be enabled in every local
and hosted Supabase environment before the client bootstrap is exercised. The current
`supabase/config.toml` still has `auth.enable_anonymous_sign_ins = false`; Task 4 intentionally does
not change that out-of-scope file. Enable the setting as a follow-up configuration change before
running the authenticated Demo path.

The `ai-companion` Edge Function requires these server-side variables:

| Variable | Purpose | Example development value |
| --- | --- | --- |
| `SUPABASE_URL` | Supabase project URL; supplied automatically when hosted | `http://127.0.0.1:54321` |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-only Auth validation and article block reads | Local CLI service-role key |
| `DEEPSEEK_API_KEY` | Server-only DeepSeek credential | Set through function secrets |
| `DEEPSEEK_MODEL` | Streaming model name | `DeepSeek-V4-Pro` |
| `AI_ENABLED` | Deployment feature switch | `true` or `false` |
| `AI_MAX_OUTPUT_TOKENS` | Per-request output cap; gateway ceiling is 4096 | `800` |
| `AI_REQUESTS_PER_HOUR` | Per-anonymous-user, per-function-isolate request cap | `20` |

Never place `SUPABASE_SERVICE_ROLE_KEY` or `DEEPSEEK_API_KEY` in Flutter defines, Appetize build
configuration, source control, screenshots, or client logs. Hosted secrets should be set with
`supabase secrets set`; local values belong in an untracked Edge Function environment file.

## Local verification

Start or reset the local stack, then serve the gateway with its local environment file:

```powershell
supabase db reset
supabase functions serve ai-companion --no-verify-jwt --env-file supabase/.env.local
```

`--no-verify-jwt` only bypasses the local Edge Runtime pre-check. The function still calls Supabase
Auth and rejects a missing or invalid bearer token. Send only `articleId`, `requestType`, `question`,
and an optional block-ID anchor. Any extra client article text is ignored.

An accepted response is `text/event-stream` and uses only `started`, `delta`, `completed`, and
`error` events. The function keeps no AI session or history. Set `AI_ENABLED=false` to stop new model
requests without changing or rebuilding the client.

## Deployment checks

Before publishing a Demo environment:

1. Enable anonymous sign-ins and retain Supabase Auth abuse controls.
2. Configure all AI variables as Edge Function secrets or deployment variables.
3. Keep JWT verification enabled for the deployed `ai-companion` function.
4. Confirm the hourly limit and output-token cap match the Demo budget.
5. Confirm logs contain request IDs and operational counters only, never prompts, article text,
   authorization headers, user IDs, or secret values.

The hourly counter is held in the warm Edge Function isolate and resets when that isolate is
replaced. A shared durable rate-limit store is required before multi-isolate production rollout;
the current mechanism is suitable only for the bounded single-Demo environment in this task.
