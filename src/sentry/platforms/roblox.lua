-- NOTE: This module depends on the Roblox environment. It should only be loaded after verifying it is indeed on Roblox
---@diagnostic disable: undefined-global

local HttpService = game:GetService("HttpService")

local M = { name = "roblox" }

function M.timestamp()
  -- "2025-08-23T21:05:17.123Z"
  return DateTime.now():ToIsoDate()
end

function M.http_post(url, body, headers, _)
  local ok, res = pcall(function()
    return HttpService:RequestAsync({
      Url = url,
      Method = "POST",
      Headers = headers or {},
      Body = body or "",
    })
  end)
  if not ok then return nil, tostring(res) end
  return res.Success, res.StatusCode, res.Body, res.Headers
end

function M.sleep(ms)
  task.wait((ms or 0) / 1000)
  return true
end

return M
