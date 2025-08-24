local diagnostic_logger = {}

diagnostic_logger.debug = function(message)
    print("[Sentry] " .. message)
end

diagnostic_logger.warn = function(message)
    warn("[Sentry] " .. message)
end

return diagnostic_logger