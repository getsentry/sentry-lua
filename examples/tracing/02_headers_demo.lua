#!/usr/bin/env lua
---
--- Headers and Propagation Demo
--- Demonstrates sentry-trace headers, baggage, and trace propagation mechanics
---

-- Set up path for running from repository root
package.path = "src/?.lua;src/?/init.lua;platforms/?.lua;platforms/?/init.lua;build/?.lua;build/?/init.lua;;" .. package.path

local sentry = require("sentry")
local tracing_platform = require("sentry.tracing.platform")
local headers_module = require("sentry.tracing.headers")

print("🔗 Headers and Propagation Demo")
print("===============================")

-- Initialize Sentry with the test DSN
sentry.init({
    dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
    environment = "tracing-examples",
    debug = true
})

-- Initialize distributed tracing
local platform = tracing_platform.init({
    tracing = {
        trace_propagation_targets = {"api%.example%.com", "localhost", ".*%.internal%.com"},
        include_traceparent = true
    }
})

local tracing = platform.tracing

-- Example 1: Header parsing and generation
print("\n📋 Example 1: Header Parsing and Generation")
print("-------------------------------------------")

-- Generate trace headers
tracing.start_trace()
local trace_info = tracing.get_current_trace_info()
print("✅ Started trace: " .. trace_info.trace_id)

-- Get headers for outgoing request
local outgoing_headers = tracing.get_request_headers("https://api.example.com/users")
print("✅ Generated outgoing headers:")
for key, value in pairs(outgoing_headers) do
    print("   " .. key .. ": " .. value)
end

-- Example 2: Parse incoming headers
print("\n📥 Example 2: Parsing Incoming Headers")
print("-------------------------------------")

-- Simulate incoming headers from another service
local incoming_headers = {
    ["content-type"] = "application/json",
    ["sentry-trace"] = "a1b2c3d4e5f6789012345678901234567890abcd-ef1234567890abcd-1",
    ["baggage"] = "user_id=12345,session_id=abcdef,environment=production"
}

print("✅ Simulated incoming headers:")
for key, value in pairs(incoming_headers) do
    if key:lower():find("sentry") or key:lower():find("baggage") then
        print("   " .. key .. ": " .. value)
    end
end

-- Continue trace from incoming headers
local continued_trace = tracing.continue_trace_from_request(incoming_headers)
print("✅ Continued trace from headers:")
print("   Trace ID: " .. continued_trace.trace_id)
print("   Parent Span: " .. (continued_trace.parent_span_id or "none"))

-- Example 3: Manual header operations
print("\n🔧 Example 3: Manual Header Operations")
print("-------------------------------------")

-- Parse sentry-trace header manually
local parsed_trace = headers_module.parse_sentry_trace("a1b2c3d4e5f6789012345678901234567890abcd-ef1234567890abcd-1")
if parsed_trace then
    print("✅ Manually parsed sentry-trace:")
    print("   Trace ID: " .. parsed_trace.trace_id)
    print("   Span ID: " .. parsed_trace.span_id)
    print("   Sampled: " .. tostring(parsed_trace.sampled))
end

-- Generate sentry-trace header manually
local trace_data = {
    trace_id = "1234567890abcdef1234567890abcdef",
    span_id = "abcdef1234567890",
    sampled = false
}

local manual_header = headers_module.generate_sentry_trace(trace_data)
print("✅ Manually generated sentry-trace: " .. manual_header)

-- Example 4: Baggage handling
print("\n🎒 Example 4: Baggage Handling")
print("-----------------------------")

-- Parse baggage header
local baggage_data = headers_module.parse_baggage("user_id=12345,session=abc123,environment=prod")
print("✅ Parsed baggage:")
for key, value in pairs(baggage_data) do
    print("   " .. key .. " = " .. value)
end

-- Generate baggage header
local custom_baggage = {
    deployment_id = "v2.1.0",
    region = "us-west-2",
    feature_flags = "new_ui,beta_api"
}

local baggage_header = headers_module.generate_baggage(custom_baggage)
print("✅ Generated baggage: " .. baggage_header)

-- Example 5: Header extraction and injection
print("\n💉 Example 5: Header Extraction and Injection")
print("--------------------------------------------")

-- Extract all trace headers from HTTP headers
local http_headers = {
    ["Host"] = "api.example.com",
    ["User-Agent"] = "lua-client/1.0",
    ["SENTRY-TRACE"] = "fedcba098765432109876543210987654-4321098765432109-0",  -- Case-insensitive
    ["Baggage"] = "request_id=req_123,user_type=premium",
    ["traceparent"] = "00-fedcba098765432109876543210987654-4321098765432109-01"
}

local extracted_trace = headers_module.extract_trace_headers(http_headers)
print("✅ Extracted trace information:")
if extracted_trace.sentry_trace then
    print("   Sentry trace found: " .. extracted_trace.sentry_trace.trace_id)
end
if extracted_trace.baggage then
    print("   Baggage found: " .. (next(extracted_trace.baggage) and "yes" or "no"))
end
if extracted_trace.traceparent then
    print("   Traceparent found: " .. extracted_trace.traceparent)
end

-- Inject trace headers into outgoing request
local request_headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer token123"
}

local current_trace = tracing.get_current_trace_info()
local inject_trace_data = {
    trace_id = current_trace.trace_id,
    span_id = current_trace.span_id,
    sampled = current_trace.sampled
}

headers_module.inject_trace_headers(request_headers, inject_trace_data, custom_baggage, {
    include_traceparent = true
})

print("✅ Injected headers into outgoing request:")
for key, value in pairs(request_headers) do
    if key:lower():find("sentry") or key:lower():find("baggage") or key:lower():find("traceparent") then
        print("   " .. key .. ": " .. value)
    end
end

-- Example 6: Trace propagation targets
print("\n🎯 Example 6: Trace Propagation Targets")
print("--------------------------------------")

local urls_to_test = {
    "https://api.example.com/users",
    "https://internal.company.com/data",  
    "https://cdn.external.com/assets",
    "https://auth.internal.com/tokens",
    "http://localhost:8080/api",
    "https://analytics.thirdparty.com/events"
}

for _, url in ipairs(urls_to_test) do
    local headers = tracing.get_request_headers(url)
    local will_propagate = next(headers) ~= nil
    print("   " .. url .. " → " .. (will_propagate and "✅ Will propagate" or "❌ Will NOT propagate"))
end

-- Example 7: W3C traceparent compatibility
print("\n🌐 Example 7: W3C Traceparent Compatibility")
print("------------------------------------------")

-- Parse W3C traceparent header
local w3c_headers = {
    ["traceparent"] = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
}

local w3c_continued = tracing.continue_trace_from_request(w3c_headers)
print("✅ Continued from W3C traceparent:")
print("   Trace ID: " .. w3c_continued.trace_id)
print("   Parent Span: " .. w3c_continued.parent_span_id)

-- Generate headers with W3C compatibility
local w3c_outgoing = tracing.get_request_headers("https://opentelemetry-service.com/api")
print("✅ Generated W3C compatible headers:")
for key, value in pairs(w3c_outgoing) do
    print("   " .. key .. ": " .. value)
end

-- Example 8: Header validation and error handling
print("\n🛡️ Example 8: Header Validation and Error Handling")
print("-------------------------------------------------")

local invalid_headers = {
    "invalid-format",
    "too-short-trace",
    "1234567890abcdef1234567890abcdef-too-short",
    "not-hex-characters!@#$%^&*()123456-abcdef1234567890-1",
    "1234567890abcdef1234567890abcdef-abcdef1234567890-invalid-sampled"
}

print("✅ Testing invalid header formats:")
for _, header in ipairs(invalid_headers) do
    local parsed = headers_module.parse_sentry_trace(header)
    print("   '" .. header:sub(1, 30) .. (#header > 30 and "..." or "") .. "' → " .. 
          (parsed and "Valid" or "Invalid (rejected)"))
end

-- Capture final event with trace context
sentry.capture_message("Headers demo completed - trace propagation verified", "info")

print("\n🎉 Headers and Propagation Demo Complete!")
print("==========================================")
print("Key concepts demonstrated:")
print("• Sentry-trace header parsing and generation")
print("• Baggage header handling for additional context")
print("• W3C traceparent compatibility")
print("• Case-insensitive header extraction")
print("• Trace propagation target configuration")
print("• Header injection for outgoing requests")
print("• Header validation and error handling")
print("")
print("Check your Sentry dashboard to see how all events")
print("are connected through the trace context!")