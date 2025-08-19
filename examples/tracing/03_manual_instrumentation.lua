#!/usr/bin/env lua
---
--- Manual Instrumentation Example
--- Demonstrates how to manually instrument HTTP requests and handlers for distributed tracing
---

-- Set up path for running from repository root
package.path = "src/?.lua;src/?/init.lua;platforms/?.lua;platforms/?/init.lua;build/?.lua;build/?/init.lua;;" .. package.path

local sentry = require("sentry")
local tracing_platform = require("sentry.tracing.platform")

print("🔧 Manual Instrumentation Demo")
print("==============================")

-- Initialize Sentry with the test DSN
sentry.init({
    dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
    environment = "tracing-examples",
    debug = true
})

-- Initialize distributed tracing (without auto-instrumentation)
local platform = tracing_platform.init({
    tracing = {
        trace_propagation_targets = {"api%.example%.com", "internal%.company%.com"},
        include_traceparent = true
    },
    auto_instrument = false  -- Manual instrumentation only
})

local tracing = platform.tracing

print("Platform: " .. platform.get_info().name)
print("Auto-instrumentation: " .. tostring(platform.get_info().auto_instrumentation_enabled))

-- Manual HTTP Client Wrapper
local function make_traced_request(url, options)
    options = options or {}
    
    print("\n🌐 Making traced HTTP request")
    print("URL: " .. url)
    
    -- Start new trace if none exists
    if not tracing.is_active() then
        tracing.start_trace()
        print("✅ Started new trace for request")
    end
    
    -- Create child span for this request
    local request_span = tracing.create_child()
    local trace_info = tracing.get_current_trace_info()
    
    print("🔗 Request trace: " .. trace_info.trace_id)
    print("📍 Request span: " .. trace_info.span_id)
    
    -- Get headers to include in the request
    local headers = tracing.get_request_headers(url)
    
    if next(headers) then
        print("📋 Trace headers to include:")
        for key, value in pairs(headers) do
            print("   " .. key .. ": " .. value)
        end
    else
        print("⚠️  No trace headers (URL not in propagation targets)")
    end
    
    -- Add breadcrumb for request start
    sentry.add_breadcrumb({
        message = "HTTP request started",
        category = "http.client",
        level = "debug",
        data = {
            method = options.method or "GET",
            url = url,
            trace_id = trace_info.trace_id,
            span_id = trace_info.span_id
        }
    })
    
    -- Simulate the actual HTTP request
    local start_time = os.clock()
    
    -- In a real implementation, you would make the actual HTTP request here
    -- For this demo, we'll simulate different response scenarios
    local simulated_response
    if url:find("error") then
        simulated_response = {
            status = 500,
            headers = {["content-type"] = "application/json"},
            body = '{"error": "Internal server error"}'
        }
    elseif url:find("slow") then
        -- Simulate slow request
        while os.clock() - start_time < 1.0 do
            -- Busy wait to simulate slow response
        end
        simulated_response = {
            status = 200,
            headers = {["content-type"] = "application/json"},
            body = '{"message": "Slow response", "duration": 1000}'
        }
    else
        simulated_response = {
            status = 200,
            headers = {["content-type"] = "application/json"},
            body = '{"message": "Success", "data": {"id": 123}}'
        }
    end
    
    local duration_ms = math.floor((os.clock() - start_time) * 1000)
    
    -- Add completion breadcrumb
    sentry.add_breadcrumb({
        message = "HTTP request completed",
        category = "http.client", 
        level = (simulated_response.status >= 400) and "error" or "info",
        data = {
            method = options.method or "GET",
            url = url,
            status = simulated_response.status,
            duration_ms = duration_ms,
            trace_id = trace_info.trace_id,
            span_id = trace_info.span_id
        }
    })
    
    -- Capture event for the request
    if simulated_response.status >= 400 then
        sentry.capture_message("HTTP request failed: " .. url, "error")
    else
        sentry.capture_message("HTTP request completed: " .. url, "info")
    end
    
    print("📥 Response: HTTP " .. simulated_response.status .. " (" .. duration_ms .. "ms)")
    
    return simulated_response
end

-- Manual HTTP Server Handler Wrapper
local function handle_traced_request(path, headers, handler)
    print("\n🌐 Handling traced HTTP request")
    print("Path: " .. path)
    
    -- Check for incoming trace headers
    local has_trace_headers = false
    for key, _ in pairs(headers or {}) do
        if key:lower():find("sentry") or key:lower():find("baggage") or key:lower():find("traceparent") then
            has_trace_headers = true
            break
        end
    end
    
    if has_trace_headers then
        print("📋 Incoming trace headers found")
        for key, value in pairs(headers) do
            if key:lower():find("sentry") or key:lower():find("baggage") or key:lower():find("traceparent") then
                print("   " .. key .. ": " .. value)
            end
        end
    else
        print("📋 No incoming trace headers - will start new trace")
    end
    
    -- Continue or start trace
    local trace_context
    if has_trace_headers then
        trace_context = tracing.continue_trace_from_request(headers)
        print("✅ Continued trace from incoming request")
    else
        trace_context = tracing.start_trace()
        print("✅ Started new trace for request")
    end
    
    local trace_info = tracing.get_current_trace_info()
    print("🔗 Handler trace: " .. trace_info.trace_id)
    print("📍 Handler span: " .. trace_info.span_id)
    
    if trace_info.parent_span_id then
        print("👆 Parent span: " .. trace_info.parent_span_id)
    end
    
    -- Add breadcrumb for request handling
    sentry.add_breadcrumb({
        message = "HTTP request handler started",
        category = "http.server",
        level = "debug",
        data = {
            path = path,
            has_parent_trace = has_trace_headers,
            trace_id = trace_info.trace_id,
            span_id = trace_info.span_id
        }
    })
    
    -- Call the actual handler
    local start_time = os.clock()
    local success, result = pcall(handler, path, headers)
    local duration_ms = math.floor((os.clock() - start_time) * 1000)
    
    if success then
        print("✅ Handler completed successfully (" .. duration_ms .. "ms)")
        
        sentry.add_breadcrumb({
            message = "HTTP request handler completed",
            category = "http.server",
            level = "info",
            data = {
                path = path,
                duration_ms = duration_ms,
                success = true,
                trace_id = trace_info.trace_id
            }
        })
        
        sentry.capture_message("HTTP handler completed: " .. path, "info")
        return result
        
    else
        print("❌ Handler failed: " .. tostring(result))
        
        sentry.add_breadcrumb({
            message = "HTTP request handler failed",
            category = "http.server", 
            level = "error",
            data = {
                path = path,
                error = tostring(result),
                duration_ms = duration_ms,
                trace_id = trace_info.trace_id
            }
        })
        
        sentry.capture_exception({
            type = "HandlerError",
            message = "HTTP handler failed: " .. tostring(result),
            extra = {
                path = path,
                duration_ms = duration_ms,
                trace_id = trace_info.trace_id
            }
        })
        
        return nil, result
    end
end

-- Example 1: Manual client instrumentation
print("\n📤 Example 1: Manual Client Instrumentation")
print("-------------------------------------------")

-- Make several traced requests
local urls = {
    "https://api.example.com/users",
    "https://api.example.com/data", 
    "https://api.example.com/error",
    "https://external.service.com/data",  -- Not in propagation targets
    "https://internal.company.com/slow"
}

for _, url in ipairs(urls) do
    make_traced_request(url, {method = "GET"})
end

-- Example 2: Manual server instrumentation
print("\n📥 Example 2: Manual Server Instrumentation")
print("-------------------------------------------")

-- Simulate incoming requests with different trace scenarios

-- Request 1: No incoming trace headers
handle_traced_request("/api/users", {
    ["host"] = "myserver.com",
    ["user-agent"] = "client/1.0"
}, function(path, headers)
    print("   Handler: Fetching users from database")
    
    -- Simulate database operation with child span
    local db_span = tracing.create_child()
    local db_trace_info = tracing.get_current_trace_info()
    print("   📊 Database span: " .. db_trace_info.span_id)
    
    sentry.add_breadcrumb({
        message = "Database query executed",
        category = "db.query",
        level = "debug",
        data = {
            query = "SELECT * FROM users",
            span_id = db_trace_info.span_id
        }
    })
    
    return {users = {{id = 1, name = "Alice"}}}
end)

-- Request 2: With incoming trace headers (continued trace)
handle_traced_request("/api/orders", {
    ["host"] = "myserver.com",
    ["user-agent"] = "client/1.0",
    ["sentry-trace"] = "abc123def456789012345678901234567890-1234567890abcdef-1",
    ["baggage"] = "user_id=12345,session_id=abcdef"
}, function(path, headers)
    print("   Handler: Processing order with user context")
    
    -- Create multiple child spans for complex operation
    local validate_span = tracing.create_child() 
    print("   📋 Validation span: " .. validate_span.span_id)
    
    local payment_span = tracing.create_child()
    print("   💳 Payment span: " .. payment_span.span_id)
    
    local inventory_span = tracing.create_child()
    print("   📦 Inventory span: " .. inventory_span.span_id)
    
    sentry.add_breadcrumb({
        message = "Order processing completed",
        category = "business.order",
        level = "info",
        data = {
            order_id = "ORD-123",
            validation_span = validate_span.span_id,
            payment_span = payment_span.span_id,
            inventory_span = inventory_span.span_id
        }
    })
    
    return {order_id = "ORD-123", status = "completed"}
end)

-- Request 3: Handler that throws an error
handle_traced_request("/api/broken", {
    ["sentry-trace"] = "def456abc789012345678901234567890123-fedcba0987654321-1"
}, function(path, headers)
    print("   Handler: This will fail intentionally")
    error("Intentional handler error for tracing demo")
end)

-- Example 3: Custom trace operations
print("\n🔧 Example 3: Custom Trace Operations")
print("------------------------------------")

-- Start a new trace for custom operations
tracing.start_trace()
local custom_trace = tracing.get_current_trace_info()
print("✅ Started custom trace: " .. custom_trace.trace_id)

-- Manually create spans for different operations
local operations = {"validate_input", "process_data", "save_result"}

for _, operation in ipairs(operations) do
    local op_span = tracing.create_child()
    local op_trace_info = tracing.get_current_trace_info()
    
    print("⚙️  Operation: " .. operation)
    print("   📍 Span: " .. op_trace_info.span_id)
    
    -- Simulate work
    local start = os.clock()
    while os.clock() - start < 0.1 do
        -- Busy wait
    end
    
    sentry.add_breadcrumb({
        message = "Custom operation completed",
        category = "custom." .. operation,
        level = "debug",
        data = {
            operation = operation,
            span_id = op_trace_info.span_id,
            duration_ms = math.floor((os.clock() - start) * 1000)
        }
    })
    
    sentry.capture_message("Custom operation: " .. operation, "debug")
end

print("\n🎉 Manual Instrumentation Demo Complete!")
print("=======================================")
print("Key concepts demonstrated:")
print("• Manual trace creation and continuation")
print("• Custom child span creation")
print("• Header extraction and injection")
print("• Request/response instrumentation patterns")
print("• Error handling within traced operations")
print("• Multi-span complex operations")
print("")
print("💡 Use manual instrumentation when:")
print("• You need fine-grained control over tracing")
print("• Auto-instrumentation doesn't cover your use case")
print("• You want to add custom business logic spans")
print("• You're working with unsupported HTTP libraries")