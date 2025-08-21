-- Simple test to check Love2D working directory and file access
function love.load()
    print("=== Love2D Working Directory Test ===")
    
    -- Get current working directory
    local success, lfs = pcall(require, "lfs")
    if success then
        print("Current working directory (lfs):", lfs.currentdir())
    else
        print("lfs not available")
    end
    
    -- Try different ways to get working directory
    local handle = io.popen("pwd")
    if handle then
        local pwd = handle:read("*a"):gsub("\n", "")
        handle:close()
        print("Current working directory (pwd):", pwd)
    end
    
    -- Test file access
    print("\n=== File Access Test ===")
    
    local files_to_test = {
        "main.lua",
        "./main.lua", 
        "test_working_dir.lua",
        "./test_working_dir.lua",
        "sentry.lua",
        "./sentry.lua"
    }
    
    for _, filename in ipairs(files_to_test) do
        local file = io.open(filename, "r")
        if file then
            print("✅ Can read:", filename)
            file:close()
        else
            print("❌ Cannot read:", filename)
        end
    end
    
    -- Test directory listing
    print("\n=== Directory Listing ===")
    local handle2 = io.popen("ls -la")
    if handle2 then
        local output = handle2:read("*a")
        handle2:close()
        print("Directory contents:")
        print(output)
    end
    
    -- Quit after showing info
    love.event.quit()
end

function love.draw()
    -- Nothing to draw
end