# Changelog

## Unreleased

### Sandbox (WoW) hardening

Driving a full capture→spool→drain through a simulated WoW environment (Lua 5.1;
`require`/`package`/`io`/`os.getenv` absent) surfaced several blockers where the SDK
would crash on load/init or silently drop every event. Fixed:

- **Self-contained bundle** (`scripts/bundle.lua`): the amalgamated bundle no longer
  assumes a host `require`/`package` (WoW strips both). It prepends a local module
  loader that shadows the globals for the whole chunk, hands the SDK off to WoW addons
  via the addon-table (`...`), and exposes `Sentry.require` so bundled sub-modules
  (platform integrations) are reachable without a host `require`.
- **`utils/config`**: env-var resolution fell back to `os.getenv`, which sandboxes lack
  — `init` called a nil. Now degrades to a nil-returning stub.
- **`utils/stacktrace`**: `get_source_context` indexed `io` unconditionally; in
  `io`-less sandboxes `capture_exception` threw (then got swallowed → silent drop). Now
  guarded (no readable source in a sandbox anyway).
- **`core/client` `is_enabled`**: spool mode no longer requires a DSN — a spooling addon
  delivers via the companion uploader, which supplies the DSN at send time.
- **WoW `saved_variables_provider`**: implements the full `PersistenceProvider` contract
  (`remove_first` for uploader drain) and takes an optional `max_records` cap with
  ring-buffer eviction (SavedVariables loads fully into memory at login).
- **`tracing/headers`**: stop reassigning a generic-`for` control variable (a compile
  error in Lua 5.4/5.5; legal in 5.1) — restores loadability under modern Lua.

### Release-health for hosts that catch errors + can crash between runs

- **`mark_unhandled_as_crash` option** (default true): where the host catches unhandled
  errors and keeps running (WoW addons), set it false so such errors mark the session
  `errored` rather than `crashed`.
- **`get_session_snapshot()`** / **`report_previous_session(record, status)`**: persist the
  live session and, on the next launch, re-emit a run that never exited cleanly as
  `crashed` against the same sid — cross-restart crash detection for sandboxed platforms.

### Advanced follow-ups

- Distributed tracing: the frozen Dynamic Sampling Context now propagates in the
  outbound `baggage` header; new `sentry.continue_trace()` / `sentry.get_trace_data()`;
  opt-in `http.client` span instrumentation.
- Automatic global error handlers for Roblox (`ScriptContext.Error`), Defold
  (`sys.set_error_handler`) and OpenResty (`nginx.wrap`) — each also attaches rich
  platform context. `deny_urls` inbound filter.
- Async delivery: `scheduler` option to defer draining to a platform loop
  (OpenResty timer, Roblox task, or a Love2D update tick via `sentry.core.scheduler`).
- `with_isolation_scope` for per-request/per-task scope isolation.
- Love2D screenshot-on-crash (best-effort attachment).
- Uploader now removes only the delivered prefix (partial-delivery + re-run safe);
  Roblox `DataStore` persistence provider for HttpService-disabled experiences.
- CI: pinned the two remaining un-pinned GitHub Actions to SHAs; `make budget`
  enforces a bundle-size cap.

### Tooling & docs

- Blocking lint (ratchet): `make lint` + a CI job (`.github/workflows/lint.yml`)
  run strict `tl check` over an allowlist of known-clean files and fail on any
  regression; `make lint-all` reports the full residual. Platform globals are
  declared in `teal-types.d.tl` (via `--global-env-def`, so the build is
  unaffected). 23 files are clean today and the allowlist grows as files migrate.
- Test suite is hermetic by default: live-network checks are opt-in via
  `SENTRY_LIVE_TESTS=1` (they now show as pending rather than flaking on
  third-party outages).
- Rockspec build compiles every module directory (creates output dirs per file),
  so new modules (metrics, uploader, WoW/Factorio) are packaged.
- README updated: features, supported platforms, full API surface, `init`
  option reference, and a sandboxed-platforms guide.

### Sandboxed platforms (no-network environments)

- Spool transport + PersistenceProvider (`spool = true`): envelopes are persisted
  (in-memory, on disk, or a custom store) instead of sent, for environments with
  no outbound HTTP (WoW addons, Factorio mods, locked-down consoles).
- Companion uploader (`sentry.uploader`): drains a spool and delivers the
  envelopes from a networked context; retains the spool on failure.
- World of Warcraft integration: attaches rich context out of the box — game
  version/build, locale, realm, and the full installed-addon list with versions —
  plus tags, a global error handler, and a SavedVariables-backed spool provider.
- Factorio integration: attaches the Factorio version and the full active-mod
  list (with versions).
- `make bundle`: amalgamates the SDK into a single self-contained file for
  platforms that lack `require()`/luarocks. Examples added for WoW, Factorio and
  the uploader.

### Sessions, logs, metrics & attachments

- Release-health sessions (application mode): a session starts at `init` when a
  `release` is set, counts errors, is marked `crashed` on an unhandled exception,
  and `exited` on clean shutdown. Opt out with `auto_session_tracking = false`.
- New trace-connected metrics (`trace_metric`): `sentry.metrics.increment/gauge/
  distribution`, buffered and flushed on their own independent cadence, separate
  from structured logs. Gated by `enable_metrics`.
- Structured logs now flush through the client queue (sharing rate limiting and
  client reports) and correctly attach `sentry.environment` / `sentry.release`
  default attributes.
- Attachments: `sentry.add_attachment(filename, data, content_type, attachment_type)`
  rides in the same envelope as the next event; oversized attachments are dropped
  (`max_attachment_size`, default 20 MiB). Suitable for crash screenshots on game
  platforms.

### Performance / tracing

- Transactions are now actually submitted to Sentry: `transaction:finish()` routes
  through the client (sampling, scope data, data scrubbing, the outbound queue and
  rate limiting) and is sent as a `transaction` envelope item.
- `traces_sample_rate` and `traces_sampler(sampling_context)` control transaction
  sampling (tracing is opt-in; unsampled transactions are recorded as client reports).
- A frozen Dynamic Sampling Context (trace_id, public_key, environment, release,
  sample_rate, sampled, transaction) is attached as the envelope `trace` header.
- New top-level `sentry.start_transaction()` / `sentry.capture_transaction()`.
- (Follow-ups: propagate the DSC in the outbound `baggage` header; automatic
  span-level HTTP client instrumentation.)

### Automatic capture & ergonomics

- Environment-variable configuration: `SENTRY_DSN`, `SENTRY_RELEASE`,
  `SENTRY_ENVIRONMENT`, `SENTRY_DEBUG` are read at `init` (explicit options win).
- `sample_rate` is now applied to captured events (discards recorded as client
  reports); `before_breadcrumb` hook to filter/modify breadcrumbs; `ignore_errors`
  inbound filter (substring match on message/exception); `attach_stacktrace` to
  control whether messages carry a stack trace.
- Integration hook: `integrations` option runs each `setup(client)` at init, so
  platform packages and users can install handlers / processors.

### Spec-correct error core

- Envelope-everything transport: all events are now sent to the modern envelope
  endpoint (`/api/{id}/envelope/`) as Sentry envelopes. The legacy `/store/`
  endpoint and dual `send`/`send_envelope` transport paths were removed; every
  transport now implements a single `send_envelope(payload, categories)`.
- DSN: dropped the deprecated `sentry_secret` from the auth header (public key
  only) and removed the legacy ingest-URL builder.
- Deterministic offline tests: `test_transport`/`file_transport` options are now
  honored by the client, so capture tests no longer make real network calls.
- Bounded outbound queue: events are enqueued (default cap 30, `max_queue_size`)
  and drained to the transport; overflow drops the oldest envelope. `flush(timeout_ms)`
  and `close(timeout_ms)` block up to a best-effort timeout and return whether the
  queue was fully delivered.
- Rate limiting: honors HTTP 429 and the `X-Sentry-Rate-Limits` header (per data
  category, keeping the longest window, with a `Retry-After`/60s fallback). The
  drain loop suppresses rate-limited envelopes without retrying, and HTTP
  transports now surface response status + headers.
- Client reports: dropped events (rate-limit backoff, queue overflow, network
  error) are counted per reason/category and sent as a batched `client_report`
  envelope (never one-per-drop). Opt out with `send_client_reports = false`.
- Three-scope model (global / isolation / current): top-level `set_tag`/`set_user`/
  `set_context`/`set_fingerprint` write to the isolation scope; `with_scope` forks
  the current scope; `configure_scope` mutates the isolation scope. Added
  `fingerprint` support and decoupled trace-context application from the scope layer.
- `capture_exception` now accepts native Lua errors (strings) as well as tables,
  and always sets an exception `mechanism` (`handled = true` by default; automatic
  handlers such as `wrap` and the Love2D hook mark `handled = false`).
- Empty/missing DSN is now valid and initializes a disabled no-op client instead
  of throwing. The capture pipeline is wrapped so the SDK never crashes the host
  or captures its own exceptions.
- Default data scrubbing: values under sensitive keys (passwords, tokens, secrets,
  auth headers, cookies, etc.) are replaced with `[Filtered]` throughout the event,
  and the user's IP address is stripped unless `send_default_pii = true`.

## 0.0.6

### Various fixes & improvements

- manual publish workflow (ebe8a3f5) by @bruno-garcia
- packaging for non luarocks use cases (319fb9e7) by @bruno-garcia
- remove oudated comment (c228ac26) by @bruno-garcia

## 0.0.5

### Various fixes & improvements

- publish as rockspec (22cd9c64) by @bruno-garcia
- luarocks instructions (22694686) by @bruno-garcia
- bump script (e8d2a291) by @bruno-garcia

## 0.0.4

### Various fixes & improvements

- package as .rock (cdced997) by @bruno-garcia
- love.errorhandler integration (a0f22464) by @bruno-garcia

## 0.0.3

### Features

- Add Love2D fatal error handler integration (#love2d)
  - Hooks into `love.errorhandler` to capture fatal crashes
  - Sets `mechanism.handled: false` for proper error classification
  - Automatically installed in Love2D environments
  - Includes comprehensive test coverage

### Various fixes & improvements

- validate rockspec in ci (1635d0d8) by @bruno-garcia
- fix rockspec deps and lua modules (3232de4a) by @bruno-garcia

## 0.0.2

### Various fixes & improvements

- changelog (37433ac9) by @bruno-garcia

## 0.0.1

Sentry Hackweek 2025 - **Experimental** SDK

* Portable Lua SDK, written in Teal, Lua 5.1 compatible.
* CI and tests on Standard Lua and LuaJIT on macOS and Linux
* Sentry Features include:
  * Error reporting with source context and local variable values
  * Context such as runtime and OS information
  * Tracing connecting all telemetry (errors, traces, logs, etc)
    * Integration with pegasus HTTP server for incoming request trace connectiveness
    * integration with luasocket for outgoing HTTP request trace propagation
  * Spans for performance monitoring
  * Log capturing including 'print' function integration
  * LÖVE framework (love2d) integration and example app

Note: This is was all built in 3 days and is likely full of bugs (even though there are 300 units tests). Please open [issues on GitHub](https://github.com/getsentry/sentry-lua/issues). Or reach out on [Sentry's Discord community](https://discord.gg/sentry).