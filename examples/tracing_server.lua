#!/usr/bin/env lua
-- Distributed Tracing HTTP Server
-- Requires: luarocks install pegasus
-- Usage: lua examples/tracing_server.lua
-- Then run tracing_client.lua in another terminal

package.path = "build/?.lua;build/?/init.lua;;" .. package.path

-- Require pegasus - fail if not available
local pegasus = require("pegasus")
local sentry = require("sentry")
local tracing = require("sentry.tracing")
local performance = require("sentry.performance")

-- Initialize Sentry
sentry.init({
    dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928", 
    debug = true,
    environment = "distributed-tracing-server"
})

-- Initialize tracing
tracing.init({
    trace_propagation_targets = {"*"}  -- Allow all for demo
})

print("🚀 Distributed Tracing Server")
print("=============================")
print("Server starting on http://localhost:8080")
print("Endpoints:")
print("  GET /             - Simple health check")
print("  GET /api/users    - User list with database simulation")
print("  POST /api/orders  - Order processing with complex workflow")  
print("  GET /api/slow     - Slow endpoint demonstrating timing")
print("  GET /api/error    - Error endpoint for error tracing")
print("\nRun tracing_client.lua in another terminal to test distributed tracing")
print("Press Ctrl+C to stop\n")

-- Create server
local server = pegasus:new({
    host = "0.0.0.0",
    port = 8080
})

-- Helper to extract trace headers
local function extract_headers(request)
    local headers = {}
    if request.headers then
        local req_headers = request:headers()
        headers["sentry-trace"] = req_headers["sentry-trace"]
        headers["baggage"] = req_headers["baggage"] 
        headers["traceparent"] = req_headers["traceparent"]
    end
    return headers
end

-- Helper to handle GET /
local function handle_health_check(request, response)
    local incoming_headers = extract_headers(request)
    local context = tracing.continue_trace_from_request(incoming_headers)
    
    -- Parse incoming trace header to get correct parent span ID
    local headers = require("sentry.tracing.headers")
    local incoming_trace = headers.parse_sentry_trace(incoming_headers["sentry-trace"])
    
    -- Start transaction with correct parent-child relationship
    local tx = performance.start_transaction("GET /", "http.server", {
        trace_id = context and context.trace_id,
        parent_span_id = incoming_trace and incoming_trace.span_id,  -- Use incoming span as parent
        span_id = headers.generate_span_id()
    })
    
    local health = { status = "healthy", timestamp = os.time() }
    
    sentry.capture_message("Health check completed", "info")
    tx:finish("ok")
    
    response:statusCode(200)
    response:addHeader("Content-Type", "application/json")
    response:write(require("sentry.utils.json").encode(health))
end

-- Helper to handle GET /api/users
local function handle_get_users(request, response)
    local incoming_headers = extract_headers(request)
    local context = tracing.continue_trace_from_request(incoming_headers)
    
    -- Parse incoming trace header to get correct parent span ID
    local headers = require("sentry.tracing.headers")
    local incoming_trace = headers.parse_sentry_trace(incoming_headers["sentry-trace"])
    
    local tx = performance.start_transaction("GET /api/users", "http.server", {
        trace_id = context and context.trace_id,
        parent_span_id = incoming_trace and incoming_trace.span_id,  -- Use incoming span as parent
        span_id = headers.generate_span_id()
    })
    print("📍 Handling GET /api/users")
    
    local db_span = tx:start_span("db.query", "SELECT * FROM users WHERE active = 1")
    print("  → Querying database...")
    os.execute("sleep 0.1")
    db_span:finish("ok")
    
    local cache_span = tx:start_span("cache.get", "Redis GET users_list")  
    print("  → Checking cache...")
    os.execute("sleep 0.05")
    cache_span:finish("ok")
    
    local users = {
        { id = 1, name = "Alice", email = "alice@example.com" },
        { id = 2, name = "Bob", email = "bob@example.com" },
        { id = 3, name = "Carol", email = "carol@example.com" }
    }
    
    sentry.capture_message("Users retrieved successfully", "info")
    tx:finish("ok")
    
    response:statusCode(200)
    response:addHeader("Content-Type", "application/json")
    response:write(require("sentry.utils.json").encode({ users = users, count = #users }))
end

-- Helper to handle POST /api/orders
local function handle_create_order(request, response)
    local incoming_headers = extract_headers(request)
    local context = tracing.continue_trace_from_request(incoming_headers)
    
    -- Parse incoming trace header to get correct parent span ID
    local headers = require("sentry.tracing.headers")
    local incoming_trace = headers.parse_sentry_trace(incoming_headers["sentry-trace"])
    
    local tx = performance.start_transaction("POST /api/orders", "http.server", {
        trace_id = context and context.trace_id,
        parent_span_id = incoming_trace and incoming_trace.span_id,  -- Use incoming span as parent
        span_id = headers.generate_span_id()
    })
    print("📍 Handling POST /api/orders")
    
    local validation_span = tx:start_span("validation.order", "Validate order data")
    print("  → Validating order...")
    os.execute("sleep 0.03")
    validation_span:finish("ok")
    
    local inventory_span = tx:start_span("inventory.check", "Check product availability")
    print("  → Checking inventory...")
    os.execute("sleep 0.08")
    inventory_span:finish("ok")
    
    local payment_span = tx:start_span("payment.process", "Process payment")
    print("  → Processing payment...")
    os.execute("sleep 0.12")
    payment_span:finish("ok")
    
    local create_span = tx:start_span("db.insert", "INSERT INTO orders")
    print("  → Creating order record...")
    os.execute("sleep 0.06")
    create_span:finish("ok")
    
    local order = { 
        id = "ORD-" .. math.random(1000, 9999),
        status = "confirmed",
        total = 29.99
    }
    
    sentry.capture_message("Order created successfully: " .. order.id, "info")
    tx:finish("ok")
    
    response:statusCode(201)
    response:addHeader("Content-Type", "application/json")
    response:write(require("sentry.utils.json").encode({ order = order, message = "Order created" }))
end

-- Helper to handle GET /api/slow
local function handle_slow_endpoint(request, response)
    local incoming_headers = extract_headers(request)
    local context = tracing.continue_trace_from_request(incoming_headers)
    
    -- Parse incoming trace header to get correct parent span ID
    local headers = require("sentry.tracing.headers")
    local incoming_trace = headers.parse_sentry_trace(incoming_headers["sentry-trace"])
    
    local tx = performance.start_transaction("GET /api/slow", "http.server", {
        trace_id = context and context.trace_id,
        parent_span_id = incoming_trace and incoming_trace.span_id,  -- Use incoming span as parent
        span_id = headers.generate_span_id()
    })
    print("📍 Handling GET /api/slow")
    
    local external_span = tx:start_span("http.client", "External API call")
    print("  → Calling external API (slow)...")
    os.execute("sleep 0.5")
    external_span:finish("ok")
    
    local slow_db_span = tx:start_span("db.query", "Complex analytical query")
    print("  → Running complex query...")
    os.execute("sleep 0.3")
    slow_db_span:finish("ok")
    
    sentry.capture_message("Slow endpoint completed", "info")
    tx:finish("ok")
    
    response:statusCode(200)
    response:addHeader("Content-Type", "application/json")
    response:write(require("sentry.utils.json").encode({ 
        message = "Slow operation completed",
        duration_ms = 800
    }))
end

-- Helper to handle GET /api/error
local function handle_error_endpoint(request, response)
    local incoming_headers = extract_headers(request)
    local context = tracing.continue_trace_from_request(incoming_headers)
    
    -- Parse incoming trace header to get correct parent span ID
    local headers = require("sentry.tracing.headers")
    local incoming_trace = headers.parse_sentry_trace(incoming_headers["sentry-trace"])
    
    local tx = performance.start_transaction("GET /api/error", "http.server", {
        trace_id = context and context.trace_id,
        parent_span_id = incoming_trace and incoming_trace.span_id,  -- Use incoming span as parent
        span_id = headers.generate_span_id()
    })
    print("📍 Handling GET /api/error")
    
    local work_span = tx:start_span("process.data", "Processing data")
    print("  → Processing data...")
    os.execute("sleep 0.05")
    work_span:finish("ok")
    
    local error_span = tx:start_span("db.query", "Query user preferences")
    print("  → Error occurred!")
    
    sentry.capture_exception({
        type = "DatabaseError",
        message = "Connection timeout: Could not connect to database after 30s"
    }, "error")
    
    error_span:finish("internal_error")
    tx:finish("internal_error")
    
    response:statusCode(500)
    response:addHeader("Content-Type", "application/json")
    response:write(require("sentry.utils.json").encode({ 
        error = "Internal server error",
        message = "Database connection failed"
    }))
end

-- Start server with request handler
server:start(function(request, response)
    local method = request:method()
    local path = request:path()
    
    print("📨 Incoming:", method, path)
    
    -- Route handling
    if method == "GET" and path == "/" then
        handle_health_check(request, response)
    elseif method == "GET" and path == "/api/users" then
        handle_get_users(request, response)
    elseif method == "POST" and path == "/api/orders" then
        handle_create_order(request, response)
    elseif method == "GET" and path == "/api/slow" then
        handle_slow_endpoint(request, response)
    elseif method == "GET" and path == "/api/error" then
        handle_error_endpoint(request, response)
    else
        -- 404 handler
        response:statusCode(404)
        response:addHeader("Content-Type", "application/json")
        response:write(require("sentry.utils.json").encode({ 
            error = "Not found",
            path = path,
            method = method 
        }))
    end
end)

print("✅ Server started on http://localhost:8080")