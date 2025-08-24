-- If 'debug' is available (not everywhere, e.g: Roblox), use it to make 'require's call relative to local directory

local function this_dir()
  if type(debug) == "table" and type(debug.getinfo) == "function" then
    local info = debug.getinfo(1, "S")
    if info and type(info.source) == "string" and info.source:sub(1,1) == "@" then
      -- handle / and \ (Windows)
      return info.source:match("@(.*/)")
          or info.source:match("@(.*\\)")
    end
  end
  return nil
end

local dir = this_dir()
if dir then
  package.path = dir .. "?.lua;" .. dir .. "?/init.lua;" .. package.path
end

print("1")
local ok, info = pcall(debug.getinfo, 1, "S")
print("info.source" .. info.source)
print("info.source outside pcall" .. debug.getinfo(1, "S").source)
print("getinfo match" .. debug.getinfo(1, "S").source:match("@(.*/)"))

if ok and info and info.source:sub(1,1) == "@" then
    print("2")
    local dir = info.source:match("@(.*/)")
    package.path = dir .. "?.lua;" .. dir .. "?/init.lua;" .. package.path
end

local Client = require("core.client");

local sentry = {}

local function init(options)
    print("init")
    sentry._client = Client:new(options)
end
local function capture_message(message)
    if not sentry._client then
        print("Sentry SDK has not been initialized")
        return
    end
    print("capture_message")
end
local function capture_exception(exception)
    if not sentry._client then
        print("Sentry SDK has not been initialized")
        return
    end
    print("capture_exception")
end
local function add_breadcrumb(exception)
    if not sentry._client then
        print("Sentry SDK has not been initialized")
        return
    end
    print("add_breadcrumb")
end
local function with_scope(callback)
    if not sentry._client then
        print("Sentry SDK has not been initialized. Executing callback for program continuity but no error handling will be active")
        return
    end
    -- local scope = scope:clone()
    callback()
    print("with_scope")
end
local function set_tag(key, value)
    if not sentry._client then
        print("Sentry SDK has not been initialized")
        return
    end
    print("set_tag")
end
local function set_extra(key, value)
    if not sentry._client then
        print("Sentry SDK has not been initialized")
        return
    end
    print("set_extra")
end
local function set_user(key, value)
    if not sentry._client then
        print("Sentry SDK has not been initialized")
        return
    end
    print("set_user")
end
local function flush(key, value)
    if not sentry._client then
        print("Sentry SDK has not been initialized")
        return
    end
    print("flush")
end
local function close()
    print("close - calling flush")
    flush()
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