-- Test Love2D Sentry error reporting
local sentry = require("sentry")

function love.load()
    print("Initializing Sentry for error testing...")
    
    sentry.init({
        dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
        environment = "love2d-test",
        release = "test@1.0.0",
        debug = true
    })
    
    -- Send a test message
    sentry.capture_message("Love2D test started with lua-https", "info")
    
    -- Generate an actual error
    local function level3()
        error("Test error from Love2D with lua-https")
    end
    
    local function level2() 
        level3()
    end
    
    local function level1()
        level2() 
    end
    
    -- Try to catch and report the error
    local ok, err = pcall(level1)
    if not ok then
        sentry.capture_exception(err)
    end
    
    love.event.quit()
end