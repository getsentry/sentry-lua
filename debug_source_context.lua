-- Debug version to test source context in Love2D-like environment
function love.load()
    print("=== Debug Source Context Test ===")
    
    local sentry = require("sentry")
    
    -- Initialize with debug logging  
    sentry.init({
        dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
        debug = true,
        enable_logs = true
    })
    
    -- Test debug.getinfo to see what file paths we get
    print("\n=== Debug Info Test ===")
    for level = 1, 5 do
        local info = debug.getinfo(level, "nSluf")
        if info then
            print(string.format("Level %d:", level))
            print("  source:", info.source or "nil")
            print("  short_src:", info.short_src or "nil")
            print("  name:", info.name or "nil")
            print("  what:", info.what or "nil")
            print("  currentline:", info.currentline or "nil")
            
            -- Test if we can resolve the source to a filename
            local filename = info.source or "unknown"
            if filename:sub(1, 1) == "@" then
                filename = filename:sub(2)
            end
            print("  resolved filename:", filename)
            
            -- Test if we can open this file
            local file = io.open(filename, "r")
            if file then
                print("  ✅ File can be opened")
                file:close()
            else
                print("  ❌ File cannot be opened")
                
                -- Try alternative paths
                local alt_paths = {
                    "./" .. filename,
                    "main.lua",
                    "./main.lua"
                }
                
                for _, alt_path in ipairs(alt_paths) do
                    local alt_file = io.open(alt_path, "r")
                    if alt_file then
                        print("  ✅ Alternative path works:", alt_path)
                        alt_file:close()
                        break
                    end
                end
            end
        else
            break
        end
        print("")
    end
    
    -- Now trigger an error to see what happens
    print("\n=== Triggering Test Error ===")
    
    -- This will cause an error on a specific line (around line 73-75)
    local function test_error()
        local x = nil
        return x.nonexistent -- Error here
    end
    
    local function wrapper()
        return test_error() -- Call from here
    end
    
    -- Capture the error
    local success, err = pcall(wrapper)
    if not success then
        print("Error captured:", err)
        
        -- Send to Sentry
        sentry.capture_exception({
            type = "DebugSourceContextError", 
            message = err
        })
        
        print("Error sent to Sentry")
    end
    
    -- Test logger
    print("\n=== Testing Logger ===")
    sentry.logger.info("Debug test info message")
    sentry.logger.warn("Debug test warning message") 
    sentry.logger.error("Debug test error message")
    
    print("Logger messages sent")
    
    sentry.flush()
    
    -- Quit after test
    love.event.quit()
end

function love.draw()
    -- Nothing to draw
end