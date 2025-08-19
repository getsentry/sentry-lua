-- Test Love2D HTTPS capabilities
local http = require("sentry.utils.http")

-- Test basic HTTPS
print("Testing HTTPS to httpbin.org...")
local response1 = http.request({
    url = "https://httpbin.org/get",
    method = "GET",
    timeout = 10
})
print("Result:", response1.success, response1.status, response1.error)

-- Test Sentry endpoint
print("\nTesting HTTPS to Sentry...")
local response2 = http.request({
    url = "https://o117736.ingest.us.sentry.io/api/4504930623356928/envelope/",
    method = "POST",
    headers = {"Content-Type: application/x-sentry-envelope"},
    body = "test",
    timeout = 10
})
print("Result:", response2.success, response2.status, response2.error)