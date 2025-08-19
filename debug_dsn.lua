#!/usr/bin/env lua

-- Debug DSN and endpoints
package.path = "build/?.lua;build/?/init.lua;" .. package.path

local sentry = require("sentry")

-- Initialize
sentry.init({
    dsn = "https://6e6b321e9b334de79f0d56c54a0e2d94@o4505842095628288.ingest.us.sentry.io/4508485766955008",
    debug = true
})

if sentry._client and sentry._client.transport then
    local transport = sentry._client.transport
    print("Debug: Endpoints:")
    print("  Regular endpoint:", transport.endpoint)
    print("  Envelope endpoint:", transport.envelope_endpoint)
    print("  DSN host:", transport.dsn and transport.dsn.host)
    print("  DSN project_id:", transport.dsn and transport.dsn.project_id)
    print("  DSN public_key:", transport.dsn and transport.dsn.public_key)
    
    print("\nDebug: Headers:")
    for k, v in pairs(transport.headers or {}) do
        print("  ", k, v)
    end
    
    print("\nDebug: Envelope Headers:")
    for k, v in pairs(transport.envelope_headers or {}) do
        print("  ", k, v)
    end
end

-- Test basic HTTP connectivity
print("\nTesting basic HTTP connectivity...")
local http_success, http_result = pcall(function()
    -- Try a simple HTTP request to test connectivity
    local http = require("socket.http")
    return http.request("https://httpbin.org/get")
end)
print("HTTP test result:", http_success, http_result and "SUCCESS" or "FAILED")