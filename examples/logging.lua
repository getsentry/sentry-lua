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

-- Demonstrate exception capture with log correlation
print("\n8. Exception capture with log correlation:")
logger.error("Critical error occurred in payment processing")
logger.info("Attempting to capture exception with context")

-- Create a realistic nested function scenario similar to basic example
local function validate_card_number(card_number, cvv_code)
    logger.debug("Validating card number ending in %s", {string.sub(card_number, -4)})
    
    -- Simulate card validation
    if #card_number ~= 16 then
        error("CardValidationError: Invalid card number length")
    end
    
    if cvv_code < 100 or cvv_code > 999 then
        error("CardValidationError: Invalid CVV code")
    end
    
    logger.info("Card validation successful")
    return true
end

local function check_customer_limits(customer_id, amount, customer_tier)
    logger.debug("Checking limits for customer %s (tier: %s)", {customer_id, customer_tier})
    
    local daily_limits = {
        bronze = 500,
        silver = 2000,
        gold = 10000,
        platinum = 50000
    }
    
    local limit = daily_limits[customer_tier] or 100
    logger.info("Customer %s has daily limit of $%s", {customer_id, limit})
    
    if amount > limit then
        error("LimitExceededError: Transaction amount $" .. tostring(amount) .. " exceeds daily limit of $" .. tostring(limit))
    end
    
    return true
end

local function validate_payment(customer_id, amount, payment_method, card_info)
    logger.debug("Validating payment for customer %s", {customer_id})
    
    if not customer_id or customer_id == "" then
        error("ValidationError: Invalid customer ID provided")
    end
    
    if amount <= 0 then
        error("ValidationError: Invalid payment amount: $" .. tostring(amount))
    end
    
    -- Check customer limits first
    check_customer_limits(customer_id, amount, card_info.tier or "bronze")
    
    -- Validate card if it's a credit card payment
    if payment_method == "credit_card" then
        validate_card_number(card_info.number, card_info.cvv)
        
        if amount > 5000 then
            logger.warn("High value credit card transaction: $%s for customer %s", {amount, customer_id})
        end
    end
    
    logger.info("Payment validation completed for customer %s", {customer_id})
    return true
end

local function connect_to_gateway(gateway_config, retry_count)
    logger.debug("Connecting to payment gateway (attempt %s)", {retry_count})
    
    -- Simulate connection logic
    if retry_count > 3 then
        error("ConnectionError: Maximum retry attempts exceeded")
    end
    
    logger.info("Successfully connected to payment gateway")
    return {connection_id = "conn_" .. math.random(10000, 99999)}
end

local function process_payment_request(gateway_connection, transaction_data, timeout_seconds)
    logger.info("Processing payment request with timeout %s seconds", {timeout_seconds})
    
    -- Simulate the actual payment processing error
    if transaction_data.amount > 1000 then
        logger.error("Payment gateway timeout after %s seconds", {timeout_seconds})
        error("PaymentGatewayTimeoutError: Connection failed after " .. tostring(timeout_seconds) .. " seconds")
    end
    
    return {
        status = "approved",
        reference = "ref_" .. math.random(100000, 999999),
        auth_code = "auth_" .. math.random(1000, 9999)
    }
end

local function process_transaction(order_data, gateway_config)
    logger.info("Starting transaction processing for order %s", {order_data.order_id})
    
    -- Add some structured data
    logger.info("Order details", nil, {
        order_id = order_data.order_id,
        customer_id = order_data.customer_id,
        amount = order_data.amount,
        payment_method = order_data.payment_method,
        merchant_id = "merchant_789"
    })
    
    -- Validate the payment first
    validate_payment(order_data.customer_id, order_data.amount, order_data.payment_method, order_data.card_info)
    
    -- Connect to payment gateway
    local connection = connect_to_gateway(gateway_config, 1)
    logger.info("Using gateway connection %s", {connection.connection_id})
    
    -- Process the actual payment
    local payment_result = process_payment_request(connection, order_data, 30)
    
    logger.info("Transaction processed successfully with reference %s", {payment_result.reference})
    return {
        status = "success",
        transaction_id = "txn_" .. order_data.order_id,
        payment_reference = payment_result.reference
    }
end

local function handle_customer_order(customer_id, items, payment_info, gateway_config)
    logger.info("Processing customer order for %s with %s items", {customer_id, #items})
    
    local order_data = {
        order_id = "order_" .. math.random(1000, 9999),
        customer_id = customer_id,
        amount = payment_info.amount,
        payment_method = payment_info.method,
        items = items,
        card_info = payment_info.card_info
    }
    
    logger.debug("Created order data structure", nil, {
        order_id = order_data.order_id,
        item_count = #items,
        total_amount = payment_info.amount
    })
    
    return process_transaction(order_data, gateway_config)
end

-- Simulate a realistic order scenario that will trigger the exception
local customer_id = "customer_12345"
local items = {"laptop", "mouse", "keyboard"}
local payment_info = {
    amount = 1250,  -- This will trigger the timeout error
    method = "credit_card",
    card_info = {
        number = "4532123456789012",
        cvv = 123,
        tier = "gold"
    }
}

local gateway_config = {
    url = "https://payment-gateway.example.com",
    merchant_id = "merchant_789",
    timeout = 30
}

-- Capture exception with surrounding log context  
logger.info("Starting customer order processing workflow")

-- Create a function chain that will trigger the error deeper in the stack
local function process_order_workflow(customer_id, items, payment_info, gateway_config)
    logger.info("Initializing order workflow")
    return handle_customer_order(customer_id, items, payment_info, gateway_config)
end

local function execute_customer_transaction(customer_data, order_details, gateway_settings)
    logger.debug("Executing customer transaction with gateway settings")
    return process_order_workflow(customer_data.id, order_details.items, order_details.payment, gateway_settings)
end

local function start_business_process(customer_info, order_info, payment_config)
    logger.info("Starting business process for customer %s", {customer_info.id})
    return execute_customer_transaction(customer_info, order_info, payment_config)
end

-- Use the nested function chain to create multi-frame stack trace
local customer_data = {id = customer_id, tier = "gold"}
local order_details = {items = items, payment = payment_info}

-- Use xpcall with a custom error handler that captures the original stack trace
local function error_handler(err)
    logger.error("Order processing failed with error: %s", {tostring(err)})
    logger.error("Failed order details", nil, {
        customer_id = customer_id,
        item_count = #items,
        payment_amount = payment_info.amount,
        error_location = "payment_processing"
    })
    
    -- Capture the exception, this will use the current stack trace from where the error occurred
    sentry.capture_exception({
        type = "PaymentGatewayTimeoutError",
        message = tostring(err)
    })
    logger.info("Exception captured and sent to Sentry with full context")
    return err
end

local success, result = xpcall(function()
    return start_business_process(customer_data, order_details, gateway_config)
end, error_handler)

if success then
    logger.info("Order completed successfully: %s", {result.transaction_id})
end

-- Wait a moment for async operations
print("\nWaiting for logs and exceptions to be sent...")
os.execute("sleep 3")

print("\nExample completed! Check your Sentry project for:")
print("- Structured logs with parameters and attributes")
print("- Print statement captures")
print("- Exception with correlated log messages")
print("- Correlation with transaction traces")
print("- Different log levels and severity")