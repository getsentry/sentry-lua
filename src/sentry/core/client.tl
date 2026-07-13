local transport = require("sentry.core.transport")
local Scope = require("sentry.core.scope")
local Scopes = require("sentry.core.scopes")
local Queue = require("sentry.core.queue")
local RateLimiter = require("sentry.core.rate_limiter")
local scrubber = require("sentry.core.scrubber")
local dsn_utils = require("sentry.utils.dsn")
local stacktrace = require("sentry.utils.stacktrace")
local serialize = require("sentry.utils.serialize")
local envelope = require("sentry.utils.envelope")
local time = require("sentry.utils.time")
local runtime_utils = require("sentry.utils.runtime")
local os_utils = require("sentry.utils.os")
local types = require("sentry.types")

-- Load platform detectors
require("sentry.platform_loader")

local SentryOptions = types.SentryOptions

-- Does the event's message / exception value match any ignore pattern (substring)?
local function event_matches_ignore(event: table, patterns: {string}): boolean
   local e = event as {string: any}
   local text = (e["message"] as string) or ""
   local exc = e["exception"] as {string: any}
   if exc and exc["values"] then
      local vals = exc["values"] as {any}
      if vals[1] then
         text = text .. " " .. ((vals[1] as {string: any})["value"] as string or "")
      end
   end
   for _, p in ipairs(patterns) do
      if text:find(p, 1, true) then
         return true
      end
   end
   return false
end

-- Does the event's transaction name or any stack-frame filename match a deny_url?
local function event_matches_deny_urls(event: table, patterns: {string}): boolean
   local e = event as {string: any}

   local function matches(text: string): boolean
      if not text then
         return false
      end
      for _, p in ipairs(patterns) do
         if text:find(p, 1, true) then
            return true
         end
      end
      return false
   end

   if matches(e["transaction"] as string) then
      return true
   end
   local exc = e["exception"] as {string: any}
   if exc and exc["values"] then
      for _, v in ipairs(exc["values"] as {any}) do
         local st = (v as {string: any})["stacktrace"] as {string: any}
         if st and st["frames"] then
            for _, f in ipairs(st["frames"] as {any}) do
               if matches((f as {string: any})["filename"] as string) then
                  return true
               end
            end
         end
      end
   end
   return false
end

local record Client
   options: SentryOptions  -- Configuration from sentry.init()
   scopes: Scopes          -- global / isolation / current scopes
   scope: Scope            -- Alias of the isolation scope (top-level set_tag/user/etc.)
   transport: any
   queue: Queue            -- Bounded outbound envelope queue
   rate_limiter: RateLimiter
   discarded: {string: number}  -- "reason:category" -> count (for client reports)
   public_key: string      -- from the DSN (used in the dynamic sampling context)
   session: any            -- release-health session (application mode)
   enabled: boolean
end

function Client:new(options: SentryOptions): Client
   local scopes = Scopes.new()
   local client = setmetatable({
      options = options or {} as SentryOptions,
      scopes = scopes,
      -- Top-level set_tag/set_user/etc. and platform contexts write to the
      -- isolation scope; `scope` is kept as an alias for convenience.
      scope = scopes.isolation,
      enabled = true
   }, {__index = Client}) as Client
   
   -- Configure transport. Explicit choices win over the registry so that
   -- test/file transports are deterministic and never touch the network.
   local dsn = (options and options.dsn) or ""
   if options.transport then
      -- User-provided transport takes precedence
      client.transport = (options.transport as any):configure(options)
   elseif options.test_transport then
      client.transport = (require("sentry.core.test_transport") as any):configure(options)
   elseif options.file_transport then
      client.transport = (require("sentry.core.file_transport") as any):configure(options)
   elseif options.spool then
      -- Sandboxed environments: persist envelopes for a companion uploader.
      client.transport = (require("sentry.core.spool_transport") as any).create_spool_transport(options)
   elseif dsn == "" then
      -- Empty/missing DSN is valid: the SDK is fully disabled (no network) and
      -- every capture API becomes a safe no-op.
      client.transport = { send_envelope = function(): boolean, string return true, "disabled" end }
      client.enabled = false
   else
      -- Use transport registry to find best available transport
      client.transport = transport.create_transport(options)
   end
   
   -- Extract the public key from the DSN for the dynamic sampling context.
   if dsn ~= "" then
      local parsed = dsn_utils.parse_dsn(dsn)
      if parsed then
         client.public_key = parsed.public_key
      end
   end

   -- Register SDK identity so the tracing layer can build the DSC / baggage.
   local ok_prop, prop = pcall(require, "sentry.tracing.propagation")
   if ok_prop and prop and (prop as any).set_sdk_metadata then
      (prop as any).set_sdk_metadata({
         public_key = client.public_key,
         environment = options.environment,
         release = options.release
      })
   end

   -- Rate limiting + discarded-event accounting for client reports.
   client.rate_limiter = RateLimiter.new()
   client.discarded = {}

   -- Bounded outbound queue. On overflow the oldest envelope is dropped and
   -- recorded so client reports can account for it.
   client.queue = Queue.new(options.max_queue_size, function(categories: {string})
      client:record_discarded("queue_overflow", categories)
      if options.debug then
         print("[Sentry] Queue overflow: dropped oldest envelope")
      end
   end)

   -- Configure scope max breadcrumbs from options
   if options.max_breadcrumbs then
      client.scope.max_breadcrumbs = options.max_breadcrumbs
   end
   
   -- Initialize runtime context in scope
   local runtime_info = runtime_utils.get_runtime_info()
   client.scope:set_context("runtime", {
      name = runtime_info.name,
      version = runtime_info.version,
      description = runtime_info.description
   })
   
   -- Initialize OS context in scope (if available)
   local os_info = os_utils.get_os_info()
   if os_info then
      local os_context: {string: string} = {
         name = os_info.name
      }
      -- Only add version if it's not nil
      if os_info.version then
         os_context.version = os_info.version
      end
      client.scope:set_context("os", os_context)
   end
   
   -- Install Love2D error handler integration if in Love2D environment
   if runtime_info.name == "love2d" and (_G as any).love then
      local ok, love2d_integration = pcall(require, "sentry.platforms.love2d.integration")
      if ok then
         local integration = love2d_integration.setup_love2d_integration()
         integration:install_error_handler(client)
         -- Store integration reference for potential cleanup
         client.love2d_integration = integration
      end
   end

   -- Run user-provided integrations. Each is a table with a `setup(client)`
   -- function that can install handlers or register event processors.
   if options.integrations then
      for _, integ in ipairs(options.integrations) do
         local setup = (integ as {string: any})["setup"]
         if setup then
            pcall(setup as function, client)
         end
      end
   end

   -- Start a release-health session (requires a release; opt out with
   -- auto_session_tracking = false).
   if client.enabled and options.auto_session_tracking ~= false
      and options.release and options.release ~= "" then
      local Session = require("sentry.core.session")
      client.session = Session.new(nil, options.release, options.environment)
      client:capture_session()
   end

   return client
end

function Client:is_enabled(): boolean
   if not self.enabled then
      return false
   end
   -- Spool mode persists envelopes for a companion uploader that supplies the
   -- DSN at send time, so spooling itself needs no DSN (WoW addons never carry
   -- one). Non-spool clients still require a DSN to be enabled.
   if self.options.spool then
      return true
   end
   return self.options.dsn ~= nil and self.options.dsn ~= ""
end

-- Collect accumulated discarded-event counts into a client_report envelope and
-- reset the accumulator. Returns "" when there is nothing to report.
function Client:build_client_report(): string
   local discarded_events: {table} = {}
   for key, quantity in pairs(self.discarded or {}) do
      local reason, category = key:match("^(.-):(.+)$")
      if reason and quantity > 0 then
         table.insert(discarded_events, {
            reason = reason,
            category = category,
            quantity = quantity
         })
      end
   end
   if #discarded_events == 0 then
      return ""
   end
   self.discarded = {}
   return envelope.build_client_report_envelope(discarded_events as {any})
end

-- Send a batched client report directly (bypassing the queue). Failures are
-- ignored and never re-recorded, so this can never recurse.
function Client:flush_client_reports()
   if self.options.send_client_reports == false then
      return
   end
   if self.rate_limiter:is_limited({"internal"}) then
      return
   end
   local report = self:build_client_report()
   if report == "" then
      return
   end
   local _ok, _err, status, headers = (self.transport as any):send_envelope(report, {"internal"})
   if status and (status as number) > 0 then
      self.rate_limiter:update_from_response(status as number, headers as {string: string})
   end
end

-- Send the current session as a `session` envelope item. After the first send
-- subsequent updates are no longer marked as the initial session update.
function Client:capture_session()
   if not self.session then
      return
   end
   local body = envelope.build_session_envelope((self.session as any):to_payload())
   self:enqueue(body, {"session"})
   (self.session as {string: any})["init"] = false
end

-- Update the session for an outgoing event: count errors and, for unhandled
-- crashes, mark the session crashed and flush it immediately.
function Client:note_session_error(event: table)
   if not self.session then
      return
   end
   local e = event as {string: any}
   local level = e["level"] as string
   local is_error = level == "error" or level == "fatal" or e["exception"] ~= nil
   if not is_error then
      return
   end

   local s = self.session as {string: any}
   s["errors"] = ((s["errors"] as number) or 0) + 1

   local exc = e["exception"] as {string: any}
   if exc and exc["values"] then
      local vals = exc["values"] as {any}
      local first = vals[1] as {string: any}
      if first and first["mechanism"] then
         local mech = first["mechanism"] as {string: any}
         -- Only unhandled == crash where the host actually dies on it. In WoW the
         -- client catches the error and keeps running, so mark_unhandled_as_crash
         -- is false there and the error just increments the session error count.
         if mech["handled"] == false and self.options.mark_unhandled_as_crash ~= false then
            s["status"] = "crashed"
            self:capture_session()
         end
      end
   end
end

-- A persistable snapshot of the current session, so a host that can crash
-- between runs (WoW, consoles) can store it and, on next launch, resurrect and
-- terminate it (see report_previous_session). Returns nil if no session.
function Client:get_session_snapshot(): table
   if not self.session then
      return nil
   end
   local s = self.session as {string: any}
   return {
      sid = s["sid"],
      did = s["did"],
      started = s["started"],
      errors = s["errors"],
      status = s["status"],
      release = s["release"],
      environment = s["environment"]
   } as table
end

-- Re-emit a session recovered from persistence with a terminal status (usually
-- "crashed" or "abnormal" for a run that never exited cleanly). Reuses the stored
-- sid so Sentry transitions the SAME session rather than counting a new one.
function Client:report_previous_session(record: table, status: string)
   if not self.enabled or not record then
      return
   end
   local Session = require("sentry.core.session")
   local r = record as {string: any}
   local s = Session.new(
      r["did"] as string,
      (r["release"] as string) or self.options.release,
      (r["environment"] as string) or self.options.environment)
   if r["sid"] then (s as {string: any})["sid"] = r["sid"] end
   if r["started"] then (s as {string: any})["started"] = r["started"] end
   ;(s as {string: any})["errors"] = (r["errors"] as number) or 0
   ;(s as {string: any})["status"] = status or (r["status"] as string) or "abnormal"
   ;(s as {string: any})["init"] = false
   local body = envelope.build_session_envelope((s as any):to_payload())
   self:enqueue(body, {"session"})
end

-- Record a discarded event for client reports, keyed by reason + data category.
function Client:record_discarded(reason: string, categories: {string})
   if not self.discarded then
      self.discarded = {}
   end
   local cats = categories
   if not cats or #cats == 0 then
      cats = {"default"}
   end
   for _, cat in ipairs(cats) do
      local key = reason .. ":" .. cat
      self.discarded[key] = (self.discarded[key] or 0) + 1
   end
end

-- Drain queued envelopes to the transport. Stops when the queue is empty or,
-- if timeout_ms is given, when the (best-effort) time budget is exceeded.
-- Honors rate limits (dropping suppressed envelopes, never retrying) and
-- updates the limiter from each response. Returns true if fully drained.
function Client:drain(timeout_ms: number): boolean
   local deadline = timeout_ms and (time.now_ms() + timeout_ms) or nil
   while self.queue:size() > 0 do
      if deadline and time.now_ms() > deadline then
         return false
      end
      local item = self.queue:peek()

      if self.rate_limiter:is_limited(item.categories) then
         -- Rate limited: drop without retrying and record a client report.
         self.queue:dequeue()
         self:record_discarded("ratelimit_backoff", item.categories)
      else
         local ok, err, status, headers = (self.transport as any):send_envelope(item.payload, item.categories)
         self.queue:dequeue()
         if status and (status as number) > 0 then
            -- Request reached Sentry; apply any rate limits it returned. Server-side
            -- drops (including 429) are handled by Sentry, not counted as client discards.
            self.rate_limiter:update_from_response(status as number, headers as {string: string})
         elseif not ok then
            -- Could not reach Sentry at all.
            self:record_discarded("network_error", item.categories)
         end
         if not ok and self.options.debug then
            print("[Sentry] Failed to send envelope: " .. tostring(err))
         end
      end
   end

   -- Queue is empty: opportunistically ship any accumulated client reports.
   self:flush_client_reports()
   return true
end

-- Enqueue an envelope. If a scheduler is configured, draining is deferred to it
-- (OpenResty timer, Roblox task, a Love2D update tick, ...); otherwise it drains
-- synchronously.
function Client:enqueue(payload: string, categories: {string})
   self.queue:enqueue(payload, categories)
   if self.options.scheduler then
      self.options.scheduler(function()
         self:drain(nil)
      end)
   else
      self:drain(nil)
   end
end

-- Deliver any queued envelopes. Blocks up to timeout_ms (best effort) and also
-- flushes transport-side buffers. Returns true if everything was delivered.
function Client:flush(timeout_ms: number): boolean
   local drained = self:drain(timeout_ms)
   local t = self.transport as any
   if t and t.flush then
      pcall(function()
         t:flush()
      end)
   end
   return drained
end

-- Attach the active distributed-tracing context to an event, if any. Kept out
-- of the scope layer so scopes stay pure data.
function Client:apply_trace_context(event: table): table
   local ok, tracing = pcall(require, "sentry.tracing.propagation")
   if ok and tracing and tracing.get_current_context then
      local trace_context = tracing.get_current_context()
      if trace_context then
         (event as any).contexts = (event as any).contexts or {}
         (event as any).contexts.trace = {
            trace_id = trace_context.trace_id,
            span_id = trace_context.span_id,
            parent_span_id = trace_context.parent_span_id
         }
      end
   end
   return event
end

-- Run the tail of a capture (scopes, before_send, enqueue) under pcall so that
-- an internal error never propagates into the host application, and the SDK
-- never captures its own exceptions.
function Client:_dispatch(event: table, kind: string): string
   local ok, result = pcall(function(): string
      -- Error sampling: drop a fraction of events (client report reason "sample_rate").
      local rate = self.options.sample_rate
      if rate ~= nil and rate < 1 then
         if rate <= 0 or math.random() >= rate then
            self:record_discarded("sample_rate", {"error"})
            return ""
         end
      end

      local ev = self.scopes:apply_to_event(event)
      ev = self:apply_trace_context(ev)

      -- Inbound filters: ignore_errors (message/exception) and deny_urls (filenames).
      if self.options.ignore_errors and event_matches_ignore(ev, self.options.ignore_errors) then
         self:record_discarded("event_processor", {"error"})
         return ""
      end
      if self.options.deny_urls and event_matches_deny_urls(ev, self.options.deny_urls) then
         self:record_discarded("event_processor", {"error"})
         return ""
      end

      if self.options.before_send then
         local filtered = self.options.before_send(ev as any)
         if not filtered then
            return ""
         end
         ev = filtered as table
      end

      -- Update release-health session (error count / crash detection).
      self:note_session_error(ev)

      -- Data scrubbing runs last, so it applies regardless of before_send.
      ev = scrubber.scrub_event(ev, self.options as table)

      local body = envelope.build_event_envelope(ev, (self.scope as any).attachments)
      self:enqueue(body, {"error"})

      if self.options.debug then
         print("[Sentry] " .. kind .. " queued: " .. tostring((ev as any).event_id))
      end
      return (ev as any).event_id as string
   end)

   if not ok then
      if self.options.debug then
         print("[Sentry] Internal error during capture: " .. tostring(result))
      end
      return ""
   end
   return result as string
end

-- Decide whether a transaction should be sampled. Uses traces_sampler if set,
-- otherwise traces_sample_rate. With neither configured, transactions are not
-- sent (tracing is opt-in), unless the incoming trace was explicitly sampled.
function Client:_sample_transaction(transaction: table): boolean
   local t = transaction as {string: any}
   local rate: number = nil

   if self.options.traces_sampler then
      local ctx: {string: any} = {
         name = t["transaction"],
         op = ((t["contexts"] as {string: any}) and ((t["contexts"] as {string: any})["trace"] as {string: any})) and (((t["contexts"] as {string: any})["trace"] as {string: any})["op"]) or nil
      }
      rate = self.options.traces_sampler(ctx as table) as number
   else
      rate = self.options.traces_sample_rate
   end

   if rate == nil then
      return false
   end
   if rate <= 0 then
      return false
   end
   if rate >= 1 then
      return true
   end
   return math.random() < rate
end

-- Build the frozen Dynamic Sampling Context that travels in the envelope `trace`
-- header (and, for propagation, the baggage header).
function Client:dynamic_sampling_context(transaction: table, sampled: boolean): {string: any}
   local t = transaction as {string: any}
   local dsc: {string: any} = {}

   local contexts = t["contexts"] as {string: any}
   if contexts and contexts["trace"] then
      local tid = (contexts["trace"] as {string: any})["trace_id"]
      if tid then
         dsc["trace_id"] = tid
      end
   end
   if self.public_key then
      dsc["public_key"] = self.public_key
   end
   if self.options.environment then
      dsc["environment"] = self.options.environment
   end
   if self.options.release then
      dsc["release"] = self.options.release
   end
   if self.options.traces_sample_rate ~= nil then
      dsc["sample_rate"] = tostring(self.options.traces_sample_rate)
   end
   dsc["sampled"] = sampled and "true" or "false"
   if t["transaction"] then
      dsc["transaction"] = t["transaction"]
   end
   return dsc
end

-- Capture a finished transaction as a `transaction` envelope item.
function Client:capture_transaction(transaction: table): string
   if not self:is_enabled() then
      return ""
   end

   if not self:_sample_transaction(transaction) then
      self:record_discarded("sample_rate", {"transaction"})
      return ""
   end

   local ok, result = pcall(function(): string
      local ev = self.scopes:apply_to_event(transaction) as {string: any}

      if self.options.before_send_transaction then
         local filtered = self.options.before_send_transaction(ev as table)
         if not filtered then
            return ""
         end
         ev = filtered as {string: any}
      end

      ev = scrubber.scrub_event(ev as table, self.options as table) as {string: any}

      local dsc = self:dynamic_sampling_context(transaction, true)
      local event_id = (ev["event_id"] as string) or ""
      local body = envelope.build_transaction_envelope(ev as table, event_id, dsc)
      self:enqueue(body, {"transaction"})
      return event_id
   end)

   if not ok then
      if self.options.debug then
         print("[Sentry] Internal error capturing transaction: " .. tostring(result))
      end
      return ""
   end
   return result as string
end

function Client:capture_message(message: string, level: string): string
   if not self:is_enabled() then
      return ""
   end

   level = level or "info"
   -- Messages only carry a stack trace when attach_stacktrace is enabled.
   local stack_trace: table = nil
   if self.options.attach_stacktrace then
      stack_trace = stacktrace.get_stack_trace(1)
   end
   local event = serialize.create_event(level, message, self.options.environment or "production", self.options.release, stack_trace)
   return self:_dispatch(event as table, "Event")
end

-- Capture an exception. `exception` may be a native Lua error (string), a table
-- with type/value/message, or any other value. `hint.mechanism` overrides the
-- default mechanism (used by automatic/unhandled handlers to set handled=false).
function Client:capture_exception(exception: any, level: string, hint: table): string
   if not self:is_enabled() then
      return ""
   end

   level = level or "error"
   local stack_trace = stacktrace.get_stack_trace(1)

   -- Normalize the value into an exception type + value.
   local ex_type = "Error"
   local ex_value = "Unknown error"
   if type(exception) == "string" then
      ex_value = exception as string
   elseif type(exception) == "table" then
      local t = exception as {string: any}
      ex_type = (t["type"] as string) or "Error"
      ex_value = (t["value"] as string) or (t["message"] as string) or "Unknown error"
   else
      ex_value = tostring(exception)
   end

   local mechanism: {string: any} = { type = "generic", handled = true }
   if hint and (hint as {string: any})["mechanism"] then
      mechanism = (hint as {string: any})["mechanism"] as {string: any}
   end

   local event = serialize.create_event(level, ex_value, self.options.environment or "production", self.options.release, stack_trace)
   (event as any).exception = {
      values = {{
         type = ex_type,
         value = ex_value,
         stacktrace = stack_trace,
         mechanism = mechanism
      }}
   }
   return self:_dispatch(event as table, "Exception")
end

function Client:add_breadcrumb(breadcrumb: table)
   if self.options.before_breadcrumb then
      local bc = self.options.before_breadcrumb(breadcrumb)
      if not bc then
         return
      end
      breadcrumb = bc as table
   end
   self.scope:add_breadcrumb(breadcrumb)
end

function Client:set_user(user: table)
   self.scope:set_user(user)
end

function Client:set_tag(key: string, value: string)
   self.scope:set_tag(key, value)
end

function Client:set_extra(key: string, value: any)
   self.scope:set_extra(key, value)
end

function Client:set_context(key: string, value: any)
   self.scope:set_context(key, value)
end

-- Attach a file/blob to subsequent events. `attachment_type` defaults to
-- "event.attachment" (use e.g. "event.view_hierarchy" for screenshots).
-- Oversized attachments (> max_attachment_size, default 20 MiB) are dropped.
function Client:add_attachment(filename: string, data: string, content_type: string, attachment_type: string)
   local max = self.options.max_attachment_size or (20 * 1024 * 1024)
   if data and #data > max then
      if self.options.debug then
         print("[Sentry] Attachment '" .. tostring(filename) .. "' exceeds max_attachment_size, dropping")
      end
      return
   end
   self.scope:add_attachment({
      filename = filename,
      data = data,
      content_type = content_type,
      attachment_type = attachment_type
   })
end

function Client:set_fingerprint(fingerprint: {string})
   self.scope:set_fingerprint(fingerprint)
end

function Client:close(timeout_ms: number): boolean
   -- End a clean session on shutdown (a crash already sent a terminal update).
   if self.session then
      local s = self.session as {string: any}
      if s["status"] == "ok" then
         s["status"] = "exited"
         self:capture_session()
      end
   end
   local drained = self:flush(timeout_ms)
   self.enabled = false
   return drained
end

return Client