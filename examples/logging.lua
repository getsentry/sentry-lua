#!/usr/bin/env lua

-- Example demonstrating Sentry logging functionality
-- This shows structured logging, print hooks, and log batching

-- Add build path for modules
package.path = "build/?.lua;build/?/init.lua;" .. package.path

local sentry = require("sentry")
local logger = require("sentry.logger")
local performance = require("sentry.performance")

-- Initialize Sentry with logging enabled
sentry.init({
    dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
    environment = "development",
    release = "logging-example@1.0.0",
    debug = true,
    
    -- Experimental logging configuration
    _experiments = {
        enable_logs = true,
        max_buffer_size = 5,  -- Small buffer for demo
        flush_timeout = 3.0,  -- Quick flush for demo
        hook_print = true     -- Hook print statements
    }
})

-- Initialize logger with configuration
logger.init({
    enable_logs = true,
    max_buffer_size = 5,
    flush_timeout = 3.0,
    hook_print = true,
    before_send_log = function(log_record)
        -- Example log filtering/modification
        if log_record.level == "debug" and log_record.body:find("sensitive") then
            print("[Logger] Filtering sensitive debug log")
            return nil  -- Filter out sensitive logs
        end
        return log_record
    end
})

print("=== Sentry Logging Example ===")
print("This example demonstrates various logging features\n")

-- Basic logging at different levels
print("1. Basic logging at different levels:")
logger.trace("This is a trace message for debugging")
logger.debug("User authentication process started")
logger.info("Application started successfully")
logger.warn("High memory usage detected: 85%")
logger.error("Failed to connect to external API")
logger.fatal("Critical system failure detected")

-- Structured logging with parameters
print("\n2. Structured logging with parameters:")
local user_id = "user_12345"
local action = "purchase"
local amount = 99.99

logger.info("User %s performed action %s with amount $%s", {user_id, action, amount})
logger.warn("API endpoint %s response time %sms exceeds threshold", {"/api/users", 1500})
logger.error("Database query failed for user %s with error %s", {user_id, "CONNECTION_TIMEOUT"})

-- Logging with additional attributes
print("\n3. Logging with additional attributes:")
logger.info("Order processed successfully", nil, {
    order_id = "order_789",
    customer_type = "premium",
    processing_time = 120,
    payment_method = "credit_card",
    is_express_shipping = true
})

logger.error("Payment processing failed", nil, {
    error_code = "CARD_DECLINED",
    attempts = 3,
    amount = 149.99,
    merchant_id = "merchant_456"
})

-- Demonstrate print hook functionality
print("\n4. Print statements (automatically captured as logs):")
print("This is a regular print statement that will be logged")
print("Debug info:", "status=active", "count=42")
print("Multiple", "arguments", "in", "print", "statement")

-- Logging within transactions (trace correlation)
print("\n5. Logging within transaction context:")
local transaction = performance.start_transaction("logging_demo", "example")

logger.info("Starting business process within transaction")

local span = transaction:start_span("data_processing", "Process user data")
logger.debug("Processing user data for user %s", {user_id})
logger.info("Data validation completed successfully")
span:finish("ok")

local payment_span = transaction:start_span("payment", "Process payment")
logger.warn("Payment provider response time high: %sms", {2100})
logger.error("Payment failed with error: %s", {"INSUFFICIENT_FUNDS"}, {
    retry_count = 2,
    fallback_available = true
})
payment_span:finish("error")

transaction:finish("error")

-- Demonstrate sensitive log filtering
print("\n6. Log filtering (sensitive logs are filtered out):")
logger.debug("Regular debug message")
logger.debug("This contains sensitive information and will be filtered")

-- Force flush before ending
print("\n7. Forcing log buffer flush:")
print("Current buffer status:", logger.get_buffer_status().logs, "logs pending")
logger.flush()

-- Wait a moment for async operations
print("\nWaiting for logs to be sent...")
os.execute("sleep 2")

print("\nExample completed! Check your Sentry project for the logged messages.")
print("Look for:")
print("- Structured logs with parameters and attributes")
print("- Print statement captures")
print("- Correlation with transaction traces")
print("- Different log levels and severity")