local record StackFrame
   filename: string
   ["function"]: string  -- Sentry expects "function", not "function_name"
   lineno: number
   in_app: boolean
   vars: {string:any}  -- local variables and parameters
   abs_path: string
   context_line: string
   pre_context: {string}
   post_context: {string}
end

local record StackTrace
   frames: {StackFrame}
end

-- Read source context from a file  
local function get_source_context(filename: string, line_number: number): string, {string}, {string}
   local empty_array: {string} = {}
   
   if line_number <= 0 then
      return "", empty_array, empty_array
   end
   
   -- Try to open and read the file
   local file = io.open(filename, "r")
   if not file then
      return "", empty_array, empty_array
   end
   
   -- Read all lines into array (using dynamic indexing to avoid Teal issues)
   local all_lines: {any} = {}
   local line_count = 0
   for line in file:lines() do
      line_count = line_count + 1
      all_lines[line_count] = line
   end
   file:close()
   
   -- Extract context lines
   local context_line = ""
   local pre_context: {string} = {}
   local post_context: {string} = {}
   
   if line_number > 0 and line_number <= line_count then
      context_line = (all_lines[line_number] as string) or ""
      
      -- Get 5 lines before
      for i = math.max(1, line_number - 5), line_number - 1 do
         if i >= 1 and i <= line_count then
            table.insert(pre_context, (all_lines[i] as string) or "")
         end
      end
      
      -- Get 5 lines after  
      for i = line_number + 1, math.min(line_count, line_number + 5) do
         if i >= 1 and i <= line_count then
            table.insert(post_context, (all_lines[i] as string) or "")
         end
      end
   end
   
   return context_line, pre_context, post_context
end

local function get_stack_trace(skip_frames: number): StackTrace
   skip_frames = skip_frames or 0
   local frames: {StackFrame} = {}
   local level = 2 + (skip_frames or 0)
   
   while true do
      local info = debug.getinfo(level as integer, "nSluf")
      if not info then
         break
      end
      
      local filename = info.source or "unknown"
      if filename:sub(1, 1) == "@" then
         filename = filename:sub(2)
      elseif filename == "=[C]" then
         filename = "[C]"
      end
      
      -- Determine if this frame is part of the user's application
      local in_app = true
      if not info.source then
         in_app = false  -- No source info
      elseif filename == "[C]" then
         in_app = false  -- C function
      elseif info.source:match("sentry") then
         in_app = false  -- SDK code
      elseif filename:match("^/opt/homebrew") then
         in_app = false  -- Homebrew-installed libraries
      end
      
      -- Get function name with better fallback
      local function_name = info.name or "anonymous"
      if info.namewhat and info.namewhat ~= "" then
         function_name = info.name or "anonymous"
      elseif info.what == "main" then
         function_name = "<main>"
      elseif info.what == "C" then
         function_name = info.name or "<C function>"
      end
      
      -- Collect local variables and parameters
      local vars: {string:any} = {}
      if info.what == "Lua" and in_app then -- Only collect vars for user code
         -- Get parameters first (they're usually the first N locals)
         for i = 1, (info.nparams or 0) do
            local name, value = debug.getlocal(level as integer, i)
            if name and not name:match("^%(") then -- Skip internal vars like (*temporary)
               local safe_value = value
               local value_type = type(value)
               if value_type == "function" then
                  safe_value = "<function>"
               elseif value_type == "userdata" then
                  safe_value = "<userdata>"
               elseif value_type == "thread" then
                  safe_value = "<thread>"
               elseif value_type == "table" then
                  safe_value = "<table>"
               end
               vars[name] = safe_value
            end
         end
         
         -- Get other local variables (skip parameters we already got)
         for i = (info.nparams or 0) + 1, 20 do -- reasonable limit
            local name, value = debug.getlocal(level as integer, i)
            if not name then break end
            if not name:match("^%(") then -- Skip internal vars like (*temporary)
               local safe_value = value
               local value_type = type(value)
               if value_type == "function" then
                  safe_value = "<function>"
               elseif value_type == "userdata" then
                  safe_value = "<userdata>"
               elseif value_type == "thread" then
                  safe_value = "<thread>"
               elseif value_type == "table" then
                  safe_value = "<table>"
               end
               vars[name] = safe_value
            end
         end
      end
      
      -- Ensure line number is non-negative for Sentry compatibility
      local line_number = info.currentline or 0
      if line_number < 0 then
         line_number = 0
      end
      
      -- Get source context if this is an in-app frame with valid line number
      local context_line, pre_context, post_context = get_source_context(filename, line_number)
      
      local frame: StackFrame = {
         filename = filename,
         ["function"] = function_name,
         lineno = line_number,
         in_app = in_app,
         vars = vars,
         abs_path = filename,  -- For now, same as filename
         context_line = context_line,
         pre_context = pre_context,
         post_context = post_context
      }
      
      table.insert(frames, frame)
      level = level + 1
   end
   
   -- Invert frames for Sentry (outermost to innermost)
   local inverted_frames: {StackFrame} = {}
   for i = #frames, 1, -1 do
      table.insert(inverted_frames, frames[i])
   end
   
   return {frames = inverted_frames}
end

local function format_stack_trace(stack_trace: StackTrace): string
   local lines: {string} = {}
   
   for _, frame in ipairs(stack_trace.frames) do
      local line = string.format("  %s:%d in %s", 
         frame.filename, 
         frame.lineno as integer, 
         frame["function"])
      table.insert(lines, line)
   end
   
   return table.concat(lines, "\n")
end

local stacktrace = {
   get_stack_trace = get_stack_trace,
   format_stack_trace = format_stack_trace,
   StackTrace = StackTrace,
   StackFrame = StackFrame
}

return stacktrace