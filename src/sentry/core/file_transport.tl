local file_io = require("sentry.core.file_io")

local record FileTransport
   endpoint: string
   timeout: number
   headers: {string: string}
   file_path: string
   file_io: file_io.FileIO
   append_mode: boolean
end

function FileTransport:send(event: table): boolean, string
   local json = require("cjson")
   local serialized = json.encode(event)
   local timestamp = os.date("%Y-%m-%d %H:%M:%S")
   local content = string.format("[%s] %s\n", timestamp, serialized)
   
   if self.append_mode and self.file_io:file_exists(self.file_path) then
      local existing_content, read_err = self.file_io:read_file(self.file_path)
      if read_err ~= "" then
         return false, "Failed to read existing file: " .. read_err
      end
      content = existing_content .. content
   end
   
   local success, err = self.file_io:write_file(self.file_path, content)
   
   if success then
      return true, "Event written to file: " .. self.file_path
   else
      return false, "Failed to write event: " .. err
   end
end

function FileTransport:configure(config: table): FileTransport
   self.endpoint = (config as any).dsn or ""
   self.timeout = (config as any).timeout or 30
   self.file_path = (config as any).file_path or "sentry-events.log"
   self.append_mode = (config as any).append_mode ~= false
   
   if (config as any).file_io then
      self.file_io = (config as any).file_io
   else
      self.file_io = file_io.create_standard_file_io()
   end
   
   local dir_path = self.file_path:match("^(.*/)")
   if dir_path then
      local dir_success, dir_err = self.file_io:ensure_directory(dir_path)
      if not dir_success then
         print("Warning: Failed to create directory: " .. dir_err)
      end
   end
   
   self.headers = {
      ["Content-Type"] = "application/json",
      ["User-Agent"] = "sentry-lua-file/0.0.1"
   }
   
   return self
end

return FileTransport