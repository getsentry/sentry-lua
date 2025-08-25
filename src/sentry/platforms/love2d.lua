---@diagnostic disable: undefined-global
-- NOTE: This module depends on the LǑVE environment. It should only be loaded after verifying it is indeed on love2d

local M = { name = "love2d" }

-- Required imports
local function safe_require(n)
  local ok, m = pcall(require, n)
  return ok and m or nil
end
local https = safe_require("ssl.https")
if not https then error("https not available (install LuaSec: ssl.https)") end
local ltn12 = safe_require("ltn12")
if not ltn12 then error("ltn12 not available (install ltn12)") end

local function tz_suffix(t)
  local z = os.date("%z", t or os.time()) or "+0000"
  assert(type(z) == "string")
  return string.format("%s%s:%s", z:sub(1, 1), z:sub(2, 3), z:sub(4, 5))
end

-- Try to grab LuaSocket once
local socket = safe_require("socket")

-- Capture baseline for love.timer blending if needed
local base_wall = os.time()
local base_mono = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0

-- Choose implementation once
local timestamp_impl
if socket and type(socket.gettime) == "function" then
  -- Best: LuaSocket with ms precision
  timestamp_impl = function()
    local now = socket.gettime()
    local sec = math.floor(now)
    local ms = math.floor((now - sec) * 1000 + 0.5)
    if ms == 1000 then
      ms, sec = 0, sec + 1
    end
    local d = os.date("*t", sec)
    return string.format("%04d-%02d-%02dT%02d:%02d:%02d.%03d%s", d.year, d.month, d.day, d.hour, d.min, d.sec, ms, tz_suffix(sec))
  end
elseif love and love.timer and love.timer.getTime then
  -- Fallback: blend os.time() with love.timer high-res clock
  timestamp_impl = function()
    local elapsed = love.timer.getTime() - base_mono
    local now = base_wall + elapsed
    local sec = math.floor(now)
    local ms = math.floor((now - sec) * 1000 + 0.5)
    if ms == 1000 then
      ms, sec = 0, sec + 1
    end
    local d = os.date("*t", sec)
    return string.format("%04d-%02d-%02dT%02d:%02d:%02d.%03d%s", d.year, d.month, d.day, d.hour, d.min, d.sec, ms, tz_suffix(sec))
  end
else
  -- Last resort: os.time() only
  timestamp_impl = function()
    local sec, ms = os.time(), 0
    local d = os.date("*t", sec)
    return string.format("%04d-%02d-%02dT%02d:%02d:%02d.%03d%s", d.year, d.month, d.day, d.hour, d.min, d.sec, ms, tz_suffix(sec))
  end
end

-- Public API
function M.timestamp() return timestamp_impl() end

local function set_timeout(lib, ms)
  if lib and ms then lib.TIMEOUT = math.max(0.001, ms / 1000) end
end

local function request_with_optional_headers(lib, url, headers, body, timeout_ms)
  set_timeout(lib, timeout_ms)
  headers = headers or {}
  body = body or ""

  if ltn12 then
    local chunks = {}
    local ok, code, resp_headers = lib.request({
      url = url,
      method = "POST",
      headers = headers,
      source = ltn12.source.string(body),
      sink = ltn12.sink.table(chunks),
    })
    if not ok then return nil, tostring(code or "request failed") end
    return true, tonumber(code), table.concat(chunks), resp_headers
  end

  local resp_body, code, resp_headers = lib.request(url, body)
  if not resp_body then return nil, tostring(code or "request failed") end
  return true, tonumber(code), resp_body, resp_headers
end

function M.http_post(url, body, headers, opts)
  opts = opts or {}
  return request_with_optional_headers(https, url, headers, body, opts.timeout_ms)
end

function M.http_post_async(url, body, headers, opts, callback)
  -- luacheck: no unused secondaries
  ---@diagnostic disable-next-line: unused-local
  local ok, status, resp_body, resp_headers = M.http_post(url, body, headers, opts)
  if callback then callback(ok, status, resp_body) end
end

return M
