local record FileIO
   write_file: function(self: FileIO, path: string, content: string): boolean, string
   read_file: function(self: FileIO, path: string): string, string
   file_exists: function(self: FileIO, path: string): boolean
   ensure_directory: function(self: FileIO, path: string): boolean, string
end

local record StandardFileIO
end

function StandardFileIO:write_file(path: string, content: string): boolean, string
   local file, err = io.open(path, "w")
   if not file then
      return false, "Failed to open file: " .. tostring(err)
   end
   
   local success, write_err = file:write(content)
   file:close()
   
   if not success then
      return false, "Failed to write file: " .. tostring(write_err)
   end
   
   return true, "File written successfully"
end

function StandardFileIO:read_file(path: string): string, string
   local file, err = io.open(path, "r")
   if not file then
      return "", "Failed to open file: " .. tostring(err)
   end
   
   local content = file:read("*all")
   file:close()
   
   return content or "", ""
end

function StandardFileIO:file_exists(path: string): boolean
   local file = io.open(path, "r")
   if file then
      file:close()
      return true
   end
   return false
end

function StandardFileIO:ensure_directory(path: string): boolean, string
   local command = "mkdir -p " .. path
   local success = os.execute(command)
   
   if success then
      return true, "Directory created"
   else
      return false, "Failed to create directory"
   end
end

local function create_standard_file_io(): FileIO
   return setmetatable({}, {__index = StandardFileIO}) as FileIO
end

return {
   FileIO = FileIO,
   StandardFileIO = StandardFileIO,
   create_standard_file_io = create_standard_file_io
}