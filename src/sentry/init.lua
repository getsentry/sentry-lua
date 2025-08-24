-- If 'debug' is available (not everywhere, e.g: Roblox), use it to make 'require's call relative to local directory
if type(debug) == "table" and type(debug.getinfo) == "function" then
local info = debug.getinfo(1, "S")
    if info and type(info.source) == "string" and info.source:sub(1,1) == "@" then
        -- handle / and \ (Windows)
        local local_dir = info.source:match("@(.*/)") or info.source:match("@(.*\\)")
        if local_dir then
            package.path = local_dir .. "?.lua;" .. local_dir .. "?/init.lua;" .. package.path
        end
    end
end

local platform = require("platforms")()
print(platform.name, platform.timestamp())

local Client = require("core.client");
local Scope = require("core.scope");
local logger = require("core.diagnostic_logger");

local sentry = {}

local function init(options)
    logger.debug("init")
    sentry._client = Client:new(options)
    sentry._scope = Scope:new()
end
local function capture_message(message)
    if not sentry._client then
        logger.debug("Sentry SDK has not been initialized")
        return
    end
    return sentry._client:capture_message(message)
end
local function capture_exception(exception)
    if not sentry._client then
        logger.debug("Sentry not initialized. Call sentry.init() first.")
        return
    end
    logger.debug("capture_exception")
end
local function add_breadcrumb(exception)
    if not sentry._client then
        logger.debug("Sentry not initialized. Call sentry.init() first.")
        return
    end
    logger.debug("add_breadcrumb")
end
local function with_scope(callback)
    if not sentry._client then
        logger.debug("Sentry SDK has not been initialized. Executing callback for program continuity but no error handling will be active")
        return
    end

    logger.debug("with_scope")
    local new_scope = sentry._scope:clone()

    local success, result = pcall(callback, new_scope)

    if not success then
        logger.error("callback failed to run through with_scope: " .. result)
    end
end
local function set_tag(key, value)
    if not sentry._client then
        logger.debug("Sentry not initialized. Call sentry.init() first.")
        return
    end
    logger.debug("set_tag")
end
local function set_extra(key, value)
    if not sentry._client then
        logger.debug("Sentry not initialized. Call sentry.init() first.")
        return
    end
    logger.debug("set_extra")
end
local function set_user(key, value)
    if not sentry._client then
        logger.debug("Sentry not initialized. Call sentry.init() first.")
        return
    end
    logger.debug("set_user")
end
local function flush(key, value)
    if not sentry._client then
        logger.debug("Sentry not initialized. Call sentry.init() first.")
        return
    end
    logger.debug("flush")
end
local function close()
    if not sentry._client then
        logger.debug("Sentry not initialized. Call sentry.init() first.")
        return
    end
    logger.debug("close")
end

sentry.init = init;
sentry.capture_message = capture_message;
sentry.capture_exception = capture_exception;
sentry.add_breadcrumb = add_breadcrumb;
sentry.with_scope = with_scope;
sentry.set_tag = set_tag;
sentry.set_extra = set_extra;
sentry.set_user = set_user;
sentry.flush = flush;
sentry.close = close;

return sentry