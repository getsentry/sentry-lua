-- Rate limiter unit tests (uses an injected clock)
local RateLimiter = require("sentry.core.rate_limiter")

describe("RateLimiter", function()
   local now
   local function clock() return now end
   local rl

   before_each(function()
      now = 1000000  -- ms
      rl = RateLimiter.new(clock)
   end)

   it("is not limited initially", function()
      assert.is_false(rl:is_limited({"error"}))
   end)

   it("applies a per-category limit from X-Sentry-Rate-Limits", function()
      rl:update_from_response(200, {["X-Sentry-Rate-Limits"] = "60:error:organization"})
      assert.is_true(rl:is_limited({"error"}))
      assert.is_false(rl:is_limited({"transaction"}))
   end)

   it("applies a global limit when categories are empty", function()
      rl:update_from_response(200, {["X-Sentry-Rate-Limits"] = "60::organization"})
      assert.is_true(rl:is_limited({"error"}))
      assert.is_true(rl:is_limited({"transaction"}))
   end)

   it("expires after the retry window", function()
      rl:update_from_response(200, {["X-Sentry-Rate-Limits"] = "60:error"})
      assert.is_true(rl:is_limited({"error"}))
      now = now + 61 * 1000
      assert.is_false(rl:is_limited({"error"}))
   end)

   it("honors 429 with Retry-After", function()
      rl:update_from_response(429, {["Retry-After"] = "30"})
      assert.is_true(rl:is_limited({"error"}))
      now = now + 29 * 1000
      assert.is_true(rl:is_limited({"error"}))
      now = now + 2 * 1000
      assert.is_false(rl:is_limited({"error"}))
   end)

   it("defaults to 60s on a bare 429", function()
      rl:update_from_response(429, {})
      assert.is_true(rl:is_limited({"anything"}))
      now = now + 61 * 1000
      assert.is_false(rl:is_limited({"anything"}))
   end)

   it("parses multiple comma-separated limits", function()
      rl:update_from_response(200, {["x-sentry-rate-limits"] = "60:error, 120:transaction"})
      assert.is_true(rl:is_limited({"error"}))
      assert.is_true(rl:is_limited({"transaction"}))
      now = now + 61 * 1000
      assert.is_false(rl:is_limited({"error"}))
      assert.is_true(rl:is_limited({"transaction"}))
   end)

   it("looks up headers case-insensitively", function()
      rl:update_from_response(200, {["X-SENTRY-RATE-LIMITS"] = "60:error"})
      assert.is_true(rl:is_limited({"error"}))
   end)

   it("keeps the longest limit on overlap", function()
      rl:update_from_response(200, {["x-sentry-rate-limits"] = "60:error"})
      rl:update_from_response(200, {["x-sentry-rate-limits"] = "10:error"})
      now = now + 11 * 1000
      assert.is_true(rl:is_limited({"error"}))
   end)
end)
