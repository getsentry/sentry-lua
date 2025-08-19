#!/usr/bin/env lua

-- Debug transport details
package.path = "build/?.lua;build/?/init.lua;" .. package.path

local sentry = require("sentry")

-- Initialize
sentry.init({
    dsn = "https://6e6b321e9b334de79f0d56c54a0e2d94@o4505842095628288.ingest.us.sentry.io/4508485766955008",
    debug = true
})

print("Debug: Client type:", type(sentry._client))
if sentry._client then
    print("Debug: Transport type:", type(sentry._client.transport))
    if sentry._client.transport then
        print("Debug: Transport methods:")
        for k, v in pairs(sentry._client.transport) do
            print("  ", k, type(v))
        end
        
        -- Try to send a simple test event first
        print("\nTesting regular event send...")
        local test_event = {
            message = "Test event",
            level = "info",
            platform = "lua",
            sdk = {
                name = "sentry.lua",
                version = "0.0.1"
            }
        }
        
        local success, err = sentry._client.transport:send(test_event)
        print("Event send result:", success, "Error:", tostring(err))
    end
end