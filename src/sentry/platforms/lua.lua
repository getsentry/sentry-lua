-- NOTE: This module depends on the standard Lua environment. It should only be loaded after verifying it is indeed on standard Lua

local function ensure_https()
  local ok, https = pcall(require, "ssl.https")
  if ok then return https end

  -- Hacks to get the debugger to work on a mac
  local lr_path  = "~/.luarocks/share/lua/5.4/?.lua;~/.luarocks/share/lua/5.4/?/init.lua;/opt/homebrew/share/lua/5.4/?.lua;/opt/homebrew/share/lua/5.4/?/init.lua"
  local lr_cpath = "~/.luarocks/lib/lua/5.4/?.so;/opt/homebrew/lib/lua/5.4/?.so"

  if not package.path:find("/.luarocks/share/lua/5.4", 1, true) then
    package.path = package.path .. ";" .. lr_path
  end
  if not package.cpath:find("/.luarocks/lib/lua/5.4", 1, true) then
    package.cpath = package.cpath .. ";" .. lr_cpath
  end

  local ok2, https2 = pcall(require, "ssl.https")
  if ok2 then return https2 end

  -- Last resort: print why (helps when the debugger’s runtime/ABI mismatches)
  local msg = ("Cannot load ssl.https.\npackage.path=%s\npackage.cpath=%s"):format(package.path, package.cpath)
  io.stderr:write(msg.."\n")
  return nil
end

ensure_https()

local function tz_suffix(t)
  local z = os.date("%z", t or os.time()) or "+0000"
  assert(type(z) == "string")
  return string.format("%s%s:%s", z:sub(1,1), z:sub(2,3), z:sub(4,5))
end

local function safe_require(n) local ok, m = pcall(require, n); return ok and m or nil end
local https = safe_require("ssl.https")
if not https then error("https not available (install LuaSec: ssl.https)") end

local ltn12 = safe_require("ltn12")

local M = { name = "lua" }

function M.timestamp()
  local now, sec, ms
  if socket_ok and type(socket.gettime) == "function" then
    now = socket.gettime(); sec = now // 1; ms = math.floor((now - sec)*1000 + 0.5)
    if ms == 1000 then ms = 0; sec = sec + 1 end
  else
    sec, ms = os.time(), 0
  end
  local d = os.date("*t", sec)
  return string.format("%04d-%02d-%02dT%02d:%02d:%02d.%03d%s",
    d.year,d.month,d.day,d.hour,d.min,d.sec,ms,tz_suffix(sec))
end


local function set_timeout(lib, ms)
  if lib and ms then lib.TIMEOUT = math.max(0.001, ms/1000) end
end

local function request_with_optional_headers(lib, url, method, headers, body, timeout_ms)
  set_timeout(lib, timeout_ms)
  headers = headers or {}
  body    = body or ""

  if ltn12 then
    local chunks = {}
    local ok, code, resp_headers, status = lib.request{
      url = url,
      method = method,
      headers = headers,
      source = ltn12.source.string(body),
      sink   = ltn12.sink.table(chunks),
    }
    if not ok then return nil, tostring(code or "request failed") end
    return true, tonumber(code), table.concat(chunks), resp_headers
  end

  -- No ltn12: reject custom headers; allow body via 2-arg form
  for _ in pairs(headers) do
    return nil, "custom headers require ltn12 (install ltn12)"
  end

  local resp_body, code, resp_headers = lib.request(url, body)
  if not resp_body then return nil, tostring(code or "request failed") end
  return true, tonumber(code), resp_body, resp_headers
end

function M.http_post(url, body, headers, opts)
  opts = opts or {}
  local scheme = url:match("^([%a][%w+.-]*)://") or error("Only https connection is supported.")
    return request_with_optional_headers(https, url, "POST", headers, body, opts.timeout_ms)
end

return M
