#!/usr/bin/env lua
---
--- Distributed Tracing HTTP Server
--- Real HTTP server that demonstrates trace continuation from incoming requests
--- Run this in one terminal, then run client.lua in another terminal
---

-- Set up path for running from repository root
package.path = "src/?.lua;src/?/init.lua;platforms/?.lua;platforms/?/init.lua;build/?.lua;build/?/init.lua;;" .. package.path

local sentry = require("sentry")
local tracing_platform = require("sentry.tracing.platform")
local performance = require("sentry.performance")

print("🚀 Distributed Tracing Server")
print("============================")

-- Initialize Sentry with the test DSN
sentry.init({
    dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
    environment = "tracing-server-example",
    debug = true,
    release = "server@1.0.0"
})

-- Initialize distributed tracing
local platform = tracing_platform.init({
    tracing = {
        trace_propagation_targets = {"localhost", "127%.0%.0%.1"},
        include_traceparent = true
    },
    auto_instrument = true
})

local tracing = platform.tracing

-- Check if Pegasus is available
local has_pegasus = platform.is_library_available("pegasus")

if not has_pegasus then
    print("❌ Pegasus not available. Install with: luarocks install pegasus")
    print("   Falling back to simple HTTP server simulation...")
    
    -- Simulate server behavior for demonstration
    print("\n📡 Server would be running on http://localhost:8080")
    print("   The following shows what would happen when requests arrive:\n")
    
    -- Simulate incoming requests
    local function simulate_request(method, path, headers)
        print("─────────────────────────────────────────────────────────")
        print("📥 [" .. os.date("%H:%M:%S") .. "] Incoming " .. method .. " " .. path)
        
        -- Show incoming headers
        local has_trace_headers = false
        for key, value in pairs(headers or {}) do
            if key:lower():find("sentry") or key:lower():find("baggage") or key:lower():find("traceparent") then
                print("   📋 " .. key .. ": " .. value)
                has_trace_headers = true
            end
        end
        
        if not has_trace_headers then
            print("   📋 No trace headers found - starting new trace")
        end
        
        -- Continue trace from headers
        local trace_context = tracing.continue_trace_from_request(headers or {})
        local trace_info = tracing.get_current_trace_info()
        
        if trace_info then
            print("   🔗 " .. (has_trace_headers and "Continued" or "Started") .. " trace: " .. trace_info.trace_id)
            print("   📍 Current span: " .. trace_info.span_id)
            if trace_info.parent_span_id then
                print("   👆 Parent span: " .. trace_info.parent_span_id)
            end
        end
        
        -- Add breadcrumb
        sentry.add_breadcrumb({
            message = "Processing " .. method .. " " .. path,
            category = "http.request",
            level = "info",
            data = {
                method = method,
                path = path,
                trace_id = trace_info and trace_info.trace_id or "none"
            }
        })
        
        -- Simulate some server work
        if path == "/api/users" then
            print("   ⚙️  Processing user request...")
            
            -- Simulate database call (child span)
            local child_context = tracing.create_child()
            print("   📊 Database query span: " .. child_context.span_id)
            
            sentry.add_breadcrumb({
                message = "Database query: SELECT * FROM users",
                category = "db.query",
                level = "debug"
            })
            
        elseif path == "/api/error" then
            print("   ❌ Simulating server error...")
            sentry.capture_exception({
                type = "ServerError",
                message = "Simulated API error for tracing demo"
            })
            
        else
            print("   ✅ Processing request...")
        end
        
        -- Capture event with trace context
        sentry.capture_message("Server processed " .. method .. " " .. path, "info")
        
        -- Simulate response
        local response = {
            status = (path == "/api/error") and 500 or 200,
            data = {
                message = "Response from traced server",
                trace_id = trace_info and trace_info.trace_id or "none",
                span_id = trace_info and trace_info.span_id or "none",
                timestamp = os.time()
            }
        }
        
        print("   📤 Response: HTTP " .. response.status)
        print("   🔗 Response trace ID: " .. response.data.trace_id)
        
        return response
    end
    
    -- Simulate various requests
    simulate_request("GET", "/", {})
    
    print("\n⏳ Waiting for client requests...")
    print("   (In real usage, run client.lua to see trace propagation)")
    
    -- Simulate request with trace headers (as if from client)
    simulate_request("GET", "/api/users", {
        ["sentry-trace"] = "abc123def456789012345678901234567890-1234567890abcdef-1",
        ["baggage"] = "client_id=test_client,version=1.0.0"
    })
    
    simulate_request("POST", "/api/error", {
        ["sentry-trace"] = "abc123def456789012345678901234567890-fedcba0987654321-1"
    })
    
    print("\n📊 Server simulation complete!")
    
else
    -- Real Pegasus server
    local pegasus = require("pegasus")
    
    -- Create server (automatically instrumented by auto_instrument = true)
    local server = pegasus:new({
        port = 8080,
        location = '/'
    })
    
    print("Platform: " .. platform.get_info().name)
    print("Auto-instrumentation: " .. tostring(platform.get_info().auto_instrumentation_enabled))
    
    print("\n📡 Server running on http://localhost:8080")
    print("   Use Ctrl+C to stop")
    print("   Run client.lua in another terminal to test trace propagation")
    print("")
    
    -- Request handler with automatic trace continuation
    server:start(function(request, response)
        local timestamp = os.date("%H:%M:%S")
        local method = request:method() or "GET"
        local path = request:path() or "/"
        
        print("─────────────────────────────────────────────────────────")
        print("📥 [" .. timestamp .. "] " .. method .. " " .. path)
        
        -- Start transaction for this HTTP request
        local transaction = performance.start_transaction({
            name = method .. " " .. path,
            op = "http.server",
            description = "HTTP request processing",
            tags = {
                ["http.method"] = method,
                ["http.url"] = path
            }
        })
        
        print("   🏁 Started transaction: " .. transaction.event_id)
        
        -- Trace is automatically continued by the instrumented server
        local trace_info = tracing.get_current_trace_info()
        
        if trace_info then
            print("   🔗 Trace ID: " .. trace_info.trace_id)
            print("   📍 Current span: " .. trace_info.span_id)
            if trace_info.parent_span_id then
                print("   👆 Parent span: " .. trace_info.parent_span_id)
                print("   ✅ Continued trace from client")
            else
                print("   🆕 Started new trace")
            end
        else
            print("   ❌ No trace context available")
        end
        
        -- Add breadcrumb for request processing
        sentry.add_breadcrumb({
            message = "Processing " .. method .. " " .. path,
            category = "http.request", 
            level = "info",
            data = {
                method = method,
                path = path,
                user_agent = request:headers()["user-agent"] or "unknown",
                trace_id = trace_info and trace_info.trace_id or "none"
            }
        })
        
        -- Route handling with different behaviors
        local response_data = {}
        local status_code = 200
        
        if path == "/" then
            response_data = {
                message = "Distributed Tracing Server",
                version = "1.0.0",
                trace_id = trace_info and trace_info.trace_id or "none",
                span_id = trace_info and trace_info.span_id or "none",
                endpoints = {
                    "/api/users",
                    "/api/data", 
                    "/api/error",
                    "/api/slow"
                }
            }
            
        elseif path == "/api/users" then
            print("   ⚙️  Fetching users...")
            
            -- Start database span
            local db_span = performance.start_span(transaction, {
                op = "db.query",
                description = "SELECT * FROM users LIMIT 10",
                tags = {
                    ["db.system"] = "postgresql",
                    ["db.operation"] = "select"
                }
            })
            print("   📊 Database span: " .. db_span.span_id)
            
            -- Simulate database work
            local start_time = os.clock()
            for i = 1, 50000 do
                local _ = math.sin(i) -- Simulate DB processing
            end
            local db_duration_ms = math.floor((os.clock() - start_time) * 1000)
            
            performance.finish_span(db_span)
            print("   ✅ Database query completed in " .. db_duration_ms .. "ms")
            
            sentry.add_breadcrumb({
                message = "Database query: SELECT * FROM users LIMIT 10",
                category = "db.query",
                level = "debug",
                data = {
                    query = "SELECT * FROM users LIMIT 10",
                    duration_ms = db_duration_ms,
                    span_id = db_span.span_id
                }
            })
            
            response_data = {
                users = {
                    {id = 1, name = "Alice", email = "alice@example.com"},
                    {id = 2, name = "Bob", email = "bob@example.com"},
                    {id = 3, name = "Carol", email = "carol@example.com"}
                },
                trace_id = trace_info and trace_info.trace_id or "none",
                database_span_id = db_span.span_id
            }
            
        elseif path == "/api/data" then
            print("   📊 Generating data...")
            
            response_data = {
                data = {
                    timestamp = os.time(),
                    random_value = math.random(1, 1000),
                    server_id = "server-" .. math.random(1000, 9999)
                },
                trace_id = trace_info and trace_info.trace_id or "none"
            }
            
        elseif path == "/api/error" then
            print("   ❌ Simulating server error...")
            status_code = 500
            
            local error_id = sentry.capture_exception({
                type = "DemoServerError",
                message = "Intentional server error for distributed tracing demo",
                extra = {
                    endpoint = path,
                    method = method,
                    trace_id = trace_info and trace_info.trace_id or "none"
                }
            })
            
            response_data = {
                error = "Internal Server Error",
                message = "Something went wrong (this is intentional for the demo)",
                error_id = error_id,
                trace_id = trace_info and trace_info.trace_id or "none"
            }
            
        elseif path == "/api/slow" then
            print("   ⏳ Simulating slow operation...")
            
            -- Start processing span for slow operation
            local slow_span = performance.start_span(transaction, {
                op = "processing",
                description = "Heavy computation simulation",
                tags = {
                    ["operation.type"] = "cpu_intensive"
                }
            })
            print("   🐌 Slow processing span: " .. slow_span.span_id)
            
            -- Simulate slow operation
            local start_time = os.clock()
            
            -- Busy wait for demo (don't do this in production!)
            local wait_time = 0.5 -- 500ms
            while os.clock() - start_time < wait_time do
                -- Busy wait
            end
            
            local duration_ms = math.floor((os.clock() - start_time) * 1000)
            
            performance.finish_span(slow_span)
            print("   ✅ Slow operation completed in " .. duration_ms .. "ms")
            
            sentry.add_breadcrumb({
                message = "Slow operation completed",
                category = "performance",
                level = "warning",
                data = {
                    duration_ms = duration_ms,
                    operation = "slow_processing",
                    span_id = slow_span.span_id
                }
            })
            
            response_data = {
                message = "Slow operation completed",
                duration_ms = duration_ms,
                trace_id = trace_info and trace_info.trace_id or "none"
            }
            
        else
            status_code = 404
            response_data = {
                error = "Not Found",
                path = path,
                trace_id = trace_info and trace_info.trace_id or "none"
            }
        end
        
        -- Capture event for this request
        local event_level = (status_code >= 400) and "error" or "info"
        sentry.capture_message("Server request: " .. method .. " " .. path, event_level)
        
        print("   📤 Response: HTTP " .. status_code)
        if trace_info then
            print("   🔗 Response includes trace: " .. trace_info.trace_id)
        end
        
        -- Send response
        response:statusCode(status_code)
        response:addHeader("Content-Type", "application/json")
        response:addHeader("Access-Control-Allow-Origin", "*")  -- For browser testing
        
        -- Add trace ID to response headers for client visibility
        if trace_info then
            response:addHeader("X-Trace-ID", trace_info.trace_id)
            response:addHeader("X-Span-ID", trace_info.span_id)
        end
        
        local json = require("build.sentry.utils.json") or {
            encode = function(t)
                -- Simple JSON encoding fallback
                if type(t) == "table" then
                    local pairs_array = {}
                    for k, v in pairs(t) do
                        if type(v) == "string" then
                            table.insert(pairs_array, '"' .. k .. '":"' .. v .. '"')
                        elseif type(v) == "number" then
                            table.insert(pairs_array, '"' .. k .. '":' .. v)
                        elseif type(v) == "table" then
                            table.insert(pairs_array, '"' .. k .. '":{}') -- Simplified
                        end
                    end
                    return "{" .. table.concat(pairs_array, ",") .. "}"
                end
                return tostring(t)
            end
        }
        
        response:write(json.encode(response_data))
        
        -- Finish the transaction
        performance.finish_transaction(transaction)
        print("   🏁 Finished transaction: " .. transaction.event_id)
        
        -- Transaction duration is tracked internally by the performance monitoring
    end)
end

print("\n🎯 Server Features Demonstrated:")
print("• Automatic trace continuation from incoming headers")
print("• Child span creation for database operations") 
print("• Error capture with trace context")
print("• Event correlation across service boundaries")
print("• Breadcrumb integration with distributed traces")
print("")
print("💡 Try these requests:")
print("   curl http://localhost:8080/")
print("   curl http://localhost:8080/api/users")  
print("   curl http://localhost:8080/api/error")
print("   curl http://localhost:8080/api/slow")
print("")
print("🔗 Run client.lua to see full trace propagation!")