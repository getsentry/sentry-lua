#!/usr/bin/env lua
---
--- Comprehensive example demonstrating Sentry distributed tracing in Lua
--- Shows both HTTP client and server integrations with trace propagation
---

-- Initialize Sentry with tracing support
local sentry = require("sentry")
local tracing_platform = require("sentry.tracing.platform")

-- Mock Sentry SDK for example purposes
local sentry = {
    init = function() end,
    add_breadcrumb = function() end,
    capture_exception = function(data) 
        print("[Sentry] Captured exception: " .. (data.message or data.type or "unknown"))
        return "mock-exception-id"
    end,
    capture_event = function(event) 
        print("[Sentry] Captured event: " .. (event.message or "unknown"))
        return "mock-event-id"
    end,
    capture_message = function(msg, level)
        print("[Sentry] Captured message (" .. (level or "info") .. "): " .. msg)
        return "mock-message-id"
    end,
    set_tag = function() end,
    set_extra = function() end
}

-- Initialize distributed tracing (auto-detects platform and HTTP libraries)
local platform = tracing_platform.init({
    tracing = {
        trace_propagation_targets = {"example%.com", "api%.service%.local"},
        include_traceparent = true -- Include W3C traceparent for OpenTelemetry interop
    },
    auto_instrument = true -- Automatically instrument HTTP libraries when loaded
})

print("🚀 Sentry Distributed Tracing Example")
print("====================================")

-- Show platform detection
local platform_info = tracing_platform.get_platform_info()
print("Platform: " .. platform_info.detected_platform)
print("Tracing supported: " .. tostring(platform_info.is_supported))
print("Lua version: " .. (platform_info.lua_version or "unknown"))
print("")

if not platform_info.is_supported then
    print("❌ Distributed tracing not supported on this platform")
    print("   Sentry will still work but without distributed tracing features")
    os.exit(0)
end

---
--- Example 1: HTTP Server with automatic trace continuation
---
print("📥 Example 1: HTTP Server with Trace Continuation")
print("------------------------------------------------")

-- Create HTTP server with automatic tracing
local function create_example_server()
    -- Check if Pegasus is available for the server example
    local has_pegasus = platform.is_library_available("pegasus")
    
    if has_pegasus then
        local pegasus = require("pegasus")
        local server = pegasus:new({port = "8080"})
        
        -- Wrap server with tracing (happens automatically with auto-instrumentation)
        server = platform.instrument_http_server(server, "pegasus")
        
        server:start(function(request, response)
            -- Trace is automatically continued from incoming headers
            local trace_info = platform.tracing.get_current_trace_info()
            
            if trace_info then
                print("  📋 Received request with trace: " .. trace_info.trace_id)
                print("      Parent span: " .. (trace_info.parent_span_id or "none"))
                print("      Current span: " .. trace_info.span_id)
            else
                print("  📋 New request - started new trace")
                platform.tracing.start_trace()
                trace_info = platform.tracing.get_current_trace_info()
                print("      New trace: " .. trace_info.trace_id)
            end
            
            -- Add breadcrumb
            sentry.add_breadcrumb({
                message = "Processing HTTP request",
                category = "http",
                level = "info",
                data = {
                    method = request.method or "GET",
                    url = request.url or "/",
                    trace_id = trace_info.trace_id
                }
            })
            
            -- Simulate some work
            local function do_work()
                -- This error will include trace context
                if math.random() < 0.3 then
                    error("Random server error for demonstration")
                end
                return "work completed"
            end
            
            local success, result = pcall(do_work)
            
            if not success then
                -- Capture error with trace context
                sentry.capture_exception({
                    type = "ServerError",
                    message = result
                })
                
                response:statusCode(500)
                response:write("Internal Server Error")
            else
                response:write("Hello from traced server! Trace ID: " .. trace_info.trace_id)
            end
        end)
        
        print("✅ Server created with tracing (would listen on :8080)")
        return server
    else
        print("⚠️  Pegasus not available - server example skipped")
        print("   Install with: luarocks install pegasus")
        return nil
    end
end

local server = create_example_server()

---
--- Example 2: HTTP Client with automatic header injection
---
print("")
print("📤 Example 2: HTTP Client with Trace Propagation")
print("-----------------------------------------------")

-- Start a trace for outgoing requests
platform.tracing.start_trace()
local trace_info = platform.tracing.get_current_trace_info()
print("  🔄 Started new trace: " .. trace_info.trace_id)

-- Create traced HTTP client
local function make_traced_request()
    -- Check if LuaSocket is available for client example
    local has_luasocket = platform.is_library_available("socket.http")
    
    if has_luasocket then
        -- Auto-instrumentation means this will automatically add trace headers
        local http = require("socket.http")
        
        -- Alternative: manually create traced client
        local traced_http_get = platform.create_http_client("luasocket")
        
        print("  📡 Making HTTP request with automatic trace header injection...")
        
        -- Show what headers would be sent
        local headers = platform.tracing.get_request_headers("https://api.example.com/users")
        print("  📋 Headers to be sent:")
        for key, value in pairs(headers) do
            print("      " .. key .. ": " .. value)
        end
        
        -- Simulate HTTP request (don't actually make external call in example)
        local function simulate_request()
            return {
                body = '{"users": [{"id": 1, "name": "John"}]}',
                status = 200,
                headers = {
                    ["content-type"] = "application/json"
                }
            }
        end
        
        local response = simulate_request()
        print("  ✅ Request completed (simulated)")
        print("      Status: " .. response.status)
        
        return response
    else
        print("⚠️  LuaSocket not available - client example skipped")
        print("   Install with: luarocks install luasocket")
        return nil
    end
end

make_traced_request()

---
--- Example 3: Manual trace management
---
print("")
print("🔧 Example 3: Manual Trace Management")
print("------------------------------------")

-- Create child span for a specific operation
local parent_trace = platform.tracing.get_current_trace_info()
local child_context = platform.tracing.create_child()

print("  👨‍👧‍👦 Created child span:")
print("      Parent trace: " .. parent_trace.trace_id)
print("      Parent span: " .. parent_trace.span_id)  
print("      Child span: " .. child_context.span_id)

-- Simulate database operation
local function database_operation()
    sentry.add_breadcrumb({
        message = "Executing database query",
        category = "database",
        level = "info"
    })
    
    -- Simulate potential database error
    if math.random() < 0.2 then
        error("Database connection timeout")
    end
    
    return {id = 123, name = "Test User"}
end

local success, result = pcall(database_operation)

if not success then
    -- Error will include trace context automatically
    sentry.capture_exception({
        type = "DatabaseError",
        message = result
    })
    print("  ❌ Database operation failed: " .. result)
else
    print("  ✅ Database operation successful")
end

---
--- Example 4: Event with trace context
---
print("")
print("📝 Example 4: Events with Trace Context")
print("--------------------------------------")

-- Create custom event with trace context
local event = {
    message = "User action completed",
    level = "info",
    extra = {
        user_id = 123,
        action = "profile_update"
    }
}

-- Attach trace context to event
event = platform.tracing.attach_trace_context_to_event(event)

print("  📋 Event with trace context:")
print("      Message: " .. event.message)
if event.contexts and event.contexts.trace then
    print("      Trace ID: " .. event.contexts.trace.trace_id)
    print("      Span ID: " .. event.contexts.trace.span_id)
end

-- Send event to Sentry
sentry.capture_event(event)
print("  ✅ Event sent to Sentry with trace context")

---
--- Example 5: Integration with existing code
---
print("")
print("🔌 Example 5: Wrapping Existing HTTP Handlers")
print("--------------------------------------------")

-- Existing HTTP handler (before tracing)
local function legacy_handler(request, response)
    local user_id = request.headers["x-user-id"] or "anonymous"
    
    -- This error would normally not have trace context
    if user_id == "banned" then
        error("User is banned")
    end
    
    return "Hello, " .. user_id
end

-- Wrap existing handler with tracing
local traced_handler = platform.wrap_request_handler(legacy_handler)

-- Simulate request with trace headers
local mock_request = {
    headers = {
        ["x-user-id"] = "user123",
        ["sentry-trace"] = "abcdef123456789012345678901234567890-1234567890abcdef-1"
    }
}

print("  📥 Processing request with existing handler (now traced)...")

local success, result = pcall(traced_handler, mock_request, {})
if success then
    print("  ✅ Handler result: " .. result)
    local current_trace = platform.tracing.get_current_trace_info()
    if current_trace then
        print("      Trace continued: " .. current_trace.trace_id)
    end
else
    print("  ❌ Handler error: " .. result)
end

---
--- Example 6: Middleware usage
---
print("")
print("🥪 Example 6: Framework Middleware")
print("--------------------------------")

-- Create tracing middleware
local middleware = platform.create_middleware("generic")

-- Simulate middleware chain
local function simulate_middleware_chain(request, response)
    local function next_middleware()
        print("  ⚙️  Processing in next middleware...")
        local trace_info = platform.tracing.get_current_trace_info()
        if trace_info then
            print("      Trace available: " .. trace_info.trace_id)
        end
        return "middleware chain complete"
    end
    
    return middleware(request, response, next_middleware)
end

local mock_request_with_trace = {
    headers = {
        ["sentry-trace"] = "fedcba098765432109876543210987654-abcdef1234567890-0"
    }
}

print("  🔄 Running middleware chain...")
local result = simulate_middleware_chain(mock_request_with_trace, {})
print("  ✅ " .. result)

---
--- Summary
---
print("")
print("📊 Summary")
print("=========")

local final_info = tracing_platform.get_platform_info()
if final_info.current_platform then
    local platform_stats = final_info.current_platform
    print("Platform: " .. platform_stats.name .. " " .. platform_stats.version)
    print("Auto-instrumentation: " .. tostring(platform_stats.auto_instrumentation_enabled))
    print("Tracing active: " .. tostring(platform_stats.tracing_active))
    
    if #platform_stats.instrumented_modules > 0 then
        print("Instrumented modules: " .. table.concat(platform_stats.instrumented_modules, ", "))
    end
end

print("")
print("🎉 Distributed tracing examples completed!")
print("")
print("Key takeaways:")
print("• Traces are automatically continued from incoming HTTP requests") 
print("• Trace headers are automatically added to outgoing HTTP requests")
print("• Errors and events automatically include trace context")
print("• Works with popular Lua HTTP libraries (LuaSocket, lua-http, Pegasus)")
print("• Supports both auto-instrumentation and manual integration")
print("• Compatible with OpenTelemetry via W3C traceparent header")
print("")
print("Next steps:")
print("• Configure trace_propagation_targets for your services")
print("• Add custom baggage data for additional context")
print("• Create custom spans for specific operations")
print("• Monitor distributed traces in your Sentry dashboard")