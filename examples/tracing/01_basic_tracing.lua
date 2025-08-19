#!/usr/bin/env lua
---
--- Basic Distributed Tracing Example
--- Demonstrates core tracing concepts: starting traces, creating spans, and trace context
---

-- Set up path for running from repository root
package.path = "src/?.lua;src/?/init.lua;platforms/?.lua;platforms/?/init.lua;build/?.lua;build/?/init.lua;;" .. package.path

local sentry = require("sentry")
local tracing_platform = require("sentry.tracing.platform")

print("🎯 Basic Distributed Tracing Demo")
print("=================================")

-- Initialize Sentry with the test DSN
sentry.init({
    dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
    environment = "tracing-examples",
    debug = true
})

-- Initialize distributed tracing
local platform = tracing_platform.init({
    tracing = {
        trace_propagation_targets = {"example%.com", "localhost"},
        include_traceparent = true
    },
    auto_instrument = true
})

local tracing = platform.tracing

print("Platform: " .. platform.get_info().name)
print("Tracing supported: " .. tostring(tracing_platform.is_tracing_supported()))

-- Example 1: Starting a new trace
print("\n📍 Example 1: Starting a New Trace")
print("----------------------------------")

local trace_context = tracing.start_trace()
print("✅ New trace started")
print("   Trace ID: " .. trace_context.trace_id)
print("   Span ID: " .. trace_context.span_id)
print("   Is active: " .. tostring(tracing.is_active()))

-- Example 2: Getting trace information
print("\n📋 Example 2: Current Trace Information")
print("--------------------------------------")

local trace_info = tracing.get_current_trace_info()
if trace_info then
    print("✅ Current trace details:")
    print("   Trace ID: " .. trace_info.trace_id)
    print("   Span ID: " .. trace_info.span_id)
    print("   Parent Span: " .. (trace_info.parent_span_id or "none"))
    print("   Sampled: " .. tostring(trace_info.sampled))
else
    print("❌ No active trace")
end

-- Example 3: Creating child spans
print("\n👨‍👧‍👦 Example 3: Creating Child Spans")
print("----------------------------------")

local child_context = tracing.create_child()
print("✅ Child span created:")
print("   Parent trace: " .. trace_info.trace_id)
print("   Parent span: " .. trace_info.span_id)
print("   Child span: " .. child_context.span_id)

-- Example 4: Capturing events with trace context
print("\n📝 Example 4: Events with Trace Context")
print("--------------------------------------")

-- Capture a message - will automatically include trace context
sentry.capture_message("Basic tracing demo - user action", "info")
print("✅ Message captured with trace context")

-- Demonstrate manual trace context attachment by setting extra data
sentry.set_extra("demo_type", "basic_tracing")
sentry.set_extra("timestamp", os.time())

-- Get current trace info to show in logs
local trace_info = tracing.get_current_trace_info()
if trace_info then
    sentry.set_extra("trace_id", trace_info.trace_id)
    sentry.set_extra("span_id", trace_info.span_id)
    print("✅ Current trace context:")
    print("   Trace ID: " .. trace_info.trace_id)
    print("   Span ID: " .. trace_info.span_id)
end

sentry.capture_message("Manual trace context demo", "debug")
print("✅ Message sent with trace context")

-- Example 5: Simulating work with breadcrumbs
print("\n🍞 Example 5: Adding Breadcrumbs")
print("-------------------------------")

sentry.add_breadcrumb({
    message = "Starting data processing",
    category = "processing",
    level = "info"
})

-- Simulate some work
local function process_data()
    sentry.add_breadcrumb({
        message = "Loading data from source",
        category = "processing",
        level = "debug"
    })
    
    -- Simulate potential error
    if math.random() < 0.3 then
        error("Simulated processing error")
    end
    
    sentry.add_breadcrumb({
        message = "Data processing completed",
        category = "processing",
        level = "info"
    })
    
    return {processed = true, records = math.random(10, 100)}
end

local success, result = pcall(process_data)

if success then
    print("✅ Data processing completed: " .. result.records .. " records")
    sentry.capture_message("Data processing successful", "info")
else
    print("❌ Data processing failed: " .. result)
    sentry.capture_exception({
        type = "ProcessingError",
        message = result
    })
end

-- Example 6: Generating IDs for custom use
print("\n🔢 Example 6: Generating Custom IDs")
print("----------------------------------")

local ids = tracing.generate_ids()
print("✅ Generated IDs for custom spans:")
print("   Trace ID: " .. ids.trace_id)
print("   Span ID: " .. ids.span_id)

-- Example 7: Clearing traces
print("\n🧹 Example 7: Clearing Traces")
print("----------------------------")

print("Active before clear: " .. tostring(tracing.is_active()))
tracing.clear()
print("Active after clear: " .. tostring(tracing.is_active()))

-- Start a new trace for final demo
tracing.start_trace()
local final_trace = tracing.get_current_trace_info()
print("✅ New trace started after clear: " .. final_trace.trace_id)

-- Final message
sentry.capture_message("Basic tracing demo completed", "info")

print("\n🎉 Basic Tracing Demo Complete!")
print("===============================")
print("Check your Sentry dashboard to see the events and trace context.")
print("All events should be connected by trace IDs.")
print("")
print("Key concepts demonstrated:")
print("• Starting and managing traces")
print("• Creating child spans")
print("• Automatic trace context in events")
print("• Manual trace context attachment")
print("• Breadcrumb integration with traces")
print("• Error correlation within traces")