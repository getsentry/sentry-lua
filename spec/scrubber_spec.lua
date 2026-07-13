-- PII / data scrubbing unit tests
local scrubber = require("sentry.core.scrubber")

describe("scrubber", function()
   it("filters sensitive keys (including nested)", function()
      local ev = {
         extra = {password = "hunter2", note = "ok", nested = {api_key = "abc", safe = 1}},
      }
      scrubber.scrub_event(ev, {})
      assert.equals("[Filtered]", ev.extra.password)
      assert.equals("ok", ev.extra.note)
      assert.equals("[Filtered]", ev.extra.nested.api_key)
      assert.equals(1, ev.extra.nested.safe)
   end)

   it("matches key substrings case-insensitively", function()
      local ev = {extra = {AUTHORIZATION = "Bearer x", client_secret = "s", ["X-Api-Key"] = "k"}}
      scrubber.scrub_event(ev, {})
      assert.equals("[Filtered]", ev.extra.AUTHORIZATION)
      assert.equals("[Filtered]", ev.extra.client_secret)
      assert.equals("[Filtered]", ev.extra["X-Api-Key"])
   end)

   it("does not over-match innocuous keys", function()
      local ev = {extra = {author = "me", description = "hi"}}
      scrubber.scrub_event(ev, {})
      assert.equals("me", ev.extra.author)
      assert.equals("hi", ev.extra.description)
   end)

   it("strips user ip unless send_default_pii", function()
      local ev = {user = {id = "1", ip_address = "1.2.3.4"}}
      scrubber.scrub_event(ev, {})
      assert.is_nil(ev.user.ip_address)
      assert.equals("1", ev.user.id)
   end)

   it("keeps user ip when send_default_pii is true", function()
      local ev = {user = {id = "1", ip_address = "1.2.3.4"}}
      scrubber.scrub_event(ev, {send_default_pii = true})
      assert.equals("1.2.3.4", ev.user.ip_address)
   end)

   it("handles cyclic tables without infinite recursion", function()
      local a = {name = "a"}
      a.self = a
      local ev = {extra = {node = a}}
      assert.has_no.errors(function()
         scrubber.scrub_event(ev, {})
      end)
   end)
end)
