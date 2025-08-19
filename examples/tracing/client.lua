#!/usr/bin/env lua
---
--- Distributed Tracing HTTP Client
--- Client that demonstrates trace propagation to the server
--- Run server.lua in one terminal, then run this in another terminal
---

-- Set up path for running from repository root
package.path = "src/?.lua;src/?/init.lua;platforms/?.lua;platforms/?/init.lua;build/?.lua;build/?/init.lua;;" .. package.path

local sentry = require("sentry")
local tracing_platform = require("sentry.tracing.platform")

print("🚀 Distributed Tracing Client")
print("============================")

-- Initialize Sentry with the test DSN
sentry.init({
    dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
    environment = "tracing-client-example",
    debug = true,
    release = "client@1.0.0"
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

-- Check if HTTP client libraries are available
local has_socket = platform.is_library_available("socket.http")
local has_lua_http = platform.is_library_available("http")

print("Platform: " .. platform.get_info().name)
print("LuaSocket available: " .. tostring(has_socket))
print("lua-http available: " .. tostring(has_lua_http))

-- Server configuration
local SERVER_BASE = "http://localhost:8080"
local ENDPOINTS = {
    "/",
    "/api/users", 
    "/api/data",
    "/api/error",
    "/api/slow"
}

-- Function to make HTTP request (will try different libraries)
local function make_http_request(url, method)
    method = method or "GET"
    
    print("📤 Making " .. method .. " request to: " .. url)
    
    -- Try to get trace headers for the request
    local trace_headers = tracing.get_request_headers(url)
    local has_trace_headers = next(trace_headers) ~= nil
    
    if has_trace_headers then
        print("   🔗 Including trace headers:")
        for key, value in pairs(trace_headers) do
            print("      " .. key .. ": " .. value)
        end
    else
        print("   ⚠️  No trace headers (URL not in propagation targets)")
    end
    
    local response = nil
    local success = false
    local error_msg = nil
    
    -- Try LuaSocket first
    if has_socket then
        local http = require("socket.http")
        local ltn12 = require("ltn12")
        
        local response_body = {}
        local headers = {
            ["User-Agent"] = "sentry-lua-client/1.0.0",
            ["Accept"] = "application/json"
        }
        
        -- Add trace headers
        for key, value in pairs(trace_headers) do
            headers[key] = value
        end
        
        local result, status_code, response_headers = http.request({
            url = url,
            method = method,
            headers = headers,
            sink = ltn12.sink.table(response_body)
        })
        
        if result then
            success = true
            response = {
                status = status_code,
                headers = response_headers or {},
                body = table.concat(response_body)
            }
        else
            error_msg = "HTTP request failed: " .. tostring(status_code)
        end
        
    else
        -- Fallback: simulate request for demo purposes
        print("   ⚠️  No HTTP client available - simulating request...")
        
        -- Simulate network delay
        local start_time = os.clock()
        while os.clock() - start_time < 0.1 do
            -- Busy wait to simulate network delay
        end
        
        success = true
        response = {
            status = (url:find("/api/error") and 500) or 200,
            headers = {
                ["content-type"] = "application/json",
                ["x-trace-id"] = has_trace_headers and "simulated-trace-id" or nil
            },
            body = '{"message":"Simulated response from server","trace_propagated":' .. 
                   tostring(has_trace_headers) .. '}'
        }
    end
    
    return success, response, error_msg
end

-- Start main trace for the client session
print("\n🎯 Starting Client Session")
print("-------------------------")

local session_trace = tracing.start_trace()
print("✅ Client session trace started: " .. session_trace.trace_id)

-- Add initial breadcrumb
sentry.add_breadcrumb({
    message = "Client session started",
    category = "client.session",
    level = "info",
    data = {
        server_base = SERVER_BASE,
        trace_id = session_trace.trace_id
    }
})

-- Function to test an endpoint
local function test_endpoint(endpoint)
    print("\n📍 Testing endpoint: " .. endpoint)
    print("---" .. string.rep("-", #endpoint + 18))
    
    -- Create child span for this request
    local request_context = tracing.create_child()
    local trace_info = tracing.get_current_trace_info()
    
    print("   🔗 Request trace: " .. trace_info.trace_id)
    print("   📍 Request span: " .. trace_info.span_id)
    if trace_info.parent_span_id then
        print("   👆 Parent span: " .. trace_info.parent_span_id)
    end
    
    local url = SERVER_BASE .. endpoint
    local start_time = os.clock()
    
    -- Make the request
    local success, response, error_msg = make_http_request(url)
    local duration_ms = math.floor((os.clock() - start_time) * 1000)
    
    if success and response then
        print("   📥 Response: HTTP " .. response.status .. " (" .. duration_ms .. "ms)")
        
        -- Check if server returned trace info
        if response.headers["x-trace-id"] then
            print("   🔗 Server trace ID: " .. response.headers["x-trace-id"])
        end
        if response.headers["x-span-id"] then
            print("   📍 Server span ID: " .. response.headers["x-span-id"])
        end
        
        -- Parse response body if JSON
        local response_data = nil
        if response.body and response.body:find("{") == 1 then
            local json_success, parsed = pcall(function()
                local json = require("build.sentry.utils.json") or {
                    decode = function() return nil end
                }
                return json.decode(response.body)
            end)
            if json_success then
                response_data = parsed
            end
        end
        
        -- Add breadcrumb for successful request
        sentry.add_breadcrumb({
            message = "HTTP request completed",
            category = "http.request",
            level = (response.status >= 400) and "error" or "info",
            data = {
                method = "GET",
                url = url,
                status_code = response.status,
                duration_ms = duration_ms,
                trace_id = trace_info.trace_id,
                response_trace_id = response.headers["x-trace-id"]
            }
        })
        
        -- Capture event based on response
        if response.status >= 500 then
            sentry.capture_message("Server error received from " .. endpoint, "error")
            print("   ❌ Server error captured")
        elseif response.status >= 400 then
            sentry.capture_message("Client error on " .. endpoint, "warning") 
            print("   ⚠️  Client error captured")
        else
            sentry.capture_message("Successful request to " .. endpoint, "info")
            print("   ✅ Success event captured")
        end
        
        -- Show response summary
        if response_data and response_data.message then
            print("   💬 Server says: " .. response_data.message)
        end
        
    else
        print("   ❌ Request failed: " .. (error_msg or "unknown error"))
        
        -- Add breadcrumb for failed request
        sentry.add_breadcrumb({
            message = "HTTP request failed", 
            category = "http.request",
            level = "error",
            data = {
                method = "GET",
                url = url,
                error = error_msg or "unknown error",
                duration_ms = duration_ms
            }
        })
        
        -- Capture exception for failed request
        sentry.capture_exception({
            type = "HTTPRequestError",
            message = "Failed to connect to server: " .. (error_msg or "unknown error"),
            extra = {
                url = url,
                endpoint = endpoint,
                duration_ms = duration_ms,
                trace_id = trace_info.trace_id
            }
        })
    end
    
    return success, response
end

-- Test each endpoint
print("\n🎯 Testing Server Endpoints")
print("==========================")

local successful_requests = 0
local total_requests = #ENDPOINTS

for i, endpoint in ipairs(ENDPOINTS) do
    local success, response = test_endpoint(endpoint)
    if success then
        successful_requests = successful_requests + 1
    end
    
    -- Small delay between requests
    if i < #ENDPOINTS then
        local delay_start = os.clock()
        while os.clock() - delay_start < 0.5 do
            -- Brief pause between requests
        end
    end
end

-- Summary
print("\n📊 Client Session Summary")
print("========================")
print("Total requests: " .. total_requests)
print("Successful requests: " .. successful_requests)
print("Failed requests: " .. (total_requests - successful_requests))

local final_trace_info = tracing.get_current_trace_info()
if final_trace_info then
    print("Session trace ID: " .. final_trace_info.trace_id)
end

-- Capture final summary event
sentry.capture_message("Client session completed: " .. successful_requests .. "/" .. 
                      total_requests .. " requests successful", "info")

-- Add final breadcrumb
sentry.add_breadcrumb({
    message = "Client session completed",
    category = "client.session",
    level = "info",
    data = {
        total_requests = total_requests,
        successful_requests = successful_requests,
        session_trace_id = final_trace_info and final_trace_info.trace_id or "none"
    }
})

print("\n🎉 Client Demo Complete!")
print("=======================")
print("Key features demonstrated:")
print("• Automatic trace header propagation to server")
print("• Child span creation for each HTTP request") 
print("• Event capture with distributed trace context")
print("• Breadcrumb integration across service boundaries")
print("• Error correlation between client and server")
print("• End-to-end trace visibility in Sentry")
print("")
print("🔍 Check your Sentry dashboard to see:")
print("• How client and server events are connected by trace IDs")
print("• Parent-child span relationships across services")
print("• Complete request flow from client → server → database")
print("• Error correlation and performance insights")
print("")
print("💡 Tips for real usage:")
print("• Install LuaSocket: luarocks install luasocket")
print("• Configure trace_propagation_targets for your domains")
print("• Use environment-specific DSNs for production")
print("• Add custom baggage for additional context propagation")