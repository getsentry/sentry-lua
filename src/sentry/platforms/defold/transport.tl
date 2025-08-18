-- Defold transport (similar to file transport but optimized for Defold)
local transport_utils = require("sentry.utils.transport")
local json = require("sentry.utils.json")
local version = require("sentry.version")

local record DefoldTransport
   endpoint: string
   timeout: number
   headers: {string: string}
   event_queue: {table}
end

function DefoldTransport:send(event: table): boolean, string
   -- In Defold, we typically queue events and process them later
   table.insert(self.event_queue, event)
   
   return true, "Event queued for Defold processing"
end

function DefoldTransport:configure(config: table): transport_utils.Transport
   self.endpoint = (config as any).dsn or ""
   self.timeout = (config as any).timeout or 30
   self.event_queue = {}
   self.headers = {
      ["Content-Type"] = "application/json",
      ["User-Agent"] = "sentry-lua-defold/" .. version
   }
   return self as transport_utils.Transport
end

-- Flush queued events (call this from your Defold script)
function DefoldTransport:flush()
   if #self.event_queue == 0 then
      return
   end
   
   for _, event in ipairs(self.event_queue) do
      local body = json.encode(event)
      -- In Defold, you would implement HTTP requests or file writing here
      print("[Sentry] Would send event: " .. ((event as any).event_id or "unknown"))
   end
   
   self.event_queue = {}
end

-- Create factory function
local function create_defold_transport(config: table): transport_utils.Transport
   local transport = DefoldTransport
   return transport:configure(config)
end

-- Check if Defold transport is available (basic check)
local function is_defold_available(): boolean
   -- We could check for Defold-specific globals here if available
   -- For now, we'll assume it's always available as a fallback
   return false -- Set to false so it doesn't interfere with other transports
end

-- Register this transport factory with low priority
transport_utils.register_transport_factory({
   name = "defold",
   priority = 50, -- Lower priority - specialized use
   create = create_defold_transport,
   is_available = is_defold_available
})

return {
   DefoldTransport = DefoldTransport,
   create_defold_transport = create_defold_transport,
   is_defold_available = is_defold_available
}