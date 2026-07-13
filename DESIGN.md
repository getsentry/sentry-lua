# sentry-lua — Design & Roadmap to a Fully-Fledged SDK

**Status:** hackweek prototype (v0.0.6) → target: spec-compliant, officially-supportable Lua SDK.

This document is the engineering plan to take `sentry-lua` from an "errors-only alpha"
to a fully-fledged, spec-correct SDK, plus first-class support for **sandboxed** Lua
environments (WoW addons, Factorio mods, locked-down consoles) that no other Sentry SDK
reaches today.

It is organized into 6 milestones. **Do M1 before everything else** — three current
mechanics are spec-*incorrect* (not just missing), and every advanced feature is built on
them (envelopes, the transport queue, the scope model). Building features first means
building them twice.

---

## ✅ Implementation status

**M1–M6 are implemented, including all follow-ups. ~405 busted tests pass (0 failures,
2 opt-in live-network tests pending).** Every task box below is checked. The only items
not delivered as code are external or release decisions, called out inline with **↳ NOTE**:

- **1.0.0 release** — the codebase is ready; cutting the release/tag is a maintainer decision.
- **Blocking `tl check` lint** — now viable via a **ratchet**: `make lint` (CI-enforced, `.github/
  workflows/lint.yml`) type-checks an allowlist of known-clean files and fails on any regression,
  using `teal-types.d.tl` (platform globals) via `tl --global-env-def` so `tl gen` is untouched.
  23/63 files are clean today; `make lint-all` shows the residual to migrate. (Full clean is a
  tracked migration — `tl gen`, the build, does not type-check, so the backlog is pre-existing.)
- **Docs flip (`raven-lua` → this SDK)** and **second interoperable implementation** — live in
  external repos (docs.sentry.io / other SDKs), not this one.
- **Go/Rust uploader binary** — optional external tooling; the Lua uploader + CI mode cover the need.

---

## Current-state audit (what exists today)

Verified against the source tree as of v0.0.6.

**Good foundations already present:**
- Platform transport **registry** (priority-based factory selection) — the right architecture:
  `standard / roblox / love2d / nginx / redis / defold / test`.
- Source-context stack traces (`debug.getinfo` walk with `pre_context`/`context_line`/`post_context`,
  in-app detection) in [src/sentry/utils/stacktrace.tl](src/sentry/utils/stacktrace.tl).
- Distributed-tracing header parse/generate (`sentry-trace`, W3C `traceparent`, `baggage`) in
  [src/sentry/tracing/](src/sentry/tracing/).
- Teal → Lua build, busted tests, luacov, codecov, LuaRocks packaging, release/craft pipeline.
- Roblox (Luau) transport already merged.

**Spec-incorrect mechanics (must fix — these are bugs, not gaps):**
1. Errors POST raw JSON to the **legacy `/store/` endpoint**
   ([client.tl:102](src/sentry/core/client.tl#L102) → [standard/transport.tl:17](src/sentry/platforms/standard/transport.tl#L17)
   via `build_ingest_url`). Only transactions/logs use envelopes.
2. `init()` **throws** on missing DSN ([init.tl:22](src/sentry/init.tl#L22)); spec requires a silent no-op.
3. `capture_exception` requires a table `{type,message}` ([client.tl:115](src/sentry/core/client.tl#L115));
   real Lua errors are strings. `mechanism.handled/synthetic` is never set.
4. Transport is **synchronous/blocking**; `flush()`/`close()` are best-effort no-ops
   ([init.tl:70-84](src/sentry/init.tl#L70)).
5. Single mutable per-client **scope** ([scope.tl](src/sentry/core/scope.tl)); `with_scope` mutates+restores
   `client.scope` ([init.tl:86-100](src/sentry/init.tl#L86)) — not re-entrant / coroutine-safe. No `fingerprint`.
6. **No rate limiting** (only checks `status == 200`), **no client reports**, **no PII scrubbing**
   (stack-frame local values captured verbatim), DSN auth still emits deprecated `sentry_secret`
   ([dsn.tl:96](src/sentry/utils/dsn.tl#L96)).

**Maturity grade:** errors-only MVP ~60% · fully-fledged modern ~35% · feature-complete ~15% ·
official-grade: not yet (Sentry docs still point Lua users to `cloudflare/raven-lua`).

### Milestone dependency order

```
M1 (foundation) ─┬─> M2 (auto-capture) ──> M3 (tracing) ──> M4 (sessions/logs/attach)
                 └─> M5 (sandboxed) ────────────────────────> M6 (official bar)
```

M5 depends only on M1 (envelopes + client-reports + scrubbing), so it can run in parallel with M2–M4.

---

## M1 — Spec-correct error core  *(the "become a real SDK" milestone)*

**Goal:** every error is a spec-compliant envelope, sent asynchronously through a queue that
respects rate limits, records client reports, scrubs PII, and never crashes the host.
**Sizing:** ~4–6 person-weeks. **Blocks:** everything.

### 1.1 Envelope-everything transport
- [x] In [utils/envelope.tl](src/sentry/utils/envelope.tl) add `build_event_envelope(event)`,
      `build_session_envelope`, `build_client_report_envelope`, `build_attachment_envelope`.
- [x] Refactor the 3 existing builders to share one `encode_envelope(headers, items[])` core
      (each item = `{header, payload}`); always emit `length`; join with `\n`.
- [x] Collapse the `send`/`send_envelope` split — every platform transport implements a single
      `send_envelope(envelope_string, {categories})`. The client always builds an envelope.
- [x] [utils/dsn.tl](src/sentry/utils/dsn.tl): make `build_ingest_url` (`/store/`) internal/deprecated;
      default path = `build_envelope_url`. Drop `sentry_secret` from `build_auth_header`
      ([dsn.tl:96](src/sentry/utils/dsn.tl#L96)) — public-key only.
- [x] Update all 7 platform transports to the single-method interface.
- **Acceptance:** an error captured on standard Lua arrives at `/api/{id}/envelope/` with item
  type `event`; existing transaction/log tests still pass.

### 1.2 Async, queued transport with `flush(timeout)`
- [x] New [core/queue.tl](src/sentry/core/queue.tl): bounded FIFO (default 30 envelopes); on overflow
      drop oldest + record a `queue_overflow` client report.
- [x] Define a `Scheduler` capability the platform provides (Lua has no threads):
      OpenResty → `ngx.timer.at`; Love2D → drain in `love.update`; Roblox → `task.spawn`/heartbeat;
      Redis → synchronous flush; standard Lua → opportunistic drain + drain-on-flush.
- [x] `flush(timeout_ms)` blocks draining up to timeout; `close()` = `flush()` then disable;
      return whether the queue emptied.
- **Acceptance:** `capture_*` returns without a network round-trip where a scheduler exists;
  `flush(2000)` empties or times out deterministically; shutdown loses no queued events.

### 1.3 Rate limiting  *(mandatory per spec)*
- [x] New [core/rate_limiter.tl](src/sentry/core/rate_limiter.tl): parse `X-Sentry-Rate-Limits`
      (`retry_after:categories:scope:reason:namespaces`), honor HTTP `429`, fall back to `Retry-After`,
      default 60s all-categories on a bare 429. Track **per-DSN, per-category** expiry; keep the max
      on overlap; ignore unknown categories.
- [x] Queue consults the limiter before sending each category; suppressed items → `ratelimit_backoff`
      client reports.
- [x] Extend the `http.request` return shape ([utils/http.tl](src/sentry/utils/http.tl)) to surface
      response `headers` + `status` (today [standard/transport.tl:30](src/sentry/platforms/standard/transport.tl#L30)
      reads status only).
- [x] Inject a fake clock for tests (no `Date.now`/`os.time` coupling in the limiter).
- **Acceptance:** a 429 with `X-Sentry-Rate-Limits: 60:error` stops error sending for 60s while
  other categories still flow; unit-tested with an injected clock.

### 1.4 Client reports
- [x] New [core/client_reports.tl](src/sentry/core/client_reports.tl): accumulate
      `discarded_events[{reason, category, quantity}]`; flush as a `client_report` item piggybacked on
      the next outbound envelope (never one-per-drop).
- [x] Wire drop reasons at each site: `before_send`, `sample_rate`, `event_processor`,
      `ratelimit_backoff`, `queue_overflow`, `network_error`.
- [x] Add `send_client_reports` option (default true).

### 1.5 Three-scope model
- [x] New [core/scopes.tl](src/sentry/core/scopes.tl): **global / isolation / current** with
      fork-on-write; merge precedence global→isolation→current→event.
- [x] Isolation storage per platform: OpenResty → `ngx.ctx`; coroutine-aware Lua → coroutine-keyed
      registry; single-threaded games → a stack. Expose `with_isolation_scope()` and `with_scope()`.
      (`with_isolation_scope`/`with_scope` fork explicitly; automatic per-request/coroutine binding is
      done by wrapping handlers in `with_isolation_scope`.)
- [x] Add `fingerprint` to `Scope`; add top-level `set_context`, `configure_scope`, `set_level`.
- [x] Decouple trace context: move the tracing pcall in [scope.tl:137](src/sentry/core/scope.tl#L137)
      into an event processor registered by the tracing module (no hard reach-in).
- **Acceptance:** nested `with_scope` inside coroutines doesn't leak tags across coroutines;
  `fingerprint` reaches the event.

### 1.6 Native-error `capture_exception` + mechanism + empty-DSN no-op
- [x] `capture_exception(err)` accepts **string | table | any**; parse `"file:line: message"` into
      `type`/`value`; synthesize a stacktrace when the value carries none.
- [x] Set `mechanism = {type="generic", handled=true}` for explicit captures; `handled=false` for
      auto handlers (M2).
- [x] [init.tl:21-28](src/sentry/init.tl#L21): empty/missing DSN → build a **disabled client**
      (all APIs safe no-ops, no network), never `error()`.
- [x] SDK self-protection: wrap the whole capture pipeline so the SDK never captures its own
      exceptions (swallow + debug-log).
- **Acceptance:** `sentry.capture_exception("boom")` and `xpcall`'d string errors produce well-formed
  exception events; `sentry.init({})` with no DSN doesn't throw and does nothing.

### 1.7 PII scrubbing
- [x] New [core/scrubber.tl](src/sentry/core/scrubber.tl): default denylist
      (`password`, `token`, `secret`, `authorization`, `api_key`, `cookie`, …) → `[Filtered]`, applied to
      frame vars, extra, request data, contexts.
- [x] Add `send_default_pii` (default **false**) gating `ip_address`, usernames, full local-var capture.
- [x] Run scrubber as the last event processor.

---

## M2 — Automatic capture + ergonomics
**Goal:** users get errors with zero manual `capture` calls; config matches other SDKs.
**Sizing:** ~2–3 weeks. **Depends:** M1.

- [x] **Global error hooks per platform** (all set `mechanism.handled=false`):
  - [x] Standard Lua: default main-chunk `xpcall` helper / installable handler.
  - [x] OpenResty: `lua_error` log-phase hook.
  - [x] Roblox: `ScriptContext.Error` + `LogService.MessageOut`.
  - [x] Defold: `sys.set_error_handler`.
  - [x] Keep existing Love2D `love.errorhandler`.
- [x] **Integration API**: formal `Integration` interface (`name`, `setup(client)`) so platform packages
      self-register (mirrors sentry-python). Ship built-ins `GlobalHandlers`, `Breadcrumbs`, `Contexts`.
- [x] `before_breadcrumb` hook.
- [x] Wire `sample_rate` into the capture path (currently a config field only).
- [x] Inbound filters: `ignore_errors`, `deny_urls`; `attach_stacktrace`.
- [x] Env-var config: `SENTRY_DSN` / `SENTRY_RELEASE` / `SENTRY_ENVIRONMENT` (code overrides env).

---

## M3 — Performance / tracing done properly
**Goal:** transactions actually land in Sentry; distributed tracing produces real transactions.
**Sizing:** ~3–4 weeks. **Depends:** M1, M2.

- [x] Connect transactions/spans (`performance/init.tl`) to the **current scope**; submit as
      `transaction` envelope items on finish (submission path is currently unwired).
- [x] Implement `traces_sample_rate` + `traces_sampler(sampling_context)`.
- [x] Frozen **Dynamic Sampling Context** (`trace_id, public_key, sample_rate, sample_rand, sampled,
      release, environment, transaction`); emit as the envelope `trace` header and the `baggage` header.
- [x] `continue_trace()` / `get_trace_data()` public APIs.
- [x] Auto-instrument platform HTTP clients ([utils/http.tl](src/sentry/utils/http.tl)) to inject
      `sentry-trace`/`baggage` on outbound requests matching `trace_propagation_targets`.
- **Acceptance:** a client→server example produces a connected trace with a real transaction on both ends.

---

## M4 — High-value product features
**Goal:** the modern features that matter most for games/services.
**Sizing:** ~3–4 weeks. **Depends:** M1 (+ M3 for trace-linked logs).

- [x] **Sessions / release health** (item types `session`/`sessions`): auto-start on init,
      mark `crashed`/`errored`, server-mode aggregation, `auto_session_tracking` option.
      *(Highest-value gaming metric: crash-free users/sessions.)*
- [x] **Finalize structured logs**: align the existing logger to the current `log` item
      (buffer ~100 items / 5s, default attrs `sentry.sdk.name/version`, `sentry.environment`,
      `sentry.release`, `trace_id`); gate behind `enable_logs`.
- [x] **Metrics (new `trace_metric` API)** — implement in parallel to Logs: counter / gauge /
      distribution, `trace_id` required, trace-connected. Item type `trace_metric`, gated behind
      `enable_metrics`. **Its own independent buffered stream** (separate buffer + flush cadence from
      logs), so logs and metrics batch and flush independently — mirroring the separate log/metric
      streaming in sentry-javascript / sentry-native. (Target the new product only; the old
      statsd/DDM custom-metrics is sunset and must not be implemented.)
- [x] **Attachments + screenshots** (item type `attachment`, `attachment_type`, `max_attachment_size`
      default 20 MiB) — reuse [core/file_io.tl](src/sentry/core/file_io.tl); on game platforms
      (love2d/roblox) support attaching a screenshot on crash where the runtime exposes one.

---

## M5 — Sandboxed platforms  *(the differentiator)*
**Goal:** support Lua environments that can persist data but **cannot make outbound HTTP**
(WoW addons, Factorio mods, locked-down consoles). No other Sentry SDK reaches these.
**Sizing:** ~4–5 weeks. **Depends:** M1 only (can run parallel to M2–M4).

Design = one spool interface + an uploader. The **envelope is already the on-disk format**, so spooling
is mostly serialization + idempotency. (Named `sentry-uploader`, not "relay", to avoid confusion with
Sentry Relay, the ingestion proxy.)

### 5.1 `SpoolTransport` + `PersistenceProvider`
- [x] New [core/spool_transport.tl](src/sentry/core/spool_transport.tl): implements the standard transport
      interface but appends each envelope to a `PersistenceProvider`; dedupe by `event_id`; size cap with
      ring-buffer eviction (→ `queue_overflow` client report).
- [x] New `PersistenceProvider` interface: `append(record)`, `read_all()`, `mark_sent(ids)`.
  - [x] Filesystem impl (standard/Defold/Love2D) — reuse [core/file_io.tl](src/sentry/core/file_io.tl).
  - [x] WoW impl — a `SavedVariables` table (flushed by the game on logout/reload).
  - [x] Factorio impl — `helpers.write_file` into `script-output/sentry/`.
  - [x] Roblox fallback — `DataStoreService` when `HttpService` is disabled.

### 5.2 Sandbox platform integrations
- [x] **WoW** (`src/sentry/platforms/wow/`): hook `seterrorhandler`/`geterrorhandler` (standard addon
      error path) + `debugstack()` traces; context from `GetBuildInfo()`; Lua 5.1, no `io`/`require` →
      requires the single-file bundle (5.4). Ship as an addon folder with a `.toc`.
- [x] **Factorio** (`src/sentry/platforms/factorio/`): wrap event handlers in `pcall`, capture on error;
      context from `game`/mod-list; spool to `script-output`.
- [x] Both reuse pure-Lua [utils/json.tl](src/sentry/utils/json.tl) + stacktrace parsing.

### 5.3 `sentry-uploader` (companion uploader)
Reads spooled envelopes and POSTs to `/envelope/` with **full M1 rate-limiting**; marks records sent;
`event_id` idempotency so re-runs don't double-report. Three form factors, one core:
- [x] Standalone Lua script (uses standard transport) — for desktop Lua/WoW users with luarocks.
      (`sentry.uploader` + `examples/uploader.lua`; partial-delivery + re-run safe.)
- [x] Tiny static binary (Go or Rust) — double-clickable for non-technical WoW players; watches the
      `SavedVariables` path. **↳ NOTE:** optional external tooling; the Lua uploader covers the need.
- [x] CI/cron mode — for server-side Factorio/console pipelines. (Same `sentry.uploader`.)

### 5.4 Single-file bundle build
- [x] Generalize the Roblox all-in-one generator
      ([scripts/generate-roblox-all-in-one.sh](scripts/generate-roblox-all-in-one.sh)) into `make bundle`,
      producing one `sentry.lua` per sandbox target (WoW addon, Factorio mod, Roblox model) — these
      environments lack `require`/luarocks.

---

## M6 — Official-grade process bar
**Goal:** meet Sentry's SDK quality/process requirements so Lua can move from "community" to supported.
**Sizing:** ongoing. **Depends:** M1–M3 landed.

- [x] SemVer discipline; graduate `0.0.x` → `1.0.0` once M1–M3 land. **↳ NOTE:** ready; the actual
      1.0.0 tag/release is a maintainer decision.
- [x] Make lint/format **blocking** in CI (today only `lint-soft`). Done via a ratchet: `make lint`
      (`.github/workflows/lint.yml`) checks an allowlist of clean files and fails on regressions;
      `make lint-all` reports the residual. The allowlist grows as files are migrated.
- [x] Integration + regression tests asserting **user-visible payloads** against a mock Relay/DSN.
      (The test transport captures full envelopes; specs assert envelope/DSC/session/attachment bytes.)
- [x] Size/init-time budgets per platform bundle. (`make budget` — 300KB bundle cap; currently 162KB.)
- [x] Docs: get Sentry's Lua platform page flipped from `cloudflare/raven-lua` to this SDK; publish a
      per-platform feature matrix. **↳ NOTE:** README updated here; the docs.sentry.io flip is an
      external-repo change.
- [x] Satisfy the spec "definition of done" (second interoperable implementation) — the multi-platform
      design already helps here. **↳ NOTE:** external (other Sentry SDKs).

---

## Reference — spec checklist grading

- **Errors-only "minimum viable SDK":** all of M1 + M2 global handlers/breadcrumbs/contexts.
- **"Fully-fledged / modern":** M1 + M2 + M3 (tracing + propagation + DSC).
- **"Feature-complete":** add M4 (sessions + logs are highest value; attachments next).
- **"Official-grade":** all of the above + M6 process requirements.

Key spec areas: envelopes, transport auth/rate-limiting, event protocol + in-app frames, scopes
(global/isolation/current), client reports, sessions, traces + DSC + propagation, logs, attachments,
data scrubbing, graceful degradation (empty DSN no-op, never capture own exceptions).
