local diagnostic_logger = require("core.diagnostic_logger")
local Transport = require("core.transport")
local Client = {}
Client.__index = Client

function Client:new(options)
    if not options then 
        diagnostic_logger.warn("Cannot create a Sentry client without options.")
        return nil
    end
    if not options.dsn then
        diagnostic_logger.warn("Cannot create a Sentry client without DSN.")
        return nil
    end
    local client = setmetatable({
        options = options,
        transport = Transport:new(options.dsn, options.transport_options),
    }, {__index = self})
    return client
end

function Client:capture_message(message)
    if not self.transport then
        diagnostic_logger.error("Transport not initialized")
        return nil
    end

    local event = {
        message = message,
        level = "info",
    }

    return self.transport:send_event(event)
end

return Client