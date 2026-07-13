-- WoW integration tests (mocked WoW API globals)
local sentry = require("sentry")
local wow = require("sentry.platforms.wow.integration")

describe("WoW integration", function()
   local orig = {}

   before_each(function()
      orig.GetBuildInfo = _G.GetBuildInfo
      orig.C_AddOns = _G.C_AddOns
      orig.GetLocale = _G.GetLocale
      orig.GetRealmName = _G.GetRealmName

      _G.GetBuildInfo = function() return "10.2.5", "53040", "2024-01-16", 100205 end
      _G.GetLocale = function() return "enUS" end
      _G.GetRealmName = function() return "Silvermoon" end
      _G.C_AddOns = {
         GetNumAddOns = function() return 2 end,
         GetAddOnInfo = function(i) if i == 1 then return "Details" else return "WeakAuras" end end,
         GetAddOnMetadata = function(name) if name == "Details" then return "1.2.3" else return "5.0" end end,
         IsAddOnLoaded = function() return true end,
      }
   end)

   after_each(function()
      _G.GetBuildInfo = orig.GetBuildInfo
      _G.C_AddOns = orig.C_AddOns
      _G.GetLocale = orig.GetLocale
      _G.GetRealmName = orig.GetRealmName
   end)

   it("attaches rich game + addon context and tags out of the box", function()
      local client = sentry.init({
         dsn = "https://t@h/1", test_transport = true,
         integrations = {wow.integration()}
      })
      sentry.capture_message("from wow")

      local e = client.transport:get_events()[1]
      assert.equals("World of Warcraft", e.contexts.game.name)
      assert.equals("10.2.5", e.contexts.game.version)
      assert.equals("53040", e.contexts.game.build)
      assert.equals("Silvermoon", e.contexts.server.realm)
      assert.equals(2, e.contexts.addons.count)
      assert.equals("Details", e.contexts.addons.loaded[1].name)
      assert.equals("1.2.3", e.contexts.addons.loaded[1].version)
      assert.equals(true, e.contexts.addons.loaded[1].loaded)

      assert.equals("10.2.5", e.tags["wow.version"])
      assert.equals("2", e.tags["wow.addons"])
      assert.equals("enUS", e.tags["wow.locale"])
   end)

   it("spools envelopes to a SavedVariables provider (no network)", function()
      local db = {}
      sentry.init({
         dsn = "https://t@h/1", spool = true,
         persistence_provider = wow.saved_variables_provider(db),
         integrations = {wow.integration()}
      })
      sentry.capture_message("wow crash")
      assert.is_true(#db.envelopes >= 1)
   end)

   it("implements the full PersistenceProvider contract (remove_first)", function()
      -- The companion uploader drains via remove_first(n); without it a
      -- successful upload calls a nil field and the spool never prunes.
      local db = {}
      local p = wow.saved_variables_provider(db)
      p.append("a"); p.append("b"); p.append("c")
      assert.equals(3, p.size())
      assert.is_function(p.remove_first)
      p.remove_first(2)                       -- drop the delivered prefix
      assert.same({ "c" }, p.read_all())
      assert.equals(1, p.size())
      p.remove_first(5)                       -- over-drain is a no-op past the end
      assert.equals(0, p.size())
   end)

   it("bounds SavedVariables growth by evicting the oldest past max_records", function()
      local db = {}
      local p = wow.saved_variables_provider(db, 3)   -- cap the ring at 3
      for i = 1, 5 do p.append("e" .. i) end
      assert.equals(3, p.size())
      assert.same({ "e3", "e4", "e5" }, p.read_all())  -- oldest two evicted
   end)

   it("spools without a DSN (WoW addons never carry one; the uploader supplies it)", function()
      -- Spool mode must stay enabled without a DSN, else every capture is a
      -- silent no-op in-game. Regression guard for is_enabled() spool-awareness.
      local db = {}
      local client = sentry.init({
         spool = true,                       -- note: no dsn
         persistence_provider = wow.saved_variables_provider(db),
         integrations = {wow.integration()}
      })
      assert.is_true(client:is_enabled())
      sentry.capture_message("no-dsn crash")
      sentry.flush(1000)
      assert.is_true(#db.envelopes >= 1)
   end)
end)
