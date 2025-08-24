local diagnostic_logger = require("core.diagnostic_logger")
local Client = {}
Client.__index = Client

function Client:new(options)
    print("client:new")
    if not options then 
        diagnostic_logger.warn("Cannot create a Sentry client without options.")
        return nil
    end
    local client = setmetatable({
        options = options,
    }, {__index = self})
    return client
end

return Client