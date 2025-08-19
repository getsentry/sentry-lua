#!/usr/bin/env lua

-- Test simple error event to see if transport works
package.path = "build/?.lua;build/?/init.lua;" .. package.path

local sentry = require("sentry")

-- Initialize
sentry.init({
    dsn = "https://6e6b321e9b334de79f0d56c54a0e2d94@o4505842095628288.ingest.us.sentry.io/4508485766955008",
    debug = true
})

print("Sending test error...")
sentry.capture_message("Test message from Lua SDK")

print("Waiting for send...")
os.execute("sleep 3")
print("Done")