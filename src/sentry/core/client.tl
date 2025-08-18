local transport = require("sentry.core.transport")
local TestTransport = require("sentry.core.test_transport")
local FileTransport = require("sentry.core.file_transport")
local auto_transport = require("sentry.core.auto_transport")
local Context = require("sentry.core.context")
local stacktrace = require("sentry.utils.stacktrace")
local serialize = require("sentry.utils.serialize")
local runtime_utils = require("sentry.utils.runtime")

local record Config
   dsn: string
   environment: string
   release: string
   debug: boolean
   sample_rate: number
   max_breadcrumbs: number
   before_send: function(event: table): table
   transport: any
   test_transport: boolean
   file_transport: boolean
   file_path: string
   append_mode: boolean
   file_io: any
   timeout: number
end

local record Client
   config: Config
   context: Context
   transport: any
   enabled: boolean
end

function Client:new(config: Config): Client
   local client = setmetatable({
      config = config or {},
      context = Context:new(),
      enabled = true
   }, {__index = Client}) as Client
   
   if config.transport then
      client.transport = config.transport:configure(config)
   elseif config.test_transport then
      client.transport = TestTransport:configure(config)
   elseif config.file_transport then
      client.transport = FileTransport:configure(config)
   else
      client.transport = auto_transport.create_auto_transport(config)
   end
   
   if config.environment then
      client.context.environment = config.environment
   end
   
   if config.release then
      client.context.release = config.release
   end
   
   if config.max_breadcrumbs then
      client.context.max_breadcrumbs = config.max_breadcrumbs
   end
   
   -- Initialize runtime context
   local runtime_info = runtime_utils.get_runtime_info()
   client.context:set_context("runtime", {
      name = runtime_info.name,
      version = runtime_info.version,
      description = runtime_info.description
   })
   
   return client
end

function Client:is_enabled(): boolean
   return self.enabled and self.config.dsn and self.config.dsn ~= ""
end

function Client:capture_message(message: string, level: string): string
   if not self:is_enabled() then
      return ""
   end
   
   level = level or "info"
   local stack_trace = stacktrace.get_stack_trace(1)
   local event = serialize.create_event(level, message, self.context as any, stack_trace)
   
   if self.config.before_send then
      event = self.config.before_send(event as any) as any
      if not event then
         return ""
      end
   end
   
   local success, err = (self.transport as any):send(event)
   
   if self.config.debug then
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
   
   local event = serialize.create_event(level, (exception as any).message or "Exception", self.context as any, stack_trace)
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
   self.context:add_breadcrumb(breadcrumb)
end

function Client:set_user(user: table)
   self.context:set_user(user)
end

function Client:set_tag(key: string, value: string)
   self.context:set_tag(key, value)
end

function Client:set_extra(key: string, value: any)
   self.context:set_extra(key, value)
end

function Client:close()
   self.enabled = false
end

return Client