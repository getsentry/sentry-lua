#!/usr/bin/env lua

-- Test direct log sending via sentry.capture_message
package.path = "build/?.lua;build/?/init.lua;" .. package.path

local sentry = require("sentry")

-- Initialize
sentry.init({
    dsn = "https://6e6b321e9b334de79f0d56c54a0e2d94@o4505842095628288.ingest.us.sentry.io/4508485766955008",
    debug = true
})

print("Sending direct log message...")
sentry.capture_message("Direct log message from Lua SDK", "info")

print("Sending direct error...")
sentry.capture_exception(debug.traceback("Test error for logging demo"))

print("Waiting...")
os.execute("sleep 3")
print("Done")