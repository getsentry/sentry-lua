#!/usr/bin/env lua
---
--- Auto-Instrumentation Example
--- Demonstrates automatic HTTP client/server instrumentation for distributed tracing
---

-- Set up path for running from repository root
package.path = "src/?.lua;src/?/init.lua;platforms/?.lua;platforms/?/init.lua;build/?.lua;build/?/init.lua;;" .. package.path

local sentry = require("sentry")
local tracing_platform = require("sentry.tracing.platform")

print("🤖 Auto-Instrumentation Demo")
print("============================")

-- Initialize Sentry with the test DSN
sentry.init({
    dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
    environment = "tracing-examples",
    debug = true
})

-- Initialize distributed tracing WITH auto-instrumentation
local platform = tracing_platform.init({
    tracing = {
        trace_propagation_targets = {
            "api%.example%.com",
            "internal%.company%.com", 
            "localhost",
            "127%.0%.0%.1"
        },
        include_traceparent = true
    },
    auto_instrument = true  -- Enable automatic instrumentation
})

local tracing = platform.tracing

print("Platform: " .. platform.get_info().name)
print("Auto-instrumentation: " .. tostring(platform.get_info().auto_instrumentation_enabled))

-- Check what HTTP libraries are available for auto-instrumentation
local available_libraries = {}
local test_libraries = {"socket.http", "http", "pegasus"}

for _, lib in ipairs(test_libraries) do
    if platform.is_library_available(lib) then
        table.insert(available_libraries, lib)
    end
end

print("Available HTTP libraries: " .. (next(available_libraries) and table.concat(available_libraries, ", ") or "none"))

-- Example 1: Auto-instrumented HTTP client requests
print("\n📤 Example 1: Auto-Instrumented HTTP Client")
print("-------------------------------------------")

-- Start a trace for the client session  
tracing.start_trace()
local session_trace = tracing.get_current_trace_info()
print("✅ Session trace started: " .. session_trace.trace_id)

-- Function to demonstrate auto-instrumented requests
local function demo_auto_request(url, description)
    print("\n🌐 " .. description)
    print("URL: " .. url)
    
    -- With auto-instrumentation, we can just use the HTTP library normally
    -- The tracing system will automatically add headers and create spans
    
    local has_socket = platform.is_library_available("socket.http")
    
    if has_socket then
        print("📡 Using LuaSocket (auto-instrumented)")
        
        -- The HTTP request will be automatically traced
        local http = require("socket.http")
        local ltn12 = require("ltn12")
        
        local response_body = {}
        local result, status_code, headers = http.request({
            url = url,
            method = "GET",
            headers = {
                ["User-Agent"] = "auto-instrumented-client/1.0"
            },
            sink = ltn12.sink.table(response_body)
        })
        
        if result then
            print("✅ Request successful: HTTP " .. status_code)
            
            -- Auto-instrumentation automatically:
            -- - Added sentry-trace headers to the request
            -- - Created a child span for the HTTP request
            -- - Captured timing and status information
            -- - Added breadcrumbs for the request lifecycle
            
        else
            print("❌ Request failed: " .. tostring(status_code))
        end
        
    else
        print("📡 Simulating auto-instrumented request (LuaSocket not available)")
        
        -- Simulate what auto-instrumentation would do
        local child_span = tracing.create_child()
        local trace_info = tracing.get_current_trace_info()
        
        print("   🔗 Auto-created span: " .. trace_info.span_id)
        
        -- Headers would be automatically added
        local headers = tracing.get_request_headers(url)
        if next(headers) then
            print("   📋 Auto-added headers:")
            for key, value in pairs(headers) do
                print("      " .. key .. ": " .. value)
            end
        end
        
        -- Breadcrumbs would be automatically added
        sentry.add_breadcrumb({
            message = "Auto-instrumented HTTP request",
            category = "http.client",
            level = "info",
            data = {
                url = url,
                method = "GET",
                auto_instrumented = true
            }
        })
        
        print("✅ Request simulated (auto-instrumented)")
    end
    
    -- Capture event (will automatically include trace context)
    sentry.capture_message("Auto-instrumented request to " .. url, "info")
end

-- Test different URLs to show propagation target behavior
local test_urls = {
    {
        url = "https://api.example.com/users",
        desc = "API request (will propagate traces)"
    },
    {
        url = "https://internal.company.com/data",
        desc = "Internal service request (will propagate traces)"  
    },
    {
        url = "https://external.thirdparty.com/service",
        desc = "Third-party request (will NOT propagate traces)"
    },
    {
        url = "http://localhost:8080/api/health", 
        desc = "Local service request (will propagate traces)"
    }
}

for _, test in ipairs(test_urls) do
    demo_auto_request(test.url, test.desc)
end

-- Example 2: Auto-instrumented HTTP server
print("\n📥 Example 2: Auto-Instrumented HTTP Server")
print("-------------------------------------------")

local function demo_auto_server()
    local has_pegasus = platform.is_library_available("pegasus")
    
    if has_pegasus then
        print("🖥️  Creating auto-instrumented Pegasus server")
        
        -- With auto-instrumentation, the server will automatically:
        -- - Extract trace headers from incoming requests
        -- - Continue traces or start new ones
        -- - Add request breadcrumbs and events
        -- - Attach trace context to all events
        
        local pegasus = require("pegasus")
        
        -- Server is automatically instrumented when auto_instrument = true
        local server = pegasus:new({
            port = 8081,  -- Different port to avoid conflicts
            location = '/'
        })
        
        print("✅ Auto-instrumented server would start on port 8081")
        print("   All incoming requests would be automatically traced")
        
        -- Simulate what would happen with incoming requests
        print("\n📋 Simulating auto-instrumented server behavior:")
        
        -- Don't actually start the server in the demo
        -- Just show what the auto-instrumentation would do
        
    else
        print("🖥️  Simulating auto-instrumented server (Pegasus not available)")
    end
    
    -- Simulate server request handling
    local function simulate_server_request(path, incoming_headers)
        print("\n   📥 Simulated incoming request: " .. path)
        
        -- Auto-instrumentation would automatically:
        -- 1. Extract trace headers
        local extracted = false
        for key, _ in pairs(incoming_headers or {}) do
            if key:lower():find("sentry") or key:lower():find("traceparent") then
                extracted = true
                break
            end
        end
        
        if extracted then
            -- 2. Continue the trace
            tracing.continue_trace_from_request(incoming_headers or {})
            print("      ✅ Auto-continued trace from headers")
        else
            -- 3. Start new trace if no headers
            tracing.start_trace()
            print("      ✅ Auto-started new trace")
        end
        
        local trace_info = tracing.get_current_trace_info()
        print("      🔗 Request trace: " .. trace_info.trace_id)
        
        -- 4. Add breadcrumbs automatically
        sentry.add_breadcrumb({
            message = "Auto-instrumented request handled",
            category = "http.server",
            level = "info",
            data = {
                path = path,
                auto_instrumented = true,
                trace_continued = extracted
            }
        })
        
        -- 5. Capture event with trace context
        sentry.capture_message("Auto-instrumented server request: " .. path, "info")
        
        print("      ✅ Auto-handled request with full tracing")
    end
    
    -- Simulate different request scenarios
    simulate_server_request("/api/users", {})  -- No trace headers
    
    simulate_server_request("/api/orders", {   -- With trace headers
        ["sentry-trace"] = "abc123def456-fedcba098765-1",
        ["baggage"] = "user_id=12345"
    })
    
    simulate_server_request("/api/data", {     -- With W3C traceparent
        ["traceparent"] = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
    })
end

demo_auto_server()

-- Example 3: Configuration and customization
print("\n⚙️  Example 3: Auto-Instrumentation Configuration")
print("-----------------------------------------------")

print("Current configuration:")
print("• Trace propagation targets:")
local config = platform.get_config()
if config and config.tracing and config.tracing.trace_propagation_targets then
    for _, target in ipairs(config.tracing.trace_propagation_targets) do
        print("  - " .. target)
    end
end

print("• Include W3C traceparent: " .. tostring(config and config.tracing and config.tracing.include_traceparent))
print("• Auto-instrumentation: " .. tostring(config and config.auto_instrument))

-- Example 4: Comparison with manual instrumentation
print("\n🔄 Example 4: Auto vs Manual Instrumentation")
print("--------------------------------------------")

print("✅ Benefits of auto-instrumentation:")
print("• Zero code changes needed for basic tracing")
print("• Automatic header propagation")
print("• Consistent tracing across all HTTP operations")
print("• Automatic span creation and timing")
print("• Built-in error capture and breadcrumbs")

print("\n🔧 When to use manual instrumentation:")
print("• Need custom business logic spans")
print("• Working with unsupported libraries")
print("• Require fine-grained control over trace data")
print("• Want to add custom baggage or metadata")

-- Example 5: Monitoring and debugging auto-instrumentation
print("\n🔍 Example 5: Monitoring Auto-Instrumentation")
print("--------------------------------------------")

-- Show current tracing state
print("Platform info:")
local platform_info = platform.get_info()
for key, value in pairs(platform_info) do
    print("• " .. key .. ": " .. tostring(value))
end

-- Capture final summary
sentry.capture_message("Auto-instrumentation demo completed", "info")

print("\n🎉 Auto-Instrumentation Demo Complete!")
print("=====================================")
print("Key concepts demonstrated:")
print("• Automatic HTTP client request tracing")
print("• Automatic HTTP server request handling")
print("• Zero-code trace propagation")
print("• Automatic span and breadcrumb creation")
print("• Configuration-driven trace targeting")
print("• W3C traceparent compatibility")
print("")
print("🚀 To enable auto-instrumentation in your app:")
print("1. Set auto_instrument = true in platform.init()")
print("2. Configure trace_propagation_targets for your domains")
print("3. Use HTTP libraries normally - tracing happens automatically!")
print("4. Monitor your Sentry dashboard for distributed traces")
print("")
print("💡 Auto-instrumentation works best when combined with:")
print("• Proper error handling and logging")  
print("• Environment-specific configuration")
print("• Performance monitoring and alerting")
print("• Custom business metric capture")