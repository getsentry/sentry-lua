---@class sentry.core.scopes
--- The three-scope model (global / isolation / current), modeled on the Sentry
--- scope architecture.
---
---   * global    — process-wide data applied to every event (release, environment)
---   * isolation  — per-request / per-task data; where top-level set_tag/set_user go
---   * current    — the innermost scope, forked by with_scope()
---
--- Events are built by merging global -> isolation -> current (more specific wins).

local Scope = require("sentry.core.scope")

local record Scopes
   global: Scope
   isolation: Scope
   current: Scope
end

function Scopes.new(): Scopes
   return setmetatable({
      global = Scope:new(),
      isolation = Scope:new(),
      current = Scope:new()
   }, {__index = Scopes}) as Scopes
end

-- Apply all three scopes onto an event in precedence order.
function Scopes:apply_to_event(event: table): table
   event = self.global:apply_to_event(event)
   event = self.isolation:apply_to_event(event)
   event = self.current:apply_to_event(event)
   return event
end

return Scopes
