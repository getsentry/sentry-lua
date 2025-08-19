#!/usr/bin/env lua
-- Distributed Tracing HTTP Client
-- Requires: luarocks install luasocket
-- Usage: First start tracing_server.lua, then run lua examples/tracing_client.lua
-- This demonstrates REAL distributed tracing between processes via HTTP

package.path = "build/?.lua;build/?/init.lua;;" .. package.path

-- Require luasocket - fail if not available
local http = require("socket.http")
local ltn12 = require("ltn12")
local sentry = require("sentry")
local tracing = require("sentry.tracing")
local performance = require("sentry.performance")

-- Initialize Sentry
sentry.init({
    dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928", 
    debug = true,
    environment = "distributed-tracing-client"
})

-- Initialize tracing
tracing.init({
    trace_propagation_targets = {"*"}  -- Allow all for demo
})

print("🚀 Distributed Tracing Client")
print("=============================")
print("Making HTTP requests to server at http://localhost:8080")
print("Each request will propagate trace context and create distributed spans\n")

-- Helper function to make HTTP request with trace propagation
local function make_request(method, url, body, transaction)
    local headers = {}
    
    -- Start HTTP client span FIRST
    local span = transaction:start_span("http.client", method .. " " .. url)
    
    -- THEN get trace headers for propagation (now from the current span context)
    local trace_headers = tracing.get_request_headers(url)
    if trace_headers then
        headers["sentry-trace"] = trace_headers["sentry-trace"]
        headers["baggage"] = trace_headers["baggage"]
        headers["traceparent"] = trace_headers["traceparent"]
        print("  → Propagating trace headers:")
        if trace_headers["sentry-trace"] then
            print("    sentry-trace:", trace_headers["sentry-trace"])
        end
    else
        print("  → No trace headers available to propagate")
    end
    
    -- Set content headers for POST requests
    if method == "POST" and body then
        headers["Content-Type"] = "application/json"
        headers["Content-Length"] = tostring(#body)
    end
    
    local response_body = {}
    local result, status, response_headers
    
    if method == "GET" then
        result, status, response_headers = http.request{
            url = url,
            method = method,
            headers = headers,
            sink = ltn12.sink.table(response_body)
        }
    elseif method == "POST" then
        result, status, response_headers = http.request{
            url = url,
            method = method,
            headers = headers,
            source = ltn12.source.string(body),
            sink = ltn12.sink.table(response_body)
        }
    end
    
    local response_text = table.concat(response_body)
    print("  → HTTP", status, "(" .. #response_text .. " bytes)")
    
    -- Finish span with status
    local span_status = "http_error"
    if type(status) == "number" and status >= 200 and status < 300 then
        span_status = "ok"
    end
    span:finish(span_status)
    
    return result, status, response_text
end

-- Demo 1: Health Check
print("📍 Demo 1: Health Check Request")
-- Note: start_transaction will automatically create a new trace if none exists
local tx1 = performance.start_transaction("client_health_check", "http.client")

local result1, status1, body1 = make_request("GET", "http://localhost:8080/", nil, tx1)
if result1 then
    print("  ✅ Health check successful")
    sentry.capture_message("Health check completed from client", "info")
else
    print("  ❌ Health check failed:", status1)
    sentry.capture_message("Health check failed from client: " .. tostring(status1), "error")
end

tx1:finish("ok")
print()

-- Demo 2: User List Request
print("📍 Demo 2: Fetch Users")
-- Start fresh trace for this demo
tracing.start_trace()
local tx2 = performance.start_transaction("client_fetch_users", "http.client")

local result2, status2, body2 = make_request("GET", "http://localhost:8080/api/users", nil, tx2)
if result2 and status2 == 200 then
    -- Parse response to show user count
    local json = require("sentry.utils.json")
    local success, data = pcall(json.decode, body2)
    if success and data and data.users then
        print("  ✅ Retrieved", #data.users, "users")
        sentry.capture_message("Retrieved " .. #data.users .. " users successfully", "info")
    else
        print("  ✅ Users request successful")
        sentry.capture_message("Users request completed", "info")  
    end
else
    print("  ❌ Users request failed:", status2)
    sentry.capture_message("Users request failed: " .. tostring(status2), "error")
end

tx2:finish("ok")
print()

-- Demo 3: Create Order (Complex Workflow)
print("📍 Demo 3: Create Order (Complex Server Workflow)")
-- Start fresh trace for this demo
tracing.start_trace()
local tx3 = performance.start_transaction("client_create_order", "http.client")

-- Simulate order data preparation
local prep_span = tx3:start_span("order.prepare", "Prepare order data")
print("  → Preparing order data...")
local order_data = {
    product_id = "PROD-123",
    quantity = 2,
    customer_id = "CUST-456"
}
local json_body = require("sentry.utils.json").encode(order_data)
os.execute("sleep 0.02")  -- Simulate prep time
prep_span:finish("ok")

local result3, status3, body3 = make_request("POST", "http://localhost:8080/api/orders", json_body, tx3)
if result3 and status3 == 201 then
    print("  ✅ Order created successfully")
    sentry.capture_message("Order creation completed", "info")
else
    print("  ❌ Order creation failed:", status3)
    sentry.capture_message("Order creation failed: " .. tostring(status3), "error")
end

tx3:finish("ok")
print()

-- Demo 4: Slow Request 
print("📍 Demo 4: Slow Request (Performance Monitoring)")
-- Start fresh trace for this demo
tracing.start_trace()
local tx4 = performance.start_transaction("client_slow_request", "http.client")

print("  → Making slow request (will take ~800ms on server)...")
local result4, status4, body4 = make_request("GET", "http://localhost:8080/api/slow", nil, tx4)
if result4 then
    print("  ✅ Slow request completed")
    sentry.capture_message("Slow request completed successfully", "info")
else
    print("  ❌ Slow request failed:", status4)
    sentry.capture_message("Slow request failed: " .. tostring(status4), "error") 
end

tx4:finish("ok")
print()

-- Demo 5: Error Request (Error Propagation)
print("📍 Demo 5: Error Request (Distributed Error Tracing)")
-- Start fresh trace for this demo
tracing.start_trace()
local tx5 = performance.start_transaction("client_error_request", "http.client")

local result5, status5, body5 = make_request("GET", "http://localhost:8080/api/error", nil, tx5)
if result5 and status5 == 500 then
    print("  ✅ Error request completed (expected 500)")
    sentry.capture_message("Error endpoint tested - server error handled correctly", "info")
else
    print("  ❌ Unexpected response:", status5)
    sentry.capture_message("Error endpoint unexpected response: " .. tostring(status5), "warning")
end

tx5:finish("ok")
print()

print("🎉 Distributed tracing client demo completed!")
print()
print("Check your Sentry dashboard to see:")
print("• Client-side transactions showing HTTP requests")
print("• Server-side transactions showing request processing")
print("• Distributed traces connecting client and server spans")
print("• Error correlation across both processes")
print("• Performance data for the complete request flow")
print()
print("The traces should show:")
print("  Client Transaction")
print("  ├── http.client span (request to server)")
print("  └── Server Transaction (same trace)")
print("      ├── db.query spans")
print("      ├── cache.get spans")
print("      └── validation spans")