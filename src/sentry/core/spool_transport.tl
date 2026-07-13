---@class sentry.core.spool_transport
--- A transport that persists envelopes to a PersistenceProvider instead of
--- sending them over the network. Used in sandboxed environments; a companion
--- `sentry.uploader` drains the spool and delivers the envelopes later.
---
--- Select it explicitly via `sentry.init({ spool = true, ... })`, providing
--- either `persistence_provider` or `spool_path` (+ optional `file_io`).

local transport_utils = require("sentry.utils.transport")
local persistence = require("sentry.core.persistence")
local file_io = require("sentry.core.file_io")

local record SpoolTransport
   provider: persistence.PersistenceProvider
end

function SpoolTransport:send_envelope(payload: string, _categories: {string}): boolean, string
   local ok, err = self.provider.append(payload)
   if ok then
      return true, "Envelope spooled"
   end
   return false, err or "Failed to spool envelope"
end

function SpoolTransport:configure(config: table): transport_utils.Transport
   local c = config as {string: any}
   if c["persistence_provider"] then
      self.provider = c["persistence_provider"] as persistence.PersistenceProvider
   else
      local io_impl = c["file_io"] or file_io.create_standard_file_io()
      local path = (c["spool_path"] as string) or "sentry-spool.envelopes"
      self.provider = persistence.file_provider(io_impl, path, c["max_queue_size"] as number)
   end
   return self as transport_utils.Transport
end

-- Flush is a no-op: delivery is the uploader's job.
function SpoolTransport:flush()
end

local function create_spool_transport(config: table): transport_utils.Transport
   local transport = setmetatable({}, {__index = SpoolTransport})
   return (transport as SpoolTransport):configure(config)
end

return {
   SpoolTransport = SpoolTransport,
   create_spool_transport = create_spool_transport
}
