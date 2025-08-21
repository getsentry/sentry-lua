#!/usr/bin/env lua

-- Test script to check package.preload entries
package.path = "examples/love2d/?.lua;build-single-file/?.lua;;"

print("=== Testing package.preload entries ===")

local sentry = require("sentry")

print("Available package.preload entries:")
for module_name, loader in pairs(package.preload) do
    if module_name:match("sentry") then
        print("  " .. module_name)
    end
end

print("\nTesting direct module loading:")

-- Test sentry.logger.init
local logger_success, logger = pcall(require, "sentry.logger.init") 
if logger_success then
    print("✅ sentry.logger.init loaded successfully")
    print("Logger type:", type(logger))
    
    if logger.info then
        print("✅ logger.info function available")
    end
else
    print("❌ sentry.logger.init failed:", logger)
end

-- Test sentry.tracing.init  
local tracing_success, tracing = pcall(require, "sentry.tracing.init")
if tracing_success then
    print("✅ sentry.tracing.init loaded successfully") 
    print("Tracing type:", type(tracing))
    
    if tracing.start_transaction then
        print("✅ tracing.start_transaction function available")
    end
else
    print("❌ sentry.tracing.init failed:", tracing)
end

-- Test sentry.performance.init
local perf_success, perf = pcall(require, "sentry.performance.init")
if perf_success then
    print("✅ sentry.performance.init loaded successfully")
    print("Performance type:", type(perf))
    
    if perf.start_transaction then
        print("✅ performance.start_transaction function available")
    end
else 
    print("❌ sentry.performance.init failed:", perf)
end