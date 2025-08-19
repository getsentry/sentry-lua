#!/usr/bin/env lua
---
--- Middleware Integration Demo
--- Demonstrates how to integrate distributed tracing with custom middleware and frameworks
---

-- Set up path for running from repository root
package.path = "src/?.lua;src/?/init.lua;platforms/?.lua;platforms/?/init.lua;build/?.lua;build/?/init.lua;;" .. package.path

local sentry = require("sentry")
local tracing_platform = require("sentry.tracing.platform")

print("🔗 Middleware Integration Demo")
print("==============================")

-- Initialize Sentry with the test DSN
sentry.init({
    dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
    environment = "tracing-examples",
    debug = true
})

-- Initialize distributed tracing
local platform = tracing_platform.init({
    tracing = {
        trace_propagation_targets = {"api%.internal%.com", "localhost", ".*%.mycompany%.com"},
        include_traceparent = true
    },
    auto_instrument = false  -- We'll handle instrumentation in middleware
})

local tracing = platform.tracing

-- Middleware Framework Simulation
local MiddlewareStack = {}
MiddlewareStack.__index = MiddlewareStack

function MiddlewareStack:new()
    return setmetatable({
        middlewares = {},
        routes = {}
    }, self)
end

function MiddlewareStack:use(middleware)
    table.insert(self.middlewares, middleware)
end

function MiddlewareStack:route(path, handler)
    self.routes[path] = handler
end

function MiddlewareStack:handle_request(path, headers, body)
    local context = {
        path = path,
        headers = headers or {},
        body = body,
        response = {},
        response_headers = {},
        status = 200
    }
    
    -- Execute middleware chain
    local function execute_next(index)
        if index > #self.middlewares then
            -- All middleware executed, now call route handler
            local handler = self.routes[path]
            if handler then
                return handler(context)
            else
                context.status = 404
                context.response = {error = "Not Found"}
                return context.response
            end
        end
        
        local middleware = self.middlewares[index]
        return middleware(context, function()
            return execute_next(index + 1)
        end)
    end
    
    return execute_next(1), context
end

-- Example 1: Tracing Middleware
print("\n🔍 Example 1: Tracing Middleware")
print("-------------------------------")

local function create_tracing_middleware()
    return function(context, next)
        local path = context.path
        print("🔗 Tracing middleware: " .. path)
        
        -- Check for incoming trace headers
        local has_trace_headers = false
        for key, _ in pairs(context.headers) do
            if key:lower():find("sentry") or key:lower():find("baggage") or key:lower():find("traceparent") then
                has_trace_headers = true
                break
            end
        end
        
        -- Continue or start trace
        local trace_context
        if has_trace_headers then
            trace_context = tracing.continue_trace_from_request(context.headers)
            print("   ✅ Continued trace from incoming headers")
        else
            trace_context = tracing.start_trace()
            print("   ✅ Started new trace for request")
        end
        
        local trace_info = tracing.get_current_trace_info()
        print("   🔗 Request trace: " .. trace_info.trace_id)
        
        -- Store trace info in context for other middleware
        context.trace_id = trace_info.trace_id
        context.span_id = trace_info.span_id
        
        -- Add trace headers to response
        context.response_headers["X-Trace-ID"] = trace_info.trace_id
        context.response_headers["X-Span-ID"] = trace_info.span_id
        
        -- Add breadcrumb for request start
        sentry.add_breadcrumb({
            message = "Request started", 
            category = "http.middleware",
            level = "debug",
            data = {
                path = path,
                method = context.method or "GET",
                has_parent_trace = has_trace_headers,
                trace_id = trace_info.trace_id
            }
        })
        
        local start_time = os.clock()
        
        -- Execute next middleware/handler
        local result = next()
        
        local duration_ms = math.floor((os.clock() - start_time) * 1000)
        
        -- Add completion breadcrumb
        sentry.add_breadcrumb({
            message = "Request completed",
            category = "http.middleware", 
            level = "info",
            data = {
                path = path,
                status = context.status,
                duration_ms = duration_ms,
                trace_id = trace_info.trace_id
            }
        })
        
        -- Capture event for request
        local event_level = (context.status >= 400) and "error" or "info"
        sentry.capture_message("Middleware request: " .. path, event_level)
        
        print("   ⏱️  Request completed in " .. duration_ms .. "ms")
        
        return result
    end
end

-- Example 2: Authentication Middleware with Tracing
print("\n🔐 Example 2: Authentication Middleware")
print("--------------------------------------")

local function create_auth_middleware()
    return function(context, next)
        local path = context.path
        print("🔐 Auth middleware: " .. path)
        
        -- Create child span for authentication
        local auth_span = tracing.create_child()
        local trace_info = tracing.get_current_trace_info()
        print("   📍 Auth span: " .. trace_info.span_id)
        
        -- Simulate authentication logic
        local auth_header = context.headers["authorization"] or context.headers["Authorization"]
        
        sentry.add_breadcrumb({
            message = "Authentication started",
            category = "auth.middleware",
            level = "debug", 
            data = {
                path = path,
                has_auth_header = auth_header ~= nil,
                span_id = trace_info.span_id
            }
        })
        
        if not auth_header then
            print("   ❌ No authorization header")
            context.status = 401
            context.response = {error = "Unauthorized", message = "Missing authorization header"}
            
            sentry.capture_message("Authentication failed: missing header for " .. path, "warning")
            return context.response
        end
        
        if auth_header ~= "Bearer valid-token" then
            print("   ❌ Invalid token")
            context.status = 403
            context.response = {error = "Forbidden", message = "Invalid token"}
            
            sentry.capture_message("Authentication failed: invalid token for " .. path, "warning")
            return context.response
        end
        
        print("   ✅ Authentication successful")
        context.user_id = "user_12345"
        
        sentry.add_breadcrumb({
            message = "Authentication successful",
            category = "auth.middleware",
            level = "info",
            data = {
                user_id = context.user_id,
                span_id = trace_info.span_id
            }
        })
        
        return next()
    end
end

-- Example 3: Database Middleware with Child Spans
print("\n🗃️  Example 3: Database Middleware")
print("---------------------------------")

local function create_database_middleware()
    return function(context, next)
        print("🗃️  Database middleware")
        
        -- Create child span for database operations
        local db_span = tracing.create_child()
        local trace_info = tracing.get_current_trace_info()
        print("   📊 Database span: " .. trace_info.span_id)
        
        -- Simulate database connection and query
        sentry.add_breadcrumb({
            message = "Database connection established",
            category = "db.middleware",
            level = "debug",
            data = {
                span_id = trace_info.span_id,
                connection_pool = "main_db"
            }
        })
        
        -- Store database connection in context
        context.db = {
            query = function(sql, params)
                print("   📋 Executing query: " .. sql:sub(1, 50) .. (sql:len() > 50 and "..." or ""))
                
                local query_span = tracing.create_child()
                local query_trace = tracing.get_current_trace_info()
                
                sentry.add_breadcrumb({
                    message = "Database query executed",
                    category = "db.query",
                    level = "debug",
                    data = {
                        sql = sql,
                        params = params,
                        span_id = query_trace.span_id
                    }
                })
                
                -- Simulate query execution time
                local query_start = os.clock()
                while os.clock() - query_start < 0.05 do end  -- 50ms simulation
                
                local duration = math.floor((os.clock() - query_start) * 1000)
                print("   ✅ Query completed in " .. duration .. "ms")
                
                return {{id = 1, name = "Sample Data"}}
            end
        }
        
        local result = next()
        
        sentry.add_breadcrumb({
            message = "Database connection closed",
            category = "db.middleware",
            level = "debug"
        })
        
        print("   🔌 Database connection closed")
        
        return result
    end
end

-- Example 4: Error Handling Middleware
print("\n❌ Example 4: Error Handling Middleware") 
print("--------------------------------------")

local function create_error_middleware()
    return function(context, next)
        print("🛡️  Error handling middleware")
        
        local success, result = pcall(next)
        
        if not success then
            print("   ❌ Caught error: " .. tostring(result))
            
            -- Create child span for error handling
            local error_span = tracing.create_child()
            local trace_info = tracing.get_current_trace_info()
            
            sentry.add_breadcrumb({
                message = "Error caught by middleware",
                category = "error.middleware",
                level = "error",
                data = {
                    error = tostring(result),
                    path = context.path,
                    span_id = trace_info.span_id
                }
            })
            
            -- Capture the exception with trace context
            sentry.capture_exception({
                type = "MiddlewareError",
                message = tostring(result),
                extra = {
                    path = context.path,
                    user_id = context.user_id,
                    trace_id = trace_info.trace_id,
                    span_id = trace_info.span_id
                }
            })
            
            context.status = 500
            context.response = {
                error = "Internal Server Error",
                message = "An error occurred while processing your request",
                trace_id = trace_info.trace_id
            }
            
            return context.response
        end
        
        return result
    end
end

-- Example 5: Build and test the middleware stack
print("\n🏗️  Example 5: Complete Middleware Stack")
print("---------------------------------------")

local app = MiddlewareStack:new()

-- Add middleware in order (they execute in this order)
app:use(create_error_middleware())      -- Outermost - catches all errors
app:use(create_tracing_middleware())    -- Sets up tracing for request
app:use(create_auth_middleware())       -- Handles authentication
app:use(create_database_middleware())   -- Provides database access

-- Add routes
app:route("/api/users", function(context)
    print("📍 Handler: GET /api/users")
    
    -- Use database from middleware
    local users = context.db.query("SELECT * FROM users WHERE active = ?", {true})
    
    sentry.add_breadcrumb({
        message = "Users fetched successfully",
        category = "handler.users",
        level = "info",
        data = {
            user_count = #users,
            user_id = context.user_id
        }
    })
    
    return {
        users = users,
        total = #users,
        trace_id = context.trace_id
    }
end)

app:route("/api/profile", function(context)
    print("📍 Handler: GET /api/profile")
    
    local profile = context.db.query("SELECT * FROM users WHERE id = ?", {context.user_id})
    
    return {
        profile = profile[1],
        trace_id = context.trace_id
    }
end)

app:route("/api/error", function(context)
    print("📍 Handler: GET /api/error")
    error("Intentional error for middleware demo")
end)

-- Test the middleware stack with different scenarios
local test_requests = {
    {
        path = "/api/users",
        headers = {
            ["Authorization"] = "Bearer valid-token",
            ["User-Agent"] = "test-client/1.0"
        },
        description = "Successful authenticated request"
    },
    {
        path = "/api/profile", 
        headers = {
            ["Authorization"] = "Bearer valid-token",
            ["sentry-trace"] = "abc123def456789012345678901234567890-1234567890abcdef-1",
            ["baggage"] = "session_id=sess_123,device=mobile"
        },
        description = "Request with incoming trace headers"
    },
    {
        path = "/api/users",
        headers = {
            ["User-Agent"] = "test-client/1.0"
            -- No Authorization header
        },
        description = "Unauthorized request"
    },
    {
        path = "/api/error",
        headers = {
            ["Authorization"] = "Bearer valid-token"
        },
        description = "Request that causes an error"
    }
}

print("\n🧪 Testing Middleware Stack")
print("==========================")

for i, test in ipairs(test_requests) do
    print("\n" .. i .. ". " .. test.description)
    print("   " .. test.path)
    
    local response, context = app:handle_request(test.path, test.headers)
    
    print("   📤 Response: HTTP " .. context.status)
    if context.trace_id then
        print("   🔗 Trace ID: " .. context.trace_id)
    end
    
    -- Add some delay between requests
    local delay_start = os.clock()
    while os.clock() - delay_start < 0.2 do end
end

print("\n🎉 Middleware Integration Demo Complete!")
print("======================================")
print("Key concepts demonstrated:")
print("• Tracing middleware for automatic instrumentation")
print("• Child span creation in middleware layers")
print("• Trace context propagation between middleware")
print("• Error handling with trace correlation")
print("• Database operation tracing")
print("• Authentication flow with tracing")
print("• Response header injection for trace visibility")
print("")
print("🏗️  Middleware integration patterns:")
print("• Tracing middleware should run early in the chain")
print("• Create child spans for expensive operations")
print("• Propagate trace context through request context")
print("• Handle errors while preserving trace information")
print("• Add meaningful breadcrumbs at each layer")
print("")
print("💡 Best practices for middleware tracing:")
print("• Keep middleware focused on single responsibilities")
print("• Use child spans for nested operations")
print("• Include relevant metadata in breadcrumbs")
print("• Ensure trace context survives error conditions")
print("• Add trace IDs to response headers for debugging")