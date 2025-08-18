local transport = require("sentry.core.transport")
local Scope = require("sentry.core.scope")
local stacktrace = require("sentry.utils.stacktrace")
local serialize = require("sentry.utils.serialize")
local runtime_utils = require("sentry.utils.runtime")
local os_utils = require("sentry.utils.os")
local types = require("sentry.types")

-- Load platform detectors
require("sentry.platform_loader")

local SentryOptions = types.SentryOptions

local record Client
   options: SentryOptions  -- Configuration from sentry.init()
   scope: Scope            -- Current scope with user, tags, contexts, etc.
   transport: any
   enabled: boolean
end

function Client:new(options: SentryOptions): Client
   local client = setmetatable({
      options = options or {} as SentryOptions,
      scope = Scope:new(),
      enabled = true
   }, {__index = Client}) as Client
   
   -- Configure transport using the registry system
   if options.transport then
      -- User-provided transport takes precedence
      client.transport = options.transport:configure(options)
   else
      -- Use transport registry to find best available transport
      client.transport = transport.create_transport(options)
   end
   
   -- Configure scope max breadcrumbs from options
   if options.max_breadcrumbs then
      client.scope.max_breadcrumbs = options.max_breadcrumbs
   end
   
   -- Initialize runtime context in scope
   local runtime_info = runtime_utils.get_runtime_info()
   client.scope:set_context("runtime", {
      name = runtime_info.name,
      version = runtime_info.version,
      description = runtime_info.description
   })
   
   -- Initialize OS context in scope (if available)
   local os_info = os_utils.get_os_info()
   if os_info then
      local os_context: {string: string} = {
         name = os_info.name
      }
      -- Only add version if it's not nil
      if os_info.version then
         os_context.version = os_info.version
      end
      client.scope:set_context("os", os_context)
   end
   
   return client
end

function Client:is_enabled(): boolean
   return self.enabled and self.options.dsn and self.options.dsn ~= ""
end

function Client:capture_message(message: string, level: string): string
   if not self:is_enabled() then
      return ""
   end
   
   level = level or "info"
   local stack_trace = stacktrace.get_stack_trace(1)
   
   -- Create basic event
   local event = serialize.create_event(level, message, self.options.environment or "production", self.options.release, stack_trace)
   
   -- Apply scope data to event
   event = self.scope:apply_to_event(event)
   
   if self.options.before_send then
      event = self.options.before_send(event) as types.EventData
      if not event then
         return ""
      end
   end
   
   local success, err = (self.transport as any):send(event)
   
   if self.options.debug then
      if success then
         print("[Sentry] Event sent: " .. event.event_id)
      else
         print("[Sentry] Failed to send event: " .. tostring(err))
      end
   end
   
   return success and event.event_id or ""
end

function Client:capture_exception(exception: table, level: string): string
   if not self:is_enabled() then
      return ""
   end
   
   level = level or "error"
   local stack_trace = stacktrace.get_stack_trace(1)
   
   local event = serialize.create_event(level, (exception as any).message or "Exception", self.options.environment or "production", self.options.release, stack_trace)
   event = self.scope:apply_to_event(event)
   (event as any).exception = {
      values = {{
         type = (exception as any).type or "Error",
         value = (exception as any).message or "Unknown error",
         stacktrace = stack_trace
      }}
   }
   
   if self.config.before_send then
      event = self.config.before_send(event as any) as any
      if not event then
         return ""
      end
   end
   
   local success, err = (self.transport as any):send(event)
   
   if self.config.debug then
      if success then
         print("[Sentry] Exception sent: " .. event.event_id)
      else
         print("[Sentry] Failed to send exception: " .. tostring(err))
      end
   end
   
   return success and event.event_id or ""
end

function Client:add_breadcrumb(breadcrumb: table)
   self.scope:add_breadcrumb(breadcrumb)
end

function Client:set_user(user: table)
   self.scope:set_user(user)
end

function Client:set_tag(key: string, value: string)
   self.scope:set_tag(key, value)
end

function Client:set_extra(key: string, value: any)
   self.scope:set_extra(key, value)
end

function Client:close()
   self.enabled = false
end

return Client