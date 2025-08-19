#!/usr/bin/env lua

-- Debug envelope creation
package.path = "build/?.lua;build/?/init.lua;" .. package.path

local sentry = require("sentry")
local logger = require("sentry.logger")
local envelope = require("sentry.utils.envelope")

-- Initialize
sentry.init({
    dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
    debug = true
})

logger.init({
    enable_logs = true,
    max_buffer_size = 1,
    flush_timeout = 1.0
})

-- Create a simple log record manually
local log_record = {
    timestamp = os.time(),
    trace_id = "12345678901234567890123456789012",
    level = "info",
    body = "Test message",
    attributes = {
        ["sentry.sdk.name"] = {value = "sentry.lua", type = "string"},
        ["sentry.sdk.version"] = {value = "0.0.1", type = "string"}
    },
    severity_number = 9
}

print("Debug: Creating envelope...")
local envelope_body = envelope.build_log_envelope({log_record})
print("Debug: Envelope created, length:", #envelope_body)
print("Debug: Envelope content preview:")
print(envelope_body:sub(1, 200) .. "...")

-- Try to send it
if sentry._client and sentry._client.transport then
    print("Debug: Attempting to send...")
    local success, err = sentry._client.transport:send_envelope(envelope_body)
    print("Debug: Send result:", success, "Error:", tostring(err))
else
    print("Debug: No client or transport available")
end