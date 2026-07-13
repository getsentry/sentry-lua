---@class sentry.metrics
--- Trace-connected metrics (the new `trace_metric` API): counters, gauges and
--- distributions. Buffered and flushed on its OWN cadence, fully independent of
--- structured logs, so the two telemetry streams batch and ship separately.

local envelope = require("sentry.utils.envelope")
local utils = require("sentry.utils")

local record MetricRecord
   timestamp: number
   trace_id: string
   name: string
   type: string          -- counter | gauge | distribution
   value: number
   unit: string
   attributes: {string: any}
end

local record MetricsConfig
   enable_metrics: boolean
   max_buffer_size: integer
   flush_timeout: number
   before_send_metric: function(MetricRecord): MetricRecord
end

local metrics = {}

-- Module-local state, independent from the logger's buffer.
local buffer: {MetricRecord} = {}
local config: MetricsConfig = nil
local last_flush = 0
local is_initialized = false

---Initialize the metrics stream.
---@param user_config MetricsConfig?
function metrics.init(user_config: MetricsConfig)
   config = {
      enable_metrics = (user_config and user_config.enable_metrics) or false,
      max_buffer_size = (user_config and user_config.max_buffer_size) or 100,
      flush_timeout = (user_config and user_config.flush_timeout) or 5.0,
      before_send_metric = user_config and user_config.before_send_metric
   }
   buffer = {}
   last_flush = os.time()
   is_initialized = true
end

-- Metrics are trace-connected: attach the current trace id, or a fresh one.
local function current_trace_id(): string
   local ok, tracing = pcall(require, "sentry.tracing")
   if ok and tracing then
      local info = (tracing as any).get_current_trace_info()
      if info and info.trace_id then
         return info.trace_id as string
      end
   end
   return (utils.generate_uuid():gsub("-", ""))
end

local function add(name: string, mtype: string, value: number, opts: {string: any})
   if not is_initialized or not config.enable_metrics then
      return
   end
   opts = opts or {}

   local attributes = (opts["attributes"] as {string: any}) or (opts["tags"] as {string: any}) or {}
   local record: MetricRecord = {
      timestamp = os.time() + (os.clock() % 1),
      trace_id = current_trace_id(),
      name = name,
      type = mtype,
      value = value,
      unit = opts["unit"] as string,
      attributes = attributes
   }

   if config.before_send_metric then
      record = config.before_send_metric(record)
      if not record then
         return
      end
   end

   table.insert(buffer, record)

   if #buffer >= config.max_buffer_size then
      metrics.flush()
   elseif config.flush_timeout > 0 and (os.time() - last_flush) >= config.flush_timeout then
      metrics.flush()
   end
end

---Increment a counter (default value 1).
function metrics.increment(name: string, value: number, opts: {string: any})
   add(name, "counter", value or 1, opts)
end

---Record a gauge value.
function metrics.gauge(name: string, value: number, opts: {string: any})
   add(name, "gauge", value, opts)
end

---Record a distribution sample.
function metrics.distribution(name: string, value: number, opts: {string: any})
   add(name, "distribution", value, opts)
end

---Flush buffered metrics as a single `trace_metric` envelope through the client.
function metrics.flush()
   if #buffer == 0 then
      return
   end

   local records = buffer
   buffer = {}
   last_flush = os.time()

   local ok, sentry = pcall(require, "sentry")
   if not ok or not sentry._client then
      return
   end

   local body = envelope.build_metrics_envelope(records as {any})
   if body ~= "" then
      (sentry._client as any):enqueue(body, {"trace_metric"})
   end
end

---Current buffer size (for debugging/tests).
function metrics.buffer_size(): integer
   return #buffer
end

return metrics
