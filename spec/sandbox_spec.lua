-- Sandboxed spool transport + companion uploader tests
local persistence = require("sentry.core.persistence")
local uploader = require("sentry.uploader")
local sentry = require("sentry")
local envelope = require("sentry.utils.envelope")

describe("sandboxed spool + uploader", function()
   it("memory provider appends/reads/clears", function()
      local p = persistence.memory_provider()
      p.append("a")
      p.append("b")
      assert.same({"a", "b"}, p.read_all())
      assert.equals(2, p.size())
      p.clear()
      assert.equals(0, p.size())
   end)

   it("file provider round-trips envelopes with embedded newlines", function()
      local file_io = require("sentry.core.file_io")
      local io_impl = file_io.create_standard_file_io()
      local path = "/tmp/sentry-spool-test-" .. tostring(os.clock()) .. ".envelopes"
      local p = persistence.file_provider(io_impl, path, 100)
      p.clear()
      p.append("line1\nline2\nline3")   -- an envelope contains newlines
      p.append("second")
      local all = p.read_all()
      assert.equals(2, #all)
      assert.equals("line1\nline2\nline3", all[1])
      assert.equals("second", all[2])
      os.remove(path)
   end)

   it("spool transport writes real envelopes to the provider", function()
      local p = persistence.memory_provider()
      local client = sentry.init({dsn = "https://pub@h/1", spool = true, persistence_provider = p})
      sentry.capture_message("spooled event")

      assert.is_true(p.size() >= 1)
      local events = envelope.extract_items(p.read_all()[1], "event")
      assert.equals("spooled event", events[1].message)
   end)

   it("uploader drains the spool and posts to the envelope endpoint", function()
      local p = persistence.memory_provider()
      p.append("envelope-1")
      p.append("envelope-2")

      local posted = {}
      local fake_http = {
         request = function(req)
            table.insert(posted, req)
            return {success = true, status = 200, body = "", headers = {}}
         end
      }
      local result = uploader.upload(p, "https://pub@o1.ingest.sentry.io/123", fake_http)

      assert.equals(2, result.sent)
      assert.equals(2, result.total)
      assert.equals(0, p.size())  -- cleared only after full delivery
      assert.matches("/api/123/envelope/", posted[1].url)
      assert.matches("sentry_key=pub", posted[1].headers["X-Sentry-Auth"])
   end)

   it("uploader retains the spool when a send fails", function()
      local p = persistence.memory_provider()
      p.append("e1")
      local fake_http = {
         request = function() return {success = false, status = 500, body = "", headers = {}} end
      }
      local result = uploader.upload(p, "https://pub@h/1", fake_http)
      assert.equals(0, result.sent)
      assert.equals(1, p.size())
   end)

   it("uploader removes only the delivered prefix on partial delivery", function()
      local p = persistence.memory_provider()
      p.append("e1")
      p.append("e2")
      p.append("e3")
      local n = 0
      local fake_http = {
         request = function()
            n = n + 1
            -- first two succeed, third fails
            if n <= 2 then
               return {success = true, status = 200, body = "", headers = {}}
            end
            return {success = false, status = 500, body = "", headers = {}}
         end
      }
      local result = uploader.upload(p, "https://pub@h/1", fake_http)
      assert.equals(2, result.sent)
      assert.equals(1, p.size())          -- e3 retained
      assert.same({"e3"}, p.read_all())
   end)

   it("roblox datastore provider round-trips through Get/SetAsync", function()
      local roblox = require("sentry.platforms.roblox.integration")
      local stored = nil
      local datastore = {
         GetAsync = function(_self, _key) return stored end,
         SetAsync = function(_self, _key, value) stored = value end,
      }
      local p = roblox.datastore_provider(datastore, "sentry")
      p.append("env-1")
      p.append("env-2")
      assert.equals(2, p.size())
      p.remove_first(1)
      assert.same({"env-2"}, p.read_all())
   end)
end)
