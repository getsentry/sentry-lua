-- Test the amalg-generated single file
print("Testing amalg-generated sentry.lua...")

-- Set the Lua path to include our build directory for any missing modules
package.path = "build-single-file/?.lua;build/?.lua;build/?/init.lua;" .. package.path

local success, sentry = pcall(require, "sentry")

if success then
    print("✅ Successfully loaded sentry module")
    print("Type of sentry:", type(sentry))
    
    if type(sentry) == "table" then
        print("Available functions:")
        for k, v in pairs(sentry) do
            print("  " .. k .. ": " .. type(v))
        end
        
        if sentry.init then
            print("✅ sentry.init is available")
        else
            print("❌ sentry.init is missing")
        end
    else
        print("❌ sentry is not a table, got:", sentry)
    end
else
    print("❌ Failed to load sentry module:", sentry)
end