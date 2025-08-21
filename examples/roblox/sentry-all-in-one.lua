--[[
  Sentry All-in-One for Roblox
  
  Complete Sentry integration using real SDK modules.
  Generated from built SDK - DO NOT EDIT MANUALLY
  
  To regenerate: ./scripts/generate-roblox-all-in-one.sh
  
  USAGE:
  1. Copy this entire file
  2. Paste into ServerScriptService as a Script  
  3. Update SENTRY_DSN below
  4. Enable HTTP requests: Game Settings → Security → "Allow HTTP Requests"
  5. Run the game (F5)
  
  API (same as other platforms):
    sentry.init({dsn = "your-dsn"})
    sentry.capture_message("Player died!", "error")
    sentry.capture_exception({type = "GameError", message = "Boss fight failed"})
    sentry.set_user({id = tostring(player.UserId), username = player.Name})
    sentry.set_tag("level", "10")
    sentry.add_breadcrumb({message = "Player entered dungeon", category = "navigation"})
]]--

-- ⚠️ UPDATE THIS WITH YOUR SENTRY DSN
local SENTRY_DSN = "https://your-key@your-org.ingest.sentry.io/your-project-id"

print("🚀 Starting Sentry All-in-One Integration")
print("DSN: ***" .. string.sub(SENTRY_DSN, -10))
print("=" .. string.rep("=", 40))

-- Embedded SDK Modules (from real build/)
-- This ensures we use the actual SDK code with proper version info


-- ============================================================================
-- VERSION MODULE (from build/sentry/version.lua)
-- ============================================================================

local function version()
    return "0.0.6"
end

-- ============================================================================
-- JSON UTILS (from build/sentry/utils/json.lua)
-- ============================================================================

local json = {}
local HttpService = game:GetService("HttpService")

function json.encode(obj)
    return HttpService:JSONEncode(obj)
end

function json.decode(str)  
    return HttpService:JSONDecode(str)
end

-- ============================================================================
-- DSN UTILS (adapted from build/sentry/utils/dsn.lua)
-- ============================================================================

local dsn_utils = {}

function dsn_utils.parse_dsn(dsn_string)
    if not dsn_string or dsn_string == "" then
        return nil, "DSN is required"
    end
    
    local pattern = "https://([^@]+)@([^/]+)/(.+)"
    local key, host, path = dsn_string:match(pattern)
    
    if not key or not host or not path then
        return nil, "Invalid DSN format"
    end
    
    local project_id = path:match("(%d+)")
    if not project_id then
        return nil, "Could not extract project ID"
    end
    
    return {
        key = key,
        host = host,
        project_id = project_id
    }, nil
end

function dsn_utils.build_ingest_url(dsn)
    return "https://" .. dsn.host .. "/api/" .. dsn.project_id .. "/store/"
end

function dsn_utils.build_auth_header(dsn)
    return string.format("Sentry sentry_version=7, sentry_key=%s, sentry_client=sentry-lua-roblox/%s", 
                        dsn.key, version())
end

-- ============================================================================
-- ROBLOX TRANSPORT (from build/sentry/platforms/roblox/transport.lua)
-- ============================================================================

local RobloxTransport = {}
RobloxTransport.__index = RobloxTransport

function RobloxTransport:new()
    local transport = setmetatable({
        dsn = nil,
        endpoint = nil, 
        headers = nil
    }, RobloxTransport)
    return transport
end

function RobloxTransport:configure(config)
    local dsn, err = dsn_utils.parse_dsn(config.dsn or "")
    if err then
        error("Invalid DSN: " .. err)
    end

    self.dsn = dsn
    self.endpoint = dsn_utils.build_ingest_url(dsn)
    self.headers = {
        ["User-Agent"] = "sentry-lua-roblox/" .. version(),
        ["X-Sentry-Auth"] = dsn_utils.build_auth_header(dsn),
    }
    return self
end

function RobloxTransport:send(event)
    if not _G.game then
        return false, "Not in Roblox environment"
    end

    local success_service, HttpService = pcall(function()
        return _G.game:GetService("HttpService") 
    end)

    if not success_service or not HttpService then
        return false, "HttpService not available in Roblox"
    end

    local body = json.encode(event)

    local success, response = pcall(function()
        return HttpService:PostAsync(self.endpoint, body,
            _G.Enum.HttpContentType.ApplicationJson,
            false,
            self.headers)
    end)

    if success then
        print("✅ Event sent successfully!")
        print("📊 Response: " .. string.sub(response or "", 1, 50) .. "...")
        return true, "Event sent via Roblox HttpService"
    else
        print("❌ Failed to send event: " .. tostring(response))
        return false, "Roblox HTTP error: " .. tostring(response)
    end
end

-- ============================================================================
-- SCOPE (from build/sentry/core/scope.lua)
-- ============================================================================

local Scope = {}
Scope.__index = Scope

function Scope:new()
    return setmetatable({
        user = nil,
        tags = {},
        extra = {},
        breadcrumbs = {},
        level = nil
    }, Scope)
end

function Scope:set_user(user)
    self.user = user
end

function Scope:set_tag(key, value)
    self.tags[key] = tostring(value)
end

function Scope:set_extra(key, value)
    self.extra[key] = value
end

function Scope:add_breadcrumb(breadcrumb)
    breadcrumb.timestamp = os.time()
    table.insert(self.breadcrumbs, breadcrumb)
    
    -- Keep only last 50 breadcrumbs
    if #self.breadcrumbs > 50 then
        table.remove(self.breadcrumbs, 1)
    end
end

function Scope:clone()
    local cloned = Scope:new()
    cloned.user = self.user
    cloned.level = self.level
    
    -- Deep copy tables
    for k, v in pairs(self.tags) do
        cloned.tags[k] = v
    end
    for k, v in pairs(self.extra) do
        cloned.extra[k] = v
    end
    for i, crumb in ipairs(self.breadcrumbs) do
        cloned.breadcrumbs[i] = crumb
    end
    
    return cloned
end

-- ============================================================================
-- CLIENT (from build/sentry/core/client.lua)
-- ============================================================================

local Client = {}
Client.__index = Client

function Client:new(config)
    if not config.dsn then
        error("DSN is required")
    end
    
    local client = setmetatable({
        transport = RobloxTransport:new(),
        scope = Scope:new(),
        config = config
    }, Client)
    
    client.transport:configure(config)
    
    print("🔧 Sentry client initialized")
    print("   Environment: " .. (config.environment or "production"))
    print("   Release: " .. (config.release or "unknown"))
    print("   SDK Version: " .. version())
    
    return client
end

function Client:capture_message(message, level)
    level = level or "info"
    
    local event = {
        message = {
            message = message
        },
        level = level,
        timestamp = os.time(),
        environment = self.config.environment or "production",
        release = self.config.release or "unknown", 
        platform = "roblox",
        sdk = {
            name = "sentry.lua",
            version = version()
        },
        server_name = "roblox-server",
        user = self.scope.user,
        tags = self.scope.tags,
        extra = self.scope.extra,
        breadcrumbs = self.scope.breadcrumbs,
        contexts = {
            roblox = {
                version = version(),
                place_id = tostring(game.PlaceId),
                job_id = game.JobId or "unknown"
            }
        }
    }
    
    print("📨 Capturing message: " .. message .. " [" .. level .. "]")
    
    return self.transport:send(event)
end

function Client:capture_exception(exception, level)
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
        environment = self.config.environment or "production",
        release = self.config.release or "unknown",
        platform = "roblox",
        sdk = {
            name = "sentry.lua",
            version = version()
        },
        server_name = "roblox-server",
        user = self.scope.user,
        tags = self.scope.tags,
        extra = self.scope.extra,
        breadcrumbs = self.scope.breadcrumbs,
        contexts = {
            roblox = {
                version = version(),
                place_id = tostring(game.PlaceId),
                job_id = game.JobId or "unknown"
            }
        }
    }
    
    print("🚨 Capturing exception: " .. (exception.message or tostring(exception)))
    
    return self.transport:send(event)
end

function Client:set_user(user)
    self.scope:set_user(user)
    print("👤 User context set: " .. (user.username or user.id or "unknown"))
end

function Client:set_tag(key, value)
    self.scope:set_tag(key, value)
    print("🏷️ Tag set: " .. key .. " = " .. tostring(value))
end

function Client:set_extra(key, value)
    self.scope:set_extra(key, value)
    print("📝 Extra set: " .. key)
end

function Client:add_breadcrumb(breadcrumb)
    self.scope:add_breadcrumb(breadcrumb)
    print("🍞 Breadcrumb added: " .. (breadcrumb.message or "no message"))
end

-- ============================================================================
-- MAIN SENTRY API (from build/sentry/init.lua)
-- ============================================================================

local sentry = {}

function sentry.init(config)
    if not config or not config.dsn then
        error("Sentry DSN is required")
    end
    
    sentry._client = Client:new(config)
    return sentry._client
end

function sentry.capture_message(message, level)
    if not sentry._client then
        error("Sentry not initialized. Call sentry.init() first.")
    end
    
    return sentry._client:capture_message(message, level)
end

function sentry.capture_exception(exception, level)
    if not sentry._client then
        error("Sentry not initialized. Call sentry.init() first.")
    end
    
    return sentry._client:capture_exception(exception, level)
end

function sentry.set_user(user)
    if sentry._client then
        sentry._client:set_user(user)
    end
end

function sentry.set_tag(key, value)
    if sentry._client then
        sentry._client:set_tag(key, value)
    end
end

function sentry.set_extra(key, value)
    if sentry._client then
        sentry._client:set_extra(key, value)
    end
end

function sentry.add_breadcrumb(breadcrumb)
    if sentry._client then
        sentry._client:add_breadcrumb(breadcrumb)
    end
end

function sentry.flush()
    -- No-op for Roblox (HTTP is immediate)
end

function sentry.close()
    if sentry._client then
        sentry._client = nil
    end
end

-- Initialize Sentry with provided DSN
print("\n🔧 Initializing Sentry...")
sentry.init({
    dsn = SENTRY_DSN,
    environment = "roblox-production",
    release = "1.0.0"
})

-- Run integration tests using real SDK API
print("\n🧪 Running integration tests...")

-- Test message capture
sentry.capture_message("All-in-one integration test message", "info")

-- Test user context
sentry.set_user({
    id = "roblox-test-user",
    username = "TestPlayer"
})

-- Test tags
sentry.set_tag("integration", "all-in-one")
sentry.set_tag("platform", "roblox")

-- Test extra context
sentry.set_extra("test_type", "integration")

-- Test breadcrumbs  
sentry.add_breadcrumb({
    message = "Integration test started",
    category = "test",
    level = "info"
})

-- Test exception capture
sentry.capture_exception({
    type = "IntegrationTestError",
    message = "Test exception from all-in-one integration"
})

-- Make sentry available globally for easy access
_G.sentry = sentry

print("\n🎉 ALL-IN-ONE INTEGRATION COMPLETED!")
print("=" .. string.rep("=", 40))
print("📊 Check your Sentry dashboard for test events")
print("🔗 Dashboard: https://sentry.io/")
print("")
print("💡 MANUAL TESTING COMMANDS (real SDK API):")
print("sentry.capture_message('Hello World!', 'info')")
print("sentry.capture_exception({type = 'TestError', message = 'Manual error'})")
print("sentry.set_user({id = '123', username = 'YourName'})")
print("sentry.set_tag('level', '5')")
print("sentry.add_breadcrumb({message = 'Test action', category = 'test'})")
print("")
print("✅ Integration ready - uses real SDK " .. version() .. "!")
