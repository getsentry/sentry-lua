-- Factorio integration tests (mocked Factorio globals)
local sentry = require("sentry")
local factorio = require("sentry.platforms.factorio.integration")

describe("Factorio integration", function()
   local orig_script

   before_each(function()
      orig_script = _G.script
      _G.script = { active_mods = { base = "1.1.109", ["my-mod"] = "0.4.2" } }
   end)

   after_each(function()
      _G.script = orig_script
   end)

   it("attaches the Factorio version and active mod list", function()
      local client = sentry.init({
         dsn = "https://t@h/1", test_transport = true,
         integrations = {factorio.integration()}
      })
      sentry.capture_message("from factorio")

      local e = client.transport:get_events()[1]
      assert.equals("Factorio", e.contexts.game.name)
      assert.equals("1.1.109", e.contexts.game.version)
      assert.equals(2, e.contexts.mods.count)
      assert.equals("1.1.109", e.tags["factorio.version"])
      assert.equals("2", e.tags["factorio.mods"])
   end)
end)
