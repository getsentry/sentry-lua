-- Trace-connected metrics (trace_metric) tests
local sentry = require("sentry")
local metrics = require("sentry.metrics")
local envelope = require("sentry.utils.envelope")

local function metric_items(client)
   for _, body in ipairs(client.transport:get_envelopes()) do
      local items = envelope.extract_items(body, "trace_metric")
      if #items > 0 then
         return items[1].items
      end
   end
   return nil
end

describe("metrics", function()
   it("buffers and flushes a trace_metric envelope independently of logs", function()
      local client = sentry.init({dsn = "https://t@h/1", test_transport = true})
      metrics.init({enable_metrics = true, max_buffer_size = 100, flush_timeout = 0})

      metrics.increment("clicks", 2, {attributes = {screen = "home"}})
      metrics.gauge("fps", 60)
      metrics.distribution("latency_ms", 12.5)
      assert.equals(3, metrics.buffer_size())

      metrics.flush()
      assert.equals(0, metrics.buffer_size())

      local items = metric_items(client)
      assert.is_not_nil(items)
      assert.equals(3, #items)
      assert.equals("clicks", items[1].name)
      assert.equals("counter", items[1].type)
      assert.equals(2, items[1].value)
      assert.equals("gauge", items[2].type)
      assert.equals("distribution", items[3].type)
      -- Every metric is trace-connected
      assert.is_not_nil(items[1].trace_id)
   end)

   it("does nothing when metrics are disabled", function()
      local client = sentry.init({dsn = "https://t@h/1", test_transport = true})
      metrics.init({enable_metrics = false})
      metrics.increment("x", 1)
      metrics.flush()
      assert.is_nil(metric_items(client))
   end)
end)
