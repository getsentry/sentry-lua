-- Love2D Integration with error handler hooking
local transport_utils = require("sentry.utils.transport")

local record Love2DIntegration
   transport: transport_utils.Transport
   original_errorhandler: function | nil
   sentry_client: any
   
   configure: function(Love2DIntegration, table): transport_utils.Transport
   install_error_handler: function(Love2DIntegration, any)
   uninstall_error_handler: function(Love2DIntegration)
end

-- Hook into love.errorhandler to capture fatal errors
local function hook_error_handler(client: any): function, function
   local original_errorhandler = (_G as any).love and (_G as any).love.errorhandler
   
   local function sentry_errorhandler(msg: string): any
      -- Capture the error in Sentry as a fatal exception
      if client then
         -- Create exception mechanism with handled: false (fatal)
         local exception: {string: any} = {
            type = "RuntimeError",
            value = tostring(msg),
            mechanism = {
               type = "love.errorhandler",
               handled = false,
               synthetic = false
            }
         }
         
         -- Add stacktrace
         local stacktrace = debug.traceback(msg, 2)
         if stacktrace then
            exception.stacktrace = {
               frames = {} -- TODO: Parse stacktrace frames if needed
            }
         end
         
         -- Create Sentry event
         local event: {string: any} = {
            level = "fatal",
            exception = {
               values = {exception}
            },
            extra = {
               error_message = tostring(msg),
               love_errorhandler = true
            }
         }
         
         -- Create a proper Sentry event with mechanism.handled: false
         local stacktrace = require("sentry.utils.stacktrace")
         local serialize = require("sentry.utils.serialize")
         local stack_trace = stacktrace.get_stack_trace(2)
         
         -- Create event with proper exception mechanism
         local event = serialize.create_event("fatal", tostring(msg), 
            client.options.environment or "production", 
            client.options.release, stack_trace)
         
         -- Add exception with mechanism.handled: false
         event.exception = {
            values = {{
               type = "RuntimeError",
               value = tostring(msg),
               mechanism = {
                  type = "love.errorhandler",
                  handled = false,
                  synthetic = false
               },
               stacktrace = stack_trace
            }}
         }
         
         -- Apply scope data to event
         event = client.scope:apply_to_event(event)
         
         -- Apply before_send hook if configured
         if client.options.before_send then
            event = client.options.before_send(event)
            if not event then
               return -- Event was filtered out
            end
         end
         
         -- Send event directly via transport
         if client.transport then
            local success, err = client.transport:send(event)
            if client.options.debug then
               if success then
                  print("[Sentry] Fatal error sent: " .. event.event_id)
               else
                  print("[Sentry] Failed to send fatal error: " .. tostring(err))
               end
            end
            
            -- Force immediate flush to ensure error is sent before app crashes
            if client.transport.flush then
               client.transport:flush()
            end
         end
      end
      
      -- Call original error handler if it exists, or create default behavior
      if original_errorhandler then
         local ok, result = xpcall(original_errorhandler, debug.traceback, msg)
         if ok then
            return result
         else
            -- Original error handler failed, create minimal error screen
            print("Error in original love.errorhandler:", result)
         end
      end
      
      -- Default error handling behavior (Love2D will crash after this)
      print("Fatal error:", msg)
      print(debug.traceback())
      
      -- Re-throw the error to ensure Love2D crashes as expected
      error(msg)
   end
   
   return sentry_errorhandler, original_errorhandler
end

-- Setup Love2D integration
local function setup_love2d_integration(): Love2DIntegration
   local love2d_transport = require("sentry.platforms.love2d.transport")
   
   if not love2d_transport.is_love2d_available() then
      error("Love2D integration can only be used in Love2D environment")
   end
   
   local integration: Love2DIntegration = {} as Love2DIntegration
   integration.transport = nil
   integration.original_errorhandler = nil
   integration.sentry_client = nil
   
   function integration:configure(config: table): transport_utils.Transport
      self.transport = love2d_transport.create_love2d_transport(config)
      return self.transport
   end
   
   function integration:install_error_handler(client: any)
      if not (_G as any).love then
         return
      end
      
      self.sentry_client = client
      local sentry_handler, original = hook_error_handler(client)
      self.original_errorhandler = original
      
      -- Install our error handler
      (_G as any).love.errorhandler = sentry_handler
      
      print("✅ Love2D error handler integration installed")
   end
   
   function integration:uninstall_error_handler()
      if (_G as any).love and self.original_errorhandler then
         (_G as any).love.errorhandler = self.original_errorhandler
         self.original_errorhandler = nil
         print("✅ Love2D error handler integration uninstalled")
      end
   end
   
   return integration
end

return {
   setup_love2d_integration = setup_love2d_integration,
   hook_error_handler = hook_error_handler
}