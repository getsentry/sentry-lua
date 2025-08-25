local platform = require("platforms")()
local logger = require("core.diagnostic_logger")

local Transport = {}
Transport.__index = Transport

function Transport:new(dsn, options)
  options = options or {}
  local transport = setmetatable({
    dsn = dsn,
    queue = {},
    max_queue_size = options.max_queue_size or 30,
    max_concurrent = options.max_concurrent or 5,
    timeout_ms = options.timeout_ms or 5000,
    processing = false,
    active_requests = 0,
  }, { __index = self })
  return transport
end

function Transport:_process_queue()
  if self.processing or #self.queue == 0 or self.active_requests >= self.max_concurrent then return end

  self.processing = true

  local event = table.remove(self.queue, 1)
  if event then
    self.active_requests = self.active_requests + 1
    platform.http_post_async(self.dsn, self:_serialize_event(event), {
      ["Content-Type"] = "application/json",
      ["User-Agent"] = "sentry-lua/1.0.0",
    }, { timeout_ms = self.timeout_ms }, function(ok, status, body)
      self.active_requests = self.active_requests - 1
      if not ok then
        local msg = "Failed to send event to Sentry: " .. tostring(status)
        if body and body ~= "" then msg = msg .. ", response: " .. tostring(body) end
        logger.error(msg)
      elseif status < 200 or status >= 300 then
        local msg = "Sentry responded with error status: " .. tostring(status)
        if body and body ~= "" then msg = msg .. ", response: " .. tostring(body) end
        logger.error(msg)
      else
        logger.debug("Event sent to Sentry, status: " .. tostring(status))
      end
      self:_process_queue()
    end)
  end

  self.processing = false

  if #self.queue > 0 and self.active_requests < self.max_concurrent then self:_process_queue() end
end

function Transport:_serialize_event(event)
  local serialized = '{"message":"' .. (event.message or "") .. '","timestamp":"' .. platform.timestamp() .. '"}'
  return serialized
end

function Transport:send_event(event)
  if #self.queue >= self.max_queue_size then
    logger.warn("Queue full, dropping event")
    return false
  end

  table.insert(self.queue, event)
  self:_process_queue()
  return true
end

return Transport
