local diagnostic_logger = {}

diagnostic_logger.debug = function(message)
    print("[Sentry] " .. message)
end

diagnostic_logger.warn = function(message)
    warn("[Sentry] " .. message)
end

diagnostic_logger.error = function(message)
    warn("[Sentry] ERROR: " .. message, 2)
    -- error("[Sentry] " .. message, 2)
end

return diagnostic_logger