local file_io = require("sentry.core.file_io")

local record DefoldFileIO
end

function DefoldFileIO:write_file(path: string, content: string): boolean, string
   if not sys then
      return false, "Defold sys module not available"
   end
   
   local success, err = pcall(function()
      local save_path = sys.get_save_file("sentry", path)
      local file = io.open(save_path, "w")
      if file then
         file:write(content)
         file:close()
      else
         error("Failed to open file for writing")
      end
   end)
   
   if success then
      return true, "Event written to Defold save file"
   else
      return false, "Defold file error: " .. tostring(err)
   end
end

function DefoldFileIO:read_file(path: string): string, string
   if not sys then
      return "", "Defold sys module not available"
   end
   
   local success, result = pcall(function()
      local save_path = sys.get_save_file("sentry", path)
      local file = io.open(save_path, "r")
      if file then
         local content = file:read("*all")
         file:close()
         return content
      end
      return ""
   end)
   
   if success then
      return result or "", ""
   else
      return "", "Failed to read Defold file: " .. tostring(result)
   end
end

function DefoldFileIO:file_exists(path: string): boolean
   if not sys then
      return false
   end
   
   local save_path = sys.get_save_file("sentry", path)
   local file = io.open(save_path, "r")
   if file then
      file:close()
      return true
   end
   return false
end

function DefoldFileIO:ensure_directory(path: string): boolean, string
   return true, "Defold handles save directories automatically"
end

local function create_defold_file_io(): file_io.FileIO
   return setmetatable({}, {__index = DefoldFileIO}) as file_io.FileIO
end

return {
   DefoldFileIO = DefoldFileIO,
   create_defold_file_io = create_defold_file_io
}