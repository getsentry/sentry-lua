local json = require("cjson")

local record EventData
   event_id: string
   timestamp: number
   level: string
   logger: string
   platform: string
   sdk: table
   message: string
   exception: table
   stacktrace: table
   user: table
   tags: {string: string}
   extra: {string: any}
   breadcrumbs: {table}
   environment: string
   release: string
   contexts: {string: any}
end

local function generate_event_id(): string
   local chars = "abcdef0123456789"
   local result: {string} = {}
   
   for _ = 1, 32 do
      local rand_idx = math.random(1, #chars)
      table.insert(result, chars:sub(rand_idx, rand_idx))
   end
   
   return table.concat(result)
end

-- Create a basic event structure - scope data will be applied separately
local function create_event(level: string, message: string, environment: string, release: string, stack_trace: table): EventData
   local event: EventData = {
      event_id = generate_event_id(),
      timestamp = os.time(),
      level = level,
      platform = "lua",
      sdk = {
         name = "sentry.lua",
         version = "0.0.1"
      },
      message = message,
      environment = environment or "production",
      release = release,
      user = {},
      tags = {},
      extra = {},
      breadcrumbs = {},
      contexts = {}
   }
   
   if stack_trace and stack_trace.frames then
      event.stacktrace = {
         frames = stack_trace.frames
      }
   end
   
   return event
end

local function serialize_event(event: EventData): string
   return json.encode(event)
end

local serialize = {
   create_event = create_event,
   serialize_event = serialize_event,
   generate_event_id = generate_event_id,
   EventData = EventData
}

return serialize