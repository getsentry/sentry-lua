local file_io = require("sentry.core.file_io")

local record RobloxFileIO
end

function RobloxFileIO:write_file(path: string, content: string): boolean, string
   local success, err = pcall(function()
      local DataStoreService = game:GetService("DataStoreService")
      local datastore = DataStoreService:GetDataStore("SentryEvents")
      
      local timestamp = tostring(os.time())
      datastore:SetAsync(timestamp, content)
   end)
   
   if success then
      return true, "Event written to Roblox DataStore"
   else
      return false, "Roblox DataStore error: " .. tostring(err)
   end
end

function RobloxFileIO:read_file(path: string): string, string
   local success, result = pcall(function()
      local DataStoreService = game:GetService("DataStoreService")
      local datastore = DataStoreService:GetDataStore("SentryEvents")
      return datastore:GetAsync(path)
   end)
   
   if success then
      return result or "", ""
   else
      return "", "Failed to read from DataStore: " .. tostring(result)
   end
end

function RobloxFileIO:file_exists(path: string): boolean
   local content, err = self:read_file(path)
   return err == ""
end

function RobloxFileIO:ensure_directory(path: string): boolean, string
   return true, "Directories not needed for Roblox DataStore"
end

local function create_roblox_file_io(): file_io.FileIO
   return setmetatable({}, {__index = RobloxFileIO}) as file_io.FileIO
end

return {
   RobloxFileIO = RobloxFileIO,
   create_roblox_file_io = create_roblox_file_io
}