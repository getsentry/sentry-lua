-- Direct test of lua-https to Sentry
function love.load()
    print("Testing direct lua-https to Sentry...")
    
    local https = require("https")
    
    -- Test with minimal envelope
    local envelope = '{"sent_at":"2025-08-19T17:00:00Z"}\n{"type":"event"}\n{"message":"Test from Love2D with lua-https"}'
    
    local status, body, headers = https.request("https://o117736.ingest.us.sentry.io/api/4504930623356928/envelope/", {
        method = "POST",
        headers = {
            ["Content-Type"] = "application/x-sentry-envelope",
            ["X-Sentry-Auth"] = "Sentry sentry_version=7, sentry_key=e247e6e48f8f482499052a65adaa9f6b, sentry_client=test-lua-https"
        },
        data = envelope
    })
    
    print("Status:", status)
    print("Body:", body)
    if headers then
        for k, v in pairs(headers) do
            print("Header " .. k .. ":", v)
        end
    end
    
    love.event.quit()
end