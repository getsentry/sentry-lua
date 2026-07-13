-- Platform global error-handler integrations + deny_urls filter
local sentry = require("sentry")

describe("Roblox integration", function()
   local captured_error_fn
   before_each(function()
      captured_error_fn = nil
      _G.game = {
         GameId = 100, PlaceId = 200, JobId = "job-1",
         GetService = function(_self, name)
            if name == "ScriptContext" then
               return { Error = { Connect = function(_s, fn) captured_error_fn = fn end } }
            end
            return nil
         end,
      }
   end)
   after_each(function() _G.game = nil end)

   it("adds place context and captures ScriptContext errors", function()
      local roblox = require("sentry.platforms.roblox.integration")
      local client = sentry.init({
         dsn = "https://t@h/1", test_transport = true,
         integrations = {roblox.integration()}
      })
      assert.is_function(captured_error_fn)
      captured_error_fn("Something broke", "stack trace here", nil)

      local e = client.transport:get_events()[1]
      assert.equals("Something broke", e.exception.values[1].value)
      assert.is_false(e.exception.values[1].mechanism.handled)
      assert.equals("200", e.tags["roblox.place_id"])
      assert.equals(200, e.contexts.roblox.place_id)
   end)
end)

describe("Defold integration", function()
   local captured_handler
   before_each(function()
      captured_handler = nil
      _G.sys = {
         get_engine_info = function() return { version = "1.6.4" } end,
         set_error_handler = function(fn) captured_handler = fn end,
      }
   end)
   after_each(function() _G.sys = nil end)

   it("adds runtime context and captures errors", function()
      local defold = require("sentry.platforms.defold.integration")
      local client = sentry.init({
         dsn = "https://t@h/1", test_transport = true,
         integrations = {defold.integration()}
      })
      assert.is_function(captured_handler)
      captured_handler("main.script", "boom", "traceback...")

      local e = client.transport:get_events()[1]
      assert.equals("boom", e.exception.values[1].value)
      assert.equals("defold", e.contexts.runtime.name)
      assert.equals("1.6.4", e.contexts.runtime.version)
   end)
end)

describe("nginx integration", function()
   before_each(function()
      _G.ngx = { var = { request_uri = "/api/users", request_method = "GET", server_name = "example.com" } }
   end)
   after_each(function() _G.ngx = nil end)

   it("adds request context and wrap() captures errors", function()
      local nginx = require("sentry.platforms.nginx.integration")
      local client = sentry.init({
         dsn = "https://t@h/1", test_transport = true,
         integrations = {nginx.integration()}
      })

      sentry.capture_message("check")
      local e = client.transport:get_events()[1]
      assert.equals("/api/users", e.contexts.request.url)
      assert.equals("example.com", e.tags.server_name)

      local wrapped = nginx.wrap(client, function() error("handler failed") end)
      assert.is_false(pcall(wrapped))
      assert.is_true(#client.transport:get_events() >= 2)
   end)
end)

describe("deny_urls filter", function()
   it("drops events whose stack frame filename matches", function()
      local client = sentry.init({
         dsn = "https://t@h/1", test_transport = true,
         deny_urls = {"platform_handlers_spec"}
      })
      sentry.capture_exception("boom")
      assert.equals(0, #client.transport:get_events())
   end)

   it("keeps events when no deny_url matches", function()
      local client = sentry.init({
         dsn = "https://t@h/1", test_transport = true,
         deny_urls = {"nonexistent_zzz"}
      })
      sentry.capture_exception("boom")
      assert.equals(1, #client.transport:get_events())
   end)
end)
