-- Platform-agnostic JSON handling
local json_lib = {}

-- Try to load JSON library with fallbacks
local json_impl = nil
local json_type = "none"

-- Try different JSON libraries in order of preference
local json_libraries = {
   {name = "cjson", type = "cjson"},
   {name = "dkjson", type = "dkjson"}, 
   {name = "json", type = "json"},
}

for _, lib in ipairs(json_libraries) do
   local success, json_module = pcall(require, lib.name)
   if success then
      json_impl = json_module
      json_type = lib.type
      break
   end
end

-- Roblox has built-in JSON
if not json_impl and _G.game and _G.game.GetService then
   local HttpService = game:GetService("HttpService")
   if HttpService then
      json_impl = {
         encode = function(obj) return HttpService:JSONEncode(obj) end,
         decode = function(str) return HttpService:JSONDecode(str) end
      }
      json_type = "roblox"
   end
end

-- Simple fallback JSON encoder (basic, but works)
if not json_impl then
   local function simple_encode(obj)
      if type(obj) == "string" then
         return '"' .. obj:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
      elseif type(obj) == "number" or type(obj) == "boolean" then
         return tostring(obj)
      elseif obj == nil then
         return "null"
      elseif type(obj) == "table" then
         local result = {}
         local is_array = true
         local array_index = 1
         
         -- Check if it's an array
         for k, _ in pairs(obj) do
            if k ~= array_index then
               is_array = false
               break
            end
            array_index = array_index + 1
         end
         
         if is_array then
            -- Array
            for i, v in ipairs(obj) do
               table.insert(result, simple_encode(v))
            end
            return "[" .. table.concat(result, ",") .. "]"
         else
            -- Object
            for k, v in pairs(obj) do
               if type(k) == "string" then
                  table.insert(result, '"' .. k .. '":' .. simple_encode(v))
               end
            end
            return "{" .. table.concat(result, ",") .. "}"
         end
      end
      return "null"
   end
   
   json_impl = {
      encode = simple_encode,
      decode = function(str)
         error("JSON decoding not supported in fallback mode")
      end
   }
   json_type = "fallback"
end

-- Unified interface
local function encode(obj)
   if json_type == "dkjson" then
      return json_impl.encode(obj)
   else
      return json_impl.encode(obj)
   end
end

local function decode(str)
   if json_type == "dkjson" then
      return json_impl.decode(str)
   else
      return json_impl.decode(str)
   end
end

return {
   encode = encode,
   decode = decode,
   available = json_impl ~= nil,
   type = json_type
}