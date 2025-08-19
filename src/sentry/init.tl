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

local function wrap(main_function: function, error_handler: function): boolean, any
   if not sentry._client then
      error("Sentry not initialized. Call sentry.init() first.")
   end
   
   -- Default error handler that captures to Sentry
   local function default_error_handler(err: any): any
      -- Add breadcrumb for the unhandled error
      add_breadcrumb({
         message = "Unhandled error occurred",
         category = "error", 
         level = "error",
         data = {
            error_message = tostring(err)
         }
      })
      
      -- Capture the exception with full context
      capture_exception({
         type = "UnhandledException",
         message = tostring(err)
      }, "fatal")
      
      -- If user provided custom error handler, call it and return its result
      if error_handler then
         return error_handler(err)
      end
      
      -- Return the error for the caller to handle (don't re-throw to avoid infinite loop)
      return tostring(err)
   end
   
   return xpcall(main_function, default_error_handler)
end

-- Set up the sentry module functions
sentry.init = init
sentry.capture_message = capture_message
sentry.capture_exception = capture_exception
sentry.add_breadcrumb = add_breadcrumb
sentry.set_user = set_user
sentry.set_tag = set_tag
sentry.set_extra = set_extra
sentry.close = close
sentry.with_scope = with_scope
sentry.wrap = wrap

return sentry