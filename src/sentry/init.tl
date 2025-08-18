local Client = require("sentry.core.client")
local Scope = require("sentry.core.scope")

local record Sentry
   _client: Client
end

local sentry: Sentry = {}

local function init(config: table): Client
   if not config or not config.dsn then
      error("Sentry DSN is required")
   end
   
   sentry._client = Client:new(config as any)
   return sentry._client
end

local function capture_message(message: string, level: string): string
   if not sentry._client then
      error("Sentry not initialized. Call sentry.init() first.")
   end
   
   return sentry._client:capture_message(message, level)
end

local function capture_exception(exception: table, level: string): string
   if not sentry._client then
      error("Sentry not initialized. Call sentry.init() first.")
   end
   
   return sentry._client:capture_exception(exception, level)
end

local function add_breadcrumb(breadcrumb: table)
   if sentry._client then
      sentry._client:add_breadcrumb(breadcrumb)
   end
end

local function set_user(user: table)
   if sentry._client then
      sentry._client:set_user(user)
   end
end

local function set_tag(key: string, value: string)
   if sentry._client then
      sentry._client:set_tag(key, value)
   end
end

local function set_extra(key: string, value: any)
   if sentry._client then
      sentry._client:set_extra(key, value)
   end
end

local function close()
   if sentry._client then
      sentry._client:close()
      sentry._client = nil
   end
end

local function with_scope(callback: function(scope: Scope))
   if not sentry._client then
      error("Sentry not initialized. Call sentry.init() first.")
   end
   
   local original_scope = sentry._client.scope:clone()
   
   local success, result = pcall(callback, sentry._client.scope)
   
   sentry._client.scope = original_scope
   
   if not success then
      error(result as any)
   end
end

return {
   init = init,
   capture_message = capture_message,
   capture_exception = capture_exception,
   add_breadcrumb = add_breadcrumb,
   set_user = set_user,
   set_tag = set_tag,
   set_extra = set_extra,
   close = close,
   with_scope = with_scope
}