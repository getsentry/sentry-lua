--[[
  Sentry Lua SDK - Single File Distribution
  
  Version: 0.0.6
  Generated from built SDK using lua-amalg - DO NOT EDIT MANUALLY
  
  To regenerate: ./scripts/generate-single-file-amalg.sh
  
  USAGE:
    local sentry = require('sentry')  -- if saved as sentry.lua
    
    sentry.init({dsn = "https://your-key@your-org.ingest.sentry.io/your-project-id"})
    sentry.capture_message("Hello from Sentry!", "info")
    sentry.capture_exception({type = "Error", message = "Something went wrong"})
    sentry.set_user({id = "123", username = "player1"})
    sentry.set_tag("environment", "production")
    sentry.add_breadcrumb({message = "User clicked button", category = "ui"})
    
    -- Logger functions
    sentry.logger.info("Application started")
    sentry.logger.error("Something went wrong")
    
    -- Tracing functions  
    local transaction = sentry.start_transaction("my-operation", "operation")
    local span = transaction:start_span("sub-task", "task")
    span:finish()
    transaction:finish()
    
    -- Error handling wrapper
    sentry.wrap(function()
        -- Your code here - errors will be automatically captured
    end)
    
    -- Clean shutdown
    sentry.close()
]]--


package.preload[ "sentry.core.auto_transport" ] = assert( (loadstring or load)( "local transport = require(\"sentry.core.transport\")\
local file_io = require(\"sentry.core.file_io\")\
local FileTransport = require(\"sentry.core.file_transport\")\
\
local function detect_platform()\
   if game and game.GetService then\
      return \"roblox\"\
   elseif ngx and ngx.say then\
      return \"nginx\"\
   elseif redis and redis.call then\
      return \"redis\"\
   elseif love and love.graphics then\
      return \"love2d\"\
   elseif sys and sys.get_save_file then\
      return \"defold\"\
   elseif _G.corona then\
      return \"solar2d\"\
   else\
      return \"standard\"\
   end\
end\
\
local function create_auto_transport(config)\
   local platform = detect_platform()\
\
   if platform == \"roblox\" then\
      local roblox_integration = require(\"sentry.integrations.roblox\")\
      local RobloxTransport = roblox_integration.setup_roblox_integration()\
      return RobloxTransport:configure(config)\
\
   elseif platform == \"nginx\" then\
      local nginx_integration = require(\"sentry.integrations.nginx\")\
      local NginxTransport = nginx_integration.setup_nginx_integration()\
      return NginxTransport:configure(config)\
\
   elseif platform == \"redis\" then\
      local redis_integration = require(\"sentry.integrations.redis\")\
      local RedisTransport = redis_integration.setup_redis_integration()\
      return RedisTransport:configure(config)\
\
   elseif platform == \"love2d\" then\
      local love2d_integration = require(\"sentry.integrations.love2d\")\
      local Love2DTransport = love2d_integration.setup_love2d_integration()\
      return Love2DTransport:configure(config)\
\
   elseif platform == \"defold\" then\
      local defold_file_io = require(\"sentry.integrations.defold_file_io\")\
      local file_transport = FileTransport:configure({\
         dsn = (config).dsn,\
         file_path = \"defold-sentry.log\",\
         file_io = defold_file_io.create_defold_file_io(),\
      })\
      return file_transport\
\
   else\
      local HttpTransport = transport.HttpTransport\
      return HttpTransport:configure(config)\
   end\
end\
\
return {\
   detect_platform = detect_platform,\
   create_auto_transport = create_auto_transport,\
}\
", '@'.."build/sentry/core/auto_transport.lua" ) )

package.preload[ "sentry.core.client" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pcall = _tl_compat and _tl_compat.pcall or pcall; local transport = require(\"sentry.core.transport\")\
local Scope = require(\"sentry.core.scope\")\
local stacktrace = require(\"sentry.utils.stacktrace\")\
local serialize = require(\"sentry.utils.serialize\")\
local runtime_utils = require(\"sentry.utils.runtime\")\
local os_utils = require(\"sentry.utils.os\")\
local types = require(\"sentry.types\")\
\
\
require(\"sentry.platform_loader\")\
\
local SentryOptions = types.SentryOptions\
\
local Client = {}\
\
\
\
\
\
\
function Client:new(options)\
   local client = setmetatable({\
      options = options or {},\
      scope = Scope:new(),\
      enabled = true,\
   }, { __index = Client })\
\
\
   if options.transport then\
\
      client.transport = options.transport:configure(options)\
   else\
\
      client.transport = transport.create_transport(options)\
   end\
\
\
   if options.max_breadcrumbs then\
      client.scope.max_breadcrumbs = options.max_breadcrumbs\
   end\
\
\
   local runtime_info = runtime_utils.get_runtime_info()\
   client.scope:set_context(\"runtime\", {\
      name = runtime_info.name,\
      version = runtime_info.version,\
      description = runtime_info.description,\
   })\
\
\
   local os_info = os_utils.get_os_info()\
   if os_info then\
      local os_context = {\
         name = os_info.name,\
      }\
\
      if os_info.version then\
         os_context.version = os_info.version\
      end\
      client.scope:set_context(\"os\", os_context)\
   end\
\
\
   if runtime_info.name == \"love2d\" and (_G).love then\
      local ok, love2d_integration = pcall(require, \"sentry.platforms.love2d.integration\")\
      if ok then\
         local integration = love2d_integration.setup_love2d_integration()\
         integration:install_error_handler(client)\
\
         client.love2d_integration = integration\
      end\
   end\
\
   return client\
end\
\
function Client:is_enabled()\
   return self.enabled and self.options.dsn and self.options.dsn ~= \"\"\
end\
\
function Client:capture_message(message, level)\
   if not self:is_enabled() then\
      return \"\"\
   end\
\
   level = level or \"info\"\
   local stack_trace = stacktrace.get_stack_trace(1)\
\
\
   local event = serialize.create_event(level, message, self.options.environment or \"production\", self.options.release, stack_trace)\
\
\
   event = self.scope:apply_to_event(event)\
\
   if self.options.before_send then\
      event = self.options.before_send(event)\
      if not event then\
         return \"\"\
      end\
   end\
\
   local success, err = (self.transport):send(event)\
\
   if self.options.debug then\
      if success then\
         print(\"[Sentry] Event sent: \" .. event.event_id)\
      else\
         print(\"[Sentry] Failed to send event: \" .. tostring(err))\
      end\
   end\
\
   return success and event.event_id or \"\"\
end\
\
function Client:capture_exception(exception, level)\
   if not self:is_enabled() then\
      return \"\"\
   end\
\
   level = level or \"error\"\
   local stack_trace = stacktrace.get_stack_trace(1)\
\
   local event = serialize.create_event(level, (exception).message or \"Exception\", self.options.environment or \"production\", self.options.release, stack_trace)\
   event = self.scope:apply_to_event(event);\
   (event).exception = {\
      values = { {\
         type = (exception).type or \"Error\",\
         value = (exception).message or \"Unknown error\",\
         stacktrace = stack_trace,\
      }, },\
   }\
\
   if self.options.before_send then\
      event = self.options.before_send(event)\
      if not event then\
         return \"\"\
      end\
   end\
\
   local success, err = (self.transport):send(event)\
\
   if self.options.debug then\
      if success then\
         print(\"[Sentry] Exception sent: \" .. event.event_id)\
      else\
         print(\"[Sentry] Failed to send exception: \" .. tostring(err))\
      end\
   end\
\
   return success and event.event_id or \"\"\
end\
\
function Client:add_breadcrumb(breadcrumb)\
   self.scope:add_breadcrumb(breadcrumb)\
end\
\
function Client:set_user(user)\
   self.scope:set_user(user)\
end\
\
function Client:set_tag(key, value)\
   self.scope:set_tag(key, value)\
end\
\
function Client:set_extra(key, value)\
   self.scope:set_extra(key, value)\
end\
\
function Client:close()\
   self.enabled = false\
end\
\
return Client\
", '@'.."build/sentry/core/client.lua" ) )

package.preload[ "sentry.core.context" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local os = _tl_compat and _tl_compat.os or os; local pairs = _tl_compat and _tl_compat.pairs or pairs; local table = _tl_compat and _tl_compat.table or table; local Context = {}\
\
\
\
\
\
\
\
\
\
\
\
function Context:new()\
   return setmetatable({\
      user = {},\
      tags = {},\
      extra = {},\
      level = \"error\",\
      environment = \"production\",\
      release = nil,\
      breadcrumbs = {},\
      max_breadcrumbs = 100,\
      contexts = {},\
   }, { __index = Context })\
end\
\
function Context:set_user(user)\
   self.user = user or {}\
end\
\
function Context:set_tag(key, value)\
   self.tags[key] = value\
end\
\
function Context:set_extra(key, value)\
   self.extra[key] = value\
end\
\
function Context:set_context(key, value)\
   self.contexts[key] = value\
end\
\
function Context:set_level(level)\
   local valid_levels = { debug = true, info = true, warning = true, error = true, fatal = true }\
   if valid_levels[level] then\
      self.level = level\
   end\
end\
\
function Context:add_breadcrumb(breadcrumb)\
   local crumb = {\
      timestamp = os.time(),\
      message = breadcrumb.message or \"\",\
      category = breadcrumb.category or \"default\",\
      level = breadcrumb.level or \"info\",\
      data = breadcrumb.data or {},\
   }\
   table.insert(self.breadcrumbs, crumb)\
\
   while #self.breadcrumbs > self.max_breadcrumbs do\
      table.remove(self.breadcrumbs, 1)\
   end\
end\
\
function Context:clear()\
   self.user = {}\
   self.tags = {}\
   self.extra = {}\
   self.breadcrumbs = {}\
   self.contexts = {}\
end\
\
function Context:clone()\
   local new_context = Context:new()\
\
   for k, v in pairs(self.user) do\
      new_context.user[k] = v\
   end\
\
   for k, v in pairs(self.tags) do\
      new_context.tags[k] = v\
   end\
\
   for k, v in pairs(self.extra) do\
      new_context.extra[k] = v\
   end\
\
   for k, v in pairs(self.contexts) do\
      new_context.contexts[k] = v\
   end\
\
   new_context.level = self.level\
   new_context.environment = self.environment\
   new_context.release = self.release\
\
   for i, breadcrumb in ipairs(self.breadcrumbs) do\
      new_context.breadcrumbs[i] = breadcrumb\
   end\
\
   return new_context\
end\
\
return Context\
", '@'.."build/sentry/core/context.lua" ) )

package.preload[ "sentry.core.file_io" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local os = _tl_compat and _tl_compat.os or os; local FileIO = {}\
\
\
\
\
\
\
local StandardFileIO = {}\
\
\
function StandardFileIO:write_file(path, content)\
   local file, err = io.open(path, \"w\")\
   if not file then\
      return false, \"Failed to open file: \" .. tostring(err)\
   end\
\
   local success, write_err = file:write(content)\
   file:close()\
\
   if not success then\
      return false, \"Failed to write file: \" .. tostring(write_err)\
   end\
\
   return true, \"File written successfully\"\
end\
\
function StandardFileIO:read_file(path)\
   local file, err = io.open(path, \"r\")\
   if not file then\
      return \"\", \"Failed to open file: \" .. tostring(err)\
   end\
\
   local content = file:read(\"*all\")\
   file:close()\
\
   return content or \"\", \"\"\
end\
\
function StandardFileIO:file_exists(path)\
   local file = io.open(path, \"r\")\
   if file then\
      file:close()\
      return true\
   end\
   return false\
end\
\
function StandardFileIO:ensure_directory(path)\
   local command = \"mkdir -p \" .. path\
   local success = os.execute(command)\
\
   if success then\
      return true, \"Directory created\"\
   else\
      return false, \"Failed to create directory\"\
   end\
end\
\
local function create_standard_file_io()\
   return setmetatable({}, { __index = StandardFileIO })\
end\
\
return {\
   FileIO = FileIO,\
   StandardFileIO = StandardFileIO,\
   create_standard_file_io = create_standard_file_io,\
}\
", '@'.."build/sentry/core/file_io.lua" ) )

package.preload[ "sentry.core.file_transport" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string; local file_io = require(\"sentry.core.file_io\")\
local json = require(\"sentry.utils.json\")\
local version = require(\"sentry.version\")\
\
local FileTransport = {}\
\
\
\
\
\
\
\
\
function FileTransport:send(event)\
   local serialized = json.encode(event)\
   local timestamp = os.date(\"%Y-%m-%d %H:%M:%S\")\
   local content = string.format(\"[%s] %s\\n\", timestamp, serialized)\
\
   if self.append_mode and self.file_io:file_exists(self.file_path) then\
      local existing_content, read_err = self.file_io:read_file(self.file_path)\
      if read_err ~= \"\" then\
         return false, \"Failed to read existing file: \" .. read_err\
      end\
      content = existing_content .. content\
   end\
\
   local success, err = self.file_io:write_file(self.file_path, content)\
\
   if success then\
      return true, \"Event written to file: \" .. self.file_path\
   else\
      return false, \"Failed to write event: \" .. err\
   end\
end\
\
function FileTransport:configure(config)\
   self.endpoint = (config).dsn or \"\"\
   self.timeout = (config).timeout or 30\
   self.file_path = (config).file_path or \"sentry-events.log\"\
   self.append_mode = (config).append_mode ~= false\
\
   if (config).file_io then\
      self.file_io = (config).file_io\
   else\
      self.file_io = file_io.create_standard_file_io()\
   end\
\
   local dir_path = self.file_path:match(\"^(.*/)\")\
   if dir_path then\
      local dir_success, dir_err = self.file_io:ensure_directory(dir_path)\
      if not dir_success then\
         print(\"Warning: Failed to create directory: \" .. dir_err)\
      end\
   end\
\
   self.headers = {\
      [\"Content-Type\"] = \"application/json\",\
      [\"User-Agent\"] = \"sentry-lua-file/\" .. version,\
   }\
\
   return self\
end\
\
return FileTransport\
", '@'.."build/sentry/core/file_transport.lua" ) )

package.preload[ "sentry.core.scope" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local os = _tl_compat and _tl_compat.os or os; local pairs = _tl_compat and _tl_compat.pairs or pairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local table = _tl_compat and _tl_compat.table or table\
\
\
local Scope = {}\
\
\
\
\
\
\
\
\
\
function Scope:new()\
   return setmetatable({\
      user = {},\
      tags = {},\
      extra = {},\
      contexts = {},\
      breadcrumbs = {},\
      max_breadcrumbs = 100,\
      level = nil,\
   }, { __index = Scope })\
end\
\
function Scope:set_user(user)\
   self.user = user or {}\
end\
\
function Scope:set_tag(key, value)\
   self.tags[key] = value\
end\
\
function Scope:set_extra(key, value)\
   self.extra[key] = value\
end\
\
function Scope:set_context(key, value)\
   self.contexts[key] = value\
end\
\
function Scope:set_level(level)\
   local valid_levels = { debug = true, info = true, warning = true, error = true, fatal = true }\
   if valid_levels[level] then\
      self.level = level\
   end\
end\
\
function Scope:add_breadcrumb(breadcrumb)\
   local crumb = {\
      timestamp = os.time(),\
      message = breadcrumb.message or \"\",\
      category = breadcrumb.category or \"default\",\
      level = breadcrumb.level or \"info\",\
      data = breadcrumb.data or {},\
   }\
   table.insert(self.breadcrumbs, crumb)\
\
   while #self.breadcrumbs > self.max_breadcrumbs do\
      table.remove(self.breadcrumbs, 1)\
   end\
end\
\
function Scope:clear()\
   self.user = {}\
   self.tags = {}\
   self.extra = {}\
   self.contexts = {}\
   self.breadcrumbs = {}\
   self.level = nil\
end\
\
function Scope:clone()\
   local new_scope = Scope:new()\
\
   for k, v in pairs(self.user) do\
      new_scope.user[k] = v\
   end\
\
   for k, v in pairs(self.tags) do\
      new_scope.tags[k] = v\
   end\
\
   for k, v in pairs(self.extra) do\
      new_scope.extra[k] = v\
   end\
\
   for k, v in pairs(self.contexts) do\
      new_scope.contexts[k] = v\
   end\
\
   new_scope.level = self.level\
   new_scope.max_breadcrumbs = self.max_breadcrumbs\
\
   for i, breadcrumb in ipairs(self.breadcrumbs) do\
      new_scope.breadcrumbs[i] = breadcrumb\
   end\
\
   return new_scope\
end\
\
\
function Scope:apply_to_event(event)\
\
   if next(self.user) then\
      event.user = event.user or {}\
      for k, v in pairs(self.user) do\
         event.user[k] = v\
      end\
   end\
\
\
   if next(self.tags) then\
      event.tags = event.tags or {}\
      for k, v in pairs(self.tags) do\
         event.tags[k] = v\
      end\
   end\
\
\
   if next(self.extra) then\
      event.extra = event.extra or {}\
      for k, v in pairs(self.extra) do\
         event.extra[k] = v\
      end\
   end\
\
\
   if next(self.contexts) then\
      event.contexts = event.contexts or {}\
      for k, v in pairs(self.contexts) do\
         event.contexts[k] = v\
      end\
   end\
\
\
   local success, tracing = pcall(require, \"sentry.tracing.propagation\")\
   if success and tracing and tracing.get_current_context then\
      local trace_context = tracing.get_current_context()\
      if trace_context then\
         event.contexts = event.contexts or {}\
         event.contexts.trace = {\
            trace_id = trace_context.trace_id,\
            span_id = trace_context.span_id,\
            parent_span_id = trace_context.parent_span_id,\
         }\
      end\
   end\
\
\
   if #self.breadcrumbs > 0 then\
      event.breadcrumbs = {}\
      for i, breadcrumb in ipairs(self.breadcrumbs) do\
         event.breadcrumbs[i] = breadcrumb\
      end\
   end\
\
\
   if self.level then\
      event.level = self.level\
   end\
\
   return event\
end\
\
return Scope\
", '@'.."build/sentry/core/scope.lua" ) )

package.preload[ "sentry.core.test_transport" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local table = _tl_compat and _tl_compat.table or table; local version = require(\"sentry.version\")\
\
local TestTransport = {}\
\
\
\
\
\
\
function TestTransport:send(event)\
   table.insert(self.events, event)\
   return true, \"Event captured in test transport\"\
end\
\
function TestTransport:configure(config)\
   self.endpoint = (config).dsn or \"\"\
   self.timeout = (config).timeout or 30\
   self.headers = {\
      [\"Content-Type\"] = \"application/json\",\
      [\"User-Agent\"] = \"sentry-lua-test/\" .. version,\
   }\
   self.events = {}\
   return self\
end\
\
function TestTransport:get_events()\
   return self.events\
end\
\
function TestTransport:clear_events()\
   self.events = {}\
end\
\
return TestTransport\
", '@'.."build/sentry/core/test_transport.lua" ) )

package.preload[ "sentry.core.transport" ] = assert( (loadstring or load)( "\
\
require(\"sentry.platforms.standard.transport\")\
require(\"sentry.platforms.standard.file_transport\")\
require(\"sentry.platforms.roblox.transport\")\
require(\"sentry.platforms.love2d.transport\")\
require(\"sentry.platforms.nginx.transport\")\
require(\"sentry.platforms.redis.transport\")\
require(\"sentry.platforms.defold.transport\")\
require(\"sentry.platforms.test.transport\")\
\
\
local transport_utils = require(\"sentry.utils.transport\")\
\
return {\
   Transport = transport_utils.Transport,\
   create_transport = transport_utils.create_transport,\
   get_available_transports = transport_utils.get_available_transports,\
   register_transport_factory = transport_utils.register_transport_factory,\
}\
", '@'.."build/sentry/core/transport.lua" ) )

package.preload[ "sentry.init" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pcall = _tl_compat and _tl_compat.pcall or pcall; local xpcall = _tl_compat and _tl_compat.xpcall or xpcall; local Client = require(\"sentry.core.client\")\
local Scope = require(\"sentry.core.scope\")\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
local sentry = {}\
\
local function init(config)\
   if not config or not config.dsn then\
      error(\"Sentry DSN is required\")\
   end\
\
   sentry._client = Client:new(config)\
   \
   -- Initialize logger if available\
   local logger_success, logger = pcall(require, \"sentry.logger.init\")\
   if logger_success then\
      logger.init({\
         enable_logs = config.enable_logs ~= nil and config.enable_logs or true,\
         hook_print = config.hook_print or false,\
         max_buffer_size = config.max_buffer_size or 100,\
         flush_timeout = config.flush_timeout or 5.0,\
         before_send_log = config.before_send_log\
      })\
   end\
   \
   -- Initialize tracing if available\
   local tracing_success, tracing = pcall(require, \"sentry.tracing.init\")\
   if tracing_success then\
      tracing.init(config)\
   end\
   \
   return sentry._client\
end\
\
local function capture_message(message, level)\
   if not sentry._client then\
      error(\"Sentry not initialized. Call sentry.init() first.\")\
   end\
\
   return sentry._client:capture_message(message, level)\
end\
\
local function capture_exception(exception, level)\
   if not sentry._client then\
      error(\"Sentry not initialized. Call sentry.init() first.\")\
   end\
\
   return sentry._client:capture_exception(exception, level)\
end\
\
local function add_breadcrumb(breadcrumb)\
   if sentry._client then\
      sentry._client:add_breadcrumb(breadcrumb)\
   end\
end\
\
local function set_user(user)\
   if sentry._client then\
      sentry._client:set_user(user)\
   end\
end\
\
local function set_tag(key, value)\
   if sentry._client then\
      sentry._client:set_tag(key, value)\
   end\
end\
\
local function set_extra(key, value)\
   if sentry._client then\
      sentry._client:set_extra(key, value)\
   end\
end\
\
local function flush()\
   if sentry._client and sentry._client.transport then\
\
      pcall(function()\
         (sentry._client.transport):flush()\
      end)\
   end\
end\
\
local function close()\
   if sentry._client then\
      sentry._client:close()\
      sentry._client = nil\
   end\
end\
\
local function with_scope(callback)\
   if not sentry._client then\
      error(\"Sentry not initialized. Call sentry.init() first.\")\
   end\
\
   local original_scope = sentry._client.scope:clone()\
\
   local success, result = pcall(callback, sentry._client.scope)\
\
   sentry._client.scope = original_scope\
\
   if not success then\
      error(result)\
   end\
end\
\
local function wrap(main_function, error_handler)\
   if not sentry._client then\
      error(\"Sentry not initialized. Call sentry.init() first.\")\
   end\
\
\
   local function default_error_handler(err)\
\
      add_breadcrumb({\
         message = \"Unhandled error occurred\",\
         category = \"error\",\
         level = \"error\",\
         data = {\
            error_message = tostring(err),\
         },\
      })\
\
\
      capture_exception({\
         type = \"UnhandledException\",\
         message = tostring(err),\
      }, \"fatal\")\
\
\
      if error_handler then\
         return error_handler(err)\
      end\
\
\
      return tostring(err)\
   end\
\
   return xpcall(main_function, default_error_handler)\
end\
\
local function start_transaction(name, op, options)\
   options = options or {}\
   local tracing_success, tracing = pcall(require, \"sentry.tracing.init\")\
   if tracing_success then\
      return tracing.start_transaction(name, op, options)\
   end\
   return nil\
end\
\
\
sentry.init = init\
sentry.capture_message = capture_message\
sentry.capture_exception = capture_exception\
sentry.add_breadcrumb = add_breadcrumb\
sentry.set_user = set_user\
sentry.set_tag = set_tag\
sentry.set_extra = set_extra\
sentry.flush = flush\
sentry.close = close\
sentry.with_scope = with_scope\
sentry.wrap = wrap\
sentry.start_transaction = start_transaction\
\
-- Expose logger module if available\
local logger_success, logger = pcall(require, \"sentry.logger.init\")\
if logger_success then\
   sentry.logger = logger\
end\
\
return sentry\
", '@'.."build/sentry/init.lua" ) )

package.preload[ "sentry.logger.init" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local os = _tl_compat and _tl_compat.os or os; local pairs = _tl_compat and _tl_compat.pairs or pairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack\
\
\
local json = require(\"sentry.utils.json\")\
local envelope = require(\"sentry.utils.envelope\")\
local utils = require(\"sentry.utils\")\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
local LOG_LEVELS = {\
   trace = \"trace\",\
   debug = \"debug\",\
   info = \"info\",\
   warn = \"warn\",\
   error = \"error\",\
   fatal = \"fatal\",\
}\
\
local SEVERITY_NUMBERS = {\
   trace = 1,\
   debug = 5,\
   info = 9,\
   warn = 13,\
   error = 17,\
   fatal = 21,\
}\
\
\
local logger = {}\
local buffer\
local config\
local original_print\
local is_initialized = false\
\
\
function logger.init(user_config)\
   config = {\
      enable_logs = user_config and user_config.enable_logs or false,\
      before_send_log = user_config and user_config.before_send_log,\
      max_buffer_size = user_config and user_config.max_buffer_size or 100,\
      flush_timeout = user_config and user_config.flush_timeout or 5.0,\
      hook_print = user_config and user_config.hook_print or false,\
   }\
\
   buffer = {\
      logs = {},\
      max_size = config.max_buffer_size,\
      flush_timeout = config.flush_timeout,\
      last_flush = os.time(),\
   }\
\
   is_initialized = true\
\
\
   if config.hook_print then\
      logger.hook_print()\
   end\
end\
\
\
local function get_trace_context()\
   local success, tracing = pcall(require, \"sentry.tracing\")\
   if not success then\
      return utils.generate_uuid():gsub(\"-\", \"\"), nil\
   end\
\
   local trace_info = tracing.get_current_trace_info()\
   if trace_info and trace_info.trace_id then\
      return trace_info.trace_id, trace_info.span_id\
   end\
\
   return utils.generate_uuid():gsub(\"-\", \"\"), nil\
end\
\
\
local function get_default_attributes(parent_span_id)\
   local attributes = {}\
\
\
   local version_success, version = pcall(require, \"sentry.version\")\
   local sdk_version = version_success and version or \"unknown\"\
\
   attributes[\"sentry.sdk.name\"] = { value = \"sentry.lua\", type = \"string\" }\
   attributes[\"sentry.sdk.version\"] = { value = sdk_version, type = \"string\" }\
\
\
   local sentry_success, sentry = pcall(require, \"sentry\")\
   if sentry_success and sentry._client and sentry._client.config then\
      local client_config = sentry._client.config\
\
      if client_config.environment then\
         attributes[\"sentry.environment\"] = { value = client_config.environment, type = \"string\" }\
      end\
\
      if client_config.release then\
         attributes[\"sentry.release\"] = { value = client_config.release, type = \"string\" }\
      end\
   end\
\
\
   if parent_span_id then\
      attributes[\"sentry.trace.parent_span_id\"] = { value = parent_span_id, type = \"string\" }\
   end\
\
   return attributes\
end\
\
\
local function create_log_record(level, body, template, params, extra_attributes)\
   if not config.enable_logs then\
      return nil\
   end\
\
   local trace_id, parent_span_id = get_trace_context()\
   local attributes = get_default_attributes(parent_span_id)\
\
\
   if template then\
      attributes[\"sentry.message.template\"] = { value = template, type = \"string\" }\
\
      if params then\
         for i, param in ipairs(params) do\
            local param_key = \"sentry.message.parameter.\" .. tostring(i - 1)\
            local param_type = type(param)\
\
            if param_type == \"number\" then\
               if math.floor(param) == param then\
                  attributes[param_key] = { value = param, type = \"integer\" }\
               else\
                  attributes[param_key] = { value = param, type = \"double\" }\
               end\
            elseif param_type == \"boolean\" then\
               attributes[param_key] = { value = param, type = \"boolean\" }\
            else\
               attributes[param_key] = { value = tostring(param), type = \"string\" }\
            end\
         end\
      end\
   end\
\
\
   if extra_attributes then\
      for key, value in pairs(extra_attributes) do\
         local value_type = type(value)\
         if value_type == \"number\" then\
            if math.floor(value) == value then\
               attributes[key] = { value = value, type = \"integer\" }\
            else\
               attributes[key] = { value = value, type = \"double\" }\
            end\
         elseif value_type == \"boolean\" then\
            attributes[key] = { value = value, type = \"boolean\" }\
         else\
            attributes[key] = { value = tostring(value), type = \"string\" }\
         end\
      end\
   end\
\
   local record = {\
      timestamp = os.time() + (os.clock() % 1),\
      trace_id = trace_id,\
      level = level,\
      body = body,\
      attributes = attributes,\
      severity_number = SEVERITY_NUMBERS[level] or 9,\
   }\
\
   return record\
end\
\
\
local function add_to_buffer(record)\
   if not record or not buffer then\
      return\
   end\
\
\
   if config.before_send_log then\
      record = config.before_send_log(record)\
      if not record then\
         return\
      end\
   end\
\
   table.insert(buffer.logs, record)\
\
\
   local should_flush = false\
\
   if #buffer.logs >= buffer.max_size then\
      should_flush = true\
   elseif buffer.flush_timeout > 0 then\
      local current_time = os.time()\
      if (current_time - buffer.last_flush) >= buffer.flush_timeout then\
         should_flush = true\
      end\
   end\
\
   if should_flush then\
      logger.flush()\
   end\
end\
\
\
function logger.flush()\
   if not buffer or #buffer.logs == 0 then\
      return\
   end\
\
\
   local sentry_success, sentry = pcall(require, \"sentry\")\
   if not sentry_success or not sentry._client or not sentry._client.transport then\
\
      buffer.logs = {}\
      buffer.last_flush = os.time()\
      return\
   end\
\
\
   local version_success, version = pcall(require, \"sentry.version\")\
   local sdk_version = version_success and version or \"unknown\"\
\
\
   local envelope_body = envelope.build_log_envelope(buffer.logs)\
\
\
   if sentry._client.transport.send_envelope then\
      local success, err = sentry._client.transport:send_envelope(envelope_body)\
      if success then\
         print(\"[Sentry] Sent \" .. #buffer.logs .. \" log records via envelope\")\
      else\
         print(\"[Sentry] Failed to send log envelope: \" .. tostring(err))\
      end\
   else\
      print(\"[Sentry] No envelope transport available for logs\")\
   end\
\
\
   buffer.logs = {}\
   buffer.last_flush = os.time()\
end\
\
\
local function log(level, message, template, params, attributes)\
   if not is_initialized or not config.enable_logs then\
      return\
   end\
\
   local record = create_log_record(level, message, template, params, attributes)\
   if record then\
      add_to_buffer(record)\
   end\
end\
\
\
local function format_message(template, ...)\
   local args = { ... }\
   local formatted = template\
\
\
   local i = 1\
   formatted = formatted:gsub(\"%%s\", function()\
      local arg = args[i]\
      i = i + 1\
      return tostring(arg or \"\")\
   end)\
\
   return formatted, args\
end\
\
\
function logger.trace(message, params, attributes)\
   if type(message) == \"string\" and message:find(\"%%s\") and params then\
      local formatted, args = format_message(message, _tl_table_unpack(params))\
      log(\"trace\", formatted, message, args, attributes)\
   else\
      log(\"trace\", message, nil, nil, attributes or params)\
   end\
end\
\
function logger.debug(message, params, attributes)\
   if type(message) == \"string\" and message:find(\"%%s\") and params then\
      local formatted, args = format_message(message, _tl_table_unpack(params))\
      log(\"debug\", formatted, message, args, attributes)\
   else\
      log(\"debug\", message, nil, nil, attributes or params)\
   end\
end\
\
function logger.info(message, params, attributes)\
   if type(message) == \"string\" and message:find(\"%%s\") and params then\
      local formatted, args = format_message(message, _tl_table_unpack(params))\
      log(\"info\", formatted, message, args, attributes)\
   else\
      log(\"info\", message, nil, nil, attributes or params)\
   end\
end\
\
function logger.warn(message, params, attributes)\
   if type(message) == \"string\" and message:find(\"%%s\") and params then\
      local formatted, args = format_message(message, _tl_table_unpack(params))\
      log(\"warn\", formatted, message, args, attributes)\
   else\
      log(\"warn\", message, nil, nil, attributes or params)\
   end\
end\
\
function logger.error(message, params, attributes)\
   if type(message) == \"string\" and message:find(\"%%s\") and params then\
      local formatted, args = format_message(message, _tl_table_unpack(params))\
      log(\"error\", formatted, message, args, attributes)\
   else\
      log(\"error\", message, nil, nil, attributes or params)\
   end\
end\
\
function logger.fatal(message, params, attributes)\
   if type(message) == \"string\" and message:find(\"%%s\") and params then\
      local formatted, args = format_message(message, _tl_table_unpack(params))\
      log(\"fatal\", formatted, message, args, attributes)\
   else\
      log(\"fatal\", message, nil, nil, attributes or params)\
   end\
end\
\
\
function logger.hook_print()\
   if original_print then\
      return\
   end\
\
   original_print = print\
\
\
   local in_sentry_print = false\
\
   _G.print = function(...)\
\
      original_print(...)\
\
\
      if in_sentry_print then\
         return\
      end\
\
      if not is_initialized or not config.enable_logs then\
         return\
      end\
\
      in_sentry_print = true\
\
\
      local args = { ... }\
      local parts = {}\
      for i, arg in ipairs(args) do\
         parts[i] = tostring(arg)\
      end\
      local message = table.concat(parts, \"\\t\")\
\
\
      local record = create_log_record(\"info\", message, nil, nil, {\
         [\"sentry.origin\"] = \"auto.logging.print\",\
      })\
\
      if record then\
         add_to_buffer(record)\
      end\
\
      in_sentry_print = false\
   end\
end\
\
function logger.unhook_print()\
   if original_print then\
      _G.print = original_print\
      original_print = nil\
   end\
end\
\
\
function logger.get_config()\
   return config\
end\
\
\
function logger.get_buffer_status()\
   if not buffer then\
      return { logs = 0, max_size = 0, last_flush = 0 }\
   end\
\
   return {\
      logs = #buffer.logs,\
      max_size = buffer.max_size,\
      last_flush = buffer.last_flush,\
   }\
end\
\
return logger\
", '@'.."build/sentry/logger/init.lua" ) )

package.preload[ "sentry.performance.init" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local os = _tl_compat and _tl_compat.os or os; local pcall = _tl_compat and _tl_compat.pcall or pcall; local table = _tl_compat and _tl_compat.table or table\
\
\
local headers = require(\"sentry.tracing.headers\")\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
local performance = {}\
\
\
\
local function get_timestamp()\
   return os.time() + (os.clock() % 1)\
end\
\
\
\
local function get_sdk_version()\
   local success, version = pcall(require, \"sentry.version\")\
   return success and version or \"unknown\"\
end\
\
\
local span_mt = {}\
span_mt.__index = span_mt\
\
\
local transaction_mt = {}\
transaction_mt.__index = transaction_mt\
\
function transaction_mt:finish(status)\
   if self.finished then\
      return\
   end\
\
   self.timestamp = get_timestamp()\
   self.status = status or \"ok\"\
   self.finished = true\
\
\
   local sentry = require(\"sentry\")\
\
   local transaction_data = {\
      event_id = self.event_id,\
      type = \"transaction\",\
      transaction = self.transaction,\
      start_timestamp = self.start_timestamp,\
      timestamp = self.timestamp,\
      spans = self.spans,\
      contexts = self.contexts,\
      tags = self.tags,\
      extra = self.extra,\
      platform = \"lua\",\
      sdk = {\
         name = \"sentry.lua\",\
         version = get_sdk_version(),\
      },\
   }\
\
\
   transaction_data.contexts = transaction_data.contexts or {}\
   transaction_data.contexts.trace = {\
      trace_id = self.trace_id,\
      span_id = self.span_id,\
      parent_span_id = self.parent_span_id,\
      op = self.op,\
      status = self.status,\
   }\
\
\
   if sentry._client then\
      local envelope = require(\"sentry.utils.envelope\")\
      if sentry._client.transport and sentry._client.transport.send_envelope then\
         local envelope_data = envelope.build_transaction_envelope(transaction_data, self.event_id)\
         local transport_success, err = sentry._client.transport:send_envelope(envelope_data)\
\
         if transport_success then\
            print(\"[Sentry] Transaction sent: \" .. self.event_id)\
         else\
            print(\"[Sentry] Failed to send transaction: \" .. tostring(err))\
         end\
      end\
   end\
end\
\
function transaction_mt:start_span(op, description, options)\
   options = options or {}\
\
   local parent_span_id = #self.active_spans > 0 and self.active_spans[#self.active_spans].span_id or self.span_id\
\
   local span_data = {\
      span_id = headers.generate_span_id(),\
      parent_span_id = parent_span_id,\
      trace_id = self.trace_id,\
      op = op,\
      description = description,\
      status = \"ok\",\
      tags = options.tags or {},\
      data = options.data or {},\
      start_timestamp = get_timestamp(),\
      timestamp = 0,\
      origin = options.origin or \"manual\",\
      finished = false,\
      transaction = self,\
   }\
\
\
   setmetatable(span_data, span_mt)\
\
   table.insert(self.active_spans, span_data)\
\
\
   local success, propagation = pcall(require, \"sentry.tracing.propagation\")\
   if success then\
      local propagation_context = {\
         trace_id = span_data.trace_id,\
         span_id = span_data.span_id,\
         parent_span_id = span_data.parent_span_id,\
         sampled = true,\
         baggage = {},\
         dynamic_sampling_context = {},\
      }\
      propagation.set_current_context(propagation_context)\
   end\
\
   return span_data\
end\
\
function transaction_mt:add_tag(key, value)\
   self.tags = self.tags or {}\
   self.tags[key] = value\
end\
\
function transaction_mt:add_data(key, value)\
   self.extra = self.extra or {}\
   self.extra[key] = value\
end\
\
\
function span_mt:finish(status)\
   if self.finished then\
      return\
   end\
\
   self.timestamp = get_timestamp()\
   self.status = status or \"ok\"\
   self.finished = true\
\
\
   local tx = self.transaction\
   for i = #tx.active_spans, 1, -1 do\
      if tx.active_spans[i].span_id == self.span_id then\
         table.remove(tx.active_spans, i)\
         break\
      end\
   end\
\
\
   table.insert(tx.spans, {\
      span_id = self.span_id,\
      parent_span_id = self.parent_span_id,\
      trace_id = self.trace_id,\
      op = self.op,\
      description = self.description,\
      status = self.status,\
      tags = self.tags,\
      data = self.data,\
      start_timestamp = self.start_timestamp,\
      timestamp = self.timestamp,\
      origin = self.origin,\
   })\
\
\
   local success, propagation = pcall(require, \"sentry.tracing.propagation\")\
   if success then\
      local parent_context\
      if #tx.active_spans > 0 then\
\
         local active_span = tx.active_spans[#tx.active_spans]\
         parent_context = {\
            trace_id = active_span.trace_id,\
            span_id = active_span.span_id,\
            parent_span_id = active_span.parent_span_id,\
            sampled = true,\
            baggage = {},\
            dynamic_sampling_context = {},\
         }\
      else\
\
         parent_context = {\
            trace_id = tx.trace_id,\
            span_id = tx.span_id,\
            parent_span_id = tx.parent_span_id,\
            sampled = true,\
            baggage = {},\
            dynamic_sampling_context = {},\
         }\
      end\
      propagation.set_current_context(parent_context)\
   end\
end\
\
function span_mt:start_span(op, description, options)\
\
   return self.transaction:start_span(op, description, options)\
end\
\
function span_mt:add_tag(key, value)\
   self.tags = self.tags or {}\
   self.tags[key] = value\
end\
\
function span_mt:add_data(key, value)\
   self.data = self.data or {}\
   self.data[key] = value\
end\
\
\
\
\
\
\
function performance.start_transaction(name, op, options)\
   options = options or {}\
\
\
   local trace_id = options.trace_id\
   local parent_span_id = options.parent_span_id\
   local span_id = options.span_id\
\
   if not trace_id or not span_id then\
      local success, propagation = pcall(require, \"sentry.tracing.propagation\")\
      if success then\
         local context = propagation.get_current_context()\
         if context then\
\
            trace_id = trace_id or context.trace_id\
            parent_span_id = parent_span_id or context.span_id\
            span_id = span_id or headers.generate_span_id()\
         else\
\
            context = propagation.start_new_trace()\
            trace_id = trace_id or context.trace_id\
            span_id = span_id or headers.generate_span_id()\
         end\
      end\
   end\
\
\
   trace_id = trace_id or headers.generate_trace_id()\
   span_id = span_id or headers.generate_span_id()\
   local start_time = get_timestamp()\
\
   local transaction = {\
      event_id = require(\"sentry.utils\").generate_uuid(),\
      type = \"transaction\",\
      transaction = name,\
      start_timestamp = start_time,\
      timestamp = start_time,\
      spans = {},\
      contexts = {\
         trace = {\
            trace_id = trace_id,\
            span_id = span_id,\
            parent_span_id = parent_span_id,\
            op = op,\
            status = \"unknown\",\
         },\
      },\
      tags = options.tags or {},\
      extra = options.extra or {},\
\
\
      span_id = span_id,\
      parent_span_id = parent_span_id,\
      trace_id = trace_id,\
      op = op,\
      description = name,\
      status = \"ok\",\
      finished = false,\
      active_spans = {},\
   }\
\
\
   setmetatable(transaction, transaction_mt)\
\
\
   local success, propagation = pcall(require, \"sentry.tracing.propagation\")\
   if success then\
      local propagation_context = {\
         trace_id = transaction.trace_id,\
         span_id = transaction.span_id,\
         parent_span_id = transaction.parent_span_id,\
         sampled = true,\
         baggage = {},\
         dynamic_sampling_context = {},\
      }\
      propagation.set_current_context(propagation_context)\
   end\
\
   return transaction\
end\
\
return performance\
", '@'.."build/sentry/performance/init.lua" ) )

package.preload[ "sentry.platform_loader" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pcall = _tl_compat and _tl_compat.pcall or pcall\
\
\
local function load_platforms()\
   local platform_modules = {\
      \"sentry.platforms.standard.os_detection\",\
      \"sentry.platforms.roblox.os_detection\",\
      \"sentry.platforms.love2d.os_detection\",\
      \"sentry.platforms.nginx.os_detection\",\
   }\
\
   for _, module_name in ipairs(platform_modules) do\
      pcall(require, module_name)\
   end\
end\
\
\
load_platforms()\
\
return {\
   load_platforms = load_platforms,\
}\
", '@'.."build/sentry/platform_loader.lua" ) )

package.preload[ "sentry.platforms.defold.file_io" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local pcall = _tl_compat and _tl_compat.pcall or pcall; local file_io = require(\"sentry.core.file_io\")\
\
local DefoldFileIO = {}\
\
\
function DefoldFileIO:write_file(path, content)\
   if not sys then\
      return false, \"Defold sys module not available\"\
   end\
\
   local success, err = pcall(function()\
      local save_path = sys.get_save_file(\"sentry\", path)\
      local file = io.open(save_path, \"w\")\
      if file then\
         file:write(content)\
         file:close()\
      else\
         error(\"Failed to open file for writing\")\
      end\
   end)\
\
   if success then\
      return true, \"Event written to Defold save file\"\
   else\
      return false, \"Defold file error: \" .. tostring(err)\
   end\
end\
\
function DefoldFileIO:read_file(path)\
   if not sys then\
      return \"\", \"Defold sys module not available\"\
   end\
\
   local success, result = pcall(function()\
      local save_path = sys.get_save_file(\"sentry\", path)\
      local file = io.open(save_path, \"r\")\
      if file then\
         local content = file:read(\"*all\")\
         file:close()\
         return content\
      end\
      return \"\"\
   end)\
\
   if success then\
      return result or \"\", \"\"\
   else\
      return \"\", \"Failed to read Defold file: \" .. tostring(result)\
   end\
end\
\
function DefoldFileIO:file_exists(path)\
   if not sys then\
      return false\
   end\
\
   local save_path = sys.get_save_file(\"sentry\", path)\
   local file = io.open(save_path, \"r\")\
   if file then\
      file:close()\
      return true\
   end\
   return false\
end\
\
function DefoldFileIO:ensure_directory(path)\
   return true, \"Defold handles save directories automatically\"\
end\
\
local function create_defold_file_io()\
   return setmetatable({}, { __index = DefoldFileIO })\
end\
\
return {\
   DefoldFileIO = DefoldFileIO,\
   create_defold_file_io = create_defold_file_io,\
}\
", '@'.."build/sentry/platforms/defold/file_io.lua" ) )

package.preload[ "sentry.platforms.defold.transport" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table\
local transport_utils = require(\"sentry.utils.transport\")\
local json = require(\"sentry.utils.json\")\
local version = require(\"sentry.version\")\
\
local DefoldTransport = {}\
\
\
\
\
\
\
function DefoldTransport:send(event)\
\
   table.insert(self.event_queue, event)\
\
   return true, \"Event queued for Defold processing\"\
end\
\
function DefoldTransport:configure(config)\
   self.endpoint = (config).dsn or \"\"\
   self.timeout = (config).timeout or 30\
   self.event_queue = {}\
   self.headers = {\
      [\"Content-Type\"] = \"application/json\",\
      [\"User-Agent\"] = \"sentry-lua-defold/\" .. version,\
   }\
   return self\
end\
\
\
function DefoldTransport:flush()\
   if #self.event_queue == 0 then\
      return\
   end\
\
   for _, event in ipairs(self.event_queue) do\
      local body = json.encode(event)\
\
      print(\"[Sentry] Would send event: \" .. ((event).event_id or \"unknown\"))\
   end\
\
   self.event_queue = {}\
end\
\
\
local function create_defold_transport(config)\
   local transport = DefoldTransport\
   return transport:configure(config)\
end\
\
\
local function is_defold_available()\
\
\
   return false\
end\
\
\
transport_utils.register_transport_factory({\
   name = \"defold\",\
   priority = 50,\
   create = create_defold_transport,\
   is_available = is_defold_available,\
})\
\
return {\
   DefoldTransport = DefoldTransport,\
   create_defold_transport = create_defold_transport,\
   is_defold_available = is_defold_available,\
}\
", '@'.."build/sentry/platforms/defold/transport.lua" ) )

package.preload[ "sentry.platforms.love2d.context" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local table = _tl_compat and _tl_compat.table or table\
local function get_love2d_context()\
   local context = {}\
\
   if _G.love then\
      local love = _G.love\
      context.love_version = love.getVersion and table.concat({ love.getVersion() }, \".\") or \"unknown\"\
\
      if love.graphics then\
         local w, h = love.graphics.getDimensions()\
         context.screen = {\
            width = w,\
            height = h,\
         }\
      end\
\
      if love.system then\
         context.os = love.system.getOS()\
      end\
   end\
\
   return context\
end\
\
return {\
   get_love2d_context = get_love2d_context,\
}\
", '@'.."build/sentry/platforms/love2d/context.lua" ) )

package.preload[ "sentry.platforms.love2d.integration" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local debug = _tl_compat and _tl_compat.debug or debug; local xpcall = _tl_compat and _tl_compat.xpcall or xpcall\
local transport_utils = require(\"sentry.utils.transport\")\
\
\
\
\
\
\
\
\
\
\
\
\
local function hook_error_handler(client)\
   local original_errorhandler = (_G).love and (_G).love.errorhandler\
\
   local function sentry_errorhandler(msg)\
\
      if client then\
\
         local exception = {\
            type = \"RuntimeError\",\
            value = tostring(msg),\
            mechanism = {\
               type = \"love.errorhandler\",\
               handled = false,\
               synthetic = false,\
            },\
         }\
\
\
         local stacktrace = debug.traceback(msg, 2)\
         if stacktrace then\
            exception.stacktrace = {\
               frames = {},\
            }\
         end\
\
\
         local event = {\
            level = \"fatal\",\
            exception = {\
               values = { exception },\
            },\
            extra = {\
               error_message = tostring(msg),\
               love_errorhandler = true,\
            },\
         }\
\
\
         local stacktrace = require(\"sentry.utils.stacktrace\")\
         local serialize = require(\"sentry.utils.serialize\")\
         local stack_trace = stacktrace.get_stack_trace(2)\
\
\
         local event = serialize.create_event(\"fatal\", tostring(msg),\
         client.options.environment or \"production\",\
         client.options.release, stack_trace)\
\
\
         event.exception = {\
            values = { {\
               type = \"RuntimeError\",\
               value = tostring(msg),\
               mechanism = {\
                  type = \"love.errorhandler\",\
                  handled = false,\
                  synthetic = false,\
               },\
               stacktrace = stack_trace,\
            }, },\
         }\
\
\
         event = client.scope:apply_to_event(event)\
\
\
         if client.options.before_send then\
            event = client.options.before_send(event)\
            if not event then\
               return\
            end\
         end\
\
\
         if client.transport then\
            local success, err = client.transport:send(event)\
            if client.options.debug then\
               if success then\
                  print(\"[Sentry] Fatal error sent: \" .. event.event_id)\
               else\
                  print(\"[Sentry] Failed to send fatal error: \" .. tostring(err))\
               end\
            end\
\
\
            if client.transport.flush then\
               client.transport:flush()\
            end\
         end\
      end\
\
\
      if original_errorhandler then\
         local ok, result = xpcall(original_errorhandler, debug.traceback, msg)\
         if ok then\
            return result\
         else\
\
            print(\"Error in original love.errorhandler:\", result)\
         end\
      end\
\
\
      print(\"Fatal error:\", msg)\
      print(debug.traceback())\
\
\
      error(msg)\
   end\
\
   return sentry_errorhandler, original_errorhandler\
end\
\
\
local function setup_love2d_integration()\
   local love2d_transport = require(\"sentry.platforms.love2d.transport\")\
\
   if not love2d_transport.is_love2d_available() then\
      error(\"Love2D integration can only be used in Love2D environment\")\
   end\
\
   local integration = {}\
   integration.transport = nil\
   integration.original_errorhandler = nil\
   integration.sentry_client = nil\
\
   function integration:configure(config)\
      self.transport = love2d_transport.create_love2d_transport(config)\
      return self.transport\
   end\
\
   function integration:install_error_handler(client)\
      if not (_G).love then\
         return\
      end\
\
      self.sentry_client = client\
      local sentry_handler, original = hook_error_handler(client)\
      self.original_errorhandler = original;\
\
\
      (_G).love.errorhandler = sentry_handler\
\
      print(\"✅ Love2D error handler integration installed\")\
   end\
\
   function integration:uninstall_error_handler()\
      if (_G).love and self.original_errorhandler then\
         (_G).love.errorhandler = self.original_errorhandler\
         self.original_errorhandler = nil\
         print(\"✅ Love2D error handler integration uninstalled\")\
      end\
   end\
\
   return integration\
end\
\
return {\
   setup_love2d_integration = setup_love2d_integration,\
   hook_error_handler = hook_error_handler,\
}\
", '@'.."build/sentry/platforms/love2d/integration.lua" ) )

package.preload[ "sentry.platforms.love2d.os_detection" ] = assert( (loadstring or load)( "local os_utils = require(\"sentry.utils.os\")\
local OSInfo = os_utils.OSInfo\
\
local function detect_os()\
   if _G.love and (_G.love).system then\
      local os_name = (_G.love).system.getOS()\
      if os_name then\
         return {\
            name = os_name,\
            version = nil,\
         }\
      end\
   end\
   return nil\
end\
\
\
os_utils.register_detector({\
   detect = detect_os,\
})\
\
return {\
   detect_os = detect_os,\
}\
", '@'.."build/sentry/platforms/love2d/os_detection.lua" ) )

package.preload[ "sentry.platforms.love2d.transport" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local table = _tl_compat and _tl_compat.table or table\
local transport_utils = require(\"sentry.utils.transport\")\
local json = require(\"sentry.utils.json\")\
local version = require(\"sentry.version\")\
local dsn_utils = require(\"sentry.utils.dsn\")\
\
local Love2DTransport = {}\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
function Love2DTransport:send(event)\
\
   local love_global = rawget(_G, \"love\")\
   if not love_global then\
      return false, \"Not in LÖVE 2D environment\"\
   end\
\
\
   table.insert(self.event_queue, event)\
\
\
   self:flush()\
\
   return true, \"Event queued for sending in LÖVE 2D\"\
end\
\
function Love2DTransport:send_envelope(envelope_body)\
\
   local love_global = rawget(_G, \"love\")\
   if not love_global then\
      return false, \"Not in LÖVE 2D environment\"\
   end\
\
\
   table.insert(self.envelope_queue, envelope_body)\
\
\
   self:flush()\
\
   return true, \"Envelope queued for sending in LÖVE 2D\"\
end\
\
function Love2DTransport:configure(config)\
   local dsn = (config).dsn or \"\"\
   self.dsn_info = dsn_utils.parse_dsn(dsn)\
   self.endpoint = dsn_utils.build_ingest_url(self.dsn_info)\
   self.envelope_endpoint = dsn_utils.build_envelope_url(self.dsn_info)\
   self.timeout = (config).timeout or 30\
   self.event_queue = {}\
   self.envelope_queue = {}\
   self.headers = {\
      [\"Content-Type\"] = \"application/json\",\
      [\"User-Agent\"] = \"sentry-lua-love2d/\" .. version,\
      [\"X-Sentry-Auth\"] = dsn_utils.build_auth_header(self.dsn_info),\
   }\
   self.envelope_headers = {\
      [\"Content-Type\"] = \"application/x-sentry-envelope\",\
      [\"User-Agent\"] = \"sentry-lua-love2d/\" .. version,\
      [\"X-Sentry-Auth\"] = dsn_utils.build_auth_header(self.dsn_info),\
   }\
\
   return self\
end\
\
\
function Love2DTransport:flush()\
   local love_global = rawget(_G, \"love\")\
   if not love_global then\
      return\
   end\
\
\
   local https_ok, https = pcall(require, \"https\")\
   if not https_ok then\
      print(\"[Sentry] lua-https module not available: \" .. tostring(https))\
      return\
   end\
\
\
   if #self.event_queue > 0 then\
      for _, event in ipairs(self.event_queue) do\
         local body = json.encode(event)\
\
         local status = https.request(self.endpoint, {\
            method = \"POST\",\
            headers = self.headers,\
            data = body,\
         })\
\
         if status == 200 then\
            print(\"[Sentry] Event sent successfully (status: \" .. status .. \")\")\
         else\
            print(\"[Sentry] Event send failed to \" .. self.endpoint .. \" (status: \" .. tostring(status) .. \")\")\
         end\
      end\
      self.event_queue = {}\
   end\
\
\
   if #self.envelope_queue > 0 then\
      for _, envelope_body in ipairs(self.envelope_queue) do\
         local status = https.request(self.envelope_endpoint, {\
            method = \"POST\",\
            headers = self.envelope_headers,\
            data = envelope_body,\
         })\
\
         if status == 200 then\
            print(\"[Sentry] Envelope sent successfully (status: \" .. status .. \")\")\
         else\
            print(\"[Sentry] Envelope send failed to \" .. self.envelope_endpoint .. \" (status: \" .. tostring(status) .. \")\")\
         end\
      end\
      self.envelope_queue = {}\
   end\
end\
\
\
function Love2DTransport:close()\
\
   self:flush()\
end\
\
\
local function create_love2d_transport(config)\
   local transport = Love2DTransport\
   return transport:configure(config)\
end\
\
\
local function is_love2d_available()\
   return rawget(_G, \"love\") ~= nil\
end\
\
\
transport_utils.register_transport_factory({\
   name = \"love2d\",\
   priority = 180,\
   create = create_love2d_transport,\
   is_available = is_love2d_available,\
})\
\
return {\
   Love2DTransport = Love2DTransport,\
   create_love2d_transport = create_love2d_transport,\
   is_love2d_available = is_love2d_available,\
}\
", '@'.."build/sentry/platforms/love2d/transport.lua" ) )

package.preload[ "sentry.platforms.nginx.os_detection" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local string = _tl_compat and _tl_compat.string or string; local os_utils = require(\"sentry.utils.os\")\
local OSInfo = os_utils.OSInfo\
\
local function detect_os()\
   if _G.ngx then\
\
      local handle = io.popen(\"uname -s 2>/dev/null\")\
      if handle then\
         local name = handle:read(\"*a\")\
         handle:close()\
         if name then\
            name = name:gsub(\"\\n\", \"\")\
            local handle_version = io.popen(\"uname -r 2>/dev/null\")\
            if handle_version then\
               local version = handle_version:read(\"*a\")\
               handle_version:close()\
               version = version and version:gsub(\"\\n\", \"\") or \"\"\
               return {\
                  name = name,\
                  version = version,\
               }\
            end\
         end\
      end\
   end\
   return nil\
end\
\
\
os_utils.register_detector({\
   detect = detect_os,\
})\
\
return {\
   detect_os = detect_os,\
}\
", '@'.."build/sentry/platforms/nginx/os_detection.lua" ) )

package.preload[ "sentry.platforms.nginx.transport" ] = assert( (loadstring or load)( "\
local transport_utils = require(\"sentry.utils.transport\")\
local dsn_utils = require(\"sentry.utils.dsn\")\
local json = require(\"sentry.utils.json\")\
local http = require(\"sentry.utils.http\")\
local version = require(\"sentry.version\")\
\
local NginxTransport = {}\
\
\
\
\
\
function NginxTransport:send(event)\
   local body = json.encode(event)\
\
   local request = {\
      url = self.endpoint,\
      method = \"POST\",\
      headers = self.headers,\
      body = body,\
      timeout = self.timeout,\
   }\
\
   local response = http.request(request)\
\
   if response.success and response.status == 200 then\
      return true, \"Event sent successfully\"\
   else\
      local error_msg = response.error or \"HTTP error: \" .. tostring(response.status)\
      return false, error_msg\
   end\
end\
\
function NginxTransport:configure(config)\
   local dsn, err = dsn_utils.parse_dsn((config).dsn or \"\")\
   if err then\
      error(\"Invalid DSN: \" .. err)\
   end\
\
   self.dsn = dsn\
   self.endpoint = dsn_utils.build_ingest_url(dsn)\
   self.timeout = (config).timeout or 30\
   self.headers = {\
      [\"Content-Type\"] = \"application/json\",\
      [\"User-Agent\"] = \"sentry-lua-nginx/\" .. version,\
      [\"X-Sentry-Auth\"] = dsn_utils.build_auth_header(dsn),\
   }\
   return self\
end\
\
\
local function create_nginx_transport(config)\
   local transport = NginxTransport\
   return transport:configure(config)\
end\
\
\
local function is_nginx_available()\
   return _G.ngx ~= nil\
end\
\
\
transport_utils.register_transport_factory({\
   name = \"nginx\",\
   priority = 190,\
   create = create_nginx_transport,\
   is_available = is_nginx_available,\
})\
\
return {\
   NginxTransport = NginxTransport,\
   create_nginx_transport = create_nginx_transport,\
   is_nginx_available = is_nginx_available,\
}\
", '@'.."build/sentry/platforms/nginx/transport.lua" ) )

package.preload[ "sentry.platforms.redis.transport" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pcall = _tl_compat and _tl_compat.pcall or pcall\
local transport_utils = require(\"sentry.utils.transport\")\
local json = require(\"sentry.utils.json\")\
local version = require(\"sentry.version\")\
\
local RedisTransport = {}\
\
\
\
\
\
\
function RedisTransport:send(event)\
   if not _G.redis then\
      return false, \"Redis not available in this environment\"\
   end\
\
   local body = json.encode(event)\
\
   local success, err = pcall(function()\
      (_G.redis).call(\"LPUSH\", self.redis_key or \"sentry:events\", body);\
      (_G.redis).call(\"LTRIM\", self.redis_key or \"sentry:events\", 0, 999)\
   end)\
\
   if success then\
      return true, \"Event queued in Redis\"\
   else\
      return false, \"Redis error: \" .. tostring(err)\
   end\
end\
\
function RedisTransport:configure(config)\
   self.endpoint = (config).dsn or \"\"\
   self.timeout = (config).timeout or 30\
   self.redis_key = (config).redis_key or \"sentry:events\"\
   self.headers = {\
      [\"Content-Type\"] = \"application/json\",\
      [\"User-Agent\"] = \"sentry-lua-redis/\" .. version,\
   }\
   return self\
end\
\
\
local function create_redis_transport(config)\
   local transport = RedisTransport\
   return transport:configure(config)\
end\
\
\
local function is_redis_available()\
   return _G.redis ~= nil\
end\
\
\
transport_utils.register_transport_factory({\
   name = \"redis\",\
   priority = 150,\
   create = create_redis_transport,\
   is_available = is_redis_available,\
})\
\
return {\
   RedisTransport = RedisTransport,\
   create_redis_transport = create_redis_transport,\
   is_redis_available = is_redis_available,\
}\
", '@'.."build/sentry/platforms/redis/transport.lua" ) )

package.preload[ "sentry.platforms.roblox.context" ] = assert( (loadstring or load)( "\
local function get_roblox_context()\
   local context = {}\
\
   if _G.game then\
      local game = _G.game\
      context.game_id = game.GameId\
      context.place_id = game.PlaceId\
      context.job_id = game.JobId\
   end\
\
   if _G.game and (_G.game).Players and (_G.game).Players.LocalPlayer then\
      local player = (_G.game).Players.LocalPlayer\
      context.player = {\
         name = player.Name,\
         user_id = player.UserId,\
      }\
   end\
\
   return context\
end\
\
return {\
   get_roblox_context = get_roblox_context,\
}\
", '@'.."build/sentry/platforms/roblox/context.lua" ) )

package.preload[ "sentry.platforms.roblox.file_io" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local os = _tl_compat and _tl_compat.os or os; local pcall = _tl_compat and _tl_compat.pcall or pcall; local file_io = require(\"sentry.core.file_io\")\
\
local RobloxFileIO = {}\
\
\
function RobloxFileIO:write_file(path, content)\
   local success, err = pcall(function()\
      local DataStoreService = game:GetService(\"DataStoreService\")\
      local datastore = DataStoreService:GetDataStore(\"SentryEvents\")\
\
      local timestamp = tostring(os.time())\
      datastore:SetAsync(timestamp, content)\
   end)\
\
   if success then\
      return true, \"Event written to Roblox DataStore\"\
   else\
      return false, \"Roblox DataStore error: \" .. tostring(err)\
   end\
end\
\
function RobloxFileIO:read_file(path)\
   local success, result = pcall(function()\
      local DataStoreService = game:GetService(\"DataStoreService\")\
      local datastore = DataStoreService:GetDataStore(\"SentryEvents\")\
      return datastore:GetAsync(path)\
   end)\
\
   if success then\
      return result or \"\", \"\"\
   else\
      return \"\", \"Failed to read from DataStore: \" .. tostring(result)\
   end\
end\
\
function RobloxFileIO:file_exists(path)\
   local content, err = self:read_file(path)\
   return err == \"\"\
end\
\
function RobloxFileIO:ensure_directory(path)\
   return true, \"Directories not needed for Roblox DataStore\"\
end\
\
local function create_roblox_file_io()\
   return setmetatable({}, { __index = RobloxFileIO })\
end\
\
return {\
   RobloxFileIO = RobloxFileIO,\
   create_roblox_file_io = create_roblox_file_io,\
}\
", '@'.."build/sentry/platforms/roblox/file_io.lua" ) )

package.preload[ "sentry.platforms.roblox.os_detection" ] = assert( (loadstring or load)( "local os_utils = require(\"sentry.utils.os\")\
local OSInfo = os_utils.OSInfo\
\
local function detect_os()\
\
\
   if _G.game and _G.game.GetService then\
      return {\
         name = \"Roblox\",\
         version = nil,\
      }\
   end\
   return nil\
end\
\
\
os_utils.register_detector({\
   detect = detect_os,\
})\
\
return {\
   detect_os = detect_os,\
}\
", '@'.."build/sentry/platforms/roblox/os_detection.lua" ) )

package.preload[ "sentry.platforms.roblox.transport" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pcall = _tl_compat and _tl_compat.pcall or pcall\
local transport_utils = require(\"sentry.utils.transport\")\
local dsn_utils = require(\"sentry.utils.dsn\")\
local json = require(\"sentry.utils.json\")\
local version = require(\"sentry.version\")\
\
local RobloxTransport = {}\
\
\
\
\
\
\
function RobloxTransport:send(event)\
\
   if not _G.game then\
      return false, \"Not in Roblox environment\"\
   end\
\
   local success_service, HttpService = pcall(function()\
      return (_G.game):GetService(\"HttpService\")\
   end)\
\
   if not success_service or not HttpService then\
      return false, \"HttpService not available in Roblox\"\
   end\
\
   local body = json.encode(event)\
\
   local success, response = pcall(function()\
      return HttpService:PostAsync(self.endpoint, body,\
      (_G).Enum.HttpContentType.ApplicationJson,\
      false,\
      self.headers)\
\
   end)\
\
   if success then\
      return true, \"Event sent via Roblox HttpService\"\
   else\
      return false, \"Roblox HTTP error: \" .. tostring(response)\
   end\
end\
\
function RobloxTransport:configure(config)\
   local dsn, err = dsn_utils.parse_dsn((config).dsn or \"\")\
   if err then\
      error(\"Invalid DSN: \" .. err)\
   end\
\
   self.dsn = dsn\
   self.endpoint = dsn_utils.build_ingest_url(dsn)\
   self.timeout = (config).timeout or 30\
   self.headers = {\
      [\"Content-Type\"] = \"application/json\",\
      [\"User-Agent\"] = \"sentry-lua-roblox/\" .. version,\
      [\"X-Sentry-Auth\"] = dsn_utils.build_auth_header(dsn),\
   }\
   return self\
end\
\
\
local function create_roblox_transport(config)\
   local transport = RobloxTransport\
   return transport:configure(config)\
end\
\
\
local function is_roblox_available()\
   return _G.game and (_G.game).GetService ~= nil\
end\
\
\
transport_utils.register_transport_factory({\
   name = \"roblox\",\
   priority = 200,\
   create = create_roblox_transport,\
   is_available = is_roblox_available,\
})\
\
return {\
   RobloxTransport = RobloxTransport,\
   create_roblox_transport = create_roblox_transport,\
   is_roblox_available = is_roblox_available,\
}\
", '@'.."build/sentry/platforms/roblox/transport.lua" ) )

package.preload[ "sentry.platforms.standard.file_transport" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string\
local transport_utils = require(\"sentry.utils.transport\")\
local file_io = require(\"sentry.core.file_io\")\
local json = require(\"sentry.utils.json\")\
local version = require(\"sentry.version\")\
\
local FileTransport = {}\
\
\
\
\
\
\
\
\
function FileTransport:send(event)\
   local serialized = json.encode(event)\
   local timestamp = os.date(\"%Y-%m-%d %H:%M:%S\")\
   local content = string.format(\"[%s] %s\\n\", timestamp, serialized)\
\
   if self.append_mode and self.file_io:file_exists(self.file_path) then\
      local existing_content, read_err = self.file_io:read_file(self.file_path)\
      if read_err ~= \"\" then\
         return false, \"Failed to read existing file: \" .. read_err\
      end\
      content = existing_content .. content\
   end\
\
   local success, err = self.file_io:write_file(self.file_path, content)\
\
   if success then\
      return true, \"Event written to file: \" .. self.file_path\
   else\
      return false, \"Failed to write event: \" .. err\
   end\
end\
\
function FileTransport:configure(config)\
   self.endpoint = (config).dsn or \"\"\
   self.timeout = (config).timeout or 30\
   self.file_path = (config).file_path or \"sentry-events.log\"\
   self.append_mode = (config).append_mode ~= false\
\
   if (config).file_io then\
      self.file_io = (config).file_io\
   else\
      self.file_io = file_io.create_standard_file_io()\
   end\
\
   local dir_path = self.file_path:match(\"^(.*/)\")\
   if dir_path then\
      local dir_success, dir_err = self.file_io:ensure_directory(dir_path)\
      if not dir_success then\
         print(\"Warning: Failed to create directory: \" .. dir_err)\
      end\
   end\
\
   self.headers = {\
      [\"Content-Type\"] = \"application/json\",\
      [\"User-Agent\"] = \"sentry-lua-file/\" .. version,\
   }\
\
   return self\
end\
\
\
local function create_file_transport(config)\
   local transport = FileTransport\
   return transport:configure(config)\
end\
\
\
local function is_file_available()\
   return true\
end\
\
\
transport_utils.register_transport_factory({\
   name = \"file\",\
   priority = 10,\
   create = create_file_transport,\
   is_available = is_file_available,\
})\
\
return {\
   FileTransport = FileTransport,\
   create_file_transport = create_file_transport,\
   is_file_available = is_file_available,\
}\
", '@'.."build/sentry/platforms/standard/file_transport.lua" ) )

package.preload[ "sentry.platforms.standard.os_detection" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local os_utils = require(\"sentry.utils.os\")\
local OSInfo = os_utils.OSInfo\
\
local function detect_os()\
\
   local handle = io.popen(\"uname -s 2>/dev/null\")\
   if handle then\
      local name = handle:read(\"*a\")\
      handle:close()\
      if name then\
         name = name:gsub(\"\\n\", \"\")\
         if name ~= \"\" then\
\
            if name == \"Darwin\" then\
\
               local sw_vers = io.popen(\"sw_vers -productVersion 2>/dev/null\")\
               if sw_vers then\
                  local macos_version = sw_vers:read(\"*a\")\
                  sw_vers:close()\
                  if macos_version and macos_version:gsub(\"\\n\", \"\") ~= \"\" then\
                     return {\
                        name = \"macOS\",\
                        version = macos_version:gsub(\"\\n\", \"\"),\
                     }\
                  end\
               end\
\
               name = \"Darwin\"\
            end\
\
\
            local version_handle = io.popen(\"uname -r 2>/dev/null\")\
            if version_handle then\
               local version = version_handle:read(\"*a\")\
               version_handle:close()\
               if version then\
                  version = version:gsub(\"\\n\", \"\")\
                  return {\
                     name = name,\
                     version = version,\
                  }\
               end\
            end\
\
            return {\
               name = name,\
               version = nil,\
            }\
         end\
      end\
   end\
\
\
   local sep = package.config:sub(1, 1)\
   if sep == \"\\\\\" then\
\
      local handle_win = io.popen(\"ver 2>nul\")\
      if handle_win then\
         local output = handle_win:read(\"*a\")\
         handle_win:close()\
         if output and output:match(\"Microsoft Windows\") then\
            local version = output:match(\"%[Version ([^%]]+)%]\")\
            return {\
               name = \"Windows\",\
               version = version or nil,\
            }\
         end\
      end\
   end\
\
   return nil\
end\
\
\
os_utils.register_detector({\
   detect = detect_os,\
})\
\
return {\
   detect_os = detect_os,\
}\
", '@'.."build/sentry/platforms/standard/os_detection.lua" ) )

package.preload[ "sentry.platforms.standard.transport" ] = assert( (loadstring or load)( "\
local transport_utils = require(\"sentry.utils.transport\")\
local dsn_utils = require(\"sentry.utils.dsn\")\
local json = require(\"sentry.utils.json\")\
local http = require(\"sentry.utils.http\")\
local version = require(\"sentry.version\")\
\
local HttpTransport = {}\
\
\
\
\
\
\
\
\
function HttpTransport:send(event)\
   local body = json.encode(event)\
\
   local request = {\
      url = self.endpoint,\
      method = \"POST\",\
      headers = self.headers,\
      body = body,\
      timeout = self.timeout,\
   }\
\
   local response = http.request(request)\
\
   if response.success and response.status == 200 then\
      return true, \"Event sent successfully\"\
   else\
      local error_msg = response.error or \"Failed to send event: \" .. tostring(response.status)\
      return false, error_msg\
   end\
end\
\
\
function HttpTransport:send_envelope(envelope_body)\
   local request = {\
      url = self.envelope_endpoint,\
      method = \"POST\",\
      headers = self.envelope_headers,\
      body = envelope_body,\
      timeout = self.timeout,\
   }\
\
   local response = http.request(request)\
\
   if response.success and response.status == 200 then\
      return true, \"Envelope sent successfully\"\
   else\
      local error_msg = response.error or \"Failed to send envelope: \" .. tostring(response.status)\
      return false, error_msg\
   end\
end\
\
function HttpTransport:configure(config)\
   local dsn, err = dsn_utils.parse_dsn((config).dsn or \"\")\
   if err then\
      error(\"Invalid DSN: \" .. err)\
   end\
\
   self.dsn = dsn\
   self.endpoint = dsn_utils.build_ingest_url(dsn)\
   self.envelope_endpoint = dsn_utils.build_envelope_url(dsn)\
   self.timeout = (config).timeout or 30\
   self.headers = {\
      [\"Content-Type\"] = \"application/json\",\
      [\"User-Agent\"] = \"sentry-lua/\" .. version,\
      [\"X-Sentry-Auth\"] = dsn_utils.build_auth_header(dsn),\
   }\
   self.envelope_headers = {\
      [\"Content-Type\"] = \"application/x-sentry-envelope\",\
      [\"User-Agent\"] = \"sentry-lua/\" .. version,\
      [\"X-Sentry-Auth\"] = dsn_utils.build_auth_header(dsn),\
   }\
   return self\
end\
\
\
local function create_http_transport(config)\
   local transport = HttpTransport\
   return transport:configure(config)\
end\
\
\
local function is_http_available()\
   return http.available\
end\
\
\
transport_utils.register_transport_factory({\
   name = \"standard-http\",\
   priority = 100,\
   create = create_http_transport,\
   is_available = is_http_available,\
})\
\
return {\
   HttpTransport = HttpTransport,\
   create_http_transport = create_http_transport,\
   is_http_available = is_http_available,\
}\
", '@'.."build/sentry/platforms/standard/transport.lua" ) )

package.preload[ "sentry.platforms.test.transport" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local table = _tl_compat and _tl_compat.table or table\
local transport_utils = require(\"sentry.utils.transport\")\
local version = require(\"sentry.version\")\
\
local TestTransport = {}\
\
\
\
\
\
\
function TestTransport:send(event)\
   table.insert(self.events, event)\
   return true, \"Event captured in test transport\"\
end\
\
function TestTransport:configure(config)\
   self.endpoint = (config).dsn or \"\"\
   self.timeout = (config).timeout or 30\
   self.headers = {\
      [\"Content-Type\"] = \"application/json\",\
      [\"User-Agent\"] = \"sentry-lua-test/\" .. version,\
   }\
   self.events = {}\
   return self\
end\
\
function TestTransport:get_events()\
   return self.events\
end\
\
function TestTransport:clear_events()\
   self.events = {}\
end\
\
\
local function create_test_transport(config)\
   local transport = TestTransport\
   return transport:configure(config)\
end\
\
\
local function is_test_available()\
   return true\
end\
\
\
transport_utils.register_transport_factory({\
   name = \"test\",\
   priority = 1,\
   create = create_test_transport,\
   is_available = is_test_available,\
})\
\
return {\
   TestTransport = TestTransport,\
   create_test_transport = create_test_transport,\
   is_test_available = is_test_available,\
}\
", '@'.."build/sentry/platforms/test/transport.lua" ) )

package.preload[ "sentry.tracing.headers" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
local headers = {}\
\
local utils = require(\"sentry.utils\")\
\
\
local TRACE_ID_LENGTH = 32\
local SPAN_ID_LENGTH = 16\
\
\
\
\
function headers.parse_sentry_trace(header_value)\
   if not header_value or type(header_value) ~= \"string\" then\
      return nil\
   end\
\
\
   local trimmed = header_value:match(\"^%s*(.-)%s*$\")\
   if not trimmed then\
      return nil\
   end\
   header_value = trimmed\
\
   if #header_value == 0 then\
      return nil\
   end\
\
\
   local parts = {}\
   for part in header_value:gmatch(\"[^%-]+\") do\
      table.insert(parts, part)\
   end\
\
\
   if #parts < 2 then\
      return nil\
   end\
\
   local trace_id = parts[1]\
   local span_id = parts[2]\
   local sampled = parts[3]\
\
\
   if not trace_id or #trace_id ~= TRACE_ID_LENGTH then\
      return nil\
   end\
\
   if not trace_id:match(\"^[0-9a-fA-F]+$\") then\
      return nil\
   end\
\
\
   if not span_id or #span_id ~= SPAN_ID_LENGTH then\
      return nil\
   end\
\
   if not span_id:match(\"^[0-9a-fA-F]+$\") then\
      return nil\
   end\
\
\
   local parsed_sampled = nil\
   if sampled then\
      if sampled == \"1\" then\
         parsed_sampled = true\
      elseif sampled == \"0\" then\
         parsed_sampled = false\
      else\
\
         parsed_sampled = nil\
      end\
   end\
\
   return {\
      trace_id = trace_id:lower(),\
      span_id = span_id:lower(),\
      sampled = parsed_sampled,\
   }\
end\
\
\
\
\
function headers.generate_sentry_trace(trace_data)\
   if not trace_data or type(trace_data) ~= \"table\" then\
      return nil\
   end\
\
   local trace_id = trace_data.trace_id\
   local span_id = trace_data.span_id\
   local sampled = trace_data.sampled\
\
\
   if not trace_id or not span_id then\
      return nil\
   end\
\
\
   if type(trace_id) ~= \"string\" or #trace_id ~= TRACE_ID_LENGTH then\
      return nil\
   end\
\
   if not trace_id:match(\"^[0-9a-fA-F]+$\") then\
      return nil\
   end\
\
\
   if type(span_id) ~= \"string\" or #span_id ~= SPAN_ID_LENGTH then\
      return nil\
   end\
\
   if not span_id:match(\"^[0-9a-fA-F]+$\") then\
      return nil\
   end\
\
\
   local header_value = trace_id:lower() .. \"-\" .. span_id:lower()\
\
\
   if sampled == true then\
      header_value = header_value .. \"-1\"\
   elseif sampled == false then\
      header_value = header_value .. \"-0\"\
   end\
\
\
   return header_value\
end\
\
\
\
\
\
function headers.parse_baggage(header_value)\
   local baggage_data = {}\
\
   if not header_value or type(header_value) ~= \"string\" then\
      return baggage_data\
   end\
\
\
   local trimmed = header_value:match(\"^%s*(.-)%s*$\")\
   if not trimmed then\
      return baggage_data\
   end\
   header_value = trimmed\
\
   if #header_value == 0 then\
      return baggage_data\
   end\
\
\
   for item in header_value:gmatch(\"[^,]+\") do\
      local trimmed_item = item:match(\"^%s*(.-)%s*$\")\
      if trimmed_item then\
         item = trimmed_item\
      end\
\
\
      local key_value_part = item:match(\"([^;]*)\")\
      if key_value_part then\
         local trimmed_kvp = key_value_part:match(\"^%s*(.-)%s*$\")\
         if trimmed_kvp then\
            key_value_part = trimmed_kvp\
         end\
\
\
         local key, value = key_value_part:match(\"^([^=]+)=(.*)$\")\
         if key and value then\
            local trimmed_key = key:match(\"^%s*(.-)%s*$\")\
            local trimmed_value = value:match(\"^%s*(.-)%s*$\")\
\
\
            if trimmed_key and trimmed_value and #trimmed_key > 0 then\
               baggage_data[trimmed_key] = trimmed_value\
            end\
         end\
      end\
   end\
\
   return baggage_data\
end\
\
\
\
\
function headers.generate_baggage(baggage_data)\
   if not baggage_data or type(baggage_data) ~= \"table\" then\
      return nil\
   end\
\
   local items = {}\
   for key, value in pairs(baggage_data) do\
      if type(key) == \"string\" and type(value) == \"string\" then\
\
         local encoded_value = value:gsub(\"([,;=%%])\", function(c)\
            return string.format(\"%%%02X\", string.byte(c))\
         end)\
\
         table.insert(items, key .. \"=\" .. encoded_value)\
      end\
   end\
\
   if #items == 0 then\
      return nil\
   end\
\
   return table.concat(items, \",\")\
end\
\
\
\
function headers.generate_trace_id()\
   local uuid_result = utils.generate_uuid():gsub(\"-\", \"\")\
   return uuid_result\
end\
\
\
\
function headers.generate_span_id()\
   local uuid_result = utils.generate_uuid():gsub(\"-\", \"\"):sub(1, 16)\
   return uuid_result\
end\
\
\
\
\
function headers.extract_trace_headers(http_headers)\
   if not http_headers or type(http_headers) ~= \"table\" then\
      return {}\
   end\
\
\
   local function get_header(name)\
      local name_lower = name:lower()\
      for key, value in pairs(http_headers) do\
         if type(key) == \"string\" and key:lower() == name_lower then\
            return value\
         end\
      end\
      return nil\
   end\
\
   local trace_info = {}\
\
\
   local sentry_trace = get_header(\"sentry-trace\")\
   if sentry_trace then\
      trace_info.sentry_trace = headers.parse_sentry_trace(sentry_trace)\
   end\
\
\
   local baggage = get_header(\"baggage\")\
   if baggage then\
      trace_info.baggage = headers.parse_baggage(baggage)\
   end\
\
\
   local traceparent = get_header(\"traceparent\")\
   if traceparent then\
      trace_info.traceparent = traceparent\
   end\
\
   return trace_info\
end\
\
\
\
\
\
\
function headers.inject_trace_headers(http_headers, trace_data, baggage_data, options)\
   if not http_headers or type(http_headers) ~= \"table\" then\
      return\
   end\
\
   if not trace_data or type(trace_data) ~= \"table\" then\
      return\
   end\
\
   options = options or {}\
\
\
   local sentry_trace = headers.generate_sentry_trace(trace_data)\
   if sentry_trace then\
      http_headers[\"sentry-trace\"] = sentry_trace\
   end\
\
\
   if baggage_data then\
      local baggage = headers.generate_baggage(baggage_data)\
      if baggage then\
         http_headers[\"baggage\"] = baggage\
      end\
   end\
\
\
   if options.include_traceparent and trace_data.trace_id and trace_data.span_id then\
\
      local flags = \"00\"\
      if trace_data.sampled == true then\
         flags = \"01\"\
      end\
\
      http_headers[\"traceparent\"] = \"00-\" .. trace_data.trace_id .. \"-\" .. trace_data.span_id .. \"-\" .. flags\
   end\
end\
\
return headers\
", '@'.."build/sentry/tracing/headers.lua" ) )

package.preload[ "sentry.tracing.init" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local pcall = _tl_compat and _tl_compat.pcall or pcall\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
local tracing = {}\
\
local headers = require(\"sentry.tracing.headers\")\
local propagation = require(\"sentry.tracing.propagation\")\
\
\
local performance = nil\
local has_performance, perf_module = pcall(require, \"sentry.performance\")\
if has_performance then\
   performance = perf_module\
end\
\
\
tracing.headers = headers\
tracing.propagation = propagation\
if performance then\
   tracing.performance = performance\
end\
\
\
\
function tracing.init(config)\
   config = config or {}\
\
\
   tracing._config = config\
\
\
   local current = propagation.get_current_context()\
   if not current then\
      propagation.start_new_trace()\
   end\
end\
\
\
\
\
\
function tracing.continue_trace_from_request(request_headers)\
   local context = propagation.continue_trace_from_headers(request_headers)\
\
\
   local trace_context = propagation.get_trace_context_for_event()\
   if trace_context then\
\
\
   end\
\
   return trace_context\
end\
\
\
\
\
\
function tracing.get_request_headers(target_url)\
   local config = tracing._config or {}\
\
   local options = {\
      trace_propagation_targets = config.trace_propagation_targets,\
      include_traceparent = config.include_traceparent,\
   }\
\
   return propagation.get_trace_headers_for_request(target_url, options)\
end\
\
\
\
\
function tracing.start_trace(options)\
   local context = propagation.start_new_trace(options)\
   return propagation.get_trace_context_for_event()\
end\
\
\
\
\
\
\
function tracing.start_transaction(name, op, options)\
   options = options or {}\
\
\
   if performance then\
\
      local trace_context = propagation.get_current_context()\
      if trace_context then\
         options.trace_id = trace_context.trace_id\
         options.parent_span_id = trace_context.span_id\
      end\
\
      return performance.start_transaction(name, op, options)\
   end\
\
\
   return tracing.start_trace(options)\
end\
\
\
\
function tracing.finish_transaction(status)\
   if performance then\
      performance.finish_transaction(status)\
   end\
end\
\
\
\
\
\
\
function tracing.start_span(op, description, options)\
   if performance then\
      return performance.start_span(op, description, options)\
   end\
\
\
   return tracing.create_child(options)\
end\
\
\
\
function tracing.finish_span(status)\
   if performance then\
      performance.finish_span(status)\
   end\
end\
\
\
\
\
function tracing.create_child(options)\
   local child_context = propagation.create_child_context(options)\
   return {\
      trace_id = child_context.trace_id,\
      span_id = child_context.span_id,\
      parent_span_id = child_context.parent_span_id,\
   }\
end\
\
\
\
function tracing.get_current_trace_info()\
   local context = propagation.get_current_context()\
   if not context then\
      return nil\
   end\
\
   return {\
      trace_id = context.trace_id,\
      span_id = context.span_id,\
      parent_span_id = context.parent_span_id,\
      sampled = context.sampled,\
      is_tracing_enabled = propagation.is_tracing_enabled(),\
   }\
end\
\
\
\
function tracing.is_active()\
   return propagation.is_tracing_enabled()\
end\
\
\
function tracing.clear()\
   propagation.clear_context()\
   tracing._config = nil\
end\
\
\
\
\
function tracing.attach_trace_context_to_event(event)\
   if not event or type(event) ~= \"table\" then\
      return event\
   end\
\
   local trace_context = propagation.get_trace_context_for_event()\
   if trace_context then\
      event.contexts = event.contexts or {}\
      event.contexts.trace = trace_context\
   end\
\
   return event\
end\
\
\
\
function tracing.get_envelope_trace_header()\
   return propagation.get_dynamic_sampling_context()\
end\
\
\
\
\
\
\
function tracing.wrap_http_request(http_client, url, options)\
   if type(http_client) ~= \"function\" then\
      error(\"http_client must be a function\")\
   end\
\
   options = options or {}\
   options.headers = options.headers or {}\
\
\
   local trace_headers = tracing.get_request_headers(url)\
   for key, value in pairs(trace_headers) do\
      options.headers[key] = value\
   end\
\
\
   return http_client(url, options)\
end\
\
\
\
\
function tracing.wrap_http_handler(handler)\
   if type(handler) ~= \"function\" then\
      error(\"handler must be a function\")\
   end\
\
   return function(request, response)\
\
      local request_headers = {}\
\
\
      if request and request.headers then\
         request_headers = request.headers\
      elseif request and request.get_header then\
\
         local get_header_fn = request.get_header\
         request_headers[\"sentry-trace\"] = get_header_fn(request, \"sentry-trace\")\
         request_headers[\"baggage\"] = get_header_fn(request, \"baggage\")\
         request_headers[\"traceparent\"] = get_header_fn(request, \"traceparent\")\
      end\
\
\
      tracing.continue_trace_from_request(request_headers)\
\
\
      local original_context = propagation.get_current_context()\
\
      local success, result = pcall(handler, request, response)\
\
\
      propagation.set_current_context(original_context)\
\
      if not success then\
         error(result)\
      end\
\
      return result\
   end\
end\
\
\
\
function tracing.generate_ids()\
   return {\
      trace_id = headers.generate_trace_id(),\
      span_id = headers.generate_span_id(),\
   }\
end\
\
return tracing\
", '@'.."build/sentry/tracing/init.lua" ) )

package.preload[ "sentry.tracing.propagation" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
local propagation = {}\
\
\
\
\
\
\
\
local headers = require(\"sentry.tracing.headers\")\
\
\
local current_context = nil\
\
\
\
\
\
function propagation.create_context(trace_data, baggage_data)\
   local context = {\
      trace_id = \"\",\
      span_id = \"\",\
      parent_span_id = nil,\
      sampled = nil,\
      baggage = {},\
      dynamic_sampling_context = {},\
   }\
\
   if trace_data then\
\
      context.trace_id = trace_data.trace_id\
      context.parent_span_id = trace_data.span_id\
      context.span_id = headers.generate_span_id()\
      context.sampled = trace_data.sampled\
   else\
\
      context.trace_id = headers.generate_trace_id()\
      context.span_id = headers.generate_span_id()\
      context.parent_span_id = nil\
      context.sampled = nil\
   end\
\
   context.baggage = baggage_data or {}\
   context.dynamic_sampling_context = {}\
\
\
   propagation.populate_dynamic_sampling_context(context)\
\
   return context\
end\
\
\
\
function propagation.populate_dynamic_sampling_context(context)\
   if not context or not context.trace_id then\
      return\
   end\
\
   local dsc = context.dynamic_sampling_context\
\
\
   dsc[\"sentry-trace_id\"] = context.trace_id\
\
\
\
\
\
\
\
\
\
\
\
\
end\
\
\
\
function propagation.get_current_context()\
   return current_context\
end\
\
\
\
function propagation.set_current_context(context)\
   current_context = context\
end\
\
\
\
\
function propagation.continue_trace_from_headers(http_headers)\
   local trace_info = headers.extract_trace_headers(http_headers)\
\
   local trace_data = nil\
   local baggage_data = trace_info.baggage or {}\
\
\
   if trace_info.sentry_trace then\
      local sentry_trace_data = trace_info.sentry_trace\
      trace_data = {\
         trace_id = sentry_trace_data.trace_id,\
         span_id = sentry_trace_data.span_id,\
         sampled = sentry_trace_data.sampled,\
      }\
   elseif trace_info.traceparent then\
\
      local version, trace_id, span_id, flags = trace_info.traceparent:match(\"^([0-9a-fA-F][0-9a-fA-F])%-([0-9a-fA-F]+)%-([0-9a-fA-F]+)%-([0-9a-fA-F][0-9a-fA-F])$\")\
      if version == \"00\" and trace_id and span_id and #trace_id == 32 and #span_id == 16 then\
         trace_data = {\
            trace_id = trace_id,\
            span_id = span_id,\
            sampled = (tonumber(flags, 16) or 0) > 0 and true or nil,\
         }\
      end\
   end\
\
   local context = propagation.create_context(trace_data, baggage_data)\
   propagation.set_current_context(context)\
\
   return context\
end\
\
\
\
\
\
function propagation.get_trace_headers_for_request(target_url, options)\
   local context = propagation.get_current_context()\
   if not context then\
      return {}\
   end\
\
   options = options or {}\
   local result_headers = {}\
\
\
   local should_propagate = true\
   if options.trace_propagation_targets then\
      should_propagate = false\
      for _, target in ipairs(options.trace_propagation_targets) do\
         if target == \"*\" then\
\
            should_propagate = true\
            break\
         elseif target_url and target_url:find(target) then\
\
            should_propagate = true\
            break\
         end\
      end\
   end\
\
   if not should_propagate then\
      return {}\
   end\
\
\
   local trace_data = {\
      trace_id = context.trace_id,\
      span_id = context.span_id,\
      sampled = context.sampled,\
   }\
\
\
   local headers_trace_data = {\
      trace_id = trace_data.trace_id,\
      span_id = trace_data.span_id,\
      sampled = trace_data.sampled,\
   }\
   headers.inject_trace_headers(result_headers, headers_trace_data, context.baggage, {\
      include_traceparent = options.include_traceparent,\
   })\
\
   return result_headers\
end\
\
\
\
function propagation.get_trace_context_for_event()\
   local context = propagation.get_current_context()\
   if not context or not context.trace_id then\
      return nil\
   end\
\
   return {\
      trace_id = context.trace_id,\
      span_id = context.span_id,\
      parent_span_id = context.parent_span_id,\
\
   }\
end\
\
\
\
function propagation.get_dynamic_sampling_context()\
   local context = propagation.get_current_context()\
   if not context or not context.dynamic_sampling_context then\
      return nil\
   end\
\
\
   local dsc = {}\
   for k, v in pairs(context.dynamic_sampling_context) do\
      dsc[k] = v\
   end\
\
   return dsc\
end\
\
\
\
\
function propagation.start_new_trace(options)\
   options = options or {}\
\
   local context = propagation.create_context(nil, options.baggage)\
   propagation.set_current_context(context)\
\
   return context\
end\
\
\
function propagation.clear_context()\
   current_context = nil\
end\
\
\
\
\
function propagation.create_child_context(options)\
   local parent_context = propagation.get_current_context()\
   if not parent_context then\
\
      return propagation.start_new_trace(options)\
   end\
\
   options = options or {}\
\
   local child_context = {\
      trace_id = parent_context.trace_id,\
      span_id = headers.generate_span_id(),\
      parent_span_id = parent_context.span_id,\
      sampled = parent_context.sampled,\
      baggage = parent_context.baggage,\
      dynamic_sampling_context = parent_context.dynamic_sampling_context,\
   }\
\
   return child_context\
end\
\
\
\
function propagation.is_tracing_enabled()\
   local context = propagation.get_current_context()\
   return context ~= nil and context.trace_id ~= nil\
end\
\
\
\
function propagation.get_current_trace_id()\
   local context = propagation.get_current_context()\
   return context and context.trace_id or nil\
end\
\
\
\
function propagation.get_current_span_id()\
   local context = propagation.get_current_context()\
   return context and context.span_id or nil\
end\
\
return propagation\
", '@'.."build/sentry/tracing/propagation.lua" ) )

package.preload[ "sentry.types" ] = assert( (loadstring or load)( "\
\
\
local SentryOptions = {}\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
local User = {}\
\
\
\
\
\
\
\
\
local Breadcrumb = {}\
\
\
\
\
\
\
\
\
local RuntimeContext = {}\
\
\
\
\
\
local OSContext = {}\
\
\
\
\
\
\
local DeviceContext = {}\
\
\
\
\
\
\
\
\
\
\
\
\
local StackFrame = {}\
\
\
\
\
\
\
\
local StackTrace = {}\
\
\
\
\
local Exception = {}\
\
\
\
\
\
\
\
\
local EventData = {}\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
local types = {\
   SentryOptions = SentryOptions,\
   User = User,\
   Breadcrumb = Breadcrumb,\
   RuntimeContext = RuntimeContext,\
   OSContext = OSContext,\
   DeviceContext = DeviceContext,\
   StackFrame = StackFrame,\
   StackTrace = StackTrace,\
   Exception = Exception,\
   EventData = EventData,\
}\
\
return types\
", '@'.."build/sentry/types.lua" ) )

package.preload[ "sentry.utils" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local math = _tl_compat and _tl_compat.math or math; local os = _tl_compat and _tl_compat.os or os; local pairs = _tl_compat and _tl_compat.pairs or pairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
local utils = {}\
\
\
\
function utils.generate_uuid()\
\
   if not utils._random_seeded then\
      math.randomseed(os.time())\
      utils._random_seeded = true\
   end\
\
   local template = \"xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx\"\
\
   local result = template:gsub(\"[xy]\", function(c)\
      local v = (c == \"x\") and math.random(0, 15) or math.random(8, 11)\
      return string.format(\"%x\", v)\
   end)\
   return result\
end\
\
\
\
\
function utils.generate_hex(length)\
   if not utils._random_seeded then\
      math.randomseed(os.time())\
      utils._random_seeded = true\
   end\
\
   local hex_chars = \"0123456789abcdef\"\
   local result = {}\
\
   for _ = 1, length do\
      local idx = math.random(1, #hex_chars)\
      table.insert(result, hex_chars:sub(idx, idx))\
   end\
\
   return table.concat(result)\
end\
\
\
\
\
function utils.url_encode(str)\
   if not str then\
      return \"\"\
   end\
\
   str = tostring(str)\
\
\
   str = str:gsub(\"([^%w%-%.%_%~])\", function(c)\
      return string.format(\"%%%02X\", string.byte(c))\
   end)\
\
   return str\
end\
\
\
\
\
function utils.url_decode(str)\
   if not str then\
      return \"\"\
   end\
\
   str = tostring(str)\
\
\
   str = str:gsub(\"%%(%x%x)\", function(hex)\
      return string.char(tonumber(hex, 16))\
   end)\
\
   return str\
end\
\
\
\
\
function utils.is_empty(str)\
   return not str or str == \"\"\
end\
\
\
\
\
function utils.trim(str)\
   if not str then\
      return \"\"\
   end\
\
   return str:match(\"^%s*(.-)%s*$\") or \"\"\
end\
\
\
\
\
function utils.deep_copy(orig)\
   local copy\
   if type(orig) == \"table\" then\
      copy = {}\
      local orig_table = orig\
      for orig_key, orig_value in next, orig_table, nil do\
         (copy)[utils.deep_copy(orig_key)] = utils.deep_copy(orig_value)\
      end\
      setmetatable(copy, utils.deep_copy(getmetatable(orig)))\
   else\
      copy = orig\
   end\
   return copy\
end\
\
\
\
\
\
function utils.merge_tables(t1, t2)\
   local result = {}\
\
   if t1 then\
      for k, v in pairs(t1) do\
         result[k] = v\
      end\
   end\
\
   if t2 then\
      for k, v in pairs(t2) do\
         result[k] = v\
      end\
   end\
\
   return result\
end\
\
\
\
function utils.get_timestamp()\
   return os.time()\
end\
\
\
\
function utils.get_timestamp_ms()\
\
   local success, socket_module = pcall(require, \"socket\")\
   if success and socket_module and type(socket_module) == \"table\" then\
      local socket_table = socket_module\
      if socket_table[\"gettime\"] and type(socket_table[\"gettime\"]) == \"function\" then\
         local gettime = socket_table[\"gettime\"]\
         return math.floor(gettime() * 1000)\
      end\
   end\
\
\
   return os.time() * 1000\
end\
\
return utils\
", '@'.."build/sentry/utils.lua" ) )

package.preload[ "sentry.utils.dsn" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local version = require(\"sentry.version\")\
\
local DSN = {}\
\
\
\
\
\
\
\
\
\
local function parse_dsn(dsn_string)\
   if not dsn_string or dsn_string == \"\" then\
      return {}, \"DSN is required\"\
   end\
\
\
\
\
   local protocol, credentials, host_path = dsn_string:match(\"^(https?)://([^@]+)@(.+)$\")\
\
   if not protocol or not credentials or not host_path then\
      return {}, \"Invalid DSN format\"\
   end\
\
\
   local public_key, secret_key = credentials:match(\"^([^:]+):(.+)$\")\
   if not public_key then\
      public_key = credentials\
      secret_key = \"\"\
   end\
\
   if not public_key or public_key == \"\" then\
      return {}, \"Invalid DSN format\"\
   end\
\
\
   local host, path = host_path:match(\"^([^/]+)(.*)$\")\
   if not host or not path or path == \"\" then\
      return {}, \"Invalid DSN format\"\
   end\
\
\
   local project_id = path:match(\"/([%d]+)$\")\
   if not project_id then\
      return {}, \"Could not extract project ID from DSN\"\
   end\
\
\
   local port = 443\
   if protocol == \"http\" then\
      port = 80\
   end\
\
   local host_part, port_part = host:match(\"^([^:]+):?(%d*)$\")\
   if host_part then\
      host = host_part\
      if port_part and port_part ~= \"\" then\
         port = tonumber(port_part) or port\
      end\
   end\
\
   return {\
      protocol = protocol,\
      public_key = public_key,\
      secret_key = secret_key or \"\",\
      host = host,\
      port = port,\
      path = path,\
      project_id = project_id,\
   }, nil\
end\
\
local function build_ingest_url(dsn)\
   return string.format(\"%s://%s/api/%s/store/\",\
   dsn.protocol,\
   dsn.host,\
   dsn.project_id)\
end\
\
local function build_envelope_url(dsn)\
   return string.format(\"%s://%s/api/%s/envelope/\",\
   dsn.protocol,\
   dsn.host,\
   dsn.project_id)\
end\
\
local function build_auth_header(dsn)\
   local auth_parts = {\
      \"Sentry sentry_version=7\",\
      \"sentry_key=\" .. dsn.public_key,\
      \"sentry_client=sentry-lua/\" .. version,\
   }\
\
   if dsn.secret_key and dsn.secret_key ~= \"\" then\
      table.insert(auth_parts, \"sentry_secret=\" .. dsn.secret_key)\
   end\
\
   return table.concat(auth_parts, \", \")\
end\
\
\
return {\
   parse_dsn = parse_dsn,\
   build_ingest_url = build_ingest_url,\
   build_envelope_url = build_envelope_url,\
   build_auth_header = build_auth_header,\
   DSN = DSN,\
}\
", '@'.."build/sentry/utils/dsn.lua" ) )

package.preload[ "sentry.utils.envelope" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table\
\
\
local json = require(\"sentry.utils.json\")\
\
\
\
\
\
local function build_transaction_envelope(transaction, event_id)\
\
   local sent_at = os.date(\"!%Y-%m-%dT%H:%M:%SZ\")\
\
\
   local envelope_header = {\
      event_id = event_id,\
      sent_at = sent_at,\
   }\
\
\
   local transaction_json = json.encode(transaction)\
   local payload_length = string.len(transaction_json)\
\
\
   local item_header = {\
      type = \"transaction\",\
      length = payload_length,\
   }\
\
\
   local envelope_parts = {\
      json.encode(envelope_header),\
      json.encode(item_header),\
      transaction_json,\
   }\
\
   return table.concat(envelope_parts, \"\\n\")\
end\
\
\
\
\
local function build_log_envelope(log_records)\
   if not log_records or #log_records == 0 then\
      return \"\"\
   end\
\
\
   local sent_at = os.date(\"!%Y-%m-%dT%H:%M:%SZ\") or \"\"\
\
\
   local envelope_header = {\
      sent_at = sent_at,\
   }\
\
\
   local log_items = {\
      items = log_records,\
   }\
\
\
   local log_json = json.encode(log_items)\
\
\
   local item_header = {\
      type = \"log\",\
      item_count = #log_records,\
      content_type = \"application/vnd.sentry.items.log+json\",\
   }\
\
\
   local envelope_parts = {\
      json.encode(envelope_header),\
      json.encode(item_header),\
      log_json,\
   }\
\
   return table.concat(envelope_parts, \"\\n\")\
end\
\
return {\
   build_transaction_envelope = build_transaction_envelope,\
   build_log_envelope = build_log_envelope,\
}\
", '@'.."build/sentry/utils/envelope.lua" ) )

package.preload[ "sentry.utils.http" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table\
local HTTPResponse = {}\
\
\
\
\
\
\
local HTTPRequest = {}\
\
\
\
\
\
\
\
\
local http_impl = nil\
local http_type = \"none\"\
\
\
local function try_luasocket()\
   local success, http = pcall(require, \"socket.http\")\
   local success_https, https = pcall(require, \"ssl.https\")\
   local success_ltn12, ltn12 = pcall(require, \"ltn12\")\
   if success and success_ltn12 then\
      return {\
         request = function(req)\
            local url = req.url\
            local is_https = url:match(\"^https://\")\
            local http_lib = (is_https and success_https) and https or http\
\
            if not http_lib then\
               return {\
                  success = false,\
                  error = \"HTTPS not supported\",\
                  status = 0,\
                  body = \"\",\
               }\
            end\
\
            local response_body = {}\
            local result, status = http_lib.request({\
               url = url,\
               method = req.method,\
               headers = req.headers,\
               source = req.body and ltn12.source.string(req.body) or nil,\
               sink = ltn12.sink.table(response_body),\
            })\
\
            return {\
               success = result ~= nil,\
               status = status or 0,\
               body = table.concat(response_body or {}),\
               error = result and \"\" or \"HTTP request failed\",\
            }\
         end,\
      }, \"luasocket\"\
   end\
   return nil, nil\
end\
\
local function try_roblox()\
   if _G.game and _G.game.GetService then\
      local HttpService = game:GetService(\"HttpService\")\
      if HttpService then\
         return {\
            request = function(req)\
               local success, response = pcall(function()\
                  return HttpService:RequestAsync({\
                     Url = req.url,\
                     Method = req.method,\
                     Headers = req.headers,\
                     Body = req.body,\
                  })\
               end)\
\
               if success and response then\
                  return {\
                     success = true,\
                     status = response.StatusCode,\
                     body = response.Body,\
                     error = \"\",\
                  }\
               else\
                  return {\
                     success = false,\
                     status = 0,\
                     body = \"\",\
                     error = tostring(response),\
                  }\
               end\
            end,\
         }, \"roblox\"\
      end\
   end\
   return nil, nil\
end\
\
local function try_openresty()\
   if _G.ngx then\
      local success, httpc = pcall(require, \"resty.http\")\
      if success then\
         return {\
            request = function(req)\
               local http_client = httpc:new()\
               http_client:set_timeout((req.timeout or 30) * 1000)\
\
               local res, err = http_client:request_uri(req.url, {\
                  method = req.method,\
                  body = req.body,\
                  headers = req.headers,\
               })\
\
               if res then\
                  return {\
                     success = true,\
                     status = res.status,\
                     body = res.body,\
                     error = \"\",\
                  }\
               else\
                  return {\
                     success = false,\
                     status = 0,\
                     body = \"\",\
                     error = err or \"HTTP request failed\",\
                  }\
               end\
            end,\
         }, \"openresty\"\
      end\
   end\
   return nil, nil\
end\
\
\
local implementations = {\
   try_roblox,\
   try_openresty,\
   try_luasocket,\
}\
\
for _, impl_func in ipairs(implementations) do\
   local impl, impl_type = impl_func()\
   if impl then\
      http_impl = impl\
      http_type = impl_type\
      break\
   end\
end\
\
\
if not http_impl then\
   http_impl = {\
      request = function(req)\
         return {\
            success = false,\
            status = 0,\
            body = \"\",\
            error = \"No HTTP implementation available\",\
         }\
      end,\
   }\
   http_type = \"none\"\
end\
\
local function request(req)\
   return http_impl.request(req)\
end\
\
return {\
   request = request,\
   available = http_type ~= \"none\",\
   type = http_type,\
   HTTPRequest = HTTPRequest,\
   HTTPResponse = HTTPResponse,\
}\
", '@'.."build/sentry/utils/http.lua" ) )

package.preload[ "sentry.utils.json" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local table = _tl_compat and _tl_compat.table or table\
local json_lib = {}\
\
\
local json_impl = nil\
local json_type = \"none\"\
\
\
local json_libraries = {\
   { name = \"cjson\", type = \"cjson\" },\
   { name = \"dkjson\", type = \"dkjson\" },\
   { name = \"json\", type = \"json\" },\
}\
\
for _, lib in ipairs(json_libraries) do\
   local success, json_module = pcall(require, lib.name)\
   if success then\
      json_impl = json_module\
      json_type = lib.type\
      break\
   end\
end\
\
\
if not json_impl and _G.game and _G.game.GetService then\
   local HttpService = game:GetService(\"HttpService\")\
   if HttpService then\
      json_impl = {\
         encode = function(obj) return HttpService:JSONEncode(obj) end,\
         decode = function(str) return HttpService:JSONDecode(str) end,\
      }\
      json_type = \"roblox\"\
   end\
end\
\
\
if not json_impl then\
   local function simple_encode(obj)\
      if type(obj) == \"string\" then\
         return '\"' .. obj:gsub('\\\\', '\\\\\\\\'):gsub('\"', '\\\\\"') .. '\"'\
      elseif type(obj) == \"number\" or type(obj) == \"boolean\" then\
         return tostring(obj)\
      elseif obj == nil then\
         return \"null\"\
      elseif type(obj) == \"table\" then\
         local result = {}\
         local is_array = true\
         local array_index = 1\
\
\
         for k, _ in pairs(obj) do\
            if k ~= array_index then\
               is_array = false\
               break\
            end\
            array_index = array_index + 1\
         end\
\
         if is_array then\
\
            for i, v in ipairs(obj) do\
               table.insert(result, simple_encode(v))\
            end\
            return \"[\" .. table.concat(result, \",\") .. \"]\"\
         else\
\
            for k, v in pairs(obj) do\
               if type(k) == \"string\" then\
                  table.insert(result, '\"' .. k .. '\":' .. simple_encode(v))\
               end\
            end\
            return \"{\" .. table.concat(result, \",\") .. \"}\"\
         end\
      end\
      return \"null\"\
   end\
\
   json_impl = {\
      encode = simple_encode,\
      decode = function(str)\
         error(\"JSON decoding not supported in fallback mode\")\
      end,\
   }\
   json_type = \"fallback\"\
end\
\
\
local function encode(obj)\
   if json_type == \"dkjson\" then\
      return json_impl.encode(obj)\
   else\
      return json_impl.encode(obj)\
   end\
end\
\
local function decode(str)\
   if json_type == \"dkjson\" then\
      return json_impl.decode(str)\
   else\
      return json_impl.decode(str)\
   end\
end\
\
return {\
   encode = encode,\
   decode = decode,\
   available = json_impl ~= nil,\
   type = json_type,\
}\
", '@'.."build/sentry/utils/json.lua" ) )

package.preload[ "sentry.utils.os" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local table = _tl_compat and _tl_compat.table or table; local OSInfo = {}\
\
\
\
\
\
local OSDetector = {}\
\
\
\
local detectors = {}\
\
local function register_detector(detector)\
   table.insert(detectors, detector)\
end\
\
local function get_os_info()\
\
   for _, detector in ipairs(detectors) do\
      local success, result = pcall(detector.detect)\
      if success and result then\
         return result\
      end\
   end\
\
\
   return nil\
end\
\
return {\
   OSInfo = OSInfo,\
   OSDetector = OSDetector,\
   register_detector = register_detector,\
   get_os_info = get_os_info,\
   detectors = detectors,\
}\
", '@'.."build/sentry/utils/os.lua" ) )

package.preload[ "sentry.utils.runtime" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string\
\
local RuntimeInfo = {}\
\
\
\
\
\
local function detect_standard_lua()\
\
   local version = _VERSION or \"Lua (unknown version)\"\
   return {\
      name = \"Lua\",\
      version = version:match(\"Lua (%d+%.%d+)\") or version,\
      description = version,\
   }\
end\
\
local function detect_luajit()\
\
   if jit and jit.version then\
      return {\
         name = \"LuaJIT\",\
         version = jit.version:match(\"LuaJIT (%S+)\") or jit.version,\
         description = jit.version,\
      }\
   end\
   return nil\
end\
\
local function detect_roblox()\
\
   if game and game.GetService then\
\
      local version = \"Unknown\"\
\
      if version and version ~= \"\" then\
         return {\
            name = \"Luau\",\
            version = version,\
            description = \"Roblox Luau \" .. version,\
         }\
      else\
         return {\
            name = \"Luau\",\
            description = \"Roblox Luau\",\
         }\
      end\
   end\
   return nil\
end\
\
local function detect_defold()\
\
   if sys and sys.get_engine_info then\
      local engine_info = sys.get_engine_info()\
      return {\
         name = \"defold\",\
         version = engine_info.version or \"unknown\",\
         description = \"Defold \" .. (engine_info.version or \"unknown\"),\
      }\
   end\
   return nil\
end\
\
local function detect_love2d()\
\
   if love and love.getVersion then\
      local major, minor, revision, codename = love.getVersion()\
      local version = string.format(\"%d.%d.%d\", major, minor, revision)\
      return {\
         name = \"love2d\",\
         version = version,\
         description = \"LÖVE \" .. version .. \" (\" .. (codename or \"\") .. \")\",\
      }\
   end\
   return nil\
end\
\
local function detect_openresty()\
\
   if ngx and ngx.var then\
      local version = \"unknown\"\
      if ngx.config and ngx.config.ngx_lua_version then\
         version = ngx.config.ngx_lua_version\
      end\
      return {\
         name = \"OpenResty\",\
         version = version,\
         description = \"OpenResty/ngx_lua \" .. version,\
      }\
   end\
   return nil\
end\
\
local function get_runtime_info()\
\
   local detectors = {\
      detect_roblox,\
      detect_defold,\
      detect_love2d,\
      detect_openresty,\
      detect_luajit,\
   }\
\
   for _, detector in ipairs(detectors) do\
      local result = detector()\
      if result then\
         return result\
      end\
   end\
\
\
   return detect_standard_lua()\
end\
\
local runtime = {\
   get_runtime_info = get_runtime_info,\
   RuntimeInfo = RuntimeInfo,\
}\
\
return runtime\
", '@'.."build/sentry/utils/runtime.lua" ) )

package.preload[ "sentry.utils.serialize" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local math = _tl_compat and _tl_compat.math or math; local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local json = require(\"sentry.utils.json\")\
local version = require(\"sentry.version\")\
\
local EventData = {}\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
local function generate_event_id()\
   local chars = \"abcdef0123456789\"\
   local result = {}\
\
   for _ = 1, 32 do\
      local rand_idx = math.random(1, #chars)\
      table.insert(result, chars:sub(rand_idx, rand_idx))\
   end\
\
   return table.concat(result)\
end\
\
\
local function create_event(level, message, environment, release, stack_trace)\
   local event = {\
      event_id = generate_event_id(),\
      timestamp = os.time(),\
      level = level,\
      platform = \"lua\",\
      sdk = {\
         name = \"sentry.lua\",\
         version = version,\
      },\
      message = message,\
      environment = environment or \"production\",\
      release = release,\
      user = {},\
      tags = {},\
      extra = {},\
      breadcrumbs = {},\
      contexts = {},\
   }\
\
   if stack_trace and stack_trace.frames then\
      event.stacktrace = {\
         frames = stack_trace.frames,\
      }\
   end\
\
   return event\
end\
\
local function serialize_event(event)\
   return json.encode(event)\
end\
\
local serialize = {\
   create_event = create_event,\
   serialize_event = serialize_event,\
   generate_event_id = generate_event_id,\
   EventData = EventData,\
}\
\
return serialize\
", '@'.."build/sentry/utils/serialize.lua" ) )

package.preload[ "sentry.utils.stacktrace" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local debug = _tl_compat and _tl_compat.debug or debug; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local StackFrame = {}\
\
\
\
\
\
\
\
\
\
\
\
local StackTrace = {}\
\
\
\
\
local function get_source_context(filename, line_number)\
   local empty_array = {}\
\
   if line_number <= 0 then\
      return \"\", empty_array, empty_array\
   end\
\
\
   local file = io.open(filename, \"r\")\
   if not file then\
      return \"\", empty_array, empty_array\
   end\
\
\
   local all_lines = {}\
   local line_count = 0\
   for line in file:lines() do\
      line_count = line_count + 1\
      all_lines[line_count] = line\
   end\
   file:close()\
\
\
   local context_line = \"\"\
   local pre_context = {}\
   local post_context = {}\
\
   if line_number > 0 and line_number <= line_count then\
      context_line = (all_lines[line_number]) or \"\"\
\
\
      for i = math.max(1, line_number - 5), line_number - 1 do\
         if i >= 1 and i <= line_count then\
            table.insert(pre_context, (all_lines[i]) or \"\")\
         end\
      end\
\
\
      for i = line_number + 1, math.min(line_count, line_number + 5) do\
         if i >= 1 and i <= line_count then\
            table.insert(post_context, (all_lines[i]) or \"\")\
         end\
      end\
   end\
\
   return context_line, pre_context, post_context\
end\
\
local function get_stack_trace(skip_frames)\
   skip_frames = skip_frames or 0\
   local frames = {}\
   local level = 2 + (skip_frames or 0)\
\
   while true do\
      local info = debug.getinfo(level, \"nSluf\")\
      if not info then\
         break\
      end\
\
      local filename = info.source or \"unknown\"\
      if filename:sub(1, 1) == \"@\" then\
         filename = filename:sub(2)\
      elseif filename == \"=[C]\" then\
         filename = \"[C]\"\
      end\
\
\
      local in_app = true\
      if not info.source then\
         in_app = false\
      elseif filename == \"[C]\" then\
         in_app = false\
      elseif info.source:match(\"sentry\") then\
         in_app = false\
      elseif filename:match(\"^/opt/homebrew\") then\
         in_app = false\
      end\
\
\
      local function_name = info.name or \"anonymous\"\
      if info.namewhat and info.namewhat ~= \"\" then\
         function_name = info.name or \"anonymous\"\
      elseif info.what == \"main\" then\
         function_name = \"<main>\"\
      elseif info.what == \"C\" then\
         function_name = info.name or \"<C function>\"\
      end\
\
\
      local vars = {}\
      if info.what == \"Lua\" and in_app then\
\
         for i = 1, (info.nparams or 0) do\
            local name, value = debug.getlocal(level, i)\
            if name and not name:match(\"^%(\") then\
               local safe_value = value\
               local value_type = type(value)\
               if value_type == \"function\" then\
                  safe_value = \"<function>\"\
               elseif value_type == \"userdata\" then\
                  safe_value = \"<userdata>\"\
               elseif value_type == \"thread\" then\
                  safe_value = \"<thread>\"\
               elseif value_type == \"table\" then\
                  safe_value = \"<table>\"\
               end\
               vars[name] = safe_value\
            end\
         end\
\
\
         for i = (info.nparams or 0) + 1, 20 do\
            local name, value = debug.getlocal(level, i)\
            if not name then break end\
            if not name:match(\"^%(\") then\
               local safe_value = value\
               local value_type = type(value)\
               if value_type == \"function\" then\
                  safe_value = \"<function>\"\
               elseif value_type == \"userdata\" then\
                  safe_value = \"<userdata>\"\
               elseif value_type == \"thread\" then\
                  safe_value = \"<thread>\"\
               elseif value_type == \"table\" then\
                  safe_value = \"<table>\"\
               end\
               vars[name] = safe_value\
            end\
         end\
      end\
\
\
      local line_number = info.currentline or 0\
      if line_number < 0 then\
         line_number = 0\
      end\
\
\
      local context_line, pre_context, post_context = get_source_context(filename, line_number)\
\
      local frame = {\
         filename = filename,\
         [\"function\"] = function_name,\
         lineno = line_number,\
         in_app = in_app,\
         vars = vars,\
         abs_path = filename,\
         context_line = context_line,\
         pre_context = pre_context,\
         post_context = post_context,\
      }\
\
      table.insert(frames, frame)\
      level = level + 1\
   end\
\
\
   local inverted_frames = {}\
   for i = #frames, 1, -1 do\
      table.insert(inverted_frames, frames[i])\
   end\
\
   return { frames = inverted_frames }\
end\
\
local function format_stack_trace(stack_trace)\
   local lines = {}\
\
   for _, frame in ipairs(stack_trace.frames) do\
      local line = string.format(\"  %s:%d in %s\",\
      frame.filename,\
      frame.lineno,\
      frame[\"function\"])\
      table.insert(lines, line)\
   end\
\
   return table.concat(lines, \"\\n\")\
end\
\
local stacktrace = {\
   get_stack_trace = get_stack_trace,\
   format_stack_trace = format_stack_trace,\
   StackTrace = StackTrace,\
   StackFrame = StackFrame,\
}\
\
return stacktrace\
", '@'.."build/sentry/utils/stacktrace.lua" ) )

package.preload[ "sentry.utils.transport" ] = assert( (loadstring or load)( "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table\
local Transport = {}\
\
\
\
\
local TransportFactory = {}\
\
\
\
\
\
\
local factories = {}\
\
\
local function register_transport_factory(factory)\
   table.insert(factories, factory)\
\
   table.sort(factories, function(a, b)\
      return a.priority > b.priority\
   end)\
end\
\
\
local function create_transport(config)\
   for _, factory in ipairs(factories) do\
      if factory.is_available() then\
         return factory.create(config)\
      end\
   end\
\
\
   local TestTransport = require(\"sentry.core.test_transport\")\
   return TestTransport:configure(config)\
end\
\
\
local function get_available_transports()\
   local available = {}\
   for _, factory in ipairs(factories) do\
      if factory.is_available() then\
         table.insert(available, factory.name)\
      end\
   end\
   return available\
end\
\
return {\
   Transport = Transport,\
   TransportFactory = TransportFactory,\
   register_transport_factory = register_transport_factory,\
   create_transport = create_transport,\
   get_available_transports = get_available_transports,\
   factories = factories,\
}\
", '@'.."build/sentry/utils/transport.lua" ) )

package.preload[ "sentry.version" ] = assert( (loadstring or load)( "\
\
\
local VERSION = \"0.0.6\"\
\
return VERSION\
", '@'.."build/sentry/version.lua" ) )


-- Return the main sentry module
return require('sentry.init')
