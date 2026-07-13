---@class sentry.core.session
--- Release-health session (application mode: one session per client run).
--- Requires a release. Tracks error count and terminal status (exited/crashed).

local utils = require("sentry.utils")

local record Session
   sid: string
   did: string
   started: string
   status: string      -- ok | exited | crashed | abnormal
   errors: number
   init: boolean
   release: string
   environment: string
end

local function now_rfc3339(): string
   return os.date("!%Y-%m-%dT%H:%M:%SZ") as string
end

---Start a new session.
---@param distinct_id string? Stable user/device id (optional)
---@param release string Release identifier (required for release health)
---@param environment string? Environment name
---@return Session
function Session.new(distinct_id: string, release: string, environment: string): Session
   local started = now_rfc3339()
   return setmetatable({
      sid = utils.generate_uuid(),
      did = distinct_id,
      started = started,
      status = "ok",
      errors = 0,
      init = true,
      release = release,
      environment = environment
   }, {__index = Session}) as Session
end

---Serialize the session to its envelope-item payload.
---@return table
function Session:to_payload(): table
   local attrs: {string: any} = { release = self.release }
   if self.environment then
      attrs["environment"] = self.environment
   end

   local payload: {string: any} = {
      sid = self.sid,
      status = self.status,
      errors = self.errors,
      started = self.started,
      timestamp = now_rfc3339(),
      init = self.init,
      attrs = attrs
   }
   if self.did then
      payload["did"] = self.did
   end
   return payload as table
end

return Session
