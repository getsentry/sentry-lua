-- Config resolution (env vars + explicit options) unit tests
local config_utils = require("sentry.utils.config")

describe("config resolve", function()
   local function fake_env(map)
      return function(k) return map[k] end
   end

   it("fills dsn/release/environment from env when unset", function()
      local c = config_utils.resolve({}, fake_env({
         SENTRY_DSN = "https://k@h/1",
         SENTRY_RELEASE = "1.2.3",
         SENTRY_ENVIRONMENT = "staging",
      }))
      assert.equals("https://k@h/1", c.dsn)
      assert.equals("1.2.3", c.release)
      assert.equals("staging", c.environment)
   end)

   it("lets explicit options override env", function()
      local c = config_utils.resolve(
         {dsn = "https://code@h/9", environment = "prod"},
         fake_env({SENTRY_DSN = "https://env@h/1", SENTRY_ENVIRONMENT = "staging"})
      )
      assert.equals("https://code@h/9", c.dsn)
      assert.equals("prod", c.environment)
   end)

   it("enables debug from SENTRY_DEBUG", function()
      local c = config_utils.resolve({}, fake_env({SENTRY_DEBUG = "1"}))
      assert.is_true(c.debug)
   end)

   it("leaves dsn unset when neither options nor env provide one", function()
      local c = config_utils.resolve({}, fake_env({}))
      assert.is_nil(c.dsn)
   end)
end)
