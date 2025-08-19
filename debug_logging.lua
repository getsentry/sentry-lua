#!/usr/bin/env lua

-- Debug logging to check transport
package.path = "build/?.lua;build/?/init.lua;" .. package.path

local sentry = require("sentry")
local logger = require("sentry.logger")

-- Initialize with debug
sentry.init({
    dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
    debug = true
})

-- Initialize logger
logger.init({
    enable_logs = true,
    max_buffer_size = 1,
    flush_timeout = 1.0,
    hook_print = false
})

print("Debug: Sentry client initialized:", sentry._client ~= nil)
if sentry._client then
    print("Debug: Transport available:", sentry._client.transport ~= nil)
    if sentry._client.transport then
        print("Debug: Send envelope available:", sentry._client.transport.send_envelope ~= nil)
    end
end

-- Try simple log
print("Sending simple log...")
logger.info("Test log message from Lua SDK")
logger.flush()

print("Waiting...")
os.execute("sleep 3")
print("Done")