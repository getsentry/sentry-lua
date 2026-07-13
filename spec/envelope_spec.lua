-- Envelope construction / (de)serialization unit tests
local envelope = require("sentry.utils.envelope")
local json = require("sentry.utils.json")

describe("Envelope", function()

   describe("build_event_envelope", function()
      it("produces header, item header and payload lines", function()
         local event = {event_id = "abc123", message = "hello", level = "error"}
         local body = envelope.build_event_envelope(event)

         local lines = {}
         for line in (body .. "\n"):gmatch("(.-)\n") do
            table.insert(lines, line)
         end

         assert.equals(3, #lines)

         local env_header = json.decode(lines[1])
         assert.equals("abc123", env_header.event_id)
         assert.is_string(env_header.sent_at)

         local item_header = json.decode(lines[2])
         assert.equals("event", item_header.type)
         assert.equals(#lines[3], item_header.length)

         local payload = json.decode(lines[3])
         assert.equals("hello", payload.message)
      end)
   end)

   describe("parse / extract_items", function()
      it("round-trips an event envelope", function()
         local event = {event_id = "deadbeef", message = "boom"}
         local body = envelope.build_event_envelope(event)

         local parsed = envelope.parse(body)
         assert.equals("deadbeef", parsed.header.event_id)
         assert.equals(1, #parsed.items)
         assert.equals("event", parsed.items[1].header.type)

         local events = envelope.extract_items(body, "event")
         assert.equals(1, #events)
         assert.equals("boom", events[1].message)
      end)

      it("is safe on empty / malformed input", function()
         assert.same({}, envelope.parse("").items)
         assert.same({}, envelope.parse("not json").items)
      end)
   end)

   describe("categories", function()
      it("maps event -> error", function()
         local env = envelope.new_envelope({})
         envelope.add_item(env, "event", {event_id = "x"})
         assert.same({"error"}, envelope.categories(env))
      end)

      it("deduplicates categories", function()
         local env = envelope.new_envelope({})
         envelope.add_item(env, "event", {event_id = "x"})
         envelope.add_item(env, "event", {event_id = "y"})
         envelope.add_item(env, "transaction", {event_id = "z"})
         assert.same({"error", "transaction"}, envelope.categories(env))
      end)
   end)

   describe("data_category", function()
      it("maps known types and passes through unknown", function()
         assert.equals("error", envelope.data_category("event"))
         assert.equals("transaction", envelope.data_category("transaction"))
         assert.equals("session", envelope.data_category("session"))
         assert.equals("attachment", envelope.data_category("attachment"))
         assert.equals("something_new", envelope.data_category("something_new"))
      end)
   end)

   describe("build_log_envelope", function()
      it("includes item_count and content_type", function()
         local logs = {
            {level = "info", body = "one"},
            {level = "warn", body = "two"},
         }
         local body = envelope.build_log_envelope(logs)

         local lines = {}
         for line in (body .. "\n"):gmatch("(.-)\n") do
            table.insert(lines, line)
         end

         local item_header = json.decode(lines[2])
         assert.equals("log", item_header.type)
         assert.equals(2, item_header.item_count)
         assert.equals("application/vnd.sentry.items.log+json", item_header.content_type)
      end)

      it("returns empty string when there are no records", function()
         assert.equals("", envelope.build_log_envelope({}))
      end)
   end)

   describe("build_client_report_envelope", function()
      it("emits a client_report item with discarded_events", function()
         local body = envelope.build_client_report_envelope({
            {reason = "ratelimit_backoff", category = "error", quantity = 3},
         })
         local parsed = envelope.parse(body)
         assert.equals("client_report", parsed.items[1].header.type)

         local reports = envelope.extract_items(body, "client_report")
         assert.equals(3, reports[1].discarded_events[1].quantity)
         assert.equals("error", reports[1].discarded_events[1].category)
      end)

      it("returns empty string when nothing was discarded", function()
         assert.equals("", envelope.build_client_report_envelope({}))
      end)
   end)

   describe("build_transaction_envelope", function()
      it("emits a transaction item", function()
         local body = envelope.build_transaction_envelope({transaction = "GET /"}, "txid")
         local parsed = envelope.parse(body)
         assert.equals("txid", parsed.header.event_id)
         assert.equals("transaction", parsed.items[1].header.type)
      end)
   end)
end)
