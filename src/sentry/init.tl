local Client = require("sentry.core.client")
local Scope = require("sentry.core.scope")
local config_utils = require("sentry.utils.config")

local record Sentry
   _client: Client
   init: function(table): Client
   capture_message: function(string, string): string
   capture_exception: function(any, string, table): string
   start_transaction: function(string, string, table): any
   capture_transaction: function(table): string
   continue_trace: function(table): any
   get_trace_data: function(string): table
   add_breadcrumb: function(table)
   set_user: function(table)
   set_tag: function(string, string)
   set_extra: function(string, any)
   set_context: function(string, any)
   set_fingerprint: function({string})
   add_attachment: function(string, string, string, string)
   flush: function(number): boolean
   close: function(number): boolean
   with_scope: function(function(Scope))
   with_isolation_scope: function(function(Scope))
   configure_scope: function(function(Scope))
   wrap: function(function, function): boolean, any
end

local sentry: Sentry = {}

local function init(config: table): Client
   -- Merge environment variables (SENTRY_DSN/RELEASE/ENVIRONMENT/DEBUG); explicit
   -- options win. An empty or missing DSN is valid: the SDK initializes disabled
   -- and every capture API becomes a safe no-op (per the SDK spec).
   config = config_utils.resolve(config)
   sentry._client = Client:new(config as any)
   return sentry._client
end

local function capture_message(message: string, level: string): string
   if not sentry._client then
      error("Sentry not initialized. Call sentry.init() first.")
   end
   
   return sentry._client:capture_message(message, level)
end

local function capture_exception(exception: any, level: string, hint: table): string
   if not sentry._client then
      error("Sentry not initialized. Call sentry.init() first.")
   end

   return sentry._client:capture_exception(exception, level, hint)
end

local function start_transaction(name: string, op: string, options: table): any
   -- Use a non-literal module name so the type checker does not statically
   -- follow this require, which would form a cycle (init -> tracing ->
   -- performance -> sentry) that crashes the checker.
   local mod = "sentry.tracing"
   local tracing = require(mod) as any
   return (tracing as any).start_transaction(name, op, options as any)
end

local function capture_transaction(transaction: table): string
   if sentry._client then
      return sentry._client:capture_transaction(transaction)
   end
   return ""
end

-- Continue a distributed trace from incoming request headers (sentry-trace/baggage).
local function continue_trace(request_headers: table): any
   local m = "sentry.tracing"
   local tracing = require(m) as any
   return (tracing as any).continue_trace_from_request(request_headers)
end

-- Get trace headers (sentry-trace + baggage) to propagate to an outgoing request.
local function get_trace_data(target_url: string): table
   local m = "sentry.tracing"
   local tracing = require(m) as any
   return (tracing as any).get_request_headers(target_url)
end

local function add_breadcrumb(breadcrumb: table)
   if sentry._client then
      sentry._client:add_breadcrumb(breadcrumb)
   end
end

local function set_user(user: table)
   if sentry._client then
      sentry._client:set_user(user)
   end
end

local function set_tag(key: string, value: string)
   if sentry._client then
      sentry._client:set_tag(key, value)
   end
end

local function set_extra(key: string, value: any)
   if sentry._client then
      sentry._client:set_extra(key, value)
   end
end

-- Deliver queued events, blocking up to timeout_ms (best effort).
-- Returns true if everything was delivered.
local function flush(timeout_ms: number): boolean
   if sentry._client then
      return sentry._client:flush(timeout_ms)
   end
   return true
end

-- Snapshot the current release-health session for persistence (sandboxed hosts
-- that can crash between runs). Returns nil if session tracking is off.
local function get_session_snapshot(): table
   if sentry._client then
      return sentry._client:get_session_snapshot()
   end
   return nil
end

-- Re-emit a persisted session with a terminal status (e.g. "crashed") — used on
-- next launch to close out a run that never exited cleanly.
local function report_previous_session(record: table, status: string)
   if sentry._client then
      sentry._client:report_previous_session(record, status)
   end
end

-- Flush and shut down the client.
local function close(timeout_ms: number): boolean
   local drained = true
   if sentry._client then
      drained = sentry._client:close(timeout_ms)
      sentry._client = nil
   end
   return drained
end

-- Run a callback with a forked *current* scope. Changes made inside are visible
-- to events captured within the callback and discarded afterwards.
local function with_scope(callback: function(scope: Scope))
   if not sentry._client then
      error("Sentry not initialized. Call sentry.init() first.")
   end

   local scopes = sentry._client.scopes
   local saved = scopes.current
   scopes.current = saved:clone()

   local success, result = pcall(callback, scopes.current)

   scopes.current = saved

   if not success then
      error(result as any)
   end
end

-- Run a callback with a forked *isolation* scope (e.g. per request / per task).
-- Data set inside is visible to events captured within, and discarded afterwards.
local function with_isolation_scope(callback: function(scope: Scope))
   if not sentry._client then
      error("Sentry not initialized. Call sentry.init() first.")
   end

   local scopes = sentry._client.scopes
   local saved = scopes.isolation
   scopes.isolation = saved:clone()
   sentry._client.scope = scopes.isolation   -- keep the alias in sync

   local success, result = pcall(callback, scopes.isolation)

   scopes.isolation = saved
   sentry._client.scope = saved

   if not success then
      error(result as any)
   end
end

-- Mutate the isolation scope persistently (top-level context).
local function configure_scope(callback: function(scope: Scope))
   if sentry._client then
      callback(sentry._client.scopes.isolation)
   end
end

local function set_context(key: string, value: any)
   if sentry._client then
      sentry._client:set_context(key, value)
   end
end

local function set_fingerprint(fingerprint: {string})
   if sentry._client then
      sentry._client:set_fingerprint(fingerprint)
   end
end

local function add_attachment(filename: string, data: string, content_type: string, attachment_type: string)
   if sentry._client then
      sentry._client:add_attachment(filename, data, content_type, attachment_type)
   end
end

local function wrap(main_function: function, error_handler: function): boolean, any
   if not sentry._client then
      error("Sentry not initialized. Call sentry.init() first.")
   end
   
   -- Default error handler that captures to Sentry
   local function default_error_handler(err: any): any
      -- Add breadcrumb for the unhandled error
      add_breadcrumb({
         message = "Unhandled error occurred",
         category = "error", 
         level = "error",
         data = {
            error_message = tostring(err)
         }
      })
      
      -- Capture the exception as unhandled (mechanism.handled = false)
      capture_exception(err, "fatal", {
         mechanism = { type = "generic", handled = false }
      })
      
      -- If user provided custom error handler, call it and return its result
      if error_handler then
         return error_handler(err)
      end
      
      -- Return the error for the caller to handle (don't re-throw to avoid infinite loop)
      return tostring(err)
   end
   
   return xpcall(main_function, default_error_handler)
end

-- Set up the sentry module functions
sentry.init = init
sentry.capture_message = capture_message
sentry.capture_exception = capture_exception
sentry.start_transaction = start_transaction
sentry.capture_transaction = capture_transaction
sentry.continue_trace = continue_trace
sentry.get_trace_data = get_trace_data
sentry.add_breadcrumb = add_breadcrumb
sentry.set_user = set_user
sentry.set_tag = set_tag
sentry.set_extra = set_extra
sentry.set_context = set_context
sentry.set_fingerprint = set_fingerprint
sentry.add_attachment = add_attachment
sentry.flush = flush
sentry.close = close
sentry.get_session_snapshot = get_session_snapshot
sentry.report_previous_session = report_previous_session
sentry.with_scope = with_scope
sentry.with_isolation_scope = with_isolation_scope
sentry.configure_scope = configure_scope
sentry.wrap = wrap

return sentry