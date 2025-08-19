#!/usr/bin/env lua
-- Basic distributed tracing example
-- Shows core tracing concepts: transactions, spans, and event correlation

package.path = "build/?.lua;build/?/init.lua;;" .. package.path

local sentry = require("sentry")
local performance = require("sentry.performance")

-- Initialize Sentry with correct DSN
sentry.init({
    dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
    debug = true,
    environment = "tracing-basic-example"
})

print("🎯 Basic Distributed Tracing Example")
print("====================================")

-- Example 1: Simple transaction
print("\n📦 Example 1: Simple Transaction")
local tx1 = performance.start_transaction("user_registration", "http.server")
print("✅ Started transaction:", tx1.transaction)

-- Simulate validation
local validation_span = performance.start_span("validation.input", "Validate email and password")
print("  → Validating user input...")
os.execute("sleep 0.05")
performance.finish_span("ok")

-- Simulate database operation
local db_span = performance.start_span("db.query", "INSERT INTO users")
print("  → Creating user record...")
os.execute("sleep 0.1")
performance.finish_span("ok")

-- Capture a success event within the transaction
sentry.capture_message("User registered successfully", "info")

performance.finish_transaction("ok")
print("✅ Transaction completed")

-- Example 2: Transaction with error
print("\n❌ Example 2: Transaction with Error")
local tx2 = performance.start_transaction("payment_processing", "task")
print("✅ Started transaction:", tx2.transaction)

-- Simulate payment validation
local validate_span = performance.start_span("payment.validate", "Validate credit card")
os.execute("sleep 0.03")
performance.finish_span("ok")

-- Simulate payment failure  
local charge_span = performance.start_span("payment.charge", "Charge credit card")
os.execute("sleep 0.08")

-- Capture error within the transaction
sentry.capture_exception({
    type = "PaymentError",
    message = "Card declined: insufficient funds"
}, "error")

performance.finish_span("internal_error")
performance.finish_transaction("internal_error")
print("✅ Transaction completed (with error)")

-- Example 3: Complex nested operations
print("\n🔢 Example 3: Complex Data Pipeline")
local tx3 = performance.start_transaction("data_processing", "task")
print("✅ Started transaction:", tx3.transaction)

-- Stage 1: Data extraction
local extract_span = performance.start_span("extract.data", "Extract from external API")
print("  → Extracting data...")

-- Nested HTTP call within extraction
local api_span = performance.start_span("http.client", "GET /api/users")
os.execute("sleep 0.04")
performance.finish_span("ok")
print("    → API call completed")

performance.finish_span("ok")
print("  → Extraction completed")

-- Stage 2: Data transformation
local transform_span = performance.start_span("transform.data", "Clean and normalize data")  
print("  → Transforming data...")
os.execute("sleep 0.06")
performance.finish_span("ok")

-- Stage 3: Data loading
local load_span = performance.start_span("load.data", "Load into data warehouse")
print("  → Loading data...")
os.execute("sleep 0.05")
performance.finish_span("ok")

-- Add breadcrumb and final message
sentry.add_breadcrumb({
    message = "Data pipeline completed",
    category = "processing",
    level = "info",
    data = { records_processed = 1250 }
})

sentry.capture_message("Data pipeline completed successfully", "info")

performance.finish_transaction("ok")
print("✅ Transaction completed")

print("\n🎉 Basic tracing examples completed!")
print("\nCheck your Sentry dashboard to see:")
print("• 3 transactions with different operations")
print("• Nested spans showing timing and hierarchy")
print("• Events correlated within transactions")
print("• Error handling within transaction context")