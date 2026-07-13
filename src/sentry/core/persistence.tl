---@class sentry.core.persistence
--- PersistenceProvider: durable storage for spooled envelopes in sandboxed
--- environments that cannot make outbound HTTP (WoW addons, Factorio mods,
--- locked-down consoles). A companion uploader later drains and delivers them.
---
--- Providers are plain tables of functions (no `self`) so they are trivial to
--- back onto a filesystem, a WoW SavedVariables table, Factorio script-output, etc.

local json = require("sentry.utils.json")

local record PersistenceProvider
   append: function(envelope: string): boolean, string
   read_all: function(): {string}
   remove_first: function(n: number)   -- drop the first n (delivered) records
   clear: function()
   size: function(): number
end

-- In-memory provider (tests / transient use).
local function memory_provider(): PersistenceProvider
   local store: {string} = {}
   return {
      append = function(envelope: string): boolean, string
         table.insert(store, envelope)
         return true, ""
      end,
      read_all = function(): {string}
         -- Return a copy so callers (e.g. the uploader clearing the spool)
         -- cannot mutate our backing store out from under themselves.
         local out: {string} = {}
         for i, v in ipairs(store) do
            out[i] = v
         end
         return out
      end,
      remove_first = function(n: number)
         for _ = 1, math.min(n, #store) do
            table.remove(store, 1)
         end
      end,
      clear = function()
         for i = #store, 1, -1 do
            store[i] = nil
         end
      end,
      size = function(): number
         return #store
      end
   }
end

-- Filesystem provider. Each envelope is stored as a JSON-encoded string on its
-- own line (so embedded newlines survive round-tripping). Oldest records are
-- evicted past `max_records`.
local function file_provider(file_io_impl: any, path: string, max_records: number): PersistenceProvider
   local cap = max_records or 1000

   local function read_all(): {string}
      local envelopes: {string} = {}
      if not file_io_impl:file_exists(path) then
         return envelopes
      end
      local content, err = file_io_impl:read_file(path)
      if err ~= "" or not content then
         return envelopes
      end
      for line in (content .. "\n"):gmatch("(.-)\n") do
         if line ~= "" then
            local ok, decoded = pcall(json.decode, line)
            if ok and decoded then
               table.insert(envelopes, decoded as string)
            end
         end
      end
      return envelopes
   end

   local function write_all(envelopes: {string})
      local lines: {string} = {}
      for _, e in ipairs(envelopes) do
         table.insert(lines, json.encode(e))
      end
      local body = table.concat(lines, "\n")
      if #lines > 0 then
         body = body .. "\n"
      end
      file_io_impl:write_file(path, body)
   end

   return {
      append = function(envelope: string): boolean, string
         local envelopes = read_all()
         table.insert(envelopes, envelope)
         while #envelopes > cap do
            table.remove(envelopes, 1)
         end
         write_all(envelopes)
         return true, ""
      end,
      read_all = read_all,
      remove_first = function(n: number)
         local envelopes = read_all()
         for _ = 1, math.min(n, #envelopes) do
            table.remove(envelopes, 1)
         end
         write_all(envelopes)
      end,
      clear = function()
         file_io_impl:write_file(path, "")
      end,
      size = function(): number
         return #read_all()
      end
   }
end

return {
   PersistenceProvider = PersistenceProvider,
   memory_provider = memory_provider,
   file_provider = file_provider
}
