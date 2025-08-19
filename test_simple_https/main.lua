function love.load()
    local http = require("socket.http")
    local https = require("ssl.https")
    
    print("Testing basic HTTPS...")
    local result, status = https.request("https://httpbin.org/get")
    print("HTTPS Result:", result ~= nil, status)
    
    print("Testing HTTP...")
    local result2, status2 = http.request("http://httpbin.org/get") 
    print("HTTP Result:", result2 ~= nil, status2)
    
    love.event.quit()
end