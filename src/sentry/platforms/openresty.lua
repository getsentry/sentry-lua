local M = { name = "openresty" }

local function safe_require(n)
  local ok, m = pcall(require, n)
  return ok and m or nil
end
local http = safe_require("resty.http")
if not http then error("http not available") end

function M.http_post(url, body, headers, opts)
  if not http then return nil, "resty.http not available" end
  local httpc = http.new()
  if opts and opts.timeout_ms then httpc:set_timeout(opts.timeout_ms) end
  local res, err = httpc:request_uri(url, {
    method = "POST",
    body = body or "",
    headers = headers or {},
    keepalive = not (opts and opts.keepalive == false),
  })
  if not res then return nil, err end
  return true, res.status, res.body, res.headers
end

function M.http_post_async(url, body, headers, opts, callback)
  ---@diagnostic disable-next-line: undefined-global
  ngx.thread.spawn(function()
    local ok, status, resp_body = M.http_post(url, body, headers, opts)
    if callback then callback(ok, status, resp_body) end
  end)
end

function M.timestamp()
  ---@diagnostic disable-next-line: undefined-global
  local now = ngx.now() -- seconds + fractional
  local sec = math.floor(now)
  local ms = math.floor((now - sec) * 1000 + 0.5)
  if ms == 1000 then
    ms = 0
    sec = sec + 1
  end
  local d = os.date("!*t", sec) -- UTC
  return string.format("%04d-%02d-%02dT%02d:%02d:%02d.%03dZ", d.year, d.month, d.day, d.hour, d.min, d.sec, ms)
end

return M
