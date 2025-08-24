-- NOTE: This module depends on the Defold environment. It should only be loaded after verifying it is indeed on Defold

local function tz_suffix(t)
  local z = os.date("%z", t or os.time()) or "+0000"
  return string.format("%s%s:%s", z:sub(1,1), z:sub(2,3), z:sub(4,5))
end

local M = { name = "defold" }

function M.timestamp()
  local sec = os.time()
  local ms  = 0 -- Defold core Lua lacks a standard ms wall clock
  local d   = os.date("*t", sec)
  return string.format("%04d-%02d-%02dT%02d:%02d:%02d.%03d%s",
    d.year,d.month,d.day,d.hour,d.min,d.sec,ms,tz_suffix(sec))
end

function M.http_post(url, body, headers, opts)
  headers = headers or {}
  local result, done = { ok=false }, false

---@diagnostic disable-next-line: undefined-global
  http.request(url, "POST", function(self, id, response)
    result.ok      = (response.status >= 200 and response.status < 400)
    result.status  = response.status
    result.body    = response.response
    result.headers = response.headers
    done = true
  end, headers, body or "")

  -- block until done (must be inside coroutine or engine update loop)
  while not done do coroutine.yield() end
  if not result.ok then return nil, tostring(result.status or "request failed") end
  return true, result.status, result.body, result.headers
end

function M.sleep(ms)
  local t0 = os.clock()
  local target = (ms or 0)/1000
  while os.clock() - t0 < target do coroutine.yield() end
  return true
end

return M
