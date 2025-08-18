-- Core types for Sentry SDK

-- Sentry initialization options
local record SentryOptions
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
end

-- User information
local record User
   id: string
   email: string
   username: string
   ip_address: string
   segment: string
end

-- Breadcrumb data
local record Breadcrumb
   timestamp: number
   message: string
   category: string
   level: string
   data: {string: any}
end

-- Context information (runtime, OS, device, etc.)
local record RuntimeContext
   name: string
   version: string
   description: string
end

local record OSContext
   name: string
   version: string
   build: string
   kernel_version: string
end

local record DeviceContext
   name: string
   family: string
   model: string
   model_id: string
   arch: string
   battery_level: number
   orientation: string
   manufacturer: string
   brand: string
end

-- Stack frame information
local record StackFrame
   filename: string
   ["function"]: string  -- Sentry expects "function", not "function_name"
   lineno: number
   in_app: boolean
   vars: {string: any}  -- local variables and parameters
end

local record StackTrace
   frames: {StackFrame}
end

-- Exception information
local record Exception
   type: string
   value: string
   module: string
   thread_id: string
   stacktrace: StackTrace
end

-- Event data structure
local record EventData
   event_id: string
   timestamp: number
   level: string
   logger: string
   platform: string
   sdk: {string: any}
   message: string
   exception: table
   stacktrace: StackTrace
   user: User
   tags: {string: string}
   extra: {string: any}
   breadcrumbs: {Breadcrumb}
   environment: string
   release: string
   contexts: {string: any}
end

local types = {
   SentryOptions = SentryOptions,
   User = User,
   Breadcrumb = Breadcrumb,
   RuntimeContext = RuntimeContext,
   OSContext = OSContext,
   DeviceContext = DeviceContext,
   StackFrame = StackFrame,
   StackTrace = StackTrace,
   Exception = Exception,
   EventData = EventData
}

return types