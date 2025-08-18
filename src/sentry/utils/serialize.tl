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

local function create_event(level: string, message: string, context: table, stack_trace: table): EventData
   local ctx = context or {}
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
      user = (ctx as any).user or {},
      tags = (ctx as any).tags or {},
      extra = (ctx as any).extra or {},
      breadcrumbs = (ctx as any).breadcrumbs or {},
      environment = (ctx as any).environment or "production",
      release = (ctx as any).release,
      contexts = (ctx as any).contexts or {}
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