-- Platform-agnostic HTTP handling
local record HTTPResponse
   status: number
   body: string
   success: boolean
   error: string
end

local record HTTPRequest
   url: string
   method: string
   headers: {string: string}
   body: string
   timeout: number
end

-- Platform-specific HTTP implementations
local http_impl = nil
local http_type = "none"

-- Try different HTTP libraries
local function try_luasocket()
   local success, http = pcall(require, "socket.http")
   local success_https, https = pcall(require, "ssl.https") 
   local success_ltn12, ltn12 = pcall(require, "ltn12")
   if success and success_ltn12 then
      return {
         request = function(req: HTTPRequest): HTTPResponse
            local url = req.url
            local is_https = url:match("^https://")
            local http_lib = (is_https and success_https) and https or http
            
            if not http_lib then
               return {
                  success = false,
                  error = "HTTPS not supported",
                  status = 0,
                  body = ""
               }
            end
            
            local response_body = {}
            local result, status = http_lib.request({
               url = url,
               method = req.method,
               headers = req.headers,
               source = req.body and ltn12.source.string(req.body) or nil,
               sink = ltn12.sink.table(response_body)
            })
            
            return {
               success = result ~= nil,
               status = status or 0,
               body = table.concat(response_body or {}),
               error = result and "" or "HTTP request failed"
            }
         end
      }, "luasocket"
   end
   return nil, nil
end

local function try_roblox()
   if _G.game and _G.game.GetService then
      local HttpService = game:GetService("HttpService")
      if HttpService then
         return {
            request = function(req: HTTPRequest): HTTPResponse
               local success, response = pcall(function()
                  return HttpService:RequestAsync({
                     Url = req.url,
                     Method = req.method,
                     Headers = req.headers,
                     Body = req.body
                  })
               end)
               
               if success and response then
                  return {
                     success = true,
                     status = response.StatusCode,
                     body = response.Body,
                     error = ""
                  }
               else
                  return {
                     success = false,
                     status = 0,
                     body = "",
                     error = tostring(response)
                  }
               end
            end
         }, "roblox"
      end
   end
   return nil, nil
end

local function try_openresty()
   if _G.ngx then
      local success, httpc = pcall(require, "resty.http")
      if success then
         return {
            request = function(req: HTTPRequest): HTTPResponse
               local http_client = httpc:new()
               http_client:set_timeout((req.timeout or 30) * 1000)
               
               local res, err = http_client:request_uri(req.url, {
                  method = req.method,
                  body = req.body,
                  headers = req.headers
               })
               
               if res then
                  return {
                     success = true,
                     status = res.status,
                     body = res.body,
                     error = ""
                  }
               else
                  return {
                     success = false,
                     status = 0,
                     body = "",
                     error = err or "HTTP request failed"
                  }
               end
            end
         }, "openresty"
      end
   end
   return nil, nil
end

-- Try implementations in order
local implementations = {
   try_roblox,      -- Try Roblox first (most restrictive)
   try_openresty,   -- Try OpenResty 
   try_luasocket,   -- Try standard Lua
}

for _, impl_func in ipairs(implementations) do
   local impl, impl_type = impl_func()
   if impl then
      http_impl = impl
      http_type = impl_type
      break
   end
end

-- Fallback implementation (no-op)
if not http_impl then
   http_impl = {
      request = function(req: HTTPRequest): HTTPResponse
         return {
            success = false,
            status = 0,
            body = "",
            error = "No HTTP implementation available"
         }
      end
   }
   http_type = "none"
end

local function request(req: HTTPRequest): HTTPResponse
   return http_impl.request(req)
end

return {
   request = request,
   available = http_type ~= "none",
   type = http_type,
   HTTPRequest = HTTPRequest,
   HTTPResponse = HTTPResponse
}