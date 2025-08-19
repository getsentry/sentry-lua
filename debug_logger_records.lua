#!/usr/bin/env lua

-- Debug logger record creation
package.path = "build/?.lua;build/?/init.lua;" .. package.path

local sentry = require("sentry")
local logger = require("sentry.logger")
local envelope = require("sentry.utils.envelope")

-- Initialize
sentry.init({
    dsn = "https://6e6b321e9b334de79f0d56c54a0e2d94@o4505842095628288.ingest.us.sentry.io/4508485766955008",
    debug = true
})

logger.init({
    enable_logs = true,
    max_buffer_size = 1,
    flush_timeout = 0.1
})

print("Sending log...")
logger.info("Test log message")

-- Wait and check buffer
os.execute("sleep 1")
print("Buffer status:", logger.get_buffer_status().logs, "logs pending")

-- Manual flush
logger.flush()

print("Done")