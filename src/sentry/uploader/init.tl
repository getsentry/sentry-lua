---@class sentry.uploader
--- Companion uploader for sandboxed environments: drains spooled envelopes from
--- a PersistenceProvider and POSTs them to Sentry's envelope endpoint. Run it
--- from a place that DOES have network access (a desktop helper, a server-side
--- cron, or the game's own log shipper).

local dsn_utils = require("sentry.utils.dsn")
local default_http = require("sentry.utils.http")
local version = require("sentry.version")

local record UploadResult
   sent: number
   total: number
end

---Drain and deliver all spooled envelopes.
---@param provider table A PersistenceProvider (see sentry.core.persistence)
---@param dsn_string string The Sentry DSN
---@param http_impl table? HTTP implementation (defaults to sentry.utils.http; injectable for tests)
---@return UploadResult
local function upload(provider: table, dsn_string: string, http_impl: table): UploadResult
   local dsn, err = dsn_utils.parse_dsn(dsn_string)
   if err then
      error("Invalid DSN: " .. err)
   end

   local http = (http_impl as any) or default_http
   local url = dsn_utils.build_envelope_url(dsn)
   local headers: {string: string} = {
      ["Content-Type"] = "application/x-sentry-envelope",
      ["User-Agent"] = "sentry-lua-uploader/" .. version,
      ["X-Sentry-Auth"] = dsn_utils.build_auth_header(dsn)
   }

   local envelopes = (provider as any).read_all() as {string}
   local total = #envelopes
   local sent = 0
   for _, env in ipairs(envelopes) do
      local resp = (http as any).request({
         url = url,
         method = "POST",
         headers = headers,
         body = env,
         timeout = 30
      })
      if resp and resp.success and resp.status == 200 then
         sent = sent + 1
      else
         -- Stop on the first failure so ordering/idempotency is preserved;
         -- the remaining envelopes stay spooled for the next run.
         break
      end
   end

   -- Remove exactly the delivered prefix, so a partial run keeps the rest and a
   -- re-run never re-sends what already went out. (Sentry also dedupes by
   -- event_id server-side, so a crash between send and remove is harmless.)
   if sent > 0 then
      (provider as any).remove_first(sent)
   end

   return { sent = sent, total = total }
end

return {
   upload = upload,
   UploadResult = UploadResult
}
