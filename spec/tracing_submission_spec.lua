-- Transaction submission (sampling + DSC) integration tests
local sentry = require("sentry")
local performance = require("sentry.performance")
local propagation = require("sentry.tracing.propagation")
local envelope = require("sentry.utils.envelope")

local function transaction_items(client)
   local names = {}
   local trace_header
   for _, body in ipairs(client.transport:get_envelopes()) do
      for _, t in ipairs(envelope.extract_items(body, "transaction")) do
         names[#names + 1] = t.transaction
         trace_header = envelope.parse(body).header.trace
      end
   end
   return names, trace_header
end

describe("transaction submission", function()
   before_each(function()
      propagation.clear_context()
   end)
   after_each(function()
      propagation.clear_context()
   end)

   it("submits a sampled transaction with a frozen DSC trace header", function()
      local client = sentry.init({
         dsn = "https://pub@h/1", test_transport = true,
         traces_sample_rate = 1, environment = "test", release = "1.0.0"
      })
      performance.start_transaction("GET /home", "http.server"):finish("ok")

      local names, trace = transaction_items(client)
      assert.same({"GET /home"}, names)
      assert.is_not_nil(trace)
      assert.equals("pub", trace.public_key)
      assert.equals("test", trace.environment)
      assert.equals("1.0.0", trace.release)
      assert.equals("true", trace.sampled)
      assert.equals("GET /home", trace.transaction)
   end)

   it("drops transactions when traces_sample_rate is 0", function()
      local client = sentry.init({dsn = "https://pub@h/1", test_transport = true, traces_sample_rate = 0})
      performance.start_transaction("dropped", "task"):finish("ok")
      local names = transaction_items(client)
      assert.equals(0, #names)
   end)

   it("does not send transactions when tracing is unconfigured", function()
      local client = sentry.init({dsn = "https://pub@h/1", test_transport = true})
      performance.start_transaction("unconfigured", "task"):finish("ok")
      local names = transaction_items(client)
      assert.equals(0, #names)
   end)

   it("propagates the DSC in the outbound baggage header", function()
      sentry.init({
         dsn = "https://pub@h/1", test_transport = true,
         environment = "prod", release = "1.0.0"
      })
      local tracing = require("sentry.tracing")
      tracing.start_trace()

      local data = sentry.get_trace_data("https://downstream.example.com")
      assert.is_not_nil(data["sentry-trace"])
      assert.is_not_nil(data["baggage"])
      assert.matches("sentry%-public_key=pub", data["baggage"])
      assert.matches("sentry%-environment=prod", data["baggage"])
      assert.matches("sentry%-release=1%.0%.0", data["baggage"])
   end)

   it("continue_trace picks up an incoming trace", function()
      sentry.init({dsn = "https://pub@h/1", test_transport = true})
      sentry.continue_trace({
         ["sentry-trace"] = "1234567890abcdef1234567890abcdef-abcdef1234567890-1"
      })
      local tracing = require("sentry.tracing")
      local info = tracing.get_current_trace_info()
      assert.equals("1234567890abcdef1234567890abcdef", info.trace_id)
   end)

   it("honors traces_sampler decisions", function()
      local client = sentry.init({
         dsn = "https://pub@h/1", test_transport = true,
         traces_sampler = function(ctx) return ctx.name == "keep" and 1 or 0 end
      })
      performance.start_transaction("keep", "task"):finish("ok")
      performance.start_transaction("drop", "task"):finish("ok")
      local names = transaction_items(client)
      assert.same({"keep"}, names)
   end)
end)
