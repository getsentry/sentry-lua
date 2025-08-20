--[[
  Sentry SDK for Roblox - Module Version
  
  Self-contained Sentry SDK module for Roblox projects.
  
  Usage:
    local sentry = require(this_module)
    sentry.init({dsn = "your-dsn"})
    sentry.capture_message("Hello!")
    sentry.capture_exception({type = "Error", message = "Something went wrong"})
    sentry.set_user({id = "user123", username = "player"})
    sentry.set_tag("level", "1")
    sentry.add_breadcrumb({message = "Player started level", category = "game"})
]]--

local HttpService = game:GetService("HttpService")

-- Sentry SDK implementation
local sentry = {}
local client = nil

function sentry.init(config)
    config = config or {}
    
    if not config.dsn then
        warn("❌ No DSN provided to sentry.init()")
        return nil
    end
    
    client = {
        dsn = config.dsn,
        environment = config.environment or "roblox",
        release = config.release or "1.0.0",
        user = nil,
        tags = {},
        breadcrumbs = {}
    }
    
    print("🔧 Sentry initialized successfully")
    print("   Environment: " .. client.environment)
    print("   Release: " .. client.release)
    
    return client
end

function sentry.capture_message(message, level)
    if not client then
        warn("❌ Sentry not initialized - call sentry.init() first")
        return nil
    end
    
    level = level or "info"
    
    local event = {
        message = {
            message = message
        },
        level = level,
        timestamp = os.time(),
        environment = client.environment,
        release = client.release,
        platform = "roblox",
        server_name = "roblox-server",
        user = client.user,
        tags = client.tags,
        breadcrumbs = client.breadcrumbs,
        extra = {
            roblox_version = version(),
            place_id = tostring(game.PlaceId),
            job_id = game.JobId or "unknown"
        }
    }
    
    print("📨 Capturing message: " .. message .. " [" .. level .. "]")
    
    return sendEventToSentry(event)
end

function sentry.capture_exception(exception, level)
    if not client then
        warn("❌ Sentry not initialized")
        return nil
    end
    
    level = level or "error"
    
    local event = {
        exception = {
            values = {
                {
                    type = exception.type or "RobloxError",
                    value = exception.message or tostring(exception),
                    stacktrace = {
                        frames = {}
                    }
                }
            }
        },
        level = level,
        timestamp = os.time(),
        environment = client.environment,
        release = client.release,
        platform = "roblox",
        server_name = "roblox-server",
        user = client.user,
        tags = client.tags,
        breadcrumbs = client.breadcrumbs,
        extra = {
            roblox_version = version(),
            place_id = tostring(game.PlaceId),
            job_id = game.JobId or "unknown"
        }
    }
    
    print("🚨 Capturing exception: " .. (exception.message or tostring(exception)))
    
    return sendEventToSentry(event)
end

function sentry.set_user(user)
    if client then
        client.user = user
        print("👤 User context set: " .. (user.username or user.id or "unknown"))
    end
end

function sentry.set_tag(key, value)
    if client then
        client.tags[key] = tostring(value)
        print("🏷️ Tag set: " .. key .. " = " .. tostring(value))
    end
end

function sentry.add_breadcrumb(breadcrumb)
    if client then
        table.insert(client.breadcrumbs, {
            message = breadcrumb.message,
            category = breadcrumb.category or "default",
            level = breadcrumb.level or "info",
            timestamp = os.time(),
            data = breadcrumb.data
        })
        
        -- Keep only last 50 breadcrumbs
        if #client.breadcrumbs > 50 then
            table.remove(client.breadcrumbs, 1)
        end
        
        print("🍞 Breadcrumb added: " .. (breadcrumb.message or "no message"))
    end
end

-- Internal function to send events to Sentry
function sendEventToSentry(event)
    if not client or not client.dsn then
        print("📝 Would send event (no DSN): " .. HttpService:JSONEncode(event))
        return true
    end
    
    local success, result = pcall(function()
        -- Parse DSN to get project info
        local pattern = "https://([^@]+)@([^/]+)/(.+)"
        local key, host, path = client.dsn:match(pattern)
        
        if not key or not host or not path then
            error("Invalid DSN format")
        end
        
        -- Extract project ID from path
        local projectId = path:match("(%d+)")
        if not projectId then
            error("Could not extract project ID from DSN")
        end
        
        -- Build Sentry endpoint URL
        local url = "https://" .. host .. "/api/" .. projectId .. "/store/"
        
        -- Prepare headers (without Content-Type as Roblox doesn't allow it)
        local headers = {
            ["X-Sentry-Auth"] = string.format(
                "Sentry sentry_version=7, sentry_key=%s, sentry_client=roblox-sdk/1.0",
                key
            )
        }
        
        -- Send the event
        local payload = HttpService:JSONEncode(event)
        print("🌐 Sending to Sentry: " .. url)
        print("📡 Payload size: " .. #payload .. " bytes")
        
        local response = HttpService:PostAsync(url, payload, Enum.HttpContentType.ApplicationJson, false, headers)
        
        print("✅ Event sent successfully!")
        print("📊 Response: " .. string.sub(response or "no response", 1, 50) .. "...")
        
        return true
    end)
    
    if success then
        return true
    else
        warn("❌ Failed to send event: " .. tostring(result))
        print("💡 Common issues:")
        print("   - HTTP requests not enabled in Game Settings")
        print("   - Invalid DSN format")
        print("   - Network connectivity issues")
        return false
    end
end

return sentry